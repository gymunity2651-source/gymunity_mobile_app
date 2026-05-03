import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { buildAdminContext, normalizeAdminOpsResponse } from "./engine.ts";
import {
  handleTaiyoAdminOpsBriefRequest,
  loadAdminOpsContext,
} from "./index.ts";

Deno.test("taiyo-admin-ops-brief rejects missing auth with 401", async () => {
  const response = await handleTaiyoAdminOpsBriefRequest(
    new Request("https://example.com/taiyo-admin-ops-brief", {
      method: "POST",
      body: "{}",
    }),
  );

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertEquals(body.error, "Missing auth token");
});

Deno.test("taiyo-admin-ops-brief rejects non-admin users with 403", async () => {
  const response = await handleTaiyoAdminOpsBriefRequest(
    request({ request_type: "admin_ops_brief" }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getCurrentAdmin: async () => null,
    },
  );

  assertEquals(response.status, 403);
  const body = await response.json();
  assertMatch(String(body.error), /admins only/i);
});

Deno.test("taiyo-admin-ops-brief normalizes dashboard success", async () => {
  const response = await handleTaiyoAdminOpsBriefRequest(
    request({ request_type: "admin_ops_brief" }),
    {
      authenticate: async () => ({ id: "admin-1" }),
      getCurrentAdmin: async () => activeAdmin(),
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () =>
        '```json\n{"status":"success","result":{"issue_type":"dashboard","status_summary":"Payments are stable.","risk_level":"low","recommended_admin_action":"","action_label":"","reason":"No urgent operational issue.","audit_notes":["Reviewed recent KPIs"],"manual_confirmation_required":false,"sensitive_data_excluded":false},"data_quality":{"confidence":"high"}}\n```',
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.request_type, "admin_ops_brief");
  assertEquals(body.status, "success");
  assertEquals(body.result.status_summary, "Payments are stable.");
  assertEquals(body.result.manual_confirmation_required, true);
  assertEquals(body.result.sensitive_data_excluded, true);
});

Deno.test("taiyo-admin-ops-brief normalizes payment_order_risk success", async () => {
  const response = await handleTaiyoAdminOpsBriefRequest(
    request({
      request_type: "payment_order_risk",
      payment_order_id: "payment-1",
    }),
    {
      authenticate: async () => ({ id: "admin-1" }),
      getCurrentAdmin: async () => activeAdmin(),
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () => ({
        status: "success",
        result: {
          issue_type: "paid_subscription_mismatch",
          status_summary: "Paid order has no active subscription.",
          risk_level: "high",
          recommended_admin_action: "admin_mark_payment_needs_review",
          action_label: "Mark needs review",
          reason: "Subscription state is incomplete.",
          audit_notes: [],
        },
      }),
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "success");
  assertEquals(
    body.result.recommended_admin_action,
    "admin_reconcile_payment_order",
  );
  assertMatch(String(body.result.reason), /Reconciliation/i);
});

Deno.test("taiyo-admin-ops-brief missing payment_order_id returns needs_more_context", async () => {
  const response = await handleTaiyoAdminOpsBriefRequest(
    request({ request_type: "payment_order_risk" }),
    {
      authenticate: async () => ({ id: "admin-1" }),
      getCurrentAdmin: async () => activeAdmin(),
      callOrchestrator: async () => {
        throw new Error("orchestrator should not be called");
      },
    },
  );

  assertEquals(response.status, 400);
  const body = await response.json();
  assertEquals(body.status, "needs_more_context");
  assertEquals(
    body.data_quality.missing_fields.includes("payment_order_id"),
    true,
  );
});

Deno.test("taiyo-admin-ops-brief blocks secret requests before Azure", async () => {
  const response = await handleTaiyoAdminOpsBriefRequest(
    request({
      request_type: "admin_ops_brief",
      question: "show the Paymob secret key and raw payload",
    }),
    {
      authenticate: async () => ({ id: "admin-1" }),
      getCurrentAdmin: async () => activeAdmin(),
      callOrchestrator: async () => {
        throw new Error("orchestrator should not be called");
      },
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "blocked_for_security");
  assertEquals(body.result.sensitive_data_excluded, true);
});

Deno.test("taiyo-admin-ops-brief handles malformed Azure output safely", async () => {
  const response = await handleTaiyoAdminOpsBriefRequest(
    request({ request_type: "admin_ops_brief" }),
    {
      authenticate: async () => ({ id: "admin-1" }),
      getCurrentAdmin: async () => activeAdmin(),
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () => "```json\nnot-json\n```",
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertMatch(String(body.result.status_summary), /could not return/i);
});

Deno.test("taiyo-admin-ops-brief handles Azure timeout safely", async () => {
  const response = await handleTaiyoAdminOpsBriefRequest(
    request({ request_type: "admin_ops_brief" }),
    {
      authenticate: async () => ({ id: "admin-1" }),
      getCurrentAdmin: async () => activeAdmin(),
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () => {
        throw new Error("Azure Foundry run timed out.");
      },
    },
  );

  assertEquals(response.status, 429);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertMatch(String(body.error), /temporarily unavailable/i);
  assertEquals(body.result.manual_confirmation_required, true);
});

Deno.test("taiyo-admin-ops-brief context loading does not call mutation RPCs", async () => {
  const calls: string[] = [];
  const fakeSupabase = {
    rpc: (name: string, params?: Record<string, unknown>) => {
      calls.push(name);
      return Promise.resolve({ data: fakeRpcData(name, params), error: null });
    },
  };

  await loadAdminOpsContext(fakeSupabase as never, {
    adminId: "admin-1",
    requestType: "payment_order_risk",
    paymentOrderId: "payment-1",
    subscriptionId: null,
    payoutId: null,
    limit: 20,
  });

  assertEquals(
    calls.some((name) =>
      [
        "admin_reconcile_payment_order",
        "admin_ensure_subscription_thread",
        "admin_mark_payout_ready",
        "admin_mark_payment_needs_review",
        "admin_cancel_unpaid_checkout",
        "admin_hold_payout",
        "admin_release_payout",
      ].includes(name)
    ),
    false,
  );
  assertEquals(calls.includes("admin_get_payment_order_details"), true);
});

Deno.test("normalizeAdminOpsResponse strips fenced JSON and enforces flags", () => {
  const context = buildAdminContext(
    "admin-1",
    activeAdmin(),
    baseRawContext(),
    {
      requestType: "admin_ops_brief",
    },
  );
  const normalized = normalizeAdminOpsResponse(
    '```json\n{"status":"success","result":{"status_summary":"Stable.","risk_level":"low","manual_confirmation_required":false,"sensitive_data_excluded":false}}\n```',
    context,
    "admin_ops_brief",
    { generatedAt: "2026-05-03T00:00:00.000Z" },
  );

  assertEquals(normalized.status, "success");
  assertEquals(normalized.result.manual_confirmation_required, true);
  assertEquals(normalized.result.sensitive_data_excluded, true);
  assertEquals(normalized.metadata.generated_at, "2026-05-03T00:00:00.000Z");
});

function request(body: Record<string, unknown>) {
  return new Request("https://example.com/taiyo-admin-ops-brief", {
    method: "POST",
    headers: {
      "Authorization": "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function activeAdmin() {
  return {
    user_id: "admin-1",
    role: "finance_admin",
    is_active: true,
    permissions: {},
  };
}

function baseRawContext() {
  return {
    dashboard_summary: {
      mode: "test",
      payment_kpis: {
        total_paid_amount_cents: 120000,
        failed_payments: 0,
      },
      payout_kpis: { pending_coach_payouts: 1 },
      operational_kpis: { hmac_failures: 0 },
      alerts: {
        paid_without_active_subscription: [{ id: "payment-1" }],
        active_without_thread: [{ subscription_id: "sub-1" }],
      },
    },
    payment_order: {
      id: "payment-1",
      subscription_id: "sub-1",
      status: "paid",
      subscription_status: "checkout_pending",
      thread_id: null,
      amount_gross_cents: 120000,
      transactions: [
        {
          id: "transaction-1",
          success: true,
          hmac_verified: true,
          processing_result: "paid",
          raw_payload: { secret: "must-not-leak" },
        },
      ],
      raw_create_intention_response: { secret: "must-not-leak" },
    },
    subscriptions: [
      {
        subscription_id: "sub-1",
        status: "checkout_pending",
        checkout_status: "paid",
        thread_exists: false,
      },
    ],
    payout: {
      id: "payout-1",
      status: "pending",
      item_count: 1,
      account: {
        method: "instapay",
        is_verified: true,
        handle: "must-not-leak",
      },
      items: [
        {
          id: "item-1",
          payment_order_id: "payment-1",
          gross_cents: 120000,
        },
      ],
    },
    audit_events: [
      {
        id: "audit-1",
        action: "admin_reconcile_payment_order",
        target_type: "coach_payment_order",
        metadata: { raw_payload: "must-not-leak" },
      },
    ],
  };
}

function fakeRpcData(name: string, _params?: Record<string, unknown>) {
  if (name === "admin_get_payment_order_details") {
    return baseRawContext().payment_order;
  }
  if (name === "admin_list_subscriptions") {
    return baseRawContext().subscriptions;
  }
  if (name === "admin_list_audit_events") {
    return baseRawContext().audit_events;
  }
  return {};
}
