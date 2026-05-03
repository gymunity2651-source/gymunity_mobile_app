import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  buildCoachClientContext,
  buildOrchestratorInput,
  needsVisibilityPermissionResponse,
  normalizeCoachCopilotResponse,
  obj,
  str,
  supportedRequestType,
  type CoachCopilotRequestType,
} from "./engine.ts";

type AuthUser = { id: string };

type HandlerDeps = {
  authenticate?: (token: string) => Promise<AuthUser>;
  getProfileRole?: (userId: string) => Promise<string | null>;
  loadContext?: (
    input: {
      coachId: string;
      clientId: string;
      subscriptionId: string;
      requestType: CoachCopilotRequestType;
    },
  ) => Promise<Record<string, unknown>>;
  callOrchestrator?: (input: Record<string, unknown>) => Promise<unknown>;
  getEnv?: (name: string) => string;
};

type SupabasePair = {
  serviceSupabase: SupabaseClient;
  userSupabase: SupabaseClient;
};

if (import.meta.main) {
  Deno.serve((req) => handleTaiyoCoachClientBriefRequest(req));
}

export async function handleTaiyoCoachClientBriefRequest(
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
    if (role !== "coach") {
      return jsonResponse({
        error:
          "TAIYO coach client brief is available for coach accounts only.",
      }, 403);
    }

    const body = obj(await req.json().catch(() => ({})));
    const requestType = supportedRequestType(body.request_type);
    const clientId = str(body.client_id);
    const subscriptionId = str(body.subscription_id);
    if (!clientId || !subscriptionId) {
      return jsonResponse({
        request_type: requestType,
        status: "needs_more_context",
        error: "client_id and subscription_id are required.",
        metadata: {
          source: "supabase_edge_function",
          generated_at: new Date().toISOString(),
        },
      }, 400);
    }

    const loadContext = deps.loadContext ||
      ((input) => loadCoachClientContext(getClients().userSupabase, input));
    const rawContext = await loadContext({
      coachId: user.id,
      clientId,
      subscriptionId,
      requestType,
    });
    const context = buildCoachClientContext(user.id, rawContext, {
      clientId,
      subscriptionId,
      requestType,
    });

    if (!context.visibility_confirmed) {
      return jsonResponse(
        needsVisibilityPermissionResponse(requestType, context, {
          debug: debugContext,
        }),
      );
    }

    const callOrchestrator = deps.callOrchestrator || callTaiyoOrchestrator;
    const aiOutput = await callOrchestrator(
      buildOrchestratorInput(requestType, context),
    );
    const normalized = normalizeCoachCopilotResponse(
      aiOutput,
      context,
      requestType,
      { debug: debugContext },
    );

    return jsonResponse(normalized);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = errorStatus(message);
    safeLog("taiyo-coach-client-brief failed", {
      status,
      reason: publicError(message, status),
    });
    return jsonResponse(
      {
        request_type: "coach_client_brief",
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

async function loadCoachClientContext(
  supabase: SupabaseClient,
  input: {
    coachId: string;
    clientId: string;
    subscriptionId: string;
    requestType: CoachCopilotRequestType;
  },
) {
  const subscriptionRes = await supabase.from("subscriptions")
    .select(
      "id,member_id,coach_id,package_id,plan_name,status,checkout_status,started_at,activated_at,created_at,next_renewal_at",
    )
    .eq("id", input.subscriptionId)
    .eq("member_id", input.clientId)
    .eq("coach_id", input.coachId)
    .maybeSingle();
  if (subscriptionRes.error) throw new Error(subscriptionRes.error.message);
  if (!subscriptionRes.data) {
    throw new Error("Coach client subscription not found.");
  }

  const [workspaceRes, insightRes] = await Promise.all([
    supabase.rpc("get_coach_client_workspace", {
      target_subscription_id: input.subscriptionId,
    }),
    supabase.rpc("get_coach_member_insight", {
      target_member_id: input.clientId,
      target_subscription_id: input.subscriptionId,
    }),
  ]);
  for (const result of [workspaceRes, insightRes]) {
    if (result.error) throw new Error(result.error.message);
  }

  const workspace = obj(workspaceRes.data);
  const threads = Array.isArray(obj(workspace).threads)
    ? obj(workspace).threads as unknown[]
    : [];
  const firstThreadId = threads.map(obj).map((thread) => str(thread.id)).find(
    Boolean,
  );
  const messagesRes = firstThreadId
    ? await supabase.from("coach_messages")
      .select("id,thread_id,sender_user_id,sender_role,message_type,content,created_at")
      .eq("thread_id", firstThreadId)
      .order("created_at", { ascending: false })
      .limit(12)
    : { data: [], error: null };
  if (messagesRes.error) throw new Error(messagesRes.error.message);

  return {
    request_type: input.requestType,
    subscription: obj(subscriptionRes.data),
    workspace,
    visibility: obj(workspace.visibility),
    member_insight: obj(insightRes.data),
    messages: Array.isArray(messagesRes.data) ? messagesRes.data : [],
  };
}

export async function callTaiyoOrchestrator(
  input: Record<string, unknown>,
): Promise<unknown> {
  const endpoint = env("AZURE_FOUNDRY_PROJECT_ENDPOINT").replace(/\/+$/, "");
  const apiVersion = optionalEnv("AZURE_FOUNDRY_API_VERSION") || "2025-05-01";
  const agentId = optionalEnv("AZURE_FOUNDRY_AGENT_ID") ||
    await resolveAgentIdByName(endpoint, apiVersion);
  if (!agentId) {
    throw new Error(
      "Missing required env var: AZURE_FOUNDRY_AGENT_ID or AZURE_FOUNDRY_AGENT_NAME",
    );
  }

  const token = await azureBearerToken();
  const thread = await azureJson(
    `${endpoint}/threads?api-version=${encodeURIComponent(apiVersion)}`,
    token,
    { method: "POST", body: "" },
  );
  const threadId = str(obj(thread).id);
  if (!threadId) throw new Error("Azure Foundry did not create a thread.");

  await azureJson(
    `${endpoint}/threads/${encodeURIComponent(threadId)}/messages?api-version=${
      encodeURIComponent(apiVersion)
    }`,
    token,
    {
      method: "POST",
      body: JSON.stringify({
        role: "user",
        content: JSON.stringify(input),
      }),
    },
  );

  const run = await azureJson(
    `${endpoint}/threads/${encodeURIComponent(threadId)}/runs?api-version=${
      encodeURIComponent(apiVersion)
    }`,
    token,
    {
      method: "POST",
      body: JSON.stringify({
        assistant_id: agentId,
        additional_instructions:
          "You are the TAIYO Orchestrator. Return only one valid JSON object for coach_client_brief, checkin_reply_draft, or client_risk_summary. Do not include markdown. Draft suggestions only; never send messages. Respect visibility permissions and do not diagnose.",
      }),
    },
  );
  const runId = str(obj(run).id);
  if (!runId) throw new Error("Azure Foundry did not create a run.");

  await waitForRun(endpoint, apiVersion, token, threadId, runId);
  const messages = await azureJson(
    `${endpoint}/threads/${encodeURIComponent(threadId)}/messages?api-version=${
      encodeURIComponent(apiVersion)
    }`,
    token,
    { method: "GET" },
  );
  const text = extractAssistantText(messages);
  if (!text) throw new Error("Azure Foundry returned no assistant text.");
  return text;
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

  const staticToken = optionalEnv("AZURE_FOUNDRY_API_KEY") ||
    optionalEnv("AZURE_FOUNDRY_AGENT_TOKEN") ||
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
  if (
    lower.includes("coach accounts only") ||
    lower.includes("subscription not found")
  ) return 403;
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
  return "TAIYO coach client brief failed.";
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
