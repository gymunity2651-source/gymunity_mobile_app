import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { callFoundryOrchestrator } from "../_shared/foundry.ts";
import {
  briefPersistencePayload,
  buildMemberContext,
  buildOrchestratorInput,
  dateOnly,
  type MemberDailyContext,
  normalizeAiDailyBrief,
  type NormalizedDailyBrief,
  obj,
  str,
} from "./engine.ts";

type AuthUser = { id: string };

type HandlerDeps = {
  authenticate?: (token: string) => Promise<AuthUser>;
  getProfileRole?: (userId: string) => Promise<string | null>;
  loadContext?: (targetDate: string) => Promise<Record<string, unknown>>;
  saveDailyBrief?: (
    memberId: string,
    targetDate: string,
    rawContext: Record<string, unknown>,
    brief: NormalizedDailyBrief,
  ) => Promise<boolean>;
  callOrchestrator?: (input: Record<string, unknown>) => Promise<unknown>;
  getEnv?: (name: string) => string;
};

type SupabasePair = {
  serviceSupabase: SupabaseClient;
  userSupabase: SupabaseClient;
};

if (import.meta.main) {
  Deno.serve((req) => handleTaiyoDailyBriefRequest(req));
}

export async function handleTaiyoDailyBriefRequest(
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
        error: "TAIYO daily brief is available for member accounts only.",
      }, 403);
    }

    const body = obj(await req.json().catch(() => ({})));
    const targetDate = dateOnly(str(body.date) || str(body.target_date));

    const loadContext = deps.loadContext ||
      ((date: string) =>
        loadMemberCoachContext(getClients().userSupabase, date));
    const rawContext = await loadContext(targetDate);
    const memberContext = buildMemberContext(user.id, rawContext);

    const callOrchestrator = deps.callOrchestrator || callTaiyoOrchestrator;
    const aiOutput = await callOrchestrator(
      buildOrchestratorInput(memberContext),
    );
    const brief = normalizeAiDailyBrief(aiOutput, memberContext, {
      debug: debugContext,
    });

    let persisted = false;
    if (brief.status === "success" || brief.status === "blocked_for_safety") {
      const saveDailyBrief = deps.saveDailyBrief ||
        ((memberId, date, context, normalizedBrief) =>
          saveMemberDailyBrief(
            getClients().userSupabase,
            memberId,
            date,
            context,
            normalizedBrief,
          ));
      persisted = await saveDailyBrief(user.id, targetDate, rawContext, brief);
    }

    return jsonResponse({
      ...brief,
      metadata: {
        ...brief.metadata,
        persisted,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = errorStatus(message);
    safeLog("taiyo-daily-brief failed", {
      status,
      reason: publicError(message, status),
    });
    return jsonResponse(
      {
        request_type: "daily_member_brief",
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
  // The service client is used only to verify the bearer token with Supabase Auth.
  // User data queries use the same project key with the member JWT as Authorization,
  // so PostgREST/RPC calls still execute through the authenticated user's RLS scope.
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

async function loadMemberCoachContext(
  supabase: SupabaseClient,
  targetDate: string,
) {
  const { data, error } = await supabase.rpc("get_member_ai_coach_context", {
    input_target_date: targetDate,
  });
  if (error) throw new Error(error.message);
  return obj(data);
}

async function saveMemberDailyBrief(
  supabase: SupabaseClient,
  memberId: string,
  targetDate: string,
  rawContext: Record<string, unknown>,
  brief: NormalizedDailyBrief,
) {
  const payload = briefPersistencePayload(
    memberId,
    targetDate,
    rawContext,
    brief,
  );
  const { error } = await supabase
    .from("member_ai_daily_briefs")
    .upsert(payload, { onConflict: "member_id,brief_date" });
  if (error) throw new Error(error.message);
  return true;
}

export async function callTaiyoOrchestrator(
  input: Record<string, unknown>,
): Promise<unknown> {
  return await callFoundryOrchestrator(input, {
    additionalInstructions:
      "You are the TAIYO Orchestrator. Return only one valid JSON object for daily_member_brief. Do not include markdown.",
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
  if (
    lower.includes("timed out") || lower.includes("rate limit") ||
    lower.includes("429")
  ) return 429;
  return 500;
}

function publicError(message: string, status: number) {
  if (status === 401 || status === 403) return message;
  if (status === 429) {
    return "TAIYO is temporarily unavailable. Please try again shortly.";
  }
  if (message.startsWith("Missing required env var:")) return message;
  return "TAIYO daily brief failed.";
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

export type { MemberDailyContext };
