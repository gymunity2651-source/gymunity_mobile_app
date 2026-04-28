import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  authenticateUser,
  buildCheckoutUrl,
  calculatePlatformFeeCents,
  centsFromEgp,
  checkoutCorsHeaders,
  createServiceClient,
  getPaymobConfig,
  HttpError,
  jsonResponse,
  objectFrom,
  sha256Hex,
  stringOrNull,
  type JsonMap,
  type PaymobConfig,
} from "../_shared/paymob.ts";

type CheckoutPayload = {
  package_id?: string;
  coach_id?: string;
  primary_goal?: string;
  experience_level?: string;
  days_per_week?: number;
  session_minutes?: number;
  city?: string;
  equipment?: string[] | string;
  limitations?: string[] | string;
  note_to_coach?: string;
  intake?: JsonMap;
};

type CheckoutDeps = {
  supabase?: SupabaseClient;
  paymobConfig?: PaymobConfig;
  fetch?: typeof fetch;
};

export async function handleCreateCoachPaymobCheckout(
  req: Request,
  deps: CheckoutDeps = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: checkoutCorsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabase = deps.supabase ?? createServiceClient();
    const config = deps.paymobConfig ?? getPaymobConfig();
    const fetcher = deps.fetch ?? fetch;
    const { user } = await authenticateUser(supabase, req);
    const payload = (await req.json().catch(() => ({}))) as CheckoutPayload;
    const packageId = payload.package_id?.trim();
    if (!packageId) {
      throw new HttpError("package_id is required.", 400);
    }

    const profile = await loadMemberProfile(supabase, user.id);
    if (profile.roleCode !== "member") {
      throw new HttpError("Only members can start coach payments.", 403);
    }

    const packageRecord = await loadPackage(supabase, packageId);
    const coachId = stringOrNull(packageRecord["coach_id"]);
    if (!coachId) {
      throw new HttpError("Coach package is missing a coach.", 400);
    }
    if (payload.coach_id?.trim() && payload.coach_id.trim() !== coachId) {
      throw new HttpError("Coach does not own this package.", 400);
    }
    if (packageRecord["visibility_status"] !== "published" || packageRecord["is_active"] !== true) {
      throw new HttpError("Coach package is not available for checkout.", 400);
    }

    const coachProfile = await loadCoachProfile(supabase, coachId);
    const existingSubscription = await findReusableOrDuplicateSubscription(
      supabase,
      user.id,
      packageId,
      coachId,
    );
    if (existingSubscription?.isDuplicate) {
      throw new HttpError("You already have an open coaching relationship for this coach or offer.", 409);
    }

    const amountGrossCents = resolveChargeAmountCents(packageRecord, coachProfile);
    const platformFeeCents = calculatePlatformFeeCents(
      amountGrossCents,
      config.platformFeeBps,
    );
    const gatewayFeeCents = 0;
    const coachNetCents = Math.max(0, amountGrossCents - platformFeeCents - gatewayFeeCents);
    const intakeSnapshot = buildIntakeSnapshot(payload);
    const noteToCoach = stringOrNull(payload.note_to_coach);

    const subscription = existingSubscription?.row ??
      await createSubscription(supabase, {
        memberId: user.id,
        coachId,
        packageRecord,
        amountGrossCents,
        platformFeeCents,
        coachNetCents,
        intakeSnapshot,
        noteToCoach,
      });

    const specialReference = buildSpecialReference(subscription.id);
    const paymentOrder = await createPaymentOrder(supabase, {
      subscription,
      packageId,
      amountGrossCents,
      platformFeeCents,
      gatewayFeeCents,
      coachNetCents,
      specialReference,
      config,
    });

    const intentionPayload = buildPaymobIntentionPayload({
      config,
      amountGrossCents,
      packageRecord,
      profile,
      userEmail: user.email,
      subscription,
      paymentOrder,
      coachId,
      packageId,
      specialReference,
      intakeSnapshot,
    });

    let paymobResponse: JsonMap;
    try {
      paymobResponse = await createPaymobIntention(
        fetcher,
        config,
        intentionPayload,
      );
    } catch (error) {
      await markCheckoutCreationFailed(supabase, {
        paymentOrderId: paymentOrder.id,
        subscriptionId: subscription.id,
        reason: error instanceof Error ? error.message : "Paymob intention creation failed.",
      });
      throw error;
    }

    const clientSecret = stringOrNull(paymobResponse["client_secret"]);
    if (!clientSecret) {
      throw new Error("Paymob did not return a client_secret.");
    }
    const checkoutUrl = stringOrNull(paymobResponse["checkout_url"]) ??
      buildCheckoutUrl(config.apiBaseUrl, config.publicKey, clientSecret);
    const paymobIntentionId = stringOrNull(
      paymobResponse["id"] ?? paymobResponse["intention_id"],
    );
    const paymobOrderId = stringOrNull(
      paymobResponse["order_id"] ??
        paymobResponse["intention_order_id"] ??
        objectFrom(paymobResponse["order"])?.["id"] ??
        objectFrom(paymobResponse["order"])?.["order_id"] ??
        firstPaymentKeyOrderId(paymobResponse),
    );
    const clientSecretHash = await sha256Hex(clientSecret);

    await updatePaymentOrderAfterPaymobCreate(supabase, {
      paymentOrderId: paymentOrder.id,
      subscriptionId: subscription.id,
      paymobResponse,
      paymobIntentionId,
      paymobOrderId,
      clientSecretHash,
      checkoutUrl,
    });

    await notifyCheckoutStarted(supabase, {
      memberId: user.id,
      coachId,
      subscriptionId: subscription.id,
      paymentOrderId: paymentOrder.id,
      packageTitle: stringOrNull(packageRecord["title"]) ?? "Coaching offer",
    });

    return jsonResponse({
      payment_order_id: paymentOrder.id,
      subscription_id: subscription.id,
      paymob_client_secret: clientSecret,
      paymob_public_key: config.publicKey,
      checkout_url: checkoutUrl,
      amount_gross_cents: amountGrossCents,
      currency: config.currency,
      mode: config.mode,
      status: "pending",
    });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    return jsonResponse({
      error: error instanceof Error ? error.message : "Unknown checkout error",
    }, status);
  }
}

