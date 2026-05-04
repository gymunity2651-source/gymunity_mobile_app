export type FoundryRunOptions = {
  agentIdEnv?: string;
  agentNameEnv?: string;
  additionalInstructions: string;
  getEnv?: (name: string) => string;
};

export function obj(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export function str(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

export async function callFoundryOrchestrator(
  input: Record<string, unknown>,
  options: FoundryRunOptions,
): Promise<unknown> {
  const getEnv = options.getEnv || env;
  const endpoint = getEnv("AZURE_FOUNDRY_PROJECT_ENDPOINT").replace(/\/+$/, "");
  const apiVersion = optionalEnvWith(getEnv, "AZURE_FOUNDRY_API_VERSION") ||
    "v1";
  const agentId = optionalEnvWith(
    getEnv,
    options.agentIdEnv || "AZURE_FOUNDRY_ORCHESTRATOR_AGENT_ID",
  ) ||
    optionalEnvWith(getEnv, "AZURE_FOUNDRY_ORCHESTRATOR_AGENT_ID") ||
    optionalEnvWith(getEnv, "AZURE_FOUNDRY_AGENT_ID") ||
    await resolveAgentIdByName(endpoint, apiVersion, options);
  if (!agentId) {
    throw new Error(
      "Missing required Azure agent env var: set AZURE_FOUNDRY_ORCHESTRATOR_AGENT_ID/NAME or AZURE_FOUNDRY_AGENT_ID/NAME.",
    );
  }

  const token = await azureBearerToken(getEnv);
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
        additional_instructions: options.additionalInstructions,
      }),
    },
  );
  const runId = str(obj(run).id);
  if (!runId) throw new Error("Azure Foundry did not create a run.");

  await waitForRun(endpoint, apiVersion, token, threadId, runId, getEnv);
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

async function resolveAgentIdByName(
  endpoint: string,
  apiVersion: string,
  options: FoundryRunOptions,
) {
  const getEnv = options.getEnv || env;
  const agentName = optionalEnvWith(
    getEnv,
    options.agentNameEnv || "AZURE_FOUNDRY_ORCHESTRATOR_AGENT_NAME",
  ) ||
    optionalEnvWith(getEnv, "AZURE_FOUNDRY_ORCHESTRATOR_AGENT_NAME") ||
    optionalEnvWith(getEnv, "AZURE_FOUNDRY_AGENT_NAME");
  if (!agentName) return "";
  const token = await azureBearerToken(getEnv);
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

async function azureBearerToken(getEnv: (name: string) => string) {
  const tenantId = optionalEnvWith(getEnv, "AZURE_TENANT_ID");
  const clientId = optionalEnvWith(getEnv, "AZURE_CLIENT_ID");
  const clientSecret = optionalEnvWith(getEnv, "AZURE_CLIENT_SECRET");
  if (tenantId && clientId && clientSecret) {
    return await azureClientCredentialsToken(tenantId, clientId, clientSecret);
  }

  const staticToken = optionalEnvWith(getEnv, "AZURE_FOUNDRY_AGENT_TOKEN") ||
    optionalEnvWith(getEnv, "AGENT_TOKEN");
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
  getEnv: (name: string) => string,
) {
  const started = Date.now();
  const timeoutMs =
    Number(optionalEnvWith(getEnv, "AZURE_FOUNDRY_RUN_TIMEOUT_MS")) || 60000;
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
    for (const part of Array.isArray(content) ? content : []) {
      const item = obj(part);
      const text = obj(item.text);
      const value = str(text.value) || str(item.text) || str(item.content);
      if (value) return value;
    }
  }
  return "";
}

function env(name: string) {
  const value = Deno.env.get(name)?.trim() || "";
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function optionalEnvWith(getEnv: (name: string) => string, name: string) {
  try {
    return getEnv(name)?.trim() || "";
  } catch {
    return Deno.env.get(name)?.trim() || "";
  }
}

function parseJson(text: string) {
  try {
    return JSON.parse(text);
  } catch {
    return {};
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
