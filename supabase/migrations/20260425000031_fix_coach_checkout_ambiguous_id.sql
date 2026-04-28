-- Fix ambiguous output-column references in coach checkout RPCs.
-- PostgreSQL treats RETURNS TABLE columns (for example `id`) as PL/pgSQL
-- variables, so unqualified `where id = ...` can conflict with table columns.

create or replace function public.create_coach_checkout(
  target_package_id uuid,
  selected_payment_rail text default 'instapay',
  input_member_note text default null,
  input_intake_snapshot jsonb default '{}'::jsonb
)
returns table (
  id uuid,
  member_id uuid,
  member_name text,
  coach_id uuid,
  package_id uuid,
  package_title text,
  plan_name text,
  billing_cycle text,
  amount numeric,
  status text,
  checkout_status text,
  payment_method text,
  starts_at timestamptz,
  ends_at timestamptz,
  activated_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz,
  member_note text,
  intake_snapshot_json jsonb,
  next_renewal_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  package_record public.coach_packages%rowtype;
  coach_record public.coach_profiles%rowtype;
  created_subscription public.subscriptions%rowtype;
  charge_amount numeric(10,2);
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can start coach checkout.';
  end if;

  if selected_payment_rail not in ('card', 'instapay', 'wallet', 'manual_fallback') then
    raise exception 'Unsupported payment rail.';
  end if;

  select pkg.*
  into package_record
  from public.coach_packages pkg
  where pkg.id = target_package_id
    and pkg.visibility_status = 'published';

  if package_record.id is null then
    raise exception 'Coach package not found.';
  end if;

  select cp.*
  into coach_record
  from public.coach_profiles cp
  where cp.user_id = package_record.coach_id;

  if exists (
    select 1
    from public.subscriptions s
    where s.member_id = requester
      and s.package_id = package_record.id
      and s.status in ('checkout_pending', 'pending_payment', 'pending_activation', 'active', 'paused')
  ) then
    raise exception 'You already have an open coaching relationship for this offer.';
  end if;

  if selected_payment_rail <> 'manual_fallback'
     and not (coalesce(package_record.payment_rails, '{card,instapay,wallet}'::text[]) @> array[selected_payment_rail]) then
    raise exception 'Selected payment rail is not available for this offer.';
  end if;

  charge_amount := case
    when coach_record.trial_offer_enabled = true
      and coalesce(package_record.trial_days, 0) > 0
      and coalesce(coach_record.trial_price_egp, 0) > 0 then coach_record.trial_price_egp
    when coalesce(package_record.deposit_amount_egp, 0) > 0 then package_record.deposit_amount_egp
    when coalesce(package_record.renewal_price_egp, 0) > 0 then package_record.renewal_price_egp
    else package_record.price
  end;

  insert into public.subscriptions (
    member_id,
    coach_id,
    package_id,
    plan_name,
    billing_cycle,
    amount,
    status,
    checkout_status,
    payment_method,
    member_note,
    intake_snapshot_json
  )
  values (
    requester,
    package_record.coach_id,
    package_record.id,
    package_record.title,
    package_record.billing_cycle,
    charge_amount,
    'checkout_pending',
    'checkout_pending',
    selected_payment_rail,
    input_member_note,
    coalesce(input_intake_snapshot, '{}'::jsonb)
  )
  returning * into created_subscription;

  insert into public.coach_checkout_requests (
    subscription_id,
    member_id,
    coach_id,
    package_id,
    payment_rail,
    requested_amount,
    payment_reference
  )
  values (
    created_subscription.id,
    created_subscription.member_id,
    created_subscription.coach_id,
    created_subscription.package_id,
    selected_payment_rail,
    charge_amount,
    null
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    package_record.coach_id,
    'coaching',
    'New paid checkout started',
    'A member started checkout for "' || package_record.title || '".',
    jsonb_build_object(
      'subscription_id', created_subscription.id,
      'package_id', package_record.id,
      'checkout_status', 'checkout_pending',
      'payment_rail', selected_payment_rail
    )
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    requester,
    'coaching',
    'Checkout started',
    'Complete the payment to activate your coaching thread and weekly check-ins.',
    jsonb_build_object(
      'subscription_id', created_subscription.id,
      'package_id', package_record.id,
      'checkout_status', 'checkout_pending',
      'payment_rail', selected_payment_rail
    )
  );

  return query
  select
    s.id,
    s.member_id,
    coalesce(nullif(p.full_name, ''), 'GymUnity Member') as member_name,
    s.coach_id,
    s.package_id,
    coalesce(pkg.title, nullif(s.plan_name, ''), 'Coaching Offer') as package_title,
    s.plan_name,
    s.billing_cycle,
    s.amount,
    s.status,
    s.checkout_status,
    s.payment_method,
    s.starts_at,
    s.ends_at,
    s.activated_at,
    s.cancelled_at,
    s.created_at,
    s.member_note,
    s.intake_snapshot_json,
    s.next_renewal_at
  from public.subscriptions s
  join public.profiles p on p.user_id = s.member_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  where s.id = created_subscription.id;
end;
$$;

create or replace function public.confirm_coach_payment(
  target_subscription_id uuid,
  input_payment_reference text default null
)
returns table (
  id uuid,
  member_id uuid,
  member_name text,
  coach_id uuid,
  package_id uuid,
  package_title text,
  plan_name text,
  billing_cycle text,
  amount numeric,
  status text,
  checkout_status text,
  payment_method text,
  starts_at timestamptz,
  ends_at timestamptz,
  activated_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz,
  member_note text,
  intake_snapshot_json jsonb,
  next_renewal_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  existing_subscription public.subscriptions%rowtype;
  package_record public.coach_packages%rowtype;
  checkout_record public.coach_checkout_requests%rowtype;
  effective_start timestamptz := timezone('utc', now());
  computed_end timestamptz;
  computed_next_renewal timestamptz;
  created_thread_id uuid;
  commission_amount numeric(10,2);
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can confirm coach payments.';
  end if;

  select s.*
  into existing_subscription
  from public.subscriptions s
  where s.id = target_subscription_id
    and s.member_id = requester;

  if existing_subscription.id is null then
    raise exception 'Subscription not found.';
  end if;

  if existing_subscription.status not in ('checkout_pending', 'pending_payment', 'pending_activation') then
    raise exception 'This subscription is not waiting for payment confirmation.';
  end if;

  select pkg.*
  into package_record
  from public.coach_packages pkg
  where pkg.id = existing_subscription.package_id;

  select ccr.*
  into checkout_record
  from public.coach_checkout_requests ccr
  where ccr.subscription_id = existing_subscription.id
  order by ccr.created_at desc
  limit 1;

  if checkout_record.id is null then
    raise exception 'Checkout request not found.';
  end if;

  computed_next_renewal := case existing_subscription.billing_cycle
    when 'weekly' then effective_start + interval '7 days'
    when 'quarterly' then effective_start + interval '3 months'
    when 'one_time' then null
    else effective_start + interval '1 month'
  end;

  computed_end := case existing_subscription.billing_cycle
    when 'one_time' then effective_start + make_interval(days => greatest(coalesce(package_record.trial_days, 0), 1))
    else computed_next_renewal
  end;

  update public.subscriptions as s
  set status = 'active',
      checkout_status = 'paid',
      payment_method = checkout_record.payment_rail,
      starts_at = coalesce(s.starts_at, effective_start),
      ends_at = coalesce(s.ends_at, computed_end),
      activated_at = coalesce(s.activated_at, effective_start),
      next_renewal_at = computed_next_renewal,
      payment_reference = coalesce(input_payment_reference, s.payment_reference),
      updated_at = timezone('utc', now())
  where s.id = existing_subscription.id
  returning * into existing_subscription;

  update public.coach_checkout_requests as ccr
  set status = 'confirmed',
      payment_reference = coalesce(input_payment_reference, ccr.payment_reference),
      updated_at = timezone('utc', now())
  where ccr.id = checkout_record.id;

  created_thread_id := public.ensure_coach_member_thread(existing_subscription.id);

  commission_amount := round(existing_subscription.amount * 0.15, 2);

  insert into public.coach_payouts (
    coach_id,
    subscription_id,
    gross_amount,
    commission_amount,
    net_amount,
    payout_status,
    eligible_at
  )
  select
    existing_subscription.coach_id,
    existing_subscription.id,
    existing_subscription.amount,
    commission_amount,
    greatest(existing_subscription.amount - commission_amount, 0),
    'held',
    effective_start + interval '14 days'
  where not exists (
    select 1
    from public.coach_payouts cp
    where cp.subscription_id = existing_subscription.id
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    existing_subscription.coach_id,
    'coaching',
    'Checkout paid',
    'A member completed payment and the coaching thread is now live.',
    jsonb_build_object(
      'subscription_id', existing_subscription.id,
      'thread_id', created_thread_id,
      'status', 'active'
    )
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    requester,
    'coaching',
    'Payment confirmed',
    'Your coaching subscription is active. Start your first weekly check-in now.',
    jsonb_build_object(
      'subscription_id', existing_subscription.id,
      'thread_id', created_thread_id,
      'status', 'active'
    )
  );

  return query
  select
    s.id,
    s.member_id,
    coalesce(nullif(p.full_name, ''), 'GymUnity Member') as member_name,
    s.coach_id,
    s.package_id,
    coalesce(pkg.title, nullif(s.plan_name, ''), 'Coaching Offer') as package_title,
    s.plan_name,
    s.billing_cycle,
    s.amount,
    s.status,
    s.checkout_status,
    s.payment_method,
    s.starts_at,
    s.ends_at,
    s.activated_at,
    s.cancelled_at,
    s.created_at,
    s.member_note,
    s.intake_snapshot_json,
    s.next_renewal_at
  from public.subscriptions s
  join public.profiles p on p.user_id = s.member_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  where s.id = existing_subscription.id;
end;
$$;

grant execute on function public.create_coach_checkout(uuid, text, text, jsonb) to authenticated;
grant execute on function public.confirm_coach_payment(uuid, text) to authenticated;
