import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  calculatePaymobTransactionHmac,
  type JsonMap,
  type PaymobConfig,
} from "../_shared/paymob.ts";
import { handlePaymobTransactionCallback } from "./index.ts";

function config(): PaymobConfig {
  return {
    mode: "test",
    merchantId: "1155713",
    apiBaseUrl: "https://accept.paymob.com",
    secretKey: "secret",
    publicKey: "public",
    hmacSecret: "hmac-secret",
    integrationIds: [123],
    currency: "EGP",
    platformFeeBps: 1500,
    payoutHoldDays: 0,
    redirectUrl:
      "https://example.supabase.co/functions/v1/paymob-payment-response",
    notificationUrl:
      "https://example.supabase.co/functions/v1/paymob-transaction-callback",
  };
}

function payload(): JsonMap {
  return {
    obj: {
      amount_cents: 10000,
      created_at: "2026-04-26T10:00:00.000000",
      currency: "EGP",
      error_occured: false,
      has_parent_transaction: false,
      id: 12345,
      integration_id: 123,
      is_3d_secure: true,
      is_auth: false,
      is_capture: false,
      is_refunded: false,
      is_standalone_payment: true,
      is_voided: false,
      order: { id: 777, merchant_order_id: "gymunity_coach_sub_abc" },
      owner: 555,
      pending: false,
      source_data: { pan: "2346", sub_type: "MasterCard", type: "card" },
      success: true,
    },
  };
}

function mockSupabase() {
  const rpcCalls: Array<{ fn: string; params: JsonMap }> = [];
  return {
    client: {
      rpc: (fn: string, params: JsonMap) => {
        rpcCalls.push({ fn, params });
        return Promise.resolve({
          data: { ok: true, processing_result: "paid" },
          error: null,
        });
      },
    },
    rpcCalls,
  };
}

Deno.test("Paymob callback rejects invalid HMAC and records unverified transaction", async () => {
  const supabase = mockSupabase();
  const response = await handlePaymobTransactionCallback(
    new Request("https://example.com/callback?hmac=bad", {
      method: "POST",
      body: JSON.stringify(payload()),
      headers: { "Content-Type": "application/json" },
    }),
    { supabase: supabase.client as never, paymobConfig: config() },
  );

  assertEquals(response.status, 401);
  assertEquals(supabase.rpcCalls.length, 1);
  assertEquals(
    supabase.rpcCalls[0].fn,
    "process_coach_paymob_callback_as_service",
  );
  assertEquals(supabase.rpcCalls[0].params.input_hmac_verified, false);
});

Deno.test("Paymob callback sends verified transaction fields to processor", async () => {
  const callbackPayload = payload();
  const hmac = await calculatePaymobTransactionHmac(
    callbackPayload,
    "hmac-secret",
  );
  const supabase = mockSupabase();
  const response = await handlePaymobTransactionCallback(
    new Request(`https://example.com/callback?hmac=${hmac}`, {
      method: "POST",
      body: JSON.stringify(callbackPayload),
      headers: { "Content-Type": "application/json" },
    }),
    { supabase: supabase.client as never, paymobConfig: config() },
  );

  assertEquals(response.status, 200);
  assertEquals(supabase.rpcCalls[0].params.input_hmac_verified, true);
  assertEquals(
    supabase.rpcCalls[0].params.input_paymob_transaction_id,
    "12345",
  );
  assertEquals(supabase.rpcCalls[0].params.input_paymob_order_id, "777");
  assertEquals(
    supabase.rpcCalls[0].params.input_special_reference,
    "gymunity_coach_sub_abc",
  );
  assertEquals(supabase.rpcCalls[0].params.input_amount_cents, 10000);
});
