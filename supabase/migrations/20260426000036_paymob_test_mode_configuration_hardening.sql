-- Paymob test-mode hardening.
-- Legacy manual receipt review must never activate or fail Paymob-backed
-- subscriptions. Paymob subscription activation is owned by verified callbacks.

create or replace function public.verify_coach_payment(
  target_receipt_id uuid,
  input_note text default null
)
returns public.coach_payment_receipts
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  receipt_record public.coach_payment_receipts%rowtype;
  latest_receipt_id uuid;
  subscription_record public.subscriptions%rowtype;
  package_record public.coach_packages%rowtype;
  computed_next_renewal timestamptz;
  computed_end timestamptz;
  thread_id uuid;
  previous_billing_state text;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can verify payments.';
  end if;

  select *
  into receipt_record
  from public.coach_payment_receipts
  where id = target_receipt_id
    and coach_id = requester
  for update;

  if receipt_record.id is null then
    raise exception 'Receipt not found.';
  end if;

  select id
  into latest_receipt_id
  from public.coach_payment_receipts
  where subscription_id = receipt_record.subscription_id
    and coach_id = requester
    and status in ('submitted', 'receipt_uploaded', 'under_verification')
  order by created_at desc
  limit 1;

  if latest_receipt_id is distinct from receipt_record.id then
    raise exception 'Only the latest submitted payment proof can be approved.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = receipt_record.subscription_id
    and coach_id = requester
  for update;

  if subscription_record.id is null then
    raise exception 'Subscription not found.';
  end if;

  if coalesce(subscription_record.payment_gateway, subscription_record.payment_method) = 'paymob'
     or subscription_record.payment_order_id is not null then
    raise exception 'Paymob payments can only be activated by verified Paymob callbacks.';
  end if;

  previous_billing_state := public.coach_billing_state(
    subscription_record.status,
    subscription_record.checkout_status,
    receipt_record.status
  );

  select *
  into package_record
  from public.coach_packages
  where id = subscription_record.package_id;

  computed_next_renewal := case subscription_record.billing_cycle
    when 'weekly' then timezone('utc', now()) + interval '7 days'
    when 'quarterly' then timezone('utc', now()) + interval '3 months'
    when 'one_time' then null
    else timezone('utc', now()) + interval '1 month'
  end;

  computed_end := case subscription_record.billing_cycle
    when 'one_time' then timezone('utc', now()) + make_interval(days => greatest(coalesce(package_record.trial_days, 0), 1))
    else computed_next_renewal
  end;

  update public.subscriptions
  set status = 'active',
      checkout_status = 'paid',
      payment_method = coalesce(payment_method, 'manual'),
      starts_at = coalesce(starts_at, timezone('utc', now())),
      ends_at = coalesce(ends_at, computed_end),
      activated_at = coalesce(activated_at, timezone('utc', now())),
      next_renewal_at = computed_next_renewal,
      payment_reference = coalesce(receipt_record.payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where id = subscription_record.id
  returning * into subscription_record;

  update public.coach_checkout_requests
  set status = 'confirmed',
      payment_reference = coalesce(receipt_record.payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where subscription_id = subscription_record.id;

  update public.coach_payment_receipts
  set status = 'activated',
      reviewed_by = requester,
      reviewed_at = timezone('utc', now()),
      failure_reason = null
  where id = receipt_record.id
  returning * into receipt_record;

  thread_id := public.ensure_coach_member_thread(subscription_record.id);

  insert into public.coach_payment_audit_events (
    subscription_id,
    receipt_id,
    actor_user_id,
    old_state,
    new_state,
    note
  )
  values (
    subscription_record.id,
    receipt_record.id,
    requester,
    previous_billing_state,
    'activated',
    coalesce(input_note, 'Coach verified manual payment.')
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    subscription_record.member_id,
    'coaching',
    'Payment verified',
    'Your coach verified payment and activated your coaching workspace.',
    jsonb_build_object('subscription_id', subscription_record.id, 'thread_id', thread_id)
  );

  return receipt_record;
end;
$$;

create or replace function public.fail_coach_payment(
  target_receipt_id uuid,
  input_reason text
)
returns public.coach_payment_receipts
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  receipt_record public.coach_payment_receipts%rowtype;
  latest_receipt_id uuid;
  cleaned_reason text := trim(coalesce(input_reason, ''));
  subscription_record public.subscriptions%rowtype;
  previous_billing_state text;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can review payments.';
  end if;

  if cleaned_reason = '' then
    raise exception 'Failure reason is required.';
  end if;

  select *
  into receipt_record
  from public.coach_payment_receipts
  where id = target_receipt_id
    and coach_id = requester
  for update;

  if receipt_record.id is null then
    raise exception 'Receipt not found.';
  end if;

  select id
  into latest_receipt_id
  from public.coach_payment_receipts
  where subscription_id = receipt_record.subscription_id
    and coach_id = requester
    and status in ('submitted', 'receipt_uploaded', 'under_verification')
  order by created_at desc
  limit 1;

  if latest_receipt_id is distinct from receipt_record.id then
    raise exception 'Only the latest submitted payment proof can be failed.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = receipt_record.subscription_id
    and coach_id = requester;

  if subscription_record.id is null then
    raise exception 'Subscription not found.';
  end if;

  if coalesce(subscription_record.payment_gateway, subscription_record.payment_method) = 'paymob'
     or subscription_record.payment_order_id is not null then
    raise exception 'Paymob payments can only be failed by verified Paymob callbacks.';
  end if;

  previous_billing_state := public.coach_billing_state(
    subscription_record.status,
    subscription_record.checkout_status,
    receipt_record.status
  );

  update public.coach_payment_receipts
  set status = 'failed',
      reviewed_by = requester,
      reviewed_at = timezone('utc', now()),
      failure_reason = cleaned_reason
  where id = receipt_record.id
  returning * into receipt_record;

  update public.subscriptions
  set checkout_status = 'failed',
      updated_at = timezone('utc', now())
  where id = receipt_record.subscription_id
    and status in ('checkout_pending', 'pending_payment', 'pending_activation');

  update public.coach_checkout_requests
  set status = 'failed',
      updated_at = timezone('utc', now())
  where subscription_id = receipt_record.subscription_id;

  insert into public.coach_payment_audit_events (
    subscription_id,
    receipt_id,
    actor_user_id,
    old_state,
    new_state,
    note
  )
  values (
    receipt_record.subscription_id,
    receipt_record.id,
    requester,
    previous_billing_state,
    'failed_needs_follow_up',
    cleaned_reason
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    receipt_record.member_id,
    'coaching',
    'Payment needs follow-up',
    cleaned_reason,
    jsonb_build_object('subscription_id', receipt_record.subscription_id, 'receipt_id', receipt_record.id)
  );

  return receipt_record;
end;
$$;

grant execute on function public.verify_coach_payment(uuid, text) to authenticated;
grant execute on function public.fail_coach_payment(uuid, text) to authenticated;
