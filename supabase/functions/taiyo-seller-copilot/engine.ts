export type SellerCopilotRequestType =
  | "seller_dashboard_brief"
  | "seller_product_advice"
  | "seller_order_brief";

export type SellerCopilotStatus =
  | "success"
  | "needs_more_context"
  | "error";

export type RiskLevel = "low" | "medium" | "high";
export type Confidence = "low" | "medium" | "high";

export type SellerContext = {
  seller_id: string;
  role: "seller";
  profile: Record<string, unknown>;
  dashboard_summary: Record<string, unknown>;
  active_products: Record<string, unknown>[];
  low_stock_products: Record<string, unknown>[];
  inactive_products: Record<string, unknown>[];
  recent_orders: Record<string, unknown>[];
  order_status_distribution: Record<string, number>;
  recent_order_issues: Record<string, unknown>[];
  product_categories: string[];
  sales_signals: Record<string, unknown>;
  selected_product: Record<string, unknown>;
  selected_order: Record<string, unknown>;
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
};

export type NormalizedSellerCopilot = {
  request_type: SellerCopilotRequestType;
  status: SellerCopilotStatus;
  result: {
    summary: string;
    priority_actions: string[];
    product_opportunities: string[];
    order_notes: string[];
    risk_level: RiskLevel;
    recommended_next_step: string;
  };
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
  metadata: {
    source: "supabase_edge_function";
    generated_at: string;
    debug_context?: SellerContext;
    raw_text?: string;
  };
};

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

export function supportedRequestType(
  value: unknown,
): SellerCopilotRequestType {
  const resolved = str(value) || "seller_dashboard_brief";
  if (
    resolved === "seller_dashboard_brief" ||
    resolved === "seller_product_advice" ||
    resolved === "seller_order_brief"
  ) {
    return resolved;
  }
  throw new Error("Unsupported request_type.");
}

export function buildSellerContext(
  sellerId: string,
  rawContext: unknown,
  options: { productId?: string | null; orderId?: string | null } = {},
): SellerContext {
  const raw = obj(rawContext);
  const products = arr(raw.products).map(obj);
  const orders = arr(raw.orders).map(obj);
  const orderItems = arr(raw.order_items).map(obj);
  const orderHistory = arr(raw.order_status_history).map(obj);
  const dashboard = obj(raw.dashboard_summary);

  const activeProducts = products.filter((product) =>
    product.is_active !== false && !str(product.deleted_at)
  );
  const lowStockProducts = activeProducts.filter((product) => {
    const stock = num(product.stock_qty) ?? 0;
    const threshold = num(product.low_stock_threshold) ?? 0;
    return stock <= threshold;
  });
  const inactiveProducts = products.filter((product) =>
    product.is_active === false || Boolean(str(product.deleted_at))
  );
  const recentOrders = orders.slice(0, 12).map((order) =>
    compactOrder(order, orderItems, orderHistory)
  );
  const statusDistribution = orderStatusDistribution(orders);
  const recentIssues = recentOrders.filter((order) =>
    ["pending", "cancelled", "failed", "refunded"].includes(
      (str(order.status) || "").toLowerCase(),
    ) || strings(order.issue_signals).length > 0
  ).slice(0, 8);
  const categories = compactStrings(products.map((product) =>
    str(product.category)
  ));

  const selectedProduct = products.find((product) =>
    str(product.id) === options.productId
  ) || {};
  const selectedOrder = recentOrders.find((order) =>
    str(order.id) === options.orderId
  ) || {};

  const missingFields = compactStrings([
    Object.keys(raw.profile || {}).length ? null : "seller_profile",
    products.length ? null : "products",
    orders.length ? null : "orders",
    Object.keys(dashboard).length ? null : "seller_dashboard_summary",
    options.productId && !Object.keys(selectedProduct).length
      ? "selected_product"
      : null,
    options.orderId && !Object.keys(selectedOrder).length
      ? "selected_order"
      : null,
  ]);

  return {
    seller_id: sellerId,
    role: "seller",
    profile: compactProfile(obj(raw.profile)),
    dashboard_summary: compactDashboard(dashboard),
    active_products: activeProducts.slice(0, 24).map(compactProduct),
    low_stock_products: lowStockProducts.slice(0, 12).map(compactProduct),
    inactive_products: inactiveProducts.slice(0, 12).map(compactProduct),
    recent_orders: recentOrders,
    order_status_distribution: statusDistribution,
    recent_order_issues: recentIssues,
    product_categories: categories,
    sales_signals: {
      gross_revenue: num(dashboard.gross_revenue) ?? 0,
      active_products: activeProducts.length,
      low_stock_products: lowStockProducts.length,
      pending_orders: statusDistribution.pending || 0,
      in_progress_orders: ["paid", "processing", "shipped"].reduce(
        (sum, status) => sum + (statusDistribution[status] || 0),
        0,
      ),
      delivered_orders: statusDistribution.delivered || 0,
    },
    selected_product: compactProduct(selectedProduct),
    selected_order: selectedOrder,
    data_quality: {
      missing_fields: missingFields,
      confidence: confidenceFor(missingFields),
    },
  };
}

