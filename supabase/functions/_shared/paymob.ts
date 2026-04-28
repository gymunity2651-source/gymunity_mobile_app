import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export const PAYMOB_TRANSACTION_HMAC_KEYS = [
  "amount_cents",
  "created_at",
  "currency",
  "error_occured",
  "has_parent_transaction",
  "id",
  "integration_id",
  "is_3d_secure",
  "is_auth",
  "is_capture",
  "is_refunded",
  "is_standalone_payment",
  "is_voided",
  "order.id",
  "owner",
  "pending",
  "source_data.pan",
  "source_data.sub_type",
  "source_data.type",
  "success",
];

export type PaymobConfig = {
  mode: "test";
  merchantId: string;
  apiBaseUrl: string;
  secretKey: string;
  publicKey: string;
  hmacSecret: string;
  integrationIds: number[];
  currency: "EGP";
  platformFeeBps: number;
  payoutHoldDays: number;
  redirectUrl: string;
  notificationUrl: string;
};

export type AuthenticatedUser = {
  id: string;
  email?: string | null;
};

export type JsonMap = Record<string, unknown>;

export const checkoutCorsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...checkoutCorsHeaders, "Content-Type": "application/json" },
  });
}

export function htmlResponse(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: { ...checkoutCorsHeaders, "Content-Type": "text/html; charset=utf-8" },
  });
}

export function getEnv(name: string, env = Deno.env): string {
  return env.get(name)?.trim() ?? "";
}

export function getPaymobConfig(env = Deno.env): PaymobConfig {
  const mode = getEnv("PAYMOB_MODE", env) || "test";
  if (mode !== "test") {
    throw new Error("Only PAYMOB_MODE=test is supported by this build.");
  }

  const apiBaseUrl = stripTrailingSlash(validateUrl(
    "PAYMOB_API_BASE_URL",
    getEnv("PAYMOB_API_BASE_URL", env) || "https://accept.paymob.com",
  ));
  const merchantId = getEnv("PAYMOB_MERCHANT_ID", env);
  const secretKey = getEnv("PAYMOB_SECRET_KEY_TEST", env);
  const publicKey = getEnv("PAYMOB_PUBLIC_KEY_TEST", env);
  const hmacSecret = getEnv("PAYMOB_HMAC_SECRET_TEST", env);
  const integrationIds = parseIntegrationIds(
    getEnv("PAYMOB_TEST_INTEGRATION_IDS", env),
  );
  const currency = getEnv("PAYMOB_CURRENCY", env) || "EGP";
  if (currency !== "EGP") {
    throw new Error("Only PAYMOB_CURRENCY=EGP is supported initially.");
  }

  const platformFeeBps = parseIntegerEnv("GYMUNITY_PLATFORM_FEE_BPS", env, {
    fallback: 0,
    min: 0,
    max: 10000,
  });
  const payoutHoldDays = parseIntegerEnv("GYMUNITY_PAYOUT_HOLD_DAYS", env, {
    fallback: 0,
    min: 0,
  });
  const redirectUrl = getEnv("APP_PUBLIC_PAYMENT_REDIRECT_URL", env);
  const notificationUrl = getEnv("PAYMOB_NOTIFICATION_URL", env);

  const missing = [
    ["PAYMOB_MERCHANT_ID", merchantId],
    ["PAYMOB_SECRET_KEY_TEST", secretKey],
    ["PAYMOB_PUBLIC_KEY_TEST", publicKey],
    ["PAYMOB_HMAC_SECRET_TEST", hmacSecret],
    ["PAYMOB_TEST_INTEGRATION_IDS", integrationIds.length ? "ok" : ""],
    ["APP_PUBLIC_PAYMENT_REDIRECT_URL", redirectUrl],
    ["PAYMOB_NOTIFICATION_URL", notificationUrl],
  ].filter(([, value]) => !value).map(([key]) => key);

  if (missing.length > 0) {
    throw new Error(`Missing required Paymob env vars: ${missing.join(", ")}`);
  }
  if (!/^\d+$/.test(merchantId)) {
    throw new Error("PAYMOB_MERCHANT_ID must be numeric.");
  }

  validateUrl("APP_PUBLIC_PAYMENT_REDIRECT_URL", redirectUrl);
  validateUrl("PAYMOB_NOTIFICATION_URL", notificationUrl);

  return {
    mode,
    merchantId,
    apiBaseUrl,
    secretKey,
    publicKey,
    hmacSecret,
    integrationIds,
    currency,
    platformFeeBps,
    payoutHoldDays,
    redirectUrl,
    notificationUrl,
  };
}

