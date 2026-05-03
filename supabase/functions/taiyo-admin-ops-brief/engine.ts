export type AdminOpsRequestType =
  | "admin_ops_brief"
  | "payment_order_risk"
  | "repair_recommendation"
  | "payout_review"
  | "audit_explanation";

export type AdminOpsStatus =
  | "success"
  | "needs_more_context"
  | "blocked_for_security"
  | "error";

export type RiskLevel = "low" | "medium" | "high";
export type Confidence = "low" | "medium" | "high";

export type AdminOpsContext = {
  admin_id: string;
  role: "admin";
  admin_profile: Record<string, unknown>;
  request_type: AdminOpsRequestType;
  dashboard_summary: Record<string, unknown>;
  payment_order: Record<string, unknown>;
  payout: Record<string, unknown>;
  subscriptions: Record<string, unknown>[];
  audit_events: Record<string, unknown>[];
  operational_signals: Record<string, unknown>;
  allowed_admin_actions: string[];
  sensitive_data_excluded: true;
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
};

export type NormalizedAdminOpsBrief = {
  request_type: AdminOpsRequestType;
  status: AdminOpsStatus;
  result: {
    issue_type: string;
    status_summary: string;
    risk_level: RiskLevel;
    recommended_admin_action: string;
    action_label: string;
    reason: string;
    audit_notes: string[];
    manual_confirmation_required: true;
    sensitive_data_excluded: true;
  };
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
  metadata: {
    source: "supabase_edge_function";
    generated_at: string;
    debug_context?: AdminOpsContext;
    raw_text?: string;
  };
};

const allowedActions = [
  "admin_reconcile_payment_order",
  "admin_ensure_subscription_thread",
  "admin_mark_payout_ready",
  "admin_mark_payment_needs_review",
  "admin_cancel_unpaid_checkout",
  "admin_hold_payout",
  "admin_release_payout",
];