export function buildOrchestratorInput(
  requestType: SellerCopilotRequestType,
  sellerContext: SellerContext,
) {
  return {
    request_type: requestType,
    user_role: "seller",
    seller_context: sellerContext,
    response_format: "json",
    instruction:
      "Return only valid JSON. Do not return markdown. Provide recommendations only. Do not modify products or orders.",
    expected_response_shape: {
      request_type: requestType,
      status: "success | needs_more_context | error",
      result: {
        summary: "string",
        priority_actions: ["string"],
        product_opportunities: ["string"],
        order_notes: ["string"],
        risk_level: "low | medium | high",
        recommended_next_step: "string",
      },
      data_quality: {
        missing_fields: ["string"],
        confidence: "low | medium | high",
      },
    },
  };
}

export function normalizeSellerCopilotResponse(
  aiOutput: unknown,
  sellerContext: SellerContext,
  requestType: SellerCopilotRequestType,
  options: { generatedAt?: string; debug?: boolean } = {},
): NormalizedSellerCopilot {
  const generatedAt = options.generatedAt || new Date().toISOString();
  const parsed = typeof aiOutput === "string"
    ? parseJsonFromText(aiOutput)
    : aiOutput;
  const raw = obj(parsed);
  if (!Object.keys(raw).length) {
    return errorResponse(
      requestType,
      sellerContext,
      "TAIYO could not return a valid seller brief right now.",
      generatedAt,
      options.debug,
      typeof aiOutput === "string" ? aiOutput : undefined,
    );
  }

  const result = obj(raw.result);
  const missingFields = compactStrings([
    ...sellerContext.data_quality.missing_fields,
    ...strings(raw.missing_fields),
    ...strings(result.missing_fields),
    ...strings(obj(raw.data_quality).missing_fields),
  ]);
  const summary = str(result.summary) || str(raw.summary) || "";
  const status = normalizeStatus(str(raw.status), summary, missingFields);

  return {
    request_type: requestType,
    status,
    result: {
      summary,
      priority_actions: compactStrings([
        ...strings(result.priority_actions),
        ...strings(raw.priority_actions),
      ]),
      product_opportunities: compactStrings([
        ...strings(result.product_opportunities),
        ...strings(raw.product_opportunities),
      ]),
      order_notes: compactStrings([
        ...strings(result.order_notes),
        ...strings(raw.order_notes),
      ]),
      risk_level: risk(str(result.risk_level) || str(raw.risk_level)),
      recommended_next_step: str(result.recommended_next_step) ||
        str(raw.recommended_next_step) || "",
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
      ...(options.debug ? { debug_context: sellerContext } : {}),
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

function compactProfile(profile: Record<string, unknown>) {
  if (!Object.keys(profile).length) return {};
  return {
    store_name: str(profile.store_name),
    store_description: str(profile.store_description),
    primary_category: str(profile.primary_category),
    shipping_scope: str(profile.shipping_scope),
    support_email_present: Boolean(str(profile.support_email)),
  };
}

function compactDashboard(row: Record<string, unknown>) {
  if (!Object.keys(row).length) return {};
  return {
    total_products: Math.round(num(row.total_products) ?? 0),
    active_products: Math.round(num(row.active_products) ?? 0),
    low_stock_products: Math.round(num(row.low_stock_products) ?? 0),
    pending_orders: Math.round(num(row.pending_orders) ?? 0),
    in_progress_orders: Math.round(num(row.in_progress_orders) ?? 0),
    delivered_orders: Math.round(num(row.delivered_orders) ?? 0),
    gross_revenue: num(row.gross_revenue) ?? 0,
  };
}

function compactProduct(product: Record<string, unknown>) {
  if (!Object.keys(product).length) return {};
  return {
    id: str(product.id),
    title: str(product.title),
    category: str(product.category),
    price: num(product.price),
    currency: str(product.currency) || "USD",
    stock_qty: Math.round(num(product.stock_qty) ?? 0),
    low_stock_threshold: Math.round(num(product.low_stock_threshold) ?? 0),
    is_active: product.is_active !== false && !str(product.deleted_at),
    created_at: str(product.created_at),
    updated_at: str(product.updated_at),
  };
}

function compactOrder(
  order: Record<string, unknown>,
  orderItems: Record<string, unknown>[],
  orderHistory: Record<string, unknown>[],
) {
  const id = str(order.id) || "";
  const items = orderItems.filter((item) => str(item.order_id) === id);
  const history = orderHistory.filter((entry) => str(entry.order_id) === id);
  const latestHistory = history[0] || {};
  return {
    id,
    status: str(order.status) || "pending",
    total_amount: num(order.total_amount) ?? 0,
    currency: str(order.currency) || "USD",
    payment_method: str(order.payment_method),
    member_name_present: Boolean(str(order.member_name)),
    item_count: Math.round(num(order.item_count) ?? items.length),
    created_at: str(order.created_at),
    updated_at: str(order.updated_at),
    top_items: items.slice(0, 5).map((item) => ({
      product_id: str(item.product_id),
      product_title: str(item.product_title_snapshot),
      quantity: Math.round(num(item.quantity) ?? 0),
      line_total: num(item.line_total) ?? 0,
    })),
    latest_status_note: str(latestHistory.note),
    latest_status_at: str(latestHistory.created_at),
    issue_signals: issueSignals(order, latestHistory),
  };
}

function orderStatusDistribution(orders: Record<string, unknown>[]) {
  const result: Record<string, number> = {};
  for (const order of orders) {
    const status = (str(order.status) || "unknown").toLowerCase();
    result[status] = (result[status] || 0) + 1;
  }
  return result;
}

function issueSignals(
  order: Record<string, unknown>,
  latestHistory: Record<string, unknown>,
) {
  const signals = new Set<string>();
  const status = (str(order.status) || "").toLowerCase();
  if (status === "pending") signals.add("pending_order");
  if (["cancelled", "failed", "refunded"].includes(status)) {
    signals.add(status);
  }
  const note = (str(latestHistory.note) || "").toLowerCase();
  if (note.includes("delay")) signals.add("delay_note");
  if (note.includes("stock")) signals.add("stock_note");
  if (note.includes("refund")) signals.add("refund_note");
  return Array.from(signals);
}

function normalizeStatus(
  value: string | null,
  summary: string,
  missingFields: string[],
): SellerCopilotStatus {
  if (
    value === "success" || value === "needs_more_context" || value === "error"
  ) return value;
  if (!summary) return "error";
  return missingFields.length >= 4 ? "needs_more_context" : "success";
}

function errorResponse(
  requestType: SellerCopilotRequestType,
  sellerContext: SellerContext,
  message: string,
  generatedAt: string,
  debug = false,
  rawText?: string,
): NormalizedSellerCopilot {
  return {
    request_type: requestType,
    status: "error",
    result: {
      summary: message,
      priority_actions: [],
      product_opportunities: [],
      order_notes: [],
      risk_level: "low",
      recommended_next_step: "",
    },
    data_quality: sellerContext.data_quality,
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(debug
        ? {
          debug_context: sellerContext,
          raw_text: rawText?.slice(0, 2000),
        }
        : {}),
    },
  };
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
  if (missingFields.length >= 4) return "low";
  if (missingFields.length >= 2) return "medium";
  return "high";
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
