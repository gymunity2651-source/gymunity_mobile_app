import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildCheckoutUrl,
  calculatePaymobTransactionHmac,
  extractCallbackFields,
  getPaymobConfig,
  verifyPaymobTransactionHmac,
  type JsonMap,
} from "./paymob.ts";

function callbackPayload(overrides: JsonMap = {}): JsonMap {
  return {
    obj: {
      amount_cents: 10000,
      created_at: "2026-04-26T10:00:00.000000",
      currency: "EGP",
      error_occured: false,
      has_parent_transaction: false,
      id: 12345,
      integration_id: 999,
      is_3d_secure: true,
      is_auth: false,
      is_capture: false,
      is_refunded: false,
      is_standalone_payment: true,
      is_voided: false,
      order: {
        id: 777,
        merchant_order_id: "gymunity_coach_sub_abc",
      },
      owner: 111,
      pending: false,
      source_data: {
        pan: "2346",
        sub_type: "MasterCard",
        type: "card",
      },
      success: true,
      ...overrides,
    },
  };
}

Deno.test("Paymob HMAC verification accepts the canonical transaction signature", async () => {
  const payload = callbackPayload();
  const hmac = await calculatePaymobTransactionHmac(payload, "hmac-secret");

  assertEquals(
    await verifyPaymobTransactionHmac(payload, hmac, "hmac-secret"),
    true,
  );
  assertEquals(
    await verifyPaymobTransactionHmac(payload, "bad-hmac", "hmac-secret"),
    false,
  );
});

Deno.test("Paymob callback extraction resolves transaction fields", () => {
  const fields = extractCallbackFields(callbackPayload());

  assertEquals(fields.paymob_transaction_id, "12345");
  assertEquals(fields.paymob_order_id, "777");
  assertEquals(fields.special_reference, "gymunity_coach_sub_abc");
  assertEquals(fields.success, true);
  assertEquals(fields.pending, false);
  assertEquals(fields.amount_cents, 10000);
  assertEquals(fields.currency, "EGP");
  assertEquals(fields.source_data_type, "card");
});

Deno.test("Paymob hosted checkout URL uses public key and client secret only", () => {
  const url = buildCheckoutUrl(
    "https://accept.paymob.com/",
    "pk_test_public",
    "cs_test_client",
  );

  assertEquals(
    url,
    "https://accept.paymob.com/unifiedcheckout/?publicKey=pk_test_public&clientSecret=cs_test_client",
  );
});

Deno.test("Paymob config accepts complete test-mode settings", () => {
  const config = getPaymobConfig(envWith({}));

  assertEquals(config.mode, "test");
  assertEquals(config.merchantId, "1155713");
  assertEquals(config.integrationIds, [5629685]);
  assertEquals(config.currency, "EGP");
  assertEquals(config.platformFeeBps, 1500);
  assertEquals(config.payoutHoldDays, 0);
});

Deno.test("Paymob config rejects unsafe or incomplete settings", () => {
  assertThrows(
    () => getPaymobConfig(envWith({ PAYMOB_MODE: "live" })),
    Error,
    "Only PAYMOB_MODE=test",
  );
  assertThrows(
    () => getPaymobConfig(envWith({ PAYMOB_SECRET_KEY_TEST: "" })),
    Error,
    "PAYMOB_SECRET_KEY_TEST",
  );
  assertThrows(
    () => getPaymobConfig(envWith({ PAYMOB_HMAC_SECRET_TEST: "" })),
    Error,
    "PAYMOB_HMAC_SECRET_TEST",
  );
  assertThrows(
    () => getPaymobConfig(envWith({ PAYMOB_PUBLIC_KEY_TEST: "" })),
    Error,
    "PAYMOB_PUBLIC_KEY_TEST",
  );
  assertThrows(
    () => getPaymobConfig(envWith({ PAYMOB_TEST_INTEGRATION_IDS: "abc" })),
    Error,
    "PAYMOB_TEST_INTEGRATION_IDS",
  );
  assertThrows(
    () => getPaymobConfig(envWith({ APP_PUBLIC_PAYMENT_REDIRECT_URL: "gymunity://payment-callback" })),
    Error,
    "APP_PUBLIC_PAYMENT_REDIRECT_URL",
  );
  assertThrows(
    () => getPaymobConfig(envWith({ GYMUNITY_PLATFORM_FEE_BPS: "10001" })),
    Error,
    "GYMUNITY_PLATFORM_FEE_BPS",
  );
});

function envWith(overrides: Record<string, string>) {
  const values: Record<string, string> = {
    PAYMOB_MODE: "test",
    PAYMOB_API_BASE_URL: "https://accept.paymob.com",
    PAYMOB_MERCHANT_ID: "1155713",
    PAYMOB_TEST_INTEGRATION_IDS: "5629685",
    PAYMOB_CURRENCY: "EGP",
    PAYMOB_PUBLIC_KEY_TEST: "pk_test_public",
    PAYMOB_SECRET_KEY_TEST: "sk_test_secret",
    PAYMOB_HMAC_SECRET_TEST: "hmac-secret",
    PAYMOB_NOTIFICATION_URL: "https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-transaction-callback",
    APP_PUBLIC_PAYMENT_REDIRECT_URL: "https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-payment-response",
    GYMUNITY_PLATFORM_FEE_BPS: "1500",
    GYMUNITY_PAYOUT_HOLD_DAYS: "0",
    ...overrides,
  };
  return {
    get: (name: string) => values[name],
  } as never;
}
