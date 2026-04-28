-- Admin dashboard support for Paymob coach payment settlement.
-- Admins remain outside public AppRole; grant access by inserting rows in app_admins.

alter table public.coach_payment_orders
  add column if not exists admin_note text,
  add column if not exists needs_review boolean not null default false,
  add column if not exists review_reason text;

create index if not exists idx_coach_payment_orders_needs_review
  on public.coach_payment_orders(needs_review, created_at desc);

create or replace function public.current_admin()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case
    when a.user_id is null then null::jsonb
    else jsonb_build_object(
      'user_id', a.user_id,
      'role', a.role,
      'permissions', a.permissions,
      'is_active', a.is_active
    )
  end
  from public.app_admins a
  where a.user_id = auth.uid()
    and a.is_active = true
  limit 1;
$$;

create or replace function public.admin_role_permissions(input_role text)
returns text[]
language sql
immutable
as $$
  select case input_role
    when 'super_admin' then array[
      'payments.read', 'payments.write', 'payouts.read', 'payouts.write',
      'payouts.mark_paid', 'payouts.hold', 'payouts.release', 'coaches.read',
      'subscriptions.read', 'subscriptions.write', 'audit.read',
      'settings.read', 'settings.write'
    ]
    when 'finance_admin' then array[
      'payments.read', 'payments.write', 'payouts.read', 'payouts.write',
      'payouts.mark_paid', 'payouts.hold', 'payouts.release', 'coaches.read',
      'subscriptions.read', 'audit.read', 'settings.read'
    ]
    when 'support_admin' then array[
      'payments.read', 'payouts.read', 'coaches.read', 'subscriptions.read',
      'audit.read', 'settings.read'
    ]
    when 'admin' then array[
      'payments.read', 'payouts.read', 'coaches.read', 'subscriptions.read',
      'audit.read', 'settings.read'
    ]
    else array[]::text[]
  end;
$$;

create or replace function public.admin_has_permission(input_permission text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.app_admins a
    where a.user_id = auth.uid()
      and a.is_active = true
      and (
        a.role = 'super_admin'
        or input_permission = any(public.admin_role_permissions(a.role))
        or coalesce((a.permissions ->> input_permission)::boolean, false)
      )
  );
$$;

create or replace function public.admin_assert_permission(input_permission text)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.admin_has_permission(input_permission) then
    raise exception 'Admin permission "%" is required.', input_permission;
  end if;
end;
$$;

