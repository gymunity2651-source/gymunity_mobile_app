import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { handleCreateCoachPaymobCheckout } from "./index.ts";
import type { JsonMap, PaymobConfig } from "../_shared/paymob.ts";

function config(): PaymobConfig {
  return {
    mode: "test",
    merchantId: "1155713",
    apiBaseUrl: "https://accept.paymob.com",
    secretKey: "secret-key",
    publicKey: "public-key",
    hmacSecret: "hmac-secret",
    integrationIds: [5629685],
    currency: "EGP",
    platformFeeBps: 1500,
    payoutHoldDays: 0,
    redirectUrl: "https://example.supabase.co/functions/v1/paymob-payment-response",
    notificationUrl: "https://example.supabase.co/functions/v1/paymob-transaction-callback",
  };
}

Deno.test("create Paymob checkout returns public pending checkout fields only", async () => {
  const supabase = mockSupabase();
  const response = await handleCreateCoachPaymobCheckout(
    new Request("https://example.com/create-coach-paymob-checkout", {
      method: "POST",
      headers: {
        "Authorization": "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ package_id: "package-1" }),
    }),
    {
      supabase: supabase.client as never,
      paymobConfig: config(),
      fetch: async (_url, init) => {
        const payload = JSON.parse(String(init?.body ?? "{}")) as JsonMap;
        assertEquals(payload.amount, 120000);
        assertEquals(payload.currency, "EGP");
        assertEquals(payload.payment_methods, [5629685]);
        assertEquals(payload.notification_url, config().notificationUrl);
        assertEquals(payload.redirection_url, config().redirectUrl);
        return new Response(JSON.stringify({
          id: "intention-1",
          order_id: "paymob-order-1",
          client_secret: "client-secret",
          checkout_url: "https://accept.paymob.com/unifiedcheckout/",
        }), { status: 200 });
      },
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.payment_order_id, "order-1");
  assertEquals(body.subscription_id, "sub-1");
  assertEquals(body.paymob_client_secret, "client-secret");
  assertEquals(body.paymob_public_key, "public-key");
  assertEquals(body.amount_gross_cents, 120000);
  assertEquals(body.currency, "EGP");
  assertEquals(body.mode, "test");
  assertEquals(body.status, "pending");
  assertEquals(body.secretKey, undefined);
  assertEquals(body.hmacSecret, undefined);
  assertEquals(supabase.insertedOrders[0].mode, "test");
});

function mockSupabase() {
  const insertedSubscriptions: JsonMap[] = [];
  const insertedOrders: JsonMap[] = [];

  const client = {
    auth: {
      getUser: (_token: string) =>
        Promise.resolve({
          data: { user: { id: "member-1", email: "member@example.com" } },
          error: null,
        }),
    },
    from: (table: string) => builder(table),
  };

  function builder(table: string) {
    const state: { op?: string; payload?: unknown } = {};
    const query = {
      select: (_columns?: string) => query,
      eq: (_column: string, _value: unknown) => query,
      in: (_column: string, _values: unknown[]) => query,
      or: (_filter: string) => query,
      order: (_column: string, _options?: unknown) => query,
      limit: (_count: number) => query,
      insert: (payload: unknown) => {
        state.op = "insert";
        state.payload = payload;
        return query;
      },
      update: (payload: unknown) => {
        state.op = "update";
        state.payload = payload;
        return query;
      },
      single: () => Promise.resolve(singleResult(table, state)),
      then: (resolve: (value: unknown) => unknown, reject: (reason?: unknown) => unknown) =>
        Promise.resolve(listResult(table, state)).then(resolve, reject),
    };
    return query;
  }

  function singleResult(table: string, state: { op?: string; payload?: unknown }) {
    if (table === "profiles") {
      return {
        data: {
          user_id: "member-1",
          full_name: "Test Member",
          phone: "01000000000",
          roles: { code: "member" },
        },
        error: null,
      };
    }
    if (table === "coach_packages") {
      return {
        data: {
          id: "package-1",
          coach_id: "coach-1",
          visibility_status: "published",
          is_active: true,
          title: "Starter Coaching",
          description: "Starter package",
          billing_cycle: "monthly",
          price: 1200,
        },
        error: null,
      };
    }
    if (table === "coach_profiles") {
      return {
        data: {
          user_id: "coach-1",
          trial_offer_enabled: false,
          trial_price_egp: 0,
        },
        error: null,
      };
    }
    if (table === "subscriptions" && state.op === "insert") {
      insertedSubscriptions.push(state.payload as JsonMap);
      return {
        data: {
          id: "sub-1",
          member_id: "member-1",
          coach_id: "coach-1",
          package_id: "package-1",
        },
        error: null,
      };
    }
    if (table === "coach_payment_orders" && state.op === "insert") {
      const row = state.payload as JsonMap;
      insertedOrders.push(row);
      return { data: { id: "order-1" }, error: null };
    }
    return { data: null, error: new Error(`Unexpected single query: ${table}`) };
  }

  function listResult(table: string, state: { op?: string }) {
    if (table === "subscriptions" && !state.op) {
      return { data: [], error: null };
    }
    if (table === "coach_payment_orders" && state.op === "update") {
      return { data: null, error: null };
    }
    if (table === "subscriptions" && state.op === "update") {
      return { data: null, error: null };
    }
    if (table === "notifications" && state.op === "insert") {
      return { data: null, error: null };
    }
    if (table === "app_admins") {
      return { data: [], error: null };
    }
    return { data: null, error: new Error(`Unexpected query: ${table}`) };
  }

  return { client, insertedSubscriptions, insertedOrders };
}