async function loadMemberProfile(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from("profiles")
    .select("user_id,full_name,phone,roles(code)")
    .eq("user_id", userId)
    .single();
  if (error || !data) {
    throw new HttpError("Member profile not found.", 403);
  }

  const role = objectFrom((data as JsonMap)["roles"]);
  return {
    fullName: stringOrNull((data as JsonMap)["full_name"]),
    phone: stringOrNull((data as JsonMap)["phone"]),
    roleCode: stringOrNull(role?.["code"]),
  };
}

async function loadPackage(supabase: SupabaseClient, packageId: string): Promise<JsonMap> {
  const { data, error } = await supabase
    .from("coach_packages")
    .select("*")
    .eq("id", packageId)
    .single();
  if (error || !data) {
    throw new HttpError("Coach package not found.", 404);
  }
  return data as JsonMap;
}

async function loadCoachProfile(supabase: SupabaseClient, coachId: string): Promise<JsonMap> {
  const { data, error } = await supabase
    .from("coach_profiles")
    .select("user_id,trial_offer_enabled,trial_price_egp")
    .eq("user_id", coachId)
    .single();
  if (error || !data) {
    throw new HttpError("Coach profile not found.", 404);
  }
  return data as JsonMap;
}

async function findReusableOrDuplicateSubscription(
  supabase: SupabaseClient,
  memberId: string,
  packageId: string,
  coachId: string,
): Promise<{ row?: SubscriptionRow; isDuplicate: boolean } | null> {
  const { data, error } = await supabase
    .from("subscriptions")
    .select("id,member_id,coach_id,package_id,status,checkout_status,payment_gateway,payment_method")
    .eq("member_id", memberId)
    .in("status", ["checkout_pending", "pending_payment", "pending_activation", "active", "paused"])
    .or(`package_id.eq.${packageId},coach_id.eq.${coachId}`)
    .order("created_at", { ascending: false })
    .limit(1);
  if (error) {
    throw new Error(error.message);
  }

  const row = (data?.[0] as JsonMap | undefined) ?? null;
  if (!row) {
    return null;
  }

  const canRetryFailedPaymob =
    row["checkout_status"] === "failed" &&
    (row["payment_gateway"] === "paymob" || row["payment_method"] === "paymob");

  return {
    isDuplicate: !canRetryFailedPaymob,
    row: canRetryFailedPaymob ? mapSubscriptionRow(row) : undefined,
  };
}