create or replace function public.admin_insert_audit(
  input_action text,
  input_target_type text,
  input_target_id uuid default null,
  input_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  event_id uuid;
begin
  insert into public.admin_audit_events (
    actor_user_id,
    action,
    target_type,
    target_id,
    metadata
  )
  values (
    auth.uid(),
    input_action,
    input_target_type,
    input_target_id,
    coalesce(input_metadata, '{}'::jsonb)
  )
  returning id into event_id;

  return event_id;
end;
$$;

create or replace function public.admin_payment_order_json(
  o public.coach_payment_orders,
  include_raw boolean default false
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', o.id,
    'subscription_id', o.subscription_id,
    'member_id', o.member_id,
    'coach_id', o.coach_id,
    'package_id', o.package_id,
    'member_name', coalesce(nullif(mp.full_name, ''), 'Member'),
    'member_email', mu.email,
    'coach_name', coalesce(nullif(cp.full_name, ''), 'Coach'),
    'coach_email', cu.email,
    'package_title', coalesce(pkg.title, s.plan_name, 'Coaching'),
    'amount_gross_cents', o.amount_gross_cents,
    'platform_fee_cents', o.platform_fee_cents,
    'gateway_fee_cents', o.gateway_fee_cents,
    'coach_net_cents', o.coach_net_cents,
    'currency', o.currency,
    'status', o.status,
    'mode', o.mode,
    'special_reference', o.special_reference,
    'paymob_order_id', o.paymob_order_id,
    'paymob_transaction_id', o.paymob_transaction_id,
    'paymob_intention_id', o.paymob_intention_id,
    'subscription_status', s.status,
    'checkout_status', s.checkout_status,
    'thread_id', t.id,
    'payout_id', pi.payout_id,
    'payout_status', po.status,
    'needs_review', o.needs_review,
    'review_reason', o.review_reason,
    'admin_note', o.admin_note,
    'failure_reason', o.failure_reason,
    'created_at', o.created_at,
    'updated_at', o.updated_at,
    'paid_at', o.paid_at,
    'failed_at', o.failed_at,
    'cancelled_at', o.cancelled_at
  ) || case when include_raw then jsonb_build_object(
    'raw_create_intention_response', o.raw_create_intention_response
  ) else '{}'::jsonb end
  from public.users mu
  left join public.profiles mp on mp.user_id = o.member_id
  left join public.users cu on cu.id = o.coach_id
  left join public.profiles cp on cp.user_id = o.coach_id
  left join public.subscriptions s on s.id = o.subscription_id
  left join public.coach_packages pkg on pkg.id = o.package_id
  left join public.coach_member_threads t on t.subscription_id = o.subscription_id
  left join public.coach_payout_items pi on pi.payment_order_id = o.id
  left join public.coach_payouts po on po.id = pi.payout_id
  where mu.id = o.member_id;
$$;

create or replace function public.admin_dashboard_summary(filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  output jsonb;
begin
  perform public.admin_assert_permission('payments.read');

  select jsonb_build_object(
    'mode', 'test',
    'payment_kpis', jsonb_build_object(
      'total_paid_amount_cents', coalesce(sum(o.amount_gross_cents) filter (where o.status = 'paid'), 0),
      'payments_today', count(*) filter (where o.created_at >= date_trunc('day', timezone('utc', now()))),
      'payments_this_week', count(*) filter (where o.created_at >= date_trunc('week', timezone('utc', now()))),
      'pending_payments', count(*) filter (where o.status in ('created', 'pending')),
      'failed_payments', count(*) filter (where o.status = 'failed'),
      'active_subscriptions_from_payments', count(distinct s.id) filter (where o.status = 'paid' and s.status = 'active')
    ),
    'payout_kpis', jsonb_build_object(
      'pending_coach_payouts', coalesce((select count(*) from public.coach_payouts where status = 'pending'), 0),
      'ready_coach_payouts', coalesce((select count(*) from public.coach_payouts where status = 'ready'), 0),
      'paid_coach_payouts', coalesce((select count(*) from public.coach_payouts where status = 'paid'), 0),
      'on_hold_payouts', coalesce((select count(*) from public.coach_payouts where status = 'on_hold'), 0),
      'total_coach_net_payable_cents', coalesce((select sum(amount_cents) from public.coach_payouts where status in ('pending', 'ready', 'processing')), 0),
      'platform_fees_earned_cents', coalesce(sum(o.platform_fee_cents) filter (where o.status = 'paid'), 0)
    ),
    'operational_kpis', jsonb_build_object(
      'new_active_relationships', count(distinct s.id) filter (where s.status = 'active' and s.activated_at >= date_trunc('week', timezone('utc', now()))),
      'webhook_failures', coalesce((select count(*) from public.coach_payment_transactions where processing_result in ('failed', 'amount_mismatch', 'currency_mismatch', 'mode_mismatch')), 0),
      'hmac_failures', coalesce((select count(*) from public.coach_payment_transactions where hmac_verified = false), 0),
      'reconciliation_needed', count(*) filter (where o.needs_review = true or (o.status = 'paid' and (s.status is distinct from 'active' or pi.id is null)))
    )
  )
  into output
  from public.coach_payment_orders o
  left join public.subscriptions s on s.id = o.subscription_id
  left join public.coach_payout_items pi on pi.payment_order_id = o.id;

  return output || jsonb_build_object(
    'recent_activity', jsonb_build_object(
      'successful_payments', coalesce((
        select jsonb_agg(public.admin_payment_order_json(po, false) order by po.paid_at desc)
        from (select * from public.coach_payment_orders where status = 'paid' order by paid_at desc nulls last limit 5) po
      ), '[]'::jsonb),
      'failed_payments', coalesce((
        select jsonb_agg(public.admin_payment_order_json(fo, false) order by fo.failed_at desc)
        from (select * from public.coach_payment_orders where status = 'failed' order by failed_at desc nulls last limit 5) fo
      ), '[]'::jsonb),
      'audit_events', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', ae.id,
          'actor_user_id', ae.actor_user_id,
          'actor_name', coalesce(nullif(p.full_name, ''), u.email, 'Admin'),
          'action', ae.action,
          'target_type', ae.target_type,
          'target_id', ae.target_id,
          'metadata', ae.metadata,
          'created_at', ae.created_at
        ) order by ae.created_at desc)
        from (
          select * from public.admin_audit_events
          order by created_at desc
          limit 8
        ) ae
        left join public.users u on u.id = ae.actor_user_id
        left join public.profiles p on p.user_id = ae.actor_user_id
      ), '[]'::jsonb)
    ),
    'alerts', jsonb_build_object(
      'paid_without_active_subscription', coalesce((
        select jsonb_agg(public.admin_payment_order_json(po, false))
        from public.coach_payment_orders po
        left join public.subscriptions ps on ps.id = po.subscription_id
        where po.status = 'paid'
          and coalesce(ps.status, '') <> 'active'
        limit 25
      ), '[]'::jsonb),
      'active_without_thread', coalesce((
        select jsonb_agg(jsonb_build_object(
          'subscription_id', s.id,
          'member_id', s.member_id,
          'coach_id', s.coach_id,
          'status', s.status,
          'checkout_status', s.checkout_status
        ))
        from public.subscriptions s
        left join public.coach_member_threads t on t.subscription_id = s.id
        where s.status = 'active'
          and t.id is null
        limit 25
      ), '[]'::jsonb),
      'paid_without_payout_item', coalesce((
        select jsonb_agg(public.admin_payment_order_json(po, false))
        from public.coach_payment_orders po
        left join public.coach_payout_items pi on pi.payment_order_id = po.id
        where po.status = 'paid'
          and pi.id is null
        limit 25
      ), '[]'::jsonb),
      'hmac_failures', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', t.id,
          'payment_order_id', t.payment_order_id,
          'processing_result', t.processing_result,
          'received_at', t.received_at
        ))
        from public.coach_payment_transactions t
        where t.hmac_verified = false
        order by t.received_at desc
        limit 25
      ), '[]'::jsonb),
      'payouts_overdue', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', p.id,
          'coach_id', p.coach_id,
          'amount_cents', p.amount_cents,
          'status', p.status,
          'created_at', p.created_at
        ))
        from public.coach_payouts p
        where p.status in ('pending', 'ready')
          and p.created_at < timezone('utc', now()) - interval '7 days'
        order by p.created_at asc
        limit 25
      ), '[]'::jsonb)
    )
  );
