import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  checkoutCorsHeaders,
  createServiceClient,
  extractCallbackFields,
  getPaymobConfig,
  jsonResponse,
  objectFrom,
  stringOrNull,
  verifyPaymobTransactionHmac,
  type JsonMap,
  type PaymobConfig,
} from "../_shared/paymob.ts";

type CallbackDeps = {
  supabase?: SupabaseClient;
  paymobConfig?: PaymobConfig;
};

export async function handlePaymobTransactionCallback(
  req: Request,
  deps: CallbackDeps = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: checkoutCorsHeaders });
  }
  if (req.method !== "POST" && req.method !== "GET") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabase = deps.supabase ?? createServiceClient();
  const config = deps.paymobConfig ?? getPaymobConfig();

  let payload: JsonMap = {};
  try {
    payload = req.method === "POST"
      ? (await req.json().catch(() => ({}))) as JsonMap
      : Object.fromEntries(new URL(req.url).searchParams.entries());
  } catch (_) {
    payload = {};
  }

  const url = new URL(req.url);
  const hmac = stringOrNull(
    url.searchParams.get("hmac") ??
      payload["hmac"] ??
      payload["secure_hash"] ??
      req.headers.get("x-paymob-hmac"),
  ) ?? "";
  const fields = extractCallbackFields(payload);
  const hmacVerified = await verifyPaymobTransactionHmac(
    payload,
    hmac,
    config.hmacSecret,
  );

  const result = await processCallback(supabase, config, payload, fields, hmacVerified);
  if (!hmacVerified) {
    return jsonResponse({ error: "Invalid HMAC", result }, 401);
  }

  return jsonResponse({ ok: true, result });
}

async function processCallback(
  supabase: SupabaseClient,
  config: PaymobConfig,
  payload: JsonMap,
  fields: JsonMap,
  hmacVerified: boolean,
): Promise<JsonMap> {
  const { data, error } = await supabase.rpc("process_coach_paymob_callback_as_service", {
    input_raw_payload: payload,
    input_hmac_verified: hmacVerified,
    input_paymob_transaction_id: stringOrNull(fields["paymob_transaction_id"]),
    input_paymob_order_id: stringOrNull(fields["paymob_order_id"]),
    input_paymob_intention_id: stringOrNull(fields["paymob_intention_id"]),
    input_special_reference: stringOrNull(fields["special_reference"]),
    input_success: fields["success"],
    input_pending: fields["pending"],
    input_is_voided: fields["is_voided"],
    input_is_refunded: fields["is_refunded"],
    input_amount_cents: fields["amount_cents"],
    input_currency: stringOrNull(fields["currency"]),
    input_source_data_type: stringOrNull(fields["source_data_type"]),
    input_failure_reason: stringOrNull(fields["failure_reason"]),
    input_payout_hold_days: config.payoutHoldDays,
  });
  if (error) {
    return {
      ok: false,
      processing_result: "rpc_error",
      error: error.message,
      extracted: redactExtractedFields(fields),
    };
  }
  return objectFrom(data) ?? { ok: true };
}

function redactExtractedFields(fields: JsonMap): JsonMap {
  return {
    paymob_transaction_id: fields["paymob_transaction_id"],
    paymob_order_id: fields["paymob_order_id"],
    paymob_intention_id: fields["paymob_intention_id"],
    special_reference: fields["special_reference"],
    amount_cents: fields["amount_cents"],
    currency: fields["currency"],
  };
}

if (import.meta.main) {
  Deno.serve((req) => handlePaymobTransactionCallback(req));
}
