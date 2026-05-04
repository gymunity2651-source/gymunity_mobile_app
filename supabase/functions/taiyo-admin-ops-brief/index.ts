import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { callFoundryOrchestrator } from "../_shared/foundry.ts";
import {
  type AdminOpsRequestType,
  blockedForSecurityResponse,
  buildAdminContext,
  buildOrchestratorInput,
  containsSecretRequest,
  needsMoreContextResponse,
  normalizeAdminOpsResponse,
  obj,
  str,
  supportedRequestType,
} from "./engine.ts";

type AuthUser = { id: string };

type HandlerDeps = {
  authenticate?: (token: string) => Promise<AuthUser>;
  getCurrentAdmin?: (userId: string) => Promise<Record<string, unknown> | null>;
  loadContext?: (
    input: {
      adminId: string;
      requestType: AdminOpsRequestType;
      paymentOrderId: string | null;
      subscriptionId: string | null;
      payoutId: string | null;
      limit: number;
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
  Deno.serve((req) => handleTaiyoAdminOpsBriefRequest(req));
}

export async function handleTaiyoAdminOpsBriefRequest(
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
  let requestType: AdminOpsRequestType = "admin_ops_brief";
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

    const getCurrentAdmin = deps.getCurrentAdmin ||
      (() => loadCurrentAdmin(getClients().userSupabase));
    const admin = await getCurrentAdmin(user.id);
    if (!admin || obj(admin).is_active === false) {
      return jsonResponse({
        error: "TAIYO admin ops brief is available for admins only.",
      }, 403);
    }

    const body = obj(await req.json().catch(() => ({})));
    requestType = supportedRequestType(body.request_type);
    if (containsSecretRequest(body)) {
      return jsonResponse(blockedForSecurityResponse(requestType));
    }

    const paymentOrderId = str(body.payment_order_id);
    const subscriptionId = str(body.subscription_id);
    const payoutId = str(body.payout_id);
    const limit = boundedLimit(body.limit);

    const scopedProblem = missingScope(
      requestType,
      paymentOrderId,
      subscriptionId,
      payoutId,
    );
    if (scopedProblem) {
      return jsonResponse(
        needsMoreContextResponse(
          requestType,
          scopedProblem.missingFields,
          scopedProblem.message,
        ),
        400,
      );
    }

    const loadContext = deps.loadContext ||
      ((input) => loadAdminOpsContext(getClients().userSupabase, input));
    const rawContext = await loadContext({
      adminId: user.id,
      requestType,
      paymentOrderId,
      subscriptionId,
      payoutId,
      limit,
    });
    const context = buildAdminContext(user.id, admin, rawContext, {
      requestType,
      paymentOrderId,
      subscriptionId,
      payoutId,
    });

    const callOrchestrator = deps.callOrchestrator || callTaiyoOrchestrator;
    const aiOutput = await callOrchestrator(
      buildOrchestratorInput(requestType, context),
    );
    const normalized = normalizeAdminOpsResponse(
      aiOutput,
      context,
      requestType,
      { debug: debugContext },
    );

    return jsonResponse(normalized);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = errorStatus(message);
    safeLog("taiyo-admin-ops-brief failed", {
      status,
      reason: publicError(message, status),
    });
    return jsonResponse(
      {
        request_type: requestType,
        status: "error",
        error: publicError(message, status),
        result: {
          issue_type: requestType,
          status_summary: publicError(message, status),
          risk_level: "low",
          recommended_admin_action: "",
          action_label: "",
          reason: "",
          audit_notes: [],
          manual_confirmation_required: true,
          sensitive_data_excluded: true,
        },
        data_quality: {
          missing_fields: [],
          confidence: "low",
        },
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

async function loadCurrentAdmin(supabase: SupabaseClient) {
  const { data, error } = await supabase.rpc("current_admin");
  if (error) throw new Error(error.message);
  return Object.keys(obj(data)).length ? obj(data) : null;
}

export async function loadAdminOpsContext(
  supabase: SupabaseClient,
  input: {
    adminId: string;
    requestType: AdminOpsRequestType;
    paymentOrderId: string | null;
    subscriptionId: string | null;
    payoutId: string | null;
    limit: number;
  },
) {
  const rpcCalls: string[] = [];
  const callRpc = async (name: string, params?: Record<string, unknown>) => {
    rpcCalls.push(name);
    const { data, error } = await supabase.rpc(name, params);
    if (error) throw new Error(error.message);
    return data;
  };

  const context: Record<string, unknown> = {
    request_type: input.requestType,
    rpc_calls: rpcCalls,
  };

  if (input.requestType === "admin_ops_brief") {
    context.dashboard_summary = obj(await callRpc("admin_dashboard_summary"));
    context.audit_events = await listAuditEvents(callRpc, input.limit);
    return context;
  }

  if (input.requestType === "audit_explanation") {
    context.audit_events = await listAuditEvents(callRpc, input.limit);
    return context;
  }

  if (
    input.requestType === "payment_order_risk" ||
    input.requestType === "repair_recommendation"
  ) {
    if (input.paymentOrderId) {
      const payment = obj(
        await callRpc("admin_get_payment_order_details", {
          target_payment_order_id: input.paymentOrderId,
        }),
      );
      context.payment_order = payment;
      const derivedSubscriptionId = str(payment.subscription_id);
      const subscriptionId = input.subscriptionId || derivedSubscriptionId;
      if (subscriptionId) {
        context.subscriptions = await listSubscriptionsBySearch(
          callRpc,
          subscriptionId,
        );
      }
    } else if (input.subscriptionId) {
      context.subscriptions = await listSubscriptionsBySearch(
        callRpc,
        input.subscriptionId,
      );
    }
    context.audit_events = await listAuditEvents(
      callRpc,
      Math.min(input.limit, 20),
    );
    return context;
  }

  if (input.requestType === "payout_review") {
    context.payout = obj(
      await callRpc("admin_get_payout_details", {
        target_payout_id: input.payoutId,
      }),
    );
    return context;
  }

  return context;
}

async function listSubscriptionsBySearch(
  callRpc: (
    name: string,
    params?: Record<string, unknown>,
  ) => Promise<unknown>,
  search: string,
) {
  const rows = await callRpc("admin_list_subscriptions", {
    filters: {
      search,
      limit: 10,
    },
  });
  return Array.isArray(rows) ? rows : [];
}

async function listAuditEvents(
  callRpc: (
    name: string,
    params?: Record<string, unknown>,
  ) => Promise<unknown>,
  limit: number,
) {
  const rows = await callRpc("admin_list_audit_events", {
    filters: { limit },
  });
  return Array.isArray(rows) ? rows : [];
}

export async function callTaiyoOrchestrator(
  input: Record<string, unknown>,
): Promise<unknown> {
  return await callFoundryOrchestrator(input, {
    additionalInstructions:
      "You are the TAIYO Orchestrator. Return only one valid JSON object for admin_ops_brief, payment_order_risk, repair_recommendation, payout_review, or audit_explanation. Do not include markdown. Do not expose secrets or raw private payment payloads. Recommend admin actions only; never execute actions.",
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

function missingScope(
  requestType: AdminOpsRequestType,
  paymentOrderId: string | null,
  subscriptionId: string | null,
  payoutId: string | null,
) {
  if (requestType === "payment_order_risk" && !paymentOrderId) {
    return {
      missingFields: ["payment_order_id"],
      message: "payment_order_id is required for payment_order_risk.",
    };
  }
  if (
    requestType === "repair_recommendation" &&
    !paymentOrderId &&
    !subscriptionId
  ) {
    return {
      missingFields: ["payment_order_id", "subscription_id"],
      message:
        "payment_order_id or subscription_id is required for repair_recommendation.",
    };
  }
  if (requestType === "payout_review" && !payoutId) {
    return {
      missingFields: ["payout_id"],
      message: "payout_id is required for payout_review.",
    };
  }
  return null;
}

function boundedLimit(value: unknown) {
  const parsed = Math.round(Number(value));
  if (!Number.isFinite(parsed)) return 20;
  return Math.min(Math.max(parsed, 1), 50);
}

function errorStatus(message: string) {
  const lower = message.toLowerCase();
  if (message === "Missing auth token" || message === "Unauthorized") {
    return 401;
  }
  if (lower.includes("admins only") || lower.includes("permission")) {
    return 403;
  }
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
  return "TAIYO admin ops brief failed.";
}

function parseJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return {};
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function safeLog(message: string, details: Record<string, unknown>) {
  console.error(message, details);
}