type SubscriptionRow = {
  id: string;
  member_id: string;
  coach_id: string;
  package_id: string | null;
};

function mapSubscriptionRow(row: JsonMap): SubscriptionRow {
  return {
    id: String(row["id"]),
    member_id: String(row["member_id"]),
    coach_id: String(row["coach_id"]),
    package_id: stringOrNull(row["package_id"]),
  };
}

function resolveChargeAmountCents(packageRecord: JsonMap, coachProfile: JsonMap): number {
  const trialDays = Number(packageRecord["trial_days"] ?? 0);
  const trialPrice = Number(coachProfile["trial_price_egp"] ?? 0);
  const trialEnabled = coachProfile["trial_offer_enabled"] === true;
  const deposit = Number(packageRecord["deposit_amount_egp"] ?? 0);
  const renewal = Number(packageRecord["renewal_price_egp"] ?? 0);
  const price = Number(packageRecord["price"] ?? 0);

  if (trialEnabled && trialDays > 0 && trialPrice > 0) {
    return centsFromEgp(trialPrice);
  }
  if (deposit > 0) {
    return centsFromEgp(deposit);
  }
  if (renewal > 0) {
    return centsFromEgp(renewal);
  }
  return centsFromEgp(price);
}

function buildIntakeSnapshot(payload: CheckoutPayload): JsonMap {
  return {
    ...(objectFrom(payload.intake) ?? {}),
    primary_goal: stringOrNull(payload.primary_goal),
    goal: stringOrNull(payload.primary_goal) ?? stringOrNull(objectFrom(payload.intake)?.["goal"]),
    experience_level: stringOrNull(payload.experience_level),
    days_per_week: integerOrUndefined(payload.days_per_week),
    session_minutes: integerOrUndefined(payload.session_minutes),
    city: stringOrNull(payload.city),
    equipment: normalizeStringList(payload.equipment),
    limitations: normalizeStringList(payload.limitations),
  };
}

async function createSubscription(
  supabase: SupabaseClient,
  input: {
    memberId: string;
    coachId: string;
    packageRecord: JsonMap;
    amountGrossCents: number;
    platformFeeCents: number;
    coachNetCents: number;
    intakeSnapshot: JsonMap;
    noteToCoach: string | null;
  },
): Promise<SubscriptionRow> {
  const { data, error } = await supabase
    .from("subscriptions")
    .insert({
      member_id: input.memberId,
      coach_id: input.coachId,
      package_id: input.packageRecord["id"],
      plan_name: input.packageRecord["title"] ?? "Coaching Offer",
      billing_cycle: input.packageRecord["billing_cycle"] ?? "monthly",
      amount: input.amountGrossCents / 100,
      status: "checkout_pending",
      checkout_status: "checkout_pending",
      payment_method: "paymob",
      payment_gateway: "paymob",
      amount_cents: input.amountGrossCents,
      currency: "EGP",
      platform_fee_cents: input.platformFeeCents,
      coach_net_cents: input.coachNetCents,
      member_note: input.noteToCoach,
      intake_snapshot_json: input.intakeSnapshot,
    })
    .select("id,member_id,coach_id,package_id")
    .single();
  if (error || !data) {
    throw new Error(error?.message ?? "Unable to create subscription.");
  }
  return mapSubscriptionRow(data as JsonMap);
}