end;
$$;

create or replace function public.admin_list_payment_orders(filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  status_filter text := nullif(filters ->> 'status', '');
  mode_filter text := nullif(filters ->> 'mode', '');
  search_filter text := nullif(filters ->> 'search', '');
  payout_status_filter text := nullif(filters ->> 'payout_status', '');
  limit_count integer := least(greatest(coalesce((filters ->> 'limit')::integer, 50), 1), 200);
begin
  perform public.admin_assert_permission('payments.read');

  return coalesce((
    select jsonb_agg(public.admin_payment_order_json(o, false) order by o.created_at desc)
    from public.coach_payment_orders o
    left join public.users mu on mu.id = o.member_id
    left join public.profiles mp on mp.user_id = o.member_id
    left join public.users cu on cu.id = o.coach_id
    left join public.profiles cp on cp.user_id = o.coach_id
    left join public.coach_packages pkg on pkg.id = o.package_id
    left join public.coach_payout_items pi on pi.payment_order_id = o.id
    left join public.coach_payouts po on po.id = pi.payout_id
    where (status_filter is null or o.status = status_filter)
      and (mode_filter is null or o.mode = mode_filter)
      and (payout_status_filter is null or coalesce(po.status, 'missing') = payout_status_filter)
      and (
        search_filter is null
        or o.special_reference ilike '%' || search_filter || '%'
        or coalesce(o.paymob_order_id, '') ilike '%' || search_filter || '%'
        or coalesce(o.paymob_transaction_id, '') ilike '%' || search_filter || '%'
        or coalesce(mu.email, '') ilike '%' || search_filter || '%'
        or coalesce(cu.email, '') ilike '%' || search_filter || '%'
        or coalesce(mp.full_name, '') ilike '%' || search_filter || '%'
        or coalesce(cp.full_name, '') ilike '%' || search_filter || '%'
        or coalesce(pkg.title, '') ilike '%' || search_filter || '%'
      )
    limit limit_count
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_get_payment_order_details(target_payment_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  order_record public.coach_payment_orders%rowtype;
  can_view_raw boolean;
begin
  perform public.admin_assert_permission('payments.read');
  can_view_raw := public.admin_has_permission('settings.write');

  select * into order_record
  from public.coach_payment_orders
  where id = target_payment_order_id;

  if order_record.id is null then
    raise exception 'Payment order not found.';
  end if;

  return public.admin_payment_order_json(order_record, can_view_raw)
    || jsonb_build_object(
      'transactions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', t.id,
          'paymob_transaction_id', t.paymob_transaction_id,
          'paymob_order_id', t.paymob_order_id,
          'success', t.success,
          'pending', t.pending,
          'is_voided', t.is_voided,
          'is_refunded', t.is_refunded,
          'amount_cents', t.amount_cents,
          'currency', t.currency,
          'hmac_verified', t.hmac_verified,
          'processing_result', t.processing_result,
          'received_at', t.received_at,
          'raw_payload', case when can_view_raw then t.raw_payload else null end
        ) order by t.received_at desc)
        from public.coach_payment_transactions t
        where t.payment_order_id = order_record.id
      ), '[]'::jsonb),
      'audit_events', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', ae.id,
          'actor_user_id', ae.actor_user_id,
          'actor_name', coalesce(nullif(p.full_name, ''), u.email, 'Admin'),
          'action', ae.action,
          'target_type', ae.target_type,
          'target_id', ae.target_id,
          'metadata', ae.metadata,
          'created_at', ae.created_at
        ) order by ae.created_at desc)
        from public.admin_audit_events ae
        left join public.users u on u.id = ae.actor_user_id
        left join public.profiles p on p.user_id = ae.actor_user_id
        where ae.target_id = order_record.id
          or (ae.metadata ->> 'payment_order_id') = order_record.id::text
      ), '[]'::jsonb)
    );
end;
$$;

