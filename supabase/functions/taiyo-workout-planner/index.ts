import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { callFoundryOrchestrator } from "../_shared/foundry.ts";
import {
  blockedForSafetyResponse,
  buildOrchestratorInput,
  buildPlannerContext,
  dateOnly,
  draftPersistencePayload,
  hasHighRiskSafetyFlags,
  missingCriticalPlannerAnswers,
  needsMoreContextResponse,
  type NormalizedWorkoutPlanner,
  normalizeWorkoutPlannerResponse,
  obj,
  type PlannerRequestType,
  publicResponse,
  shouldPersistDraft,
  str,
  supportedRequestType,
} from "./engine.ts";

type AuthUser = { id: string };

type HandlerDeps = {
  authenticate?: (token: string) => Promise<AuthUser>;
  getProfileRole?: (userId: string) => Promise<string | null>;
  loadContext?: (
    input: {
      memberId: string;
      targetDate: string;
      sessionId: string | null;
      draftId: string | null;
    },
  ) => Promise<Record<string, unknown>>;
  saveDraft?: (
    memberId: string,
    sessionId: string | null,
    normalized: NormalizedWorkoutPlanner,
  ) => Promise<{ persisted: boolean; draft_id?: string; session_id?: string }>;
  callOrchestrator?: (input: Record<string, unknown>) => Promise<unknown>;
  getEnv?: (name: string) => string;
};

type SupabasePair = {
  serviceSupabase: SupabaseClient;
  userSupabase: SupabaseClient;
};

if (import.meta.main) {
  Deno.serve((req) => handleTaiyoWorkoutPlannerRequest(req));
}

export async function handleTaiyoWorkoutPlannerRequest(
  req: Request,
  deps: HandlerDeps = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let clients: SupabasePair | null = null;
  const getEnv = deps.getEnv || env;
  const debugContext =
    optionalEnvWith(getEnv, "DEBUG_TAIYO_CONTEXT") === "true";

  try {
    const token = bearer(req);
    const getClients = () => {
      clients ??= createSupabaseClients(token, getEnv);
      return clients;
    };

    const authenticate = deps.authenticate ||
      ((authToken: string) =>
        authUser(getClients().serviceSupabase, authToken));
    const user = await authenticate(token);

    const getProfileRole = deps.getProfileRole ||
      ((userId: string) => loadProfileRole(getClients().userSupabase, userId));
    const role = await getProfileRole(user.id);
    if (role !== "member") {
      return jsonResponse({
        error: "TAIYO workout planner is available for member accounts only.",
      }, 403);
    }

    const body = obj(await req.json().catch(() => ({})));
    const requestType = supportedRequestType(body.request_type);
    const plannerAnswers = obj(body.planner_answers);
    const sessionId = str(body.session_id);
    const draftId = str(body.draft_id);
    const targetDate = dateOnly(str(body.date) || str(body.target_date));

    const loadContext = deps.loadContext ||
      ((input) => loadPlannerContext(getClients().userSupabase, input));
    const rawContext = await loadContext({
      memberId: user.id,
      targetDate,
      sessionId,
      draftId,
    });
    const plannerContext = buildPlannerContext(
      user.id,
      rawContext,
      plannerAnswers,
    );

    let normalized: NormalizedWorkoutPlanner;
    const missingCritical = requestType === "workout_plan_draft"
      ? missingCriticalPlannerAnswers(plannerAnswers)
      : [];
    if (missingCritical.length) {
      normalized = needsMoreContextResponse(
        requestType,
        plannerContext,
        missingCritical,
        { debug: debugContext },
      );
    } else if (hasHighRiskSafetyFlags(plannerContext.safety_flags)) {
      normalized = blockedForSafetyResponse(requestType, plannerContext, {
        debug: debugContext,
      });
    } else {
      const callOrchestrator = deps.callOrchestrator || callTaiyoOrchestrator;
      const aiOutput = await callOrchestrator(
        buildOrchestratorInput(requestType, plannerContext, plannerAnswers),
      );
      normalized = normalizeWorkoutPlannerResponse(
        aiOutput,
        plannerContext,
        requestType,
        { debug: debugContext },
      );
    }

    let persistence = { persisted: false } as {
      persisted: boolean;
      draft_id?: string;
      session_id?: string;
    };
    if (shouldPersistDraft(normalized)) {
      const saveDraft = deps.saveDraft ||
        ((memberId, targetSessionId, plannerResult) =>
          savePlannerDraft(
            getClients().serviceSupabase,
            memberId,
            targetSessionId,
            plannerResult,
          ));
      persistence = await saveDraft(user.id, sessionId, normalized);
    }

    return jsonResponse(publicResponse(normalized, persistence));
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = errorStatus(message);
    safeLog("taiyo-workout-planner failed", {
      status,
      reason: publicError(message, status),
    });
    return jsonResponse(
      {
        request_type: "workout_plan_draft",
        status: "error",
        error: publicError(message, status),
        metadata: {
          source: "supabase_edge_function",
          generated_at: new Date().toISOString(),
        },
      },
      status,
    );
  }
}