export function createServiceClient(env = Deno.env): SupabaseClient {
  const supabaseUrl = getEnv("SUPABASE_URL", env);
  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY", env);
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing required env vars: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY");
  }

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
}

export async function authenticateUser(
  supabase: SupabaseClient,
  req: Request,
): Promise<{ token: string; user: AuthenticatedUser }> {
  const authHeader = req.headers.get("Authorization");
  const token = authHeader?.replace("Bearer ", "").trim() ?? "";
  if (!token) {
    throw new HttpError("Missing auth token", 401);
  }

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    throw new HttpError("Unauthorized", 401);
  }

  return {
    token,
    user: { id: data.user.id, email: data.user.email },
  };
}

export class HttpError extends Error {
  constructor(message: string, readonly status = 400) {
    super(message);
    this.name = "HttpError";
  }
}

export function centsFromEgp(value: unknown): number {
  const amount = typeof value === "number" ? value : Number(value ?? 0);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpError("Coach package amount must be greater than zero.", 400);
  }
  return Math.round(amount * 100);
}

export function calculatePlatformFeeCents(
  amountGrossCents: number,
  platformFeeBps: number,
): number {
  if (!Number.isFinite(platformFeeBps) || platformFeeBps < 0) {
    return 0;
  }
  return Math.floor((amountGrossCents * platformFeeBps) / 10000);
}

export function buildCheckoutUrl(
  apiBaseUrl: string,
  publicKey: string,
  clientSecret: string,
): string {
  const url = new URL(`${stripTrailingSlash(apiBaseUrl)}/unifiedcheckout/`);
  url.searchParams.set("publicKey", publicKey);
  url.searchParams.set("clientSecret", clientSecret);
  return url.toString();
}

export async function sha256Hex(raw: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(raw),
  );
  return bytesToHex(new Uint8Array(digest));
}

export async function hmacSha512Hex(
  secret: string,
  raw: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(raw),
  );
  return bytesToHex(new Uint8Array(signature));
}

export async function verifyPaymobTransactionHmac(
  payload: JsonMap,
  hmac: string,
  secret: string,
): Promise<boolean> {
  const provided = hmac.trim().toLowerCase();
  if (!provided || !secret.trim()) {
    return false;
  }

  const calculated = await calculatePaymobTransactionHmac(payload, secret);
  return timingSafeEqualHex(calculated, provided);
}

export async function calculatePaymobTransactionHmac(
  payload: JsonMap,
  secret: string,
): Promise<string> {
  const obj = objectFrom(payload["obj"]) ?? payload;
  const concatenated = PAYMOB_TRANSACTION_HMAC_KEYS.map((key) =>
    stringifyHmacValue(getPath(obj, key))
  ).join("");
  return hmacSha512Hex(secret, concatenated);
}