create or replace function public.admin_payout_json(p public.coach_payouts)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'coach_id', p.coach_id,
    'coach_name', coalesce(nullif(pr.full_name, ''), 'Coach'),
    'coach_email', u.email,
    'amount_cents', p.amount_cents,
    'currency', p.currency,
    'status', p.status,
    'method', p.method,
    'admin_id', p.admin_id,
    'admin_name', coalesce(nullif(ap.full_name, ''), au.email),
    'external_reference', p.external_reference,
    'admin_note', p.admin_note,
    'transfer_proof_path', p.transfer_proof_path,
    'created_at', p.created_at,
    'updated_at', p.updated_at,
    'ready_at', p.ready_at,
    'paid_at', p.paid_at,
    'failed_at', p.failed_at,
    'cancelled_at', p.cancelled_at,
    'item_count', coalesce((select count(*) from public.coach_payout_items i where i.payout_id = p.id), 0),
    'account', coalesce((
      select jsonb_build_object(
        'method', a.method,
        'account_holder_name', a.account_holder_name,
        'bank_name', a.bank_name,
        'bank_account_last4', a.bank_account_last4,
        'wallet_phone_last4', a.wallet_phone_last4,
        'instapay_handle_masked', a.instapay_handle_masked,
        'is_verified', a.is_verified,
        'admin_note', a.admin_note
      )
      from public.coach_payout_accounts a
      where a.coach_id = p.coach_id
    ), '{}'::jsonb)
  )
  from public.users u
  left join public.profiles pr on pr.user_id = p.coach_id
  left join public.users au on au.id = p.admin_id
  left join public.profiles ap on ap.user_id = p.admin_id
  where u.id = p.coach_id;
$$;

create or replace function public.admin_list_payouts(filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  status_filter text := nullif(filters ->> 'status', '');
  search_filter text := nullif(filters ->> 'search', '');
  limit_count integer := least(greatest(coalesce((filters ->> 'limit')::integer, 50), 1), 200);
begin
  perform public.admin_assert_permission('payouts.read');

  return coalesce((
    select jsonb_agg(public.admin_payout_json(p) order by p.created_at desc)
    from public.coach_payouts p
    left join public.users u on u.id = p.coach_id
    left join public.profiles pr on pr.user_id = p.coach_id
    where (status_filter is null or p.status = status_filter)
      and (
        search_filter is null
        or p.id::text ilike '%' || search_filter || '%'
        or coalesce(u.email, '') ilike '%' || search_filter || '%'
        or coalesce(pr.full_name, '') ilike '%' || search_filter || '%'
        or coalesce(p.external_reference, '') ilike '%' || search_filter || '%'
      )
    limit limit_count
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_get_payout_details(target_payout_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  payout_record public.coach_payouts%rowtype;
begin
  perform public.admin_assert_permission('payouts.read');

  select * into payout_record
  from public.coach_payouts
  where id = target_payout_id;

  if payout_record.id is null then
    raise exception 'Payout not found.';
  end if;

  return public.admin_payout_json(payout_record)
    || jsonb_build_object(
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', i.id,
          'payment_order_id', i.payment_order_id,
          'subscription_id', i.subscription_id,
          'gross_cents', i.gross_cents,
          'platform_fee_cents', i.platform_fee_cents,
          'gateway_fee_cents', i.gateway_fee_cents,
          'coach_net_cents', i.coach_net_cents,
          'payment_order', public.admin_payment_order_json(o, false),
          'created_at', i.created_at
        ) order by i.created_at desc)
        from public.coach_payout_items i
        join public.coach_payment_orders o on o.id = i.payment_order_id
        where i.payout_id = payout_record.id
      ), '[]'::jsonb),
      'audit_events', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', ae.id,
          'actor_user_id', ae.actor_user_id,
          'action', ae.action,
          'target_type', ae.target_type,
          'target_id', ae.target_id,
          'metadata', ae.metadata,
          'created_at', ae.created_at
        ) order by ae.created_at desc)
        from public.admin_audit_events ae
        where ae.target_id = payout_record.id
      ), '[]'::jsonb)
    );
end;
$$;

