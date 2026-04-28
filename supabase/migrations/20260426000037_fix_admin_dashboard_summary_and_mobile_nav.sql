-- Fix admin dashboard summary aggregate subqueries. PostgreSQL does not allow
-- ORDER BY on non-grouped source columns in aggregate-only subqueries; wrap the
-- ordered/limited rows first, then aggregate.

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
        from (
          select po.*
          from public.coach_payment_orders po
          left join public.subscriptions ps on ps.id = po.subscription_id
          where po.status = 'paid'
            and coalesce(ps.status, '') <> 'active'
          order by po.paid_at desc nulls last, po.created_at desc
          limit 25
        ) po
      ), '[]'::jsonb),
      'active_without_thread', coalesce((
        select jsonb_agg(jsonb_build_object(
          'subscription_id', missing.id,
          'member_id', missing.member_id,
          'coach_id', missing.coach_id,
          'status', missing.status,
          'checkout_status', missing.checkout_status
        ))
        from (
          select s.*
          from public.subscriptions s
          left join public.coach_member_threads t on t.subscription_id = s.id
          where s.status = 'active'
            and t.id is null
          order by s.activated_at desc nulls last, s.created_at desc
          limit 25
        ) missing
      ), '[]'::jsonb),
      'paid_without_payout_item', coalesce((
        select jsonb_agg(public.admin_payment_order_json(po, false))
        from (
          select po.*
          from public.coach_payment_orders po
          left join public.coach_payout_items pi on pi.payment_order_id = po.id
          where po.status = 'paid'
            and pi.id is null
          order by po.paid_at desc nulls last, po.created_at desc
          limit 25
        ) po
      ), '[]'::jsonb),
      'hmac_failures', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', failures.id,
          'payment_order_id', failures.payment_order_id,
          'processing_result', failures.processing_result,
          'received_at', failures.received_at
        ))
        from (
          select *
          from public.coach_payment_transactions
          where hmac_verified = false
          order by received_at desc
          limit 25
        ) failures
      ), '[]'::jsonb),
      'payouts_overdue', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', overdue.id,
          'coach_id', overdue.coach_id,
          'amount_cents', overdue.amount_cents,
          'status', overdue.status,
          'created_at', overdue.created_at
        ))
        from (
          select *
          from public.coach_payouts
          where status in ('pending', 'ready')
            and created_at < timezone('utc', now()) - interval '7 days'
          order by created_at asc
          limit 25
        ) overdue
      ), '[]'::jsonb)
    )
  );
end;
$$;

grant execute on function public.admin_dashboard_summary(jsonb) to authenticated;
