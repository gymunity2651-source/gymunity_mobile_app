-- Paymob coach payments smoke checks.
-- Run against a disposable Supabase test database after applying migrations.
-- Replace UUID placeholders with real seeded users/packages before running.

begin;

-- Admin helper should be false for normal SQL sessions unless auth claims are set.
select public.current_user_id() as current_user_id;

-- Payout item idempotency check for an already-paid order.
-- select public.create_pending_coach_payout_for_payment('PAYMENT_ORDER_UUID'::uuid, 0);
-- select public.create_pending_coach_payout_for_payment('PAYMENT_ORDER_UUID'::uuid, 0);
-- select count(*) = 1 as payout_item_is_unique
-- from public.coach_payout_items
-- where payment_order_id = 'PAYMENT_ORDER_UUID'::uuid;

-- Thread idempotency check for an already-active subscription.
-- select public.ensure_coach_member_thread('SUBSCRIPTION_UUID'::uuid);
-- select public.ensure_coach_member_thread('SUBSCRIPTION_UUID'::uuid);
-- select count(*) = 1 as thread_is_unique
-- from public.coach_member_threads
-- where subscription_id = 'SUBSCRIPTION_UUID'::uuid;

-- Safe status RPC should not expose raw Paymob payloads.
-- select *
-- from public.get_coach_payment_order_status('PAYMENT_ORDER_UUID'::uuid);

-- Column-level grants should keep these raw fields admin/service-only.
-- select raw_payload from public.coach_payment_transactions limit 1;
-- select raw_create_intention_response from public.coach_payment_orders limit 1;

rollback;