async function createPaymentOrder(
  supabase: SupabaseClient,
  input: {
    subscription: SubscriptionRow;
    packageId: string;
    amountGrossCents: number;
    platformFeeCents: number;
    gatewayFeeCents: number;
    coachNetCents: number;
    specialReference: string;
    config: PaymobConfig;
  },
): Promise<{ id: string }> {
  const { data, error } = await supabase
    .from("coach_payment_orders")
    .insert({
      subscription_id: input.subscription.id,
      member_id: input.subscription.member_id,
      coach_id: input.subscription.coach_id,
      package_id: input.packageId,
      currency: input.config.currency,
      amount_gross_cents: input.amountGrossCents,
      platform_fee_cents: input.platformFeeCents,
      gateway_fee_cents: input.gatewayFeeCents,
      coach_net_cents: input.coachNetCents,
      payment_gateway: "paymob",
      mode: input.config.mode,
      status: "created",
      special_reference: input.specialReference,
    })
    .select("id")
    .single();
  if (error || !data) {
    throw new Error(error?.message ?? "Unable to create payment order.");
  }
  return { id: String((data as JsonMap)["id"]) };
}

function buildPaymobIntentionPayload(input: {
  config: PaymobConfig;
  amountGrossCents: number;
  packageRecord: JsonMap;
  profile: { fullName: string | null; phone: string | null };
  userEmail?: string | null;
  subscription: SubscriptionRow;
  paymentOrder: { id: string };
  coachId: string;
  packageId: string;
  specialReference: string;
  intakeSnapshot: JsonMap;
}): JsonMap {
  const nameParts = (input.profile.fullName ?? "GymUnity Member").split(/\s+/);
  const firstName = nameParts[0] || "GymUnity";
  const lastName = nameParts.slice(1).join(" ") || "Member";
  const packageTitle = stringOrNull(input.packageRecord["title"]) ?? "Coach package";

  return {
    amount: input.amountGrossCents,
    currency: input.config.currency,
    payment_methods: input.config.integrationIds,
    billing_data: {
      first_name: firstName,
      last_name: lastName,
      email: input.userEmail ?? "test@gymunity.local",
      phone_number: input.profile.phone ?? "01000000000",
      apartment: "NA",
      floor: "NA",
      street: "NA",
      building: "NA",
      shipping_method: "NA",
      postal_code: "NA",
      city: stringOrNull(input.intakeSnapshot["city"]) ?? "Cairo",
      country: "EG",
      state: "NA",
    },
    items: [{
      name: packageTitle,
      amount: input.amountGrossCents,
      description: stringOrNull(input.packageRecord["description"]) ?? packageTitle,
      quantity: 1,
    }],
    special_reference: input.specialReference,
    notification_url: input.config.notificationUrl,
    redirection_url: input.config.redirectUrl,
    extras: {
      subscription_id: input.subscription.id,
      payment_order_id: input.paymentOrder.id,
      member_id: input.subscription.member_id,
      coach_id: input.coachId,
      package_id: input.packageId,
      special_reference: input.specialReference,
      mode: input.config.mode,
    },
  };
}

