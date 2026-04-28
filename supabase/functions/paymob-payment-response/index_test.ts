import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { handlePaymobPaymentResponse } from "./index.ts";

Deno.test("Paymob response does not redirect to itself", async () => {
  const previous = Deno.env.get("APP_PUBLIC_PAYMENT_REDIRECT_URL");
  Deno.env.set(
    "APP_PUBLIC_PAYMENT_REDIRECT_URL",
    "https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-payment-response",
  );
  try {
    const response = handlePaymobPaymentResponse(
      new Request(
        "https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-payment-response?success=true",
        { headers: { accept: "text/html" } },
      ),
    );

    assertEquals(response.status, 200);
    assertEquals(response.headers.get("location"), null);
    assertStringIncludes(await response.text(), "Return to GymUnity");
  } finally {
    if (previous == null) {
      Deno.env.delete("APP_PUBLIC_PAYMENT_REDIRECT_URL");
    } else {
      Deno.env.set("APP_PUBLIC_PAYMENT_REDIRECT_URL", previous);
    }
  }
});

Deno.test("Paymob response redirects to a different configured URL", () => {
  const previous = Deno.env.get("APP_PUBLIC_PAYMENT_REDIRECT_URL");
  Deno.env.set(
    "APP_PUBLIC_PAYMENT_REDIRECT_URL",
    "https://example.com/payment-return",
  );
  try {
    const response = handlePaymobPaymentResponse(
      new Request(
        "https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-payment-response?success=true&order=order-1",
      ),
    );

    assertEquals(response.status, 302);
    assertEquals(
      response.headers.get("location"),
      "https://example.com/payment-return?payment_status=success&payment_order_id=order-1",
    );
  } finally {
    if (previous == null) {
      Deno.env.delete("APP_PUBLIC_PAYMENT_REDIRECT_URL");
    } else {
      Deno.env.set("APP_PUBLIC_PAYMENT_REDIRECT_URL", previous);
    }
  }
});
