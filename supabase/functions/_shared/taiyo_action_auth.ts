import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

export type AuthContext = {
  userId: string;
  role: string;
  authMode: "user_jwt" | "foundry_action";
  scope: string;
};

export type SupabasePair = {
  serviceSupabase: SupabaseClient;
  userSupabase: SupabaseClient;
};

export function bearer(req: Request) {
  const header = req.headers.get("Authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new Error("Missing auth token");
  return match[1].trim();
}

export function createSupabaseClients(
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

export async function authUser(
  supabase: SupabaseClient,
  token: string,
): Promise<{ id: string }> {
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) throw new Error("Unauthorized");
  return { id: data.user.id };
}

export async function loadProfileRole(
  supabase: SupabaseClient,
  userId: string,
) {
  const { data, error } = await supabase
    .from("profiles")
    .select("user_id,roles(code)")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return extractRoleCode(obj(data).roles);
}

export async function authenticateTaiyoRequest(
  req: Request,
  expectedScope: string,
  deps: {
    getEnv: (name: string) => string;
    createClients?: (token: string) => SupabasePair;
    authenticate?: (token: string) => Promise<{ id: string }>;
    getProfileRole?: (userId: string) => Promise<string | null>;
  },
): Promise<{
  auth: AuthContext;
  clients: SupabasePair | null;
  token: string | null;
}> {
  const actionSecret = req.headers.get("x-taiyo-action-secret")?.trim() || "";
  const configuredSecret = optionalEnvWith(deps.getEnv, "TAIYO_ACTION_SECRET");
  if (
    actionSecret && configuredSecret &&
    safeEqual(actionSecret, configuredSecret)
  ) {
    const contextToken = req.headers.get("x-taiyo-context-token")?.trim() || "";
    const claims = await verifyContextToken(contextToken, deps.getEnv);
    const scope = stringValue(claims.scope) || "";
    if (scope !== expectedScope && scope !== "taiyo:any") {
      throw new Error("Invalid TAIYO context token scope.");
    }
    const exp = Number(claims.exp);
    if (!Number.isFinite(exp) || exp < Math.floor(Date.now() / 1000)) {
      throw new Error("Expired TAIYO context token.");
    }
    const userId = stringValue(claims.sub) || "";
    const role = stringValue(claims.role) || "";
    if (!userId || !role) throw new Error("Invalid TAIYO context token.");
    return {
      auth: { userId, role, authMode: "foundry_action", scope },
      clients: null,
      token: null,
    };
  }

  const token = bearer(req);
  const getClients = deps.createClients ||
    ((authToken: string) => createSupabaseClients(authToken, deps.getEnv));
  let clients: SupabasePair | null = null;
  const ensureClients = () => {
    clients ??= getClients(token);
    return clients;
  };
  const authenticate = deps.authenticate ||
    ((authToken: string) =>
      authUser(ensureClients().serviceSupabase, authToken));
  const user = await authenticate(token);
  const getProfileRole = deps.getProfileRole ||
    ((userId: string) => loadProfileRole(ensureClients().userSupabase, userId));
  const role = await getProfileRole(user.id);
  return {
    auth: {
      userId: user.id,
      role: role || "",
      authMode: "user_jwt",
      scope: expectedScope,
    },
    clients,
    token,
  };
}

export async function createContextToken(
  claims: {
    sub: string;
    role: string;
    scope: string;
    ttlSeconds?: number;
  },
  getEnv: (name: string) => string,
) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: claims.sub,
    role: claims.role,
    scope: claims.scope,
    iat: now,
    exp: now + (claims.ttlSeconds || 300),
  };
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signature = await hmac(encodedPayload, contextTokenSecret(getEnv));
  return `${encodedPayload}.${signature}`;
}

export async function verifyContextToken(
  token: string,
  getEnv: (name: string) => string,
) {
  const [payload, signature] = token.split(".");
  if (!payload || !signature) throw new Error("Missing TAIYO context token.");
  const expected = await hmac(payload, contextTokenSecret(getEnv));
  if (!safeEqual(signature, expected)) {
    throw new Error("Invalid TAIYO context token signature.");
  }
  const decoded = new TextDecoder().decode(base64UrlDecode(payload));
  return obj(JSON.parse(decoded));
}

export function obj(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export function extractRoleCode(value: unknown): string | null {
  if (Array.isArray(value)) {
    return extractRoleCode(value[0]);
  }
  return stringValue(obj(value).code);
}

function contextTokenSecret(getEnv: (name: string) => string) {
  const value = getEnv("TAIYO_CONTEXT_TOKEN_SECRET");
  if (value.length < 24) {
    throw new Error(
      "TAIYO_CONTEXT_TOKEN_SECRET must be at least 24 characters.",
    );
  }
  return value;
}

async function hmac(payload: string, secret: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload),
  );
  return base64UrlEncodeBytes(new Uint8Array(signature));
}

function base64UrlEncode(value: string) {
  return base64UrlEncodeBytes(new TextEncoder().encode(value));
}

function base64UrlEncodeBytes(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

function base64UrlDecode(value: string) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(
    Math.ceil(value.length / 4) * 4,
    "=",
  );
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function safeEqual(left: string, right: string) {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  if (leftBytes.length !== rightBytes.length) return false;
  let diff = 0;
  for (let i = 0; i < leftBytes.length; i++) {
    diff |= leftBytes[i] ^ rightBytes[i];
  }
  return diff === 0;
}

function optionalEnvWith(getEnv: (name: string) => string, name: string) {
  try {
    return getEnv(name)?.trim() || "";
  } catch {
    return Deno.env.get(name)?.trim() || "";
  }
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}