async function createPaymobIntention(
  fetcher: typeof fetch,
  config: PaymobConfig,
  payload: JsonMap,
): Promise<JsonMap> {
  const response = await fetcher(`${config.apiBaseUrl}/v1/intention/`, {
    method: "POST",
    headers: {
      "Authorization": `Token ${config.secretKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const body = await response.json().catch(() => ({})) as JsonMap;
  if (!response.ok) {
    throw new Error(
      stringOrNull(body["detail"] ?? body["message"] ?? body["error"]) ??
        `Paymob intention creation failed with status ${response.status}.`,
    );
  }
  return body;
}

function firstPaymentKeyOrderId(paymobResponse: JsonMap): unknown {
  const paymentKeys = paymobResponse["payment_keys"];
  if (!Array.isArray(paymentKeys) || paymentKeys.length === 0) {
    return null;
  }
  return objectFrom(paymentKeys[0])?.["order_id"];
}

async function updatePaymentOrderAfterPaymobCreate(
  supabase: SupabaseClient,
  input: {
    paymentOrderId: string;
    subscriptionId: string;
    paymobResponse: JsonMap;
    paymobIntentionId: string | null;
    paymobOrderId: string | null;
    clientSecretHash: string;
    checkoutUrl: string;
  },
) {
  const { error: orderError } = await supabase
    .from("coach_payment_orders")
    .update({
      status: "pending",
      paymob_intention_id: input.paymobIntentionId,
      paymob_order_id: input.paymobOrderId,
      paymob_client_secret_hash: input.clientSecretHash,
      checkout_url: input.checkoutUrl,
      raw_create_intention_response: input.paymobResponse,
      updated_at: new Date().toISOString(),
    })
    .eq("id", input.paymentOrderId);
  if (orderError) {
    throw new Error(orderError.message);
  }

  const { error: subscriptionError } = await supabase
    .from("subscriptions")
    .update({
      payment_order_id: input.paymentOrderId,
      checkout_status: "checkout_pending",
      updated_at: new Date().toISOString(),
    })
    .eq("id", input.subscriptionId);
  if (subscriptionError) {
    throw new Error(subscriptionError.message);
  }
}

async function markCheckoutCreationFailed(
  supabase: SupabaseClient,
  input: {
    paymentOrderId: string;
    subscriptionId: string;
    reason: string;
  },
) {
  const now = new Date().toISOString();
  await supabase
    .from("coach_payment_orders")
    .update({
      status: "failed",
      failure_reason: input.reason,
      failed_at: now,
      updated_at: now,
    })
    .eq("id", input.paymentOrderId);
  await supabase
    .from("subscriptions")
    .update({
      checkout_status: "failed",
      updated_at: now,
    })
    .eq("id", input.subscriptionId);
}

async function notifyCheckoutStarted(
  supabase: SupabaseClient,
  input: {
    memberId: string;
    coachId: string;
    subscriptionId: string;
    paymentOrderId: string;
    packageTitle: string;
  },
) {
  await supabase.from("notifications").insert([
    {
      user_id: input.memberId,
      type: "payment",
      title: "TEST payment started",
      body: "Paymob test checkout was opened. GymUnity will activate your subscription after Paymob confirms payment.",
      data: {
        subscription_id: input.subscriptionId,
        payment_order_id: input.paymentOrderId,
        mode: "test",
      },
    },
    {
      user_id: input.coachId,
      type: "coaching",
      title: "Client checkout started",
      body: `A client started Paymob test checkout for "${input.packageTitle}".`,
      data: {
        subscription_id: input.subscriptionId,
        payment_order_id: input.paymentOrderId,
        mode: "test",
      },
    },
  ]);

  const { data: admins } = await supabase
    .from("app_admins")
    .select("user_id")
    .eq("is_active", true);
  const adminRows = (admins ?? []) as JsonMap[];
  if (adminRows.length > 0) {
    await supabase.from("notifications").insert(adminRows.map((row) => ({
      user_id: row["user_id"],
      type: "payment",
      title: "Paymob checkout started",
      body: "A coach subscription test checkout was created.",
      data: {
        subscription_id: input.subscriptionId,
        payment_order_id: input.paymentOrderId,
        mode: "test",
      },
    })));
  }
}

function buildSpecialReference(subscriptionId: string): string {
  const shortRandom = crypto.randomUUID().replaceAll("-", "").slice(0, 10);
  return `gymunity_coach_${subscriptionId.replaceAll("-", "")}_${shortRandom}`;
}

function normalizeStringList(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.map((item) => String(item).trim()).filter((item) => item.length > 0);
  }
  if (typeof value === "string") {
    return value.split(/[,;\n]/).map((item) => item.trim()).filter((item) => item.length > 0);
  }
  return [];
}

function integerOrUndefined(value: unknown): number | undefined {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : undefined;
}

if (import.meta.main) {
  Deno.serve((req) => handleCreateCoachPaymobCheckout(req));
}