function createSupabaseClients(
  token: string,
  getEnv: (name: string) => string,
): SupabasePair {
  const url = getEnv("SUPABASE_URL");
  const serviceKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  const serviceSupabase = createClient(url, serviceKey, {
    auth: { persistSession: false },
  });
  const userSupabase = createClient(url, serviceKey, {
    auth: { persistSession: false },
    global: {
      headers: { Authorization: `Bearer ${token}` },
    },
  });
  return { serviceSupabase, userSupabase };
}

function env(name: string) {
  const value = Deno.env.get(name)?.trim() || "";
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function optionalEnv(name: string) {
  return Deno.env.get(name)?.trim() || "";
}

function optionalEnvWith(getEnv: (name: string) => string, name: string) {
  try {
    return getEnv(name)?.trim() || "";
  } catch {
    return optionalEnv(name);
  }
}

function bearer(req: Request) {
  const header = req.headers.get("Authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new Error("Missing auth token");
  return match[1].trim();
}

async function authUser(
  supabase: SupabaseClient,
  token: string,
): Promise<AuthUser> {
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) throw new Error("Unauthorized");
  return { id: data.user.id };
}

async function loadProfileRole(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from("profiles")
    .select("user_id,roles(code)")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return extractRoleCode(obj(data).roles);
}

async function loadPlannerContext(
  supabase: SupabaseClient,
  input: {
    memberId: string;
    targetDate: string;
    sessionId: string | null;
    draftId: string | null;
  },
) {
  const [
    coachContextRes,
    memoriesRes,
    draftRes,
    latestDraftRes,
    readinessRes,
    activeWorkoutRes,
  ] = await Promise.all([
    supabase.rpc("get_member_ai_coach_context", {
      input_target_date: input.targetDate,
    }),
    supabase.from("ai_user_memories")
      .select("memory_key,memory_value_json")
      .eq("user_id", input.memberId)
      .order("updated_at", { ascending: false })
      .limit(24),
    input.draftId
      ? supabase.from("ai_plan_drafts")
        .select(
          "id,status,assistant_message,missing_fields,extracted_profile_json,plan_json,session_id",
        )
        .eq("id", input.draftId)
        .eq("user_id", input.memberId)
        .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    !input.draftId && input.sessionId
      ? supabase.from("ai_plan_drafts")
        .select(
          "id,status,assistant_message,missing_fields,extracted_profile_json,plan_json,session_id",
        )
        .eq("session_id", input.sessionId)
        .eq("user_id", input.memberId)
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    supabase.from("member_daily_readiness_logs")
      .select(
        "log_date,readiness_score,energy_level,soreness_level,stress_level,note",
      )
      .eq("member_id", input.memberId)
      .order("log_date", { ascending: false })
      .limit(7),
    supabase.from("member_active_workout_sessions")
      .select("id,status,started_at,ended_at,plan_id,day_id,summary_json")
      .eq("member_id", input.memberId)
      .order("started_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);

  for (
    const result of [
      coachContextRes,
      memoriesRes,
      draftRes,
      latestDraftRes,
      readinessRes,
      activeWorkoutRes,
    ]
  ) {
    if ("error" in result && result.error) {
      throw new Error(result.error.message);
    }
  }

  return {
    coach_context: obj(coachContextRes.data),
    memories: Array.isArray(memoriesRes.data) ? memoriesRes.data : [],
    current_draft: obj(draftRes.data || latestDraftRes.data),
    recent_readiness: Array.isArray(readinessRes.data) ? readinessRes.data : [],
    active_workout_session: obj(activeWorkoutRes.data),
  };
}

async function savePlannerDraft(
  supabase: SupabaseClient,
  memberId: string,
  sessionId: string | null,
  normalized: NormalizedWorkoutPlanner,
) {
  // ai_plan_drafts intentionally has no broad client-side insert policy.
  // After bearer auth, role validation, and explicit member ownership checks,
  // the service client persists this controlled AI draft for the authenticated user.
  const resolvedSessionId = await ensurePlannerSession(
    supabase,
    memberId,
    sessionId,
    normalized,
  );
  const payload = draftPersistencePayload(
    memberId,
    resolvedSessionId,
    normalized,
  );
  const { data, error } = await supabase
    .from("ai_plan_drafts")
    .insert(payload)
    .select("id")
    .single();
  if (error || !data?.id) {
    throw new Error(error?.message || "Unable to persist AI plan draft.");
  }
  const draftId = String(data.id);
  const { error: sessionError } = await supabase
    .from("chat_sessions")
    .update({
      planner_status: payload.status,
      latest_draft_id: draftId,
      planner_profile_json: payload.extracted_profile_json,
      updated_at: new Date().toISOString(),
      title: normalized.plan_json.title || "TAIYO Workout Plan",
    })
    .eq("id", resolvedSessionId)
    .eq("user_id", memberId);
  if (sessionError) throw new Error(sessionError.message);
  return {
    persisted: true,
    draft_id: draftId,
    session_id: resolvedSessionId,
  };
}

async function ensurePlannerSession(
  supabase: SupabaseClient,
  memberId: string,
  sessionId: string | null,
  normalized: NormalizedWorkoutPlanner,
) {
  if (sessionId) {
    const { data, error } = await supabase
      .from("chat_sessions")
      .select("id,user_id,session_type")
      .eq("id", sessionId)
      .eq("user_id", memberId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (data?.id && data.session_type === "planner") return String(data.id);
    throw new Error("Planner session not found.");
  }
  const { data, error } = await supabase
    .from("chat_sessions")
    .insert({
      user_id: memberId,
      title: normalized.plan_json.title || "TAIYO Workout Plan",
      session_type: "planner",
      planner_status: normalized.status === "blocked_for_safety"
        ? "unsafe_request"
        : "plan_ready",
      planner_profile_json: normalized.extracted_profile,
    })
    .select("id")
    .single();
  if (error || !data?.id) {
    throw new Error(error?.message || "Unable to create planner session.");
  }
  return String(data.id);
}

export async function callTaiyoOrchestrator(
  input: Record<string, unknown>,
): Promise<unknown> {
  return await callFoundryOrchestrator(input, {
    additionalInstructions:
      "You are the TAIYO Orchestrator. Return only one valid JSON object for workout_plan_draft or plan_review. Do not include markdown. Draft only; do not activate plans. The result must include title, summary, duration_weeks, level, weekly_structure[].days[].tasks[] with task titles and instructions, safety_notes, progression_rule, deload_rule, and activation_allowed. activation_allowed means safe for later user-reviewed activation in the app, not automatic activation.",
  });
}

async function resolveAgentIdByName(endpoint: string, apiVersion: string) {
  const agentName = optionalEnv("AZURE_FOUNDRY_AGENT_NAME");
  if (!agentName) return "";
  const token = await azureBearerToken();
  const response = await azureJson(
    `${endpoint}/assistants?api-version=${encodeURIComponent(apiVersion)}`,
    token,
    { method: "GET" },
  );
  const agents = Array.isArray(obj(response).data)
    ? obj(response).data as unknown[]
    : [];
  const match = agents.map(obj).find((agent) => str(agent.name) === agentName);
  return str(match?.id) || "";
}

async function azureBearerToken() {
  const tenantId = optionalEnv("AZURE_TENANT_ID");
  const clientId = optionalEnv("AZURE_CLIENT_ID");
  const clientSecret = optionalEnv("AZURE_CLIENT_SECRET");
  if (tenantId && clientId && clientSecret) {
    return await azureClientCredentialsToken(tenantId, clientId, clientSecret);
  }

  const staticToken = optionalEnv("AZURE_FOUNDRY_AGENT_TOKEN") ||
    optionalEnv("AGENT_TOKEN");
  if (staticToken) return staticToken;

  throw new Error(
    "Missing Azure auth env vars: provide Entra credentials or an agent bearer token.",
  );
}

async function azureClientCredentialsToken(
  tenantId: string,
  clientId: string,
  clientSecret: string,
) {
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: "client_credentials",
    scope: "https://ai.azure.com/.default",
  });
  const response = await fetchWithTimeout(
    `https://login.microsoftonline.com/${
      encodeURIComponent(tenantId)
    }/oauth2/v2.0/token`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    },
    15000,
  );
  const text = await response.text();
  if (!response.ok) {
    throw new Error(
      `Azure token request failed with status ${response.status}.`,
    );
  }
  const accessToken = str(obj(parseJson(text)).access_token);
  if (!accessToken) {
    throw new Error("Azure token response did not include an access token.");
  }
  return accessToken;
}

async function waitForRun(
  endpoint: string,
  apiVersion: string,
  token: string,
  threadId: string,
  runId: string,
) {
  const started = Date.now();
  const timeoutMs = Number(optionalEnv("AZURE_FOUNDRY_RUN_TIMEOUT_MS")) ||
    60000;
  while (Date.now() - started < timeoutMs) {
    const run = obj(
      await azureJson(
        `${endpoint}/threads/${encodeURIComponent(threadId)}/runs/${
          encodeURIComponent(runId)
        }?api-version=${encodeURIComponent(apiVersion)}`,
        token,
        { method: "GET" },
      ),
    );
    const status = str(run.status) || "";
    if (status === "completed") return;
    if (["failed", "cancelled", "expired"].includes(status)) {
      throw new Error(`Azure Foundry run ended with status ${status}.`);
    }
    if (status === "requires_action") {
      throw new Error(
        "Azure Foundry run requires tool action that this Edge Function does not handle.",
      );
    }
    await sleep(1200);
  }
  throw new Error("Azure Foundry run timed out.");
}

async function azureJson(
  url: string,
  bearerToken: string,
  init: { method: string; body?: BodyInit | null },
) {
  const response = await fetchWithTimeout(
    url,
    {
      method: init.method,
      headers: {
        "Authorization": `Bearer ${bearerToken}`,
        "Content-Type": "application/json",
      },
      body: init.body,
    },
    20000,
  );
  const text = await response.text();
  if (!response.ok) {
    throw new Error(
      `Azure Foundry request failed with status ${response.status}.`,
    );
  }
  return text ? parseJson(text) : {};
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort("timed out"), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) {
      throw new Error("Azure Foundry request timed out.");
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

function extractAssistantText(messages: unknown) {
  const rows = Array.isArray(obj(messages).data)
    ? obj(messages).data as unknown[]
    : [];
  for (const row of rows.map(obj)) {
    if (str(row.role) !== "assistant") continue;
    const content = row.content;
    if (typeof content === "string") return content;
    for (const part of arrContent(content)) {
      const item = obj(part);
      const text = obj(item.text);
      const value = str(text.value) || str(item.text) || str(item.content);
      if (value) return value;
    }
  }
  return "";
}

function arrContent(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function errorStatus(message: string) {
  const lower = message.toLowerCase();
  if (message === "Missing auth token" || message === "Unauthorized") {
    return 401;
  }
  if (lower.includes("member accounts only")) return 403;
  if (lower.includes("unsupported request_type")) return 400;
  if (
    lower.includes("timed out") || lower.includes("rate limit") ||
    lower.includes("429")
  ) return 429;
  return 500;
}

function publicError(message: string, status: number) {
  if (status === 401 || status === 403 || status === 400) return message;
  if (status === 429) {
    return "TAIYO is temporarily unavailable. Please try again shortly.";
  }
  if (message.startsWith("Missing required env var:")) return message;
  return "TAIYO workout planner failed.";
}

function parseJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return {};
  }
}

function extractRoleCode(value: unknown) {
  const direct = obj(value);
  if (str(direct.code)) return str(direct.code);
  const first = Array.isArray(value) && value.length ? obj(value[0]) : {};
  return str(first.code);
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function safeLog(message: string, details: Record<string, unknown>) {
  console.error(message, details);
}