create or replace function public.admin_update_payout_status(
  target_payout_id uuid,
  target_status text,
  input_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  payout_record public.coach_payouts%rowtype;
  old_status text;
  action_name text;
begin
  if target_status = 'paid' then
    raise exception 'Use admin_mark_payout_paid for paid settlements.';
  end if;

  if target_status not in ('pending', 'on_hold', 'ready', 'processing', 'failed', 'cancelled') then
    raise exception 'Unsupported payout status.';
  end if;

  if target_status = 'on_hold' then
    perform public.admin_assert_permission('payouts.hold');
    if nullif(trim(coalesce(input_note, '')), '') is null then
      raise exception 'Hold reason is required.';
    end if;
  elsif target_status = 'ready' then
    perform public.admin_assert_permission('payouts.release');
  else
    perform public.admin_assert_permission('payouts.write');
  end if;

  select * into payout_record
  from public.coach_payouts
  where id = target_payout_id
  for update;

  if payout_record.id is null then
    raise exception 'Payout not found.';
  end if;
  if payout_record.status = 'paid' then
    raise exception 'Paid payouts cannot be changed.';
  end if;
  if target_status = 'processing' and payout_record.status not in ('ready', 'processing') then
    raise exception 'Only ready payouts can move to processing.';
  end if;
  if target_status = 'ready' and payout_record.status not in ('pending', 'on_hold', 'ready') then
    raise exception 'Only pending or held payouts can be marked ready.';
  end if;
  if target_status = 'failed' and payout_record.status not in ('ready', 'processing') then
    raise exception 'Only ready or processing payouts can fail.';
  end if;
  if target_status = 'cancelled' and payout_record.status in ('paid', 'cancelled') then
    raise exception 'Payout cannot be cancelled.';
  end if;

  old_status := payout_record.status;

  update public.coach_payouts
  set status = target_status,
      payout_status = case target_status
        when 'ready' then 'eligible'
        when 'paid' then 'paid'
        when 'cancelled' then 'reversed'
        else payout_status
      end,
      admin_note = coalesce(nullif(trim(coalesce(input_note, '')), ''), admin_note),
      ready_at = case when target_status = 'ready' then coalesce(ready_at, timezone('utc', now())) else ready_at end,
      failed_at = case when target_status = 'failed' then coalesce(failed_at, timezone('utc', now())) else failed_at end,
      cancelled_at = case when target_status = 'cancelled' then coalesce(cancelled_at, timezone('utc', now())) else cancelled_at end,
      updated_at = timezone('utc', now())
  where id = target_payout_id
  returning * into payout_record;

  action_name := case target_status
    when 'ready' then 'admin_release_payout'
    when 'on_hold' then 'admin_hold_payout'
    when 'processing' then 'admin_mark_payout_processing'
    when 'failed' then 'admin_mark_payout_failed'
    when 'cancelled' then 'admin_cancel_payout'
    else 'admin_update_payout'
  end;

  perform public.admin_insert_audit(
    action_name,
    'coach_payout',
    payout_record.id,
    jsonb_build_object(
      'before', jsonb_build_object('status', old_status),
      'after', jsonb_build_object('status', payout_record.status),
      'note', input_note
    )
  );

  if target_status = 'on_hold' then
    insert into public.notifications (user_id, type, title, body, data)
    values (
      payout_record.coach_id,
      'coaching',
      'Payout on hold',
      coalesce(nullif(trim(coalesce(input_note, '')), ''), 'A GymUnity admin put this payout on hold.'),
      jsonb_build_object('payout_id', payout_record.id, 'status', payout_record.status)
    );
  end if;

  return public.admin_payout_json(payout_record);
end;
$$;

create or replace function public.admin_mark_payout_ready(payout_id uuid, note text default null)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.admin_update_payout_status(payout_id, 'ready', note);
$$;

create or replace function public.admin_hold_payout(payout_id uuid, reason text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.admin_update_payout_status(payout_id, 'on_hold', reason);
$$;

create or replace function public.admin_release_payout(payout_id uuid, note text default null)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.admin_update_payout_status(payout_id, 'ready', note);
$$;

create or replace function public.admin_mark_payout_processing(payout_id uuid, note text default null)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.admin_update_payout_status(payout_id, 'processing', note);
$$;

create or replace function public.admin_mark_payout_failed(payout_id uuid, reason text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.admin_update_payout_status(payout_id, 'failed', reason);
$$;

create or replace function public.admin_cancel_payout(payout_id uuid, reason text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.admin_update_payout_status(payout_id, 'cancelled', reason);
$$;

create or replace function public.admin_mark_payout_paid(
  target_payout_id uuid,
  input_method text,
  input_external_reference text,
  input_admin_note text default null,
  input_transfer_proof_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  payout_record public.coach_payouts%rowtype;
  old_status text;
begin
  perform public.admin_assert_permission('payouts.mark_paid');

  if input_method not in ('manual', 'bank', 'wallet', 'instapay') then
    raise exception 'Unsupported payout method.';
  end if;
  if nullif(trim(coalesce(input_external_reference, '')), '') is null then
    raise exception 'External reference is required.';
  end if;

  select * into payout_record
  from public.coach_payouts
  where id = target_payout_id
  for update;

  if payout_record.id is null then
    raise exception 'Payout not found.';
  end if;
  if payout_record.status not in ('ready', 'processing') then
    raise exception 'Only ready or processing payouts can be marked paid.';
  end if;

  old_status := payout_record.status;

  update public.coach_payouts
  set status = 'paid',
      payout_status = 'paid',
      method = input_method,
      admin_id = auth.uid(),
      external_reference = trim(input_external_reference),
      admin_note = nullif(trim(coalesce(input_admin_note, '')), ''),
      transfer_proof_path = nullif(trim(coalesce(input_transfer_proof_path, '')), ''),
      paid_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = target_payout_id
  returning * into payout_record;

  perform public.admin_insert_audit(
    'admin_mark_payout_paid',
    'coach_payout',
    payout_record.id,
    jsonb_build_object(
      'before', jsonb_build_object('status', old_status),
      'after', jsonb_build_object(
        'status', payout_record.status,
        'method', payout_record.method,
        'external_reference', payout_record.external_reference
      ),
      'amount_cents', payout_record.amount_cents,
      'coach_id', payout_record.coach_id
    )
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    payout_record.coach_id,
    'coaching',
    'Your payout has been marked as paid',
    'GymUnity recorded your manual coaching payout.',
    jsonb_build_object('payout_id', payout_record.id, 'amount_cents', payout_record.amount_cents)
  );

  return public.admin_payout_json(payout_record);
end;
$$;

create or replace function public.admin_verify_coach_payout_account(
  coach_id uuid,
  is_verified boolean,
  note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  account_record public.coach_payout_accounts%rowtype;
begin
  perform public.admin_assert_permission('payouts.write');

  insert into public.coach_payout_accounts (coach_id, is_verified, admin_note)
  values (coach_id, is_verified, nullif(trim(coalesce(note, '')), ''))
  on conflict (coach_id) do update
  set is_verified = excluded.is_verified,
      admin_note = excluded.admin_note,
      updated_at = timezone('utc', now())
  returning * into account_record;

  perform public.admin_insert_audit(
    'admin_verify_payout_account',
    'coach_payout_account',
    account_record.id,
    jsonb_build_object('coach_id', coach_id, 'is_verified', is_verified, 'note', note)
  );

  return jsonb_build_object(
    'id', account_record.id,
    'coach_id', account_record.coach_id,
    'is_verified', account_record.is_verified,
    'admin_note', account_record.admin_note
  );
end;
$$;

create or replace function public.admin_list_coach_balances(filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  search_filter text := nullif(filters ->> 'search', '');
  limit_count integer := least(greatest(coalesce((filters ->> 'limit')::integer, 50), 1), 200);
begin
  perform public.admin_assert_permission('coaches.read');

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'coach_id', c.id,
      'coach_name', coalesce(nullif(p.full_name, ''), 'Coach'),
      'coach_email', c.email,
      'active_clients_count', coalesce(s.active_count, 0),
      'total_paid_client_payments_cents', coalesce(payments.total_paid, 0),
      'total_platform_fees_cents', coalesce(payments.total_platform_fee, 0),
      'total_coach_net_earned_cents', coalesce(payments.total_coach_net, 0),
      'pending_payout_amount_cents', coalesce(payouts.pending_amount, 0),
      'paid_payout_amount_cents', coalesce(payouts.paid_amount, 0),
      'on_hold_amount_cents', coalesce(payouts.on_hold_amount, 0),
      'last_payout_date', payouts.last_paid_at,
      'payout_account', coalesce(account.account_json, '{}'::jsonb)
    ) order by coalesce(payments.total_coach_net, 0) desc)
    from public.users c
    join public.profiles p on p.user_id = c.id
    left join public.roles r on r.id = p.role_id
    left join lateral (
      select count(*) as active_count
      from public.subscriptions s
      where s.coach_id = c.id and s.status = 'active'
    ) s on true
    left join lateral (
      select
        sum(amount_gross_cents) filter (where status = 'paid') as total_paid,
        sum(platform_fee_cents) filter (where status = 'paid') as total_platform_fee,
        sum(coach_net_cents) filter (where status = 'paid') as total_coach_net
      from public.coach_payment_orders o
      where o.coach_id = c.id
    ) payments on true
    left join lateral (
      select
        sum(amount_cents) filter (where status in ('pending', 'ready', 'processing')) as pending_amount,
        sum(amount_cents) filter (where status = 'paid') as paid_amount,
        sum(amount_cents) filter (where status = 'on_hold') as on_hold_amount,
        max(paid_at) filter (where status = 'paid') as last_paid_at
      from public.coach_payouts po
      where po.coach_id = c.id
    ) payouts on true
    left join lateral (
      select jsonb_build_object(
        'method', a.method,
        'is_verified', a.is_verified,
        'bank_name', a.bank_name,
        'bank_account_last4', a.bank_account_last4,
        'wallet_phone_last4', a.wallet_phone_last4,
        'instapay_handle_masked', a.instapay_handle_masked
      ) as account_json
      from public.coach_payout_accounts a
      where a.coach_id = c.id
    ) account on true
    where r.code = 'coach'
      and (
        search_filter is null
        or c.email ilike '%' || search_filter || '%'
        or coalesce(p.full_name, '') ilike '%' || search_filter || '%'
      )
    limit limit_count
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_get_coach_settlement_details(coach_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.admin_assert_permission('coaches.read');

  return jsonb_build_object(
    'coach', coalesce((
      select jsonb_build_object(
        'coach_id', u.id,
        'coach_name', coalesce(nullif(p.full_name, ''), 'Coach'),
        'coach_email', u.email
      )
      from public.users u
      left join public.profiles p on p.user_id = u.id
      where u.id = coach_id
    ), '{}'::jsonb),
    'payment_orders', coalesce((
      select jsonb_agg(public.admin_payment_order_json(o, false) order by o.created_at desc)
      from public.coach_payment_orders o
      where o.coach_id = coach_id
      limit 50
    ), '[]'::jsonb),
    'payouts', coalesce((
      select jsonb_agg(public.admin_payout_json(p) order by p.created_at desc)
      from public.coach_payouts p
      where p.coach_id = coach_id
      limit 50
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_list_subscriptions(filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  status_filter text := nullif(filters ->> 'status', '');
  search_filter text := nullif(filters ->> 'search', '');
  limit_count integer := least(greatest(coalesce((filters ->> 'limit')::integer, 50), 1), 200);
begin
  perform public.admin_assert_permission('subscriptions.read');

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'subscription_id', s.id,
      'member_id', s.member_id,
      'member_name', coalesce(nullif(mp.full_name, ''), 'Member'),
      'member_email', mu.email,
      'coach_id', s.coach_id,
      'coach_name', coalesce(nullif(cp.full_name, ''), 'Coach'),
      'coach_email', cu.email,
      'package_id', s.package_id,
      'package_title', coalesce(pkg.title, s.plan_name, 'Coaching'),
      'status', s.status,
      'checkout_status', s.checkout_status,
      'payment_order_id', s.payment_order_id,
      'payment_order_status', o.status,
      'thread_exists', t.id is not null,
      'thread_id', t.id,
      'activated_at', s.activated_at,
      'current_period_end', s.current_period_end,
      'payout_status', po.status
    ) order by s.created_at desc)
    from public.subscriptions s
    left join public.users mu on mu.id = s.member_id
    left join public.profiles mp on mp.user_id = s.member_id
    left join public.users cu on cu.id = s.coach_id
    left join public.profiles cp on cp.user_id = s.coach_id
    left join public.coach_packages pkg on pkg.id = s.package_id
    left join public.coach_payment_orders o on o.id = s.payment_order_id
    left join public.coach_member_threads t on t.subscription_id = s.id
    left join public.coach_payout_items pi on pi.payment_order_id = o.id
    left join public.coach_payouts po on po.id = pi.payout_id
    where (status_filter is null or s.status = status_filter)
      and (
        search_filter is null
        or s.id::text ilike '%' || search_filter || '%'
        or coalesce(mu.email, '') ilike '%' || search_filter || '%'
        or coalesce(cu.email, '') ilike '%' || search_filter || '%'
        or coalesce(mp.full_name, '') ilike '%' || search_filter || '%'
        or coalesce(cp.full_name, '') ilike '%' || search_filter || '%'
        or coalesce(pkg.title, '') ilike '%' || search_filter || '%'
      )
    limit limit_count
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_ensure_subscription_thread(subscription_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sub_record public.subscriptions%rowtype;
  thread_id uuid;
begin
  perform public.admin_assert_permission('subscriptions.write');

  select * into sub_record
  from public.subscriptions
  where id = subscription_id
  for update;

  if sub_record.id is null then
    raise exception 'Subscription not found.';
  end if;
  if sub_record.status <> 'active' then
    raise exception 'Only active subscriptions can have threads repaired.';
  end if;

  thread_id := public.ensure_coach_member_thread(subscription_id);

  perform public.admin_insert_audit(
    'admin_ensure_subscription_thread',
    'subscription',
    subscription_id,
    jsonb_build_object('thread_id', thread_id)
  );

  return jsonb_build_object('subscription_id', subscription_id, 'thread_id', thread_id);
end;
$$;

create or replace function public.admin_list_audit_events(filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  action_filter text := nullif(filters ->> 'action', '');
  target_type_filter text := nullif(filters ->> 'target_type', '');
  limit_count integer := least(greatest(coalesce((filters ->> 'limit')::integer, 100), 1), 300);
begin
  perform public.admin_assert_permission('audit.read');

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', ae.id,
      'actor_user_id', ae.actor_user_id,
      'actor_name', coalesce(nullif(p.full_name, ''), u.email, 'Admin'),
      'action', ae.action,
      'target_type', ae.target_type,
      'target_id', ae.target_id,
      'metadata', ae.metadata,
      'created_at', ae.created_at
    ) order by ae.created_at desc)
    from public.admin_audit_events ae
    left join public.users u on u.id = ae.actor_user_id
    left join public.profiles p on p.user_id = ae.actor_user_id
    where (action_filter is null or ae.action = action_filter)
      and (target_type_filter is null or ae.target_type = target_type_filter)
    limit limit_count
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_add_payment_note(payment_order_id uuid, note text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  order_record public.coach_payment_orders%rowtype;
begin
  perform public.admin_assert_permission('payments.write');

  update public.coach_payment_orders
  set admin_note = nullif(trim(coalesce(note, '')), ''),
      updated_at = timezone('utc', now())
  where id = payment_order_id
  returning * into order_record;

  if order_record.id is null then
    raise exception 'Payment order not found.';
  end if;

  perform public.admin_insert_audit(
    'admin_add_payment_note',
    'coach_payment_order',
    payment_order_id,
    jsonb_build_object('note', note)
  );

  return public.admin_payment_order_json(order_record, false);
end;
$$;

create or replace function public.admin_mark_payment_needs_review(payment_order_id uuid, reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  order_record public.coach_payment_orders%rowtype;
begin
  perform public.admin_assert_permission('payments.write');
  if nullif(trim(coalesce(reason, '')), '') is null then
    raise exception 'Review reason is required.';
  end if;

  update public.coach_payment_orders
  set needs_review = true,
      review_reason = trim(reason),
      updated_at = timezone('utc', now())
  where id = payment_order_id
  returning * into order_record;

  if order_record.id is null then
    raise exception 'Payment order not found.';
  end if;

  perform public.admin_insert_audit(
    'admin_mark_payment_needs_review',
    'coach_payment_order',
    payment_order_id,
    jsonb_build_object('reason', reason)
  );

  return public.admin_payment_order_json(order_record, false);
end;
$$;

create or replace function public.admin_cancel_unpaid_checkout(payment_order_id uuid, reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  order_record public.coach_payment_orders%rowtype;
begin
  perform public.admin_assert_permission('payments.write');
  if nullif(trim(coalesce(reason, '')), '') is null then
    raise exception 'Cancel reason is required.';
  end if;

  update public.coach_payment_orders
  set status = 'cancelled',
      cancelled_at = timezone('utc', now()),
      failure_reason = trim(reason),
      updated_at = timezone('utc', now())
  where id = payment_order_id
    and status in ('created', 'pending', 'failed')
  returning * into order_record;

  if order_record.id is null then
    raise exception 'Payment order not found or cannot be cancelled.';
  end if;

  update public.subscriptions
  set status = case when status = 'checkout_pending' then 'cancelled' else status end,
      checkout_status = 'failed',
      updated_at = timezone('utc', now())
  where id = order_record.subscription_id
    and status <> 'active';

  perform public.admin_insert_audit(
    'admin_cancel_unpaid_checkout',
    'coach_payment_order',
    payment_order_id,
    jsonb_build_object('reason', reason)
  );

  return public.admin_payment_order_json(order_record, false);
end;
$$;

create or replace function public.admin_reconcile_payment_order(payment_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  order_record public.coach_payment_orders%rowtype;
begin
  perform public.admin_assert_permission('payments.write');

  update public.coach_payment_orders
  set needs_review = true,
      review_reason = coalesce(review_reason, 'Manual Paymob inquiry is not implemented in MVP test mode.'),
      updated_at = timezone('utc', now())
  where id = payment_order_id
  returning * into order_record;

  if order_record.id is null then
    raise exception 'Payment order not found.';
  end if;

  perform public.admin_insert_audit(
    'admin_reconcile_payment',
    'coach_payment_order',
    payment_order_id,
    jsonb_build_object('status', 'needs_review', 'mode', order_record.mode)
  );

  return public.admin_payment_order_json(order_record, false);
end;
$$;

grant execute on function public.current_admin() to authenticated;
grant execute on function public.admin_has_permission(text) to authenticated;
grant execute on function public.admin_assert_permission(text) to authenticated;
grant execute on function public.admin_dashboard_summary(jsonb) to authenticated;
grant execute on function public.admin_list_payment_orders(jsonb) to authenticated;
grant execute on function public.admin_get_payment_order_details(uuid) to authenticated;
grant execute on function public.admin_list_payouts(jsonb) to authenticated;
grant execute on function public.admin_get_payout_details(uuid) to authenticated;
grant execute on function public.admin_mark_payout_ready(uuid, text) to authenticated;
grant execute on function public.admin_hold_payout(uuid, text) to authenticated;
grant execute on function public.admin_release_payout(uuid, text) to authenticated;
grant execute on function public.admin_mark_payout_processing(uuid, text) to authenticated;
grant execute on function public.admin_mark_payout_paid(uuid, text, text, text, text) to authenticated;
grant execute on function public.admin_mark_payout_failed(uuid, text) to authenticated;
grant execute on function public.admin_cancel_payout(uuid, text) to authenticated;
grant execute on function public.admin_verify_coach_payout_account(uuid, boolean, text) to authenticated;
grant execute on function public.admin_list_coach_balances(jsonb) to authenticated;
grant execute on function public.admin_get_coach_settlement_details(uuid) to authenticated;
grant execute on function public.admin_list_subscriptions(jsonb) to authenticated;
grant execute on function public.admin_ensure_subscription_thread(uuid) to authenticated;
grant execute on function public.admin_list_audit_events(jsonb) to authenticated;
grant execute on function public.admin_add_payment_note(uuid, text) to authenticated;
grant execute on function public.admin_mark_payment_needs_review(uuid, text) to authenticated;
grant execute on function public.admin_cancel_unpaid_checkout(uuid, text) to authenticated;
grant execute on function public.admin_reconcile_payment_order(uuid) to authenticated;