export function extractCallbackFields(payload: JsonMap): JsonMap {
  const obj = objectFrom(payload["obj"]) ?? payload;
  const order = objectFrom(obj["order"]);
  const sourceData = objectFrom(obj["source_data"]);
  const data = objectFrom(obj["data"]);
  const extras = objectFrom(obj["extras"]) ?? objectFrom(data?.["extras"]);

  return {
    paymob_transaction_id: stringOrNull(obj["id"]),
    paymob_order_id: stringOrNull(order?.["id"] ?? obj["order_id"]),
    paymob_intention_id: stringOrNull(
      obj["intention_id"] ??
        obj["payment_intention"] ??
        obj["payment_intention_id"] ??
        data?.["payment_intention"] ??
        extras?.["payment_intention_id"],
    ),
    special_reference: stringOrNull(
      obj["special_reference"] ??
        obj["merchant_order_id"] ??
        order?.["merchant_order_id"] ??
        order?.["special_reference"] ??
        extras?.["special_reference"] ??
        extras?.["payment_order_reference"],
    ),
    success: booleanOrNull(obj["success"]),
    pending: booleanOrNull(obj["pending"]),
    is_voided: booleanOrNull(obj["is_voided"]),
    is_refunded: booleanOrNull(obj["is_refunded"]),
    amount_cents: integerOrNull(obj["amount_cents"]),
    currency: stringOrNull(obj["currency"]),
    source_data_type: stringOrNull(sourceData?.["type"]),
    failure_reason: stringOrNull(
      obj["data_message"] ??
        obj["txn_response_code"] ??
        obj["acq_response_code"] ??
        data?.["message"],
    ),
  };
}

export function objectFrom(value: unknown): JsonMap | null {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return null;
}

export function stringOrNull(value: unknown): string | null {
  if (value == null) {
    return null;
  }
  const stringValue = String(value).trim();
  return stringValue.length === 0 ? null : stringValue;
}

export function integerOrNull(value: unknown): number | null {
  if (value == null || value === "") {
    return null;
  }
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  return Math.trunc(parsed);
}

export function booleanOrNull(value: unknown): boolean | null {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true") return true;
    if (normalized === "false") return false;
  }
  return null;
}

function parseIntegrationIds(raw: string): number[] {
  if (!raw.trim()) {
    return [];
  }
  const parts = raw.split(",").map((item) => item.trim());
  const ids = parts
    .map((item) => Number(item))
    .filter((value) => Number.isInteger(value) && value > 0);
  if (ids.length !== parts.length) {
    throw new Error("PAYMOB_TEST_INTEGRATION_IDS must contain comma-separated numeric IDs.");
  }
  return ids;
}

function parseIntegerEnv(
  name: string,
  env: typeof Deno.env,
  options: { fallback: number; min?: number; max?: number },
): number {
  const raw = getEnv(name, env);
  if (!raw) {
    return options.fallback;
  }
  const parsed = Number(raw);
  if (!Number.isInteger(parsed)) {
    throw new Error(`${name} must be an integer.`);
  }
  if (options.min != null && parsed < options.min) {
    throw new Error(`${name} must be greater than or equal to ${options.min}.`);
  }
  if (options.max != null && parsed > options.max) {
    throw new Error(`${name} must be less than or equal to ${options.max}.`);
  }
  return parsed;
}

function validateUrl(name: string, raw: string): string {
  try {
    const url = new URL(raw);
    if (url.protocol !== "https:" && url.protocol !== "http:") {
      throw new Error("Invalid protocol");
    }
    return raw;
  } catch (_) {
    throw new Error(`${name} must be a valid URL.`);
  }
}

function stripTrailingSlash(value: string): string {
  return value.replace(/\/+$/, "");
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function getPath(obj: JsonMap, path: string): unknown {
  let current: unknown = obj;
  for (const part of path.split(".")) {
    if (!current || typeof current !== "object" || Array.isArray(current)) {
      return "";
    }
    current = (current as JsonMap)[part];
  }
  return current ?? "";
}

function stringifyHmacValue(value: unknown): string {
  if (value == null) {
    return "";
  }
  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }
  return String(value);
}

function timingSafeEqualHex(a: string, b: string): boolean {
  const left = a.toLowerCase();
  const right = b.toLowerCase();
  if (left.length !== right.length) {
    return false;
  }

  let mismatch = 0;
  for (let i = 0; i < left.length; i += 1) {
    mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return mismatch === 0;
}
