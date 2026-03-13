import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export type LifecycleState =
  | "pending"
  | "active"
  | "renewing"
  | "cancellation_requested_active_until_expiry"
  | "expired"
  | "grace_period"
  | "on_hold_or_suspended"
  | "restored_or_restarted"
  | "revoked_or_refunded";

export type PurchasePayload = {
  offering_code?: string;
  product_id?: string;
  purchase_id?: string;
  transaction_date?: string;
  purchase_status?: string;
  verification_data?: {
    source?: string;
    local_verification_data?: string;
    server_verification_data?: string;
  };
  google?: {
    purchase_token?: string;
    obfuscated_account_id?: string;
    package_name?: string;
    products?: string[];
    original_json?: string;
  };
};

export type UpsertBillingStateInput = {
  supabase: SupabaseClient;
  userId: string;
  offeringCode: string;
  planCode: string | null;
  platform: "ios" | "android";
  productId: string;
  basePlanId?: string | null;
  entitlementCode?: string;
  purchaseState: string;
  lifecycleState: LifecycleState;
  transactionId: string;
  originalTransactionId?: string | null;
  purchaseToken?: string | null;
  transactionDate?: string | null;
  accessExpiresAt?: string | null;
  renewsAt?: string | null;
  cancellationRequestedAt?: string | null;
  gracePeriodUntil?: string | null;
  environment?: string | null;
  verificationSource?: string | null;
  rawPayload: unknown;
};

export function createServiceClient() {
  const supabaseUrl = getEnvOrThrow("SUPABASE_URL");
  const serviceRoleKey = getEnvOrThrow("SUPABASE_SERVICE_ROLE_KEY");

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
}

export function getEnvOrThrow(name: string) {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

export async function authenticateUser(
  supabase: SupabaseClient,
  req: Request,
) {
  const authHeader = req.headers.get("Authorization");
  const token = authHeader?.replace("Bearer ", "").trim();
  if (!token) {
    throw new Error("Missing auth token");
  }

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    throw new Error("Unauthorized");
  }

  return { token, user: data.user };
}

export function entitlementStatusForLifecycle(
  lifecycleState: LifecycleState,
) {
  switch (lifecycleState) {
    case "active":
    case "renewing":
    case "grace_period":
    case "cancellation_requested_active_until_expiry":
    case "restored_or_restarted":
      return "enabled";
    case "pending":
      return "pending";
    case "expired":
    case "on_hold_or_suspended":
    case "revoked_or_refunded":
      return "disabled";
  }
}

export function parseDate(raw: string | null | undefined) {
  if (!raw) {
    return null;
  }

  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed.toISOString();
}

export async function upsertBillingState(input: UpsertBillingStateInput) {
  const verifiedAt = new Date().toISOString();
  const entitlementStatus = entitlementStatusForLifecycle(input.lifecycleState);

  const transactionPayload = {
    user_id: input.userId,
    offering_code: input.offeringCode,
    plan_code: input.planCode,
    entitlement_code: input.entitlementCode ?? "ai_premium_access",
    source_platform: input.platform,
    store_product_id: input.productId,
    store_base_plan_id: input.basePlanId ?? "",
    purchase_state: input.purchaseState,
    lifecycle_state: input.lifecycleState,
    entitlement_status: entitlementStatus,
    transaction_id: input.transactionId,
    original_transaction_id: input.originalTransactionId ?? null,
    purchase_token: input.purchaseToken ?? "",
    transaction_date: parseDate(input.transactionDate),
    access_expires_at: parseDate(input.accessExpiresAt),
    renews_at: parseDate(input.renewsAt),
    cancellation_requested_at: parseDate(input.cancellationRequestedAt),
    grace_period_until: parseDate(input.gracePeriodUntil),
    environment: input.environment ?? null,
    verification_source: input.verificationSource ?? null,
    raw_payload: input.rawPayload ?? {},
    last_verified_at: verifiedAt,
    updated_at: verifiedAt,
  };

  const entitlementPayload = {
    user_id: input.userId,
    offering_code: input.offeringCode,
    plan_code: input.planCode,
    entitlement_code: input.entitlementCode ?? "ai_premium_access",
    source_platform: input.platform,
    store_product_id: input.productId,
    store_base_plan_id: input.basePlanId ?? "",
    lifecycle_state: input.lifecycleState,
    entitlement_status: entitlementStatus,
    latest_transaction_id: input.transactionId,
    latest_purchase_token: input.purchaseToken ?? "",
    access_expires_at: parseDate(input.accessExpiresAt),
    renews_at: parseDate(input.renewsAt),
    cancellation_requested_at: parseDate(input.cancellationRequestedAt),
    grace_period_until: parseDate(input.gracePeriodUntil),
    last_verified_at: verifiedAt,
    metadata: {
      environment: input.environment ?? null,
      verification_source: input.verificationSource ?? null,
    },
    updated_at: verifiedAt,
  };

  const { error: transactionError } = await input.supabase
    .from("store_transactions")
    .upsert(transactionPayload, {
      onConflict: "source_platform,transaction_id",
    });
  if (transactionError) {
    throw new Error(transactionError.message);
  }

  const { data: entitlementRows, error: entitlementError } = await input.supabase
    .from("subscription_entitlements")
    .upsert(entitlementPayload, {
      onConflict: "user_id,offering_code",
    })
    .select(
      "offering_code,entitlement_code,entitlement_status,lifecycle_state," +
        "plan_code,source_platform,store_product_id,store_base_plan_id," +
        "latest_transaction_id,latest_purchase_token,access_expires_at," +
        "renews_at,last_verified_at,cancellation_requested_at," +
        "grace_period_until,metadata",
    )
    .single();
  if (entitlementError) {
    throw new Error(entitlementError.message);
  }

  return entitlementRows;
}

export async function recordSyncEvent({
  supabase,
  platform,
  eventType,
  externalEventId,
  rawPayload,
  verificationState = "pending",
}: {
  supabase: SupabaseClient;
  platform: "ios" | "android";
  eventType: string;
  externalEventId?: string | null;
  rawPayload: unknown;
  verificationState?: string;
}) {
  const { error } = await supabase.from("billing_sync_events").insert({
    source_platform: platform,
    event_type: eventType,
    external_event_id: externalEventId ?? null,
    verification_state: verificationState,
    raw_payload: rawPayload ?? {},
  });
  if (error) {
    throw new Error(error.message);
  }
}