export function obj(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export function arr(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export function str(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

export function strings(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return compactStrings(value.map((item) => str(item)));
}

export function num(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function bool(value: unknown): boolean {
  return value === true;
}

export function supportedRequestType(
  value: unknown,
): AdminOpsRequestType {
  const resolved = str(value) || "admin_ops_brief";
  if (
    resolved === "admin_ops_brief" ||
    resolved === "payment_order_risk" ||
    resolved === "repair_recommendation" ||
    resolved === "payout_review" ||
    resolved === "audit_explanation"
  ) {
    return resolved;
  }
  throw new Error("Unsupported request_type.");
}

export function containsSecretRequest(value: unknown): boolean {
  const text = searchableText(value).toLowerCase();
  if (!text) return false;
  const sensitive = [
    "service role",
    "service_role",
    "supabase key",
    "api key",
    "apikey",
    "hmac secret",
    "hmac key",
    "secret key",
    "paymob secret",
    "password",
    "access token",
    "raw payload",
    "raw paymob",
  ];
  const verbs = [
    "show",
    "print",
    "return",
    "expose",
    "reveal",
    "dump",
    "include",
    "send",
  ];
  return sensitive.some((needle) => text.includes(needle)) &&
    verbs.some((verb) => text.includes(verb));
}

export function blockedForSecurityResponse(
  requestType: AdminOpsRequestType,
  options: { generatedAt?: string } = {},
): NormalizedAdminOpsBrief {
  return baseResponse(
    requestType,
    "blocked_for_security",
    {
      issue_type: "security_request",
      status_summary:
        "TAIYO cannot expose secrets, raw private payment payloads, tokens, or credentials.",
      risk_level: "high",
      recommended_admin_action: "",
      action_label: "",
      reason:
        "Operational summaries can exclude sensitive data, but secret material must stay out of AI responses.",
      audit_notes: ["Sensitive data request blocked before Azure."],
    },
    { missing_fields: [], confidence: "high" },
    options.generatedAt,
  );
}

export function needsMoreContextResponse(
  requestType: AdminOpsRequestType,
  missingFields: string[],
  message: string,
  options: { generatedAt?: string } = {},
): NormalizedAdminOpsBrief {
  return baseResponse(
    requestType,
    "needs_more_context",
    {
      issue_type: requestType,
      status_summary: message,
      risk_level: "medium",
      recommended_admin_action: "",
      action_label: "",
      reason: "The request is missing required scoped identifiers.",
      audit_notes: [],
    },
    { missing_fields: missingFields, confidence: "low" },
    options.generatedAt,
  );
}

export function buildAdminContext(
  adminId: string,
  admin: unknown,
  rawContext: unknown,
  options: {
    requestType: AdminOpsRequestType;
    paymentOrderId?: string | null;
    subscriptionId?: string | null;
    payoutId?: string | null;
  },
): AdminOpsContext {
  const raw = obj(rawContext);
  const dashboard = obj(raw.dashboard_summary);
  const paymentOrder = compactPaymentOrder(obj(raw.payment_order));
  const payout = compactPayout(obj(raw.payout));
  const subscriptions = arr(raw.subscriptions).map(obj).map(compactSubscription)
    .slice(0, 20);
  const auditEvents = arr(raw.audit_events).map(obj).map(compactAuditEvent)
    .slice(0, 30);
  const alerts = compactAlerts(obj(dashboard.alerts));
  const missingFields = compactStrings([
    Object.keys(dashboard).length || options.requestType !== "admin_ops_brief"
      ? null
      : "admin_dashboard_summary",
    options.paymentOrderId && !Object.keys(paymentOrder).length
      ? "payment_order"
      : null,
    options.subscriptionId && !subscriptions.length ? "subscription" : null,
    options.payoutId && !Object.keys(payout).length ? "payout" : null,
    options.requestType === "audit_explanation" && !auditEvents.length
      ? "audit_events"
      : null,
  ]);

  return {
    admin_id: adminId,
    role: "admin",
    admin_profile: compactAdmin(admin),
    request_type: options.requestType,
    dashboard_summary: compactDashboard(dashboard, alerts),
    payment_order: paymentOrder,
    payout,
    subscriptions,
    audit_events: auditEvents,
    operational_signals: {
      alert_counts: Object.fromEntries(
        Object.entries(alerts).map(([key, value]) => [key, value.length]),
      ),
      payment_order_status: str(paymentOrder.status),
      subscription_status: str(paymentOrder.subscription_status) ||
        str(subscriptions[0]?.status),
      thread_missing: threadMissing(paymentOrder, subscriptions),
      payout_status: str(payout.status),
      hmac_failures: Math.round(
        num(obj(dashboard.operational_kpis).hmac_failures) ?? 0,
      ),
    },
    allowed_admin_actions: allowedActions,
    sensitive_data_excluded: true,
    data_quality: {
      missing_fields: missingFields,
      confidence: confidenceFor(missingFields),
    },
  };
}

export function buildOrchestratorInput(
  requestType: AdminOpsRequestType,
  context: AdminOpsContext,
) {
  return {
    request_type: requestType,
    user_role: "admin",
    admin_context: context,
    response_format: "json",
    instruction:
      "Return only valid JSON. Do not return markdown. Do not expose secrets. Recommend admin actions only; do not execute actions. Preserve exact admin action names where appropriate.",
    expected_response_shape: {
      request_type: requestType,
      status: "success | needs_more_context | blocked_for_security | error",
      result: {
        issue_type: "string",
        status_summary: "string",
        risk_level: "low | medium | high",
        recommended_admin_action: "string",
        action_label: "string",
        reason: "string",
        audit_notes: ["string"],
        manual_confirmation_required: true,
        sensitive_data_excluded: true,
      },
      data_quality: {
        missing_fields: ["string"],
        confidence: "low | medium | high",
      },
    },
  };
}

export function normalizeAdminOpsResponse(
  aiOutput: unknown,
  context: AdminOpsContext,
  requestType: AdminOpsRequestType,
  options: { generatedAt?: string; debug?: boolean } = {},
): NormalizedAdminOpsBrief {
  const generatedAt = options.generatedAt || new Date().toISOString();
  const parsed = typeof aiOutput === "string"
    ? parseJsonFromText(aiOutput)
    : aiOutput;
  const raw = obj(parsed);
  if (!Object.keys(raw).length) {
    return errorResponse(
      requestType,
      context,
      "TAIYO could not return a valid admin operations brief right now.",
      generatedAt,
      options.debug,
      typeof aiOutput === "string" ? aiOutput : undefined,
    );
  }

  const result = obj(raw.result);
  const missingFields = compactStrings([
    ...context.data_quality.missing_fields,
    ...strings(raw.missing_fields),
    ...strings(result.missing_fields),
    ...strings(obj(raw.data_quality).missing_fields),
  ]);
  const deterministic = deterministicRecommendation(context);
  const statusSummary = str(result.status_summary) || str(raw.status_summary) ||
    str(result.summary) || str(raw.summary) || "";
  const action = deterministic?.action ||
    allowedAction(
      str(result.recommended_admin_action) ||
        str(raw.recommended_admin_action),
    );

  return {
    request_type: requestType,
    status: normalizeStatus(str(raw.status), statusSummary, missingFields),
    result: {
      issue_type: str(result.issue_type) || str(raw.issue_type) || requestType,
      status_summary: statusSummary,
      risk_level: risk(
        deterministic?.riskLevel ||
          str(result.risk_level) ||
          str(raw.risk_level),
      ),
      recommended_admin_action: action,
      action_label: deterministic?.label ||
        str(result.action_label) ||
        str(raw.action_label) ||
        labelForAction(action),
      reason: deterministic?.reason ||
        str(result.reason) ||
        str(raw.reason) ||
        "",
      audit_notes: compactStrings([
        ...strings(result.audit_notes),
        ...strings(raw.audit_notes),
        ...(deterministic?.auditNote ? [deterministic.auditNote] : []),
      ]),
      manual_confirmation_required: true,
      sensitive_data_excluded: true,
    },
    data_quality: {
      missing_fields: missingFields,
      confidence: confidence(
        str(obj(raw.data_quality).confidence),
        confidenceFor(missingFields),
      ),
    },
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(options.debug ? { debug_context: context } : {}),
    },
  };
}

export function parseJsonFromText(text: string): unknown {
  const cleaned = text
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(cleaned.slice(start, end + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
}

function baseResponse(
  requestType: AdminOpsRequestType,
  status: AdminOpsStatus,
  result: Omit<
    NormalizedAdminOpsBrief["result"],
    "manual_confirmation_required" | "sensitive_data_excluded"
  >,
  dataQuality: NormalizedAdminOpsBrief["data_quality"],
  generatedAt = new Date().toISOString(),
): NormalizedAdminOpsBrief {
  return {
    request_type: requestType,
    status,
    result: {
      ...result,
      manual_confirmation_required: true,
      sensitive_data_excluded: true,
    },
    data_quality: dataQuality,
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
    },
  };
}

function errorResponse(
  requestType: AdminOpsRequestType,
  context: AdminOpsContext,
  message: string,
  generatedAt: string,
  debug = false,
  rawText?: string,
): NormalizedAdminOpsBrief {
  return {
    request_type: requestType,
    status: "error",
    result: {
      issue_type: requestType,
      status_summary: message,
      risk_level: "low",
      recommended_admin_action: "",
      action_label: "",
      reason: "",
      audit_notes: [],
      manual_confirmation_required: true,
      sensitive_data_excluded: true,
    },
    data_quality: context.data_quality,
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(debug
        ? {
          debug_context: context,
          raw_text: rawText?.slice(0, 2000),
        }
        : {}),
    },
  };
}

function compactAdmin(admin: unknown) {
  const row = obj(admin);
  return {
    role: str(row.role) || "admin",
    is_active: bool(row.is_active) || row.is_active !== false,
  };
}

function compactDashboard(
  dashboard: Record<string, unknown>,
  alerts: Record<string, Record<string, unknown>[]>,
) {
  if (!Object.keys(dashboard).length) return {};
  return {
    mode: str(dashboard.mode),
    payment_kpis: numericRecord(obj(dashboard.payment_kpis)),
    payout_kpis: numericRecord(obj(dashboard.payout_kpis)),
    operational_kpis: numericRecord(obj(dashboard.operational_kpis)),
    alert_counts: Object.fromEntries(
      Object.entries(alerts).map(([key, value]) => [key, value.length]),
    ),
    recent_activity_counts: {
      successful_payments:
        arr(obj(dashboard.recent_activity).successful_payments)
          .length,
      failed_payments: arr(obj(dashboard.recent_activity).failed_payments)
        .length,
      audit_events: arr(obj(dashboard.recent_activity).audit_events).length,
    },
  };
}

function compactAlerts(alerts: Record<string, unknown>) {
  const result: Record<string, Record<string, unknown>[]> = {};
  for (const [key, value] of Object.entries(alerts)) {
    result[key] = arr(value).map(obj).map((row) => ({
      id: str(row.id) || str(row.subscription_id) || str(row.payment_order_id),
      status: str(row.status),
      checkout_status: str(row.checkout_status),
      amount_cents: Math.round(num(row.amount_cents) ?? 0),
      created_at: str(row.created_at),
      processing_result: str(row.processing_result),
    })).slice(0, 8);
  }
  return result;
}

function compactPaymentOrder(order: Record<string, unknown>) {
  if (!Object.keys(order).length) return {};
  return {
    id: str(order.id),
    subscription_id: str(order.subscription_id),
    member_id_present: Boolean(str(order.member_id)),
    coach_id_present: Boolean(str(order.coach_id)),
    package_title: str(order.package_title),
    amount_gross_cents: Math.round(num(order.amount_gross_cents) ?? 0),
    platform_fee_cents: Math.round(num(order.platform_fee_cents) ?? 0),
    gateway_fee_cents: Math.round(num(order.gateway_fee_cents) ?? 0),
    coach_net_cents: Math.round(num(order.coach_net_cents) ?? 0),
    currency: str(order.currency) || "EGP",
    status: str(order.status) || "created",
    mode: str(order.mode),
    special_reference_present: Boolean(str(order.special_reference)),
    paymob_order_id_present: Boolean(str(order.paymob_order_id)),
    paymob_transaction_id_present: Boolean(str(order.paymob_transaction_id)),
    subscription_status: str(order.subscription_status),
    checkout_status: str(order.checkout_status),
    thread_id: str(order.thread_id),
    payout_id: str(order.payout_id),
    payout_status: str(order.payout_status),
    needs_review: bool(order.needs_review),
    review_reason: str(order.review_reason),
    failure_reason: str(order.failure_reason),
    created_at: str(order.created_at),
    paid_at: str(order.paid_at),
    failed_at: str(order.failed_at),
    transactions: arr(order.transactions).map(obj).map(compactTransaction)
      .slice(0, 10),
    audit_events: arr(order.audit_events).map(obj).map(compactAuditEvent)
      .slice(0, 10),
  };
}

function compactTransaction(transaction: Record<string, unknown>) {
  return {
    id: str(transaction.id),
    paymob_transaction_id_present: Boolean(
      str(transaction.paymob_transaction_id),
    ),
    paymob_order_id_present: Boolean(str(transaction.paymob_order_id)),
    success: transaction.success === true,
    pending: transaction.pending === true,
    is_voided: transaction.is_voided === true,
    is_refunded: transaction.is_refunded === true,
    amount_cents: Math.round(num(transaction.amount_cents) ?? 0),
    currency: str(transaction.currency),
    hmac_verified: transaction.hmac_verified === true,
    processing_result: str(transaction.processing_result),
    received_at: str(transaction.received_at),
  };
}

function compactPayout(payout: Record<string, unknown>) {
  if (!Object.keys(payout).length) return {};
  const account = obj(payout.account);
  return {
    id: str(payout.id),
    coach_id_present: Boolean(str(payout.coach_id)),
    amount_cents: Math.round(num(payout.amount_cents) ?? 0),
    currency: str(payout.currency) || "EGP",
    status: str(payout.status) || "pending",
    method: str(payout.method),
    external_reference_present: Boolean(str(payout.external_reference)),
    admin_note_present: Boolean(str(payout.admin_note)),
    item_count: Math.round(num(payout.item_count) ?? arr(payout.items).length),
    account_method: str(account.method),
    account_verified: account.is_verified === true,
    created_at: str(payout.created_at),
    ready_at: str(payout.ready_at),
    paid_at: str(payout.paid_at),
    failed_at: str(payout.failed_at),
    items: arr(payout.items).map(obj).map(compactPayoutItem).slice(0, 20),
    audit_events: arr(payout.audit_events).map(obj).map(compactAuditEvent)
      .slice(0, 10),
  };
}

function compactPayoutItem(item: Record<string, unknown>) {
  const paymentOrder = compactPaymentOrder(obj(item.payment_order));
  return {
    id: str(item.id),
    payment_order_id: str(item.payment_order_id),
    subscription_id: str(item.subscription_id),
    gross_cents: Math.round(num(item.gross_cents) ?? 0),
    platform_fee_cents: Math.round(num(item.platform_fee_cents) ?? 0),
    gateway_fee_cents: Math.round(num(item.gateway_fee_cents) ?? 0),
    coach_net_cents: Math.round(num(item.coach_net_cents) ?? 0),
    payment_order_status: str(paymentOrder.status),
    payment_order_subscription_status: str(paymentOrder.subscription_status),
    created_at: str(item.created_at),
  };
}

function compactSubscription(subscription: Record<string, unknown>) {
  if (!Object.keys(subscription).length) return {};
  return {
    subscription_id: str(subscription.subscription_id) || str(subscription.id),
    status: str(subscription.status),
    checkout_status: str(subscription.checkout_status),
    payment_order_id: str(subscription.payment_order_id),
    payment_order_status: str(subscription.payment_order_status),
    thread_exists: subscription.thread_exists === true ||
      Boolean(str(subscription.thread_id)),
    thread_id: str(subscription.thread_id),
    payout_status: str(subscription.payout_status),
    activated_at: str(subscription.activated_at),
    current_period_end: str(subscription.current_period_end),
  };
}

function compactAuditEvent(event: Record<string, unknown>) {
  if (!Object.keys(event).length) return {};
  return {
    id: str(event.id),
    actor_present: Boolean(str(event.actor_user_id) || str(event.actor_name)),
    action: str(event.action),
    target_type: str(event.target_type),
    target_id: str(event.target_id),
    metadata_keys: Object.keys(obj(event.metadata)).slice(0, 12),
    created_at: str(event.created_at),
  };
}

function deterministicRecommendation(context: AdminOpsContext): {
  action: string;
  label: string;
  reason: string;
  auditNote: string;
  riskLevel: RiskLevel;
} | null {
  const payment = context.payment_order;
  const firstSubscription = context.subscriptions[0] || {};
  const paymentStatus = str(payment.status);
  const subscriptionStatus = str(payment.subscription_status) ||
    str(firstSubscription.status);
  const missingThread = threadMissing(payment, context.subscriptions);
  if (
    paymentStatus === "paid" &&
    subscriptionStatus !== "active" &&
    missingThread
  ) {
    return {
      action: "admin_reconcile_payment_order",
      label: "Reconcile payment order",
      reason:
        "Payment appears paid while the subscription/thread state is incomplete. Reconciliation should repair payment-derived subscription state first.",
      auditNote: "Recommendation only; admin must confirm manually.",
      riskLevel: "high",
    };
  }
  if (subscriptionStatus === "active" && missingThread) {
    return {
      action: "admin_ensure_subscription_thread",
      label: "Ensure subscription thread",
      reason:
        "The subscription is active, but no coach/member thread is present in the sanitized context.",
      auditNote: "Recommendation only; admin must confirm manually.",
      riskLevel: "medium",
    };
  }
  const payout = context.payout;
  if (
    ["pending", "on_hold"].includes(str(payout.status) || "") &&
    Math.round(num(payout.item_count) ?? arr(payout.items).length) > 0
  ) {
    return {
      action: "admin_mark_payout_ready",
      label: "Mark payout ready",
      reason:
        "The payout has payable items and is not marked ready in the sanitized context.",
      auditNote: "Recommendation only; admin must confirm manually.",
      riskLevel: "medium",
    };
  }
  return null;
}

function threadMissing(
  payment: Record<string, unknown>,
  subscriptions: Record<string, unknown>[],
) {
  if (str(payment.thread_id)) return false;
  if (
    subscriptions.some((subscription) => subscription.thread_exists === true)
  ) {
    return false;
  }
  return Boolean(str(payment.subscription_id) || subscriptions.length);
}

function normalizeStatus(
  value: string | null,
  summary: string,
  missingFields: string[],
): AdminOpsStatus {
  if (
    value === "success" ||
    value === "needs_more_context" ||
    value === "blocked_for_security" ||
    value === "error"
  ) return value;
  if (missingFields.length) return "needs_more_context";
  return summary ? "success" : "error";
}

function allowedAction(value: string | null) {
  return value && allowedActions.includes(value) ? value : "";
}

function labelForAction(action: string) {
  return action ? action.replace(/^admin_/, "").replaceAll("_", " ") : "";
}

function risk(value: string | null): RiskLevel {
  if (value === "high" || value === "medium" || value === "low") return value;
  return "low";
}

function confidence(value: string | null, fallback: Confidence): Confidence {
  if (value === "high" || value === "medium" || value === "low") {
    return value;
  }
  return fallback;
}

function confidenceFor(missingFields: string[]): Confidence {
  if (missingFields.length >= 3) return "low";
  if (missingFields.length >= 1) return "medium";
  return "high";
}

function numericRecord(value: Record<string, unknown>) {
  return Object.fromEntries(
    Object.entries(value).map(([key, rowValue]) => [
      key,
      num(rowValue) ?? 0,
    ]),
  );
}

function compactStrings(values: Array<string | null | undefined>) {
  return Array.from(
    new Set(
      values
        .filter((value): value is string => Boolean(value && value.trim()))
        .map((value) => value.trim()),
    ),
  );
}

function searchableText(value: unknown): string {
  if (typeof value === "string") return value;
  if (Array.isArray(value)) return value.map(searchableText).join(" ");
  const row = obj(value);
  return Object.entries(row)
    .map(([key, item]) => `${key} ${searchableText(item)}`)
    .join(" ");
}
