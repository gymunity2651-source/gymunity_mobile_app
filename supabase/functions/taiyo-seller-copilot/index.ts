import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  buildOrchestratorInput,
  buildSellerContext,
  normalizeSellerCopilotResponse,
  obj,
  type SellerCopilotRequestType,
  str,
  supportedRequestType,
} from "./engine.ts";

type AuthUser = { id: string };

type HandlerDeps = {
  authenticate?: (token: string) => Promise<AuthUser>;
  getProfileRole?: (userId: string) => Promise<string | null>;
  loadContext?: (
    input: {
      sellerId: string;
      requestType: SellerCopilotRequestType;
      productId: string | null;
      orderId: string | null;
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
  Deno.serve((req) => handleTaiyoSellerCopilotRequest(req));
}

export async function handleTaiyoSellerCopilotRequest(
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
    if (role !== "seller") {
      return jsonResponse({
        error: "TAIYO seller copilot is available for seller accounts only.",
      }, 403);
    }

    const body = obj(await req.json().catch(() => ({})));
    const requestType = supportedRequestType(body.request_type);
    const productId = str(body.product_id);
    const orderId = str(body.order_id);

    const loadContext = deps.loadContext ||
      ((input) => loadSellerCopilotContext(getClients().userSupabase, input));
    const rawContext = await loadContext({
      sellerId: user.id,
      requestType,
      productId,
      orderId,
    });
    const sellerContext = buildSellerContext(user.id, rawContext, {
      productId,
      orderId,
    });

    const callOrchestrator = deps.callOrchestrator || callTaiyoOrchestrator;
    const aiOutput = await callOrchestrator(
      buildOrchestratorInput(requestType, sellerContext),
    );
    const normalized = normalizeSellerCopilotResponse(
      aiOutput,
      sellerContext,
      requestType,
      { debug: debugContext },
    );

    return jsonResponse(normalized);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = errorStatus(message);
    safeLog("taiyo-seller-copilot failed", {
      status,
      reason: publicError(message, status),
    });
    return jsonResponse(
      {
        request_type: "seller_dashboard_brief",
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

async function loadSellerCopilotContext(
  supabase: SupabaseClient,
  input: {
    sellerId: string;
    requestType: SellerCopilotRequestType;
    productId: string | null;
    orderId: string | null;
  },
) {
  const [profileRes, dashboardRes, productsRes, ordersRes] = await Promise
    .all([
      supabase.from("seller_profiles")
        .select(
          "user_id,store_name,store_description,primary_category,shipping_scope,support_email",
        )
        .eq("user_id", input.sellerId)
        .maybeSingle(),
      supabase.rpc("seller_dashboard_summary"),
      supabase.from("products")
        .select(
          "id,seller_id,title,category,price,currency,stock_qty,low_stock_threshold,is_active,deleted_at,created_at,updated_at",
        )
        .eq("seller_id", input.sellerId)
        .order("updated_at", { ascending: false })
        .limit(60),
      supabase.rpc("list_seller_orders_detailed"),
    ]);

  for (const result of [profileRes, dashboardRes, productsRes, ordersRes]) {
    if ("error" in result && result.error) throw new Error(result.error.message);
  }

  const dashboardRows = Array.isArray(dashboardRes.data)
    ? dashboardRes.data
    : [];
  const orders = Array.isArray(ordersRes.data) ? ordersRes.data : [];
  const orderIds = orders.map((row) => str(obj(row).id)).filter(Boolean) as
    string[];

  const [itemsRes, historyRes] = orderIds.length
    ? await Promise.all([
      supabase.from("order_items")
        .select(
          "id,order_id,product_id,seller_id,product_title_snapshot,unit_price,quantity,line_total",
        )
        .in("order_id", orderIds)
        .eq("seller_id", input.sellerId),
      supabase.from("order_status_history")
        .select("id,order_id,status,actor_user_id,note,created_at")
        .in("order_id", orderIds)
        .order("created_at", { ascending: false }),
    ])
    : [
      { data: [], error: null },
      { data: [], error: null },
    ];

  for (const result of [itemsRes, historyRes]) {
    if (result.error) throw new Error(result.error.message);
  }

  return {
    request_type: input.requestType,
    profile: obj(profileRes.data),
    dashboard_summary: obj(dashboardRows[0]),
    products: Array.isArray(productsRes.data) ? productsRes.data : [],
    orders,
    order_items: Array.isArray(itemsRes.data) ? itemsRes.data : [],
    order_status_history: Array.isArray(historyRes.data)
      ? historyRes.data
      : [],
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
          "You are the TAIYO Orchestrator. Return only one valid JSON object for seller_dashboard_brief, seller_product_advice, or seller_order_brief. Do not include markdown. Recommendations and drafts only; do not modify products or orders.",
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
  if (lower.includes("seller accounts only")) return 403;
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
  return "TAIYO seller copilot failed.";
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
