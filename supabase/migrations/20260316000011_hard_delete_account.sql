-- Hard-delete account flow with reusable email support
-- Date: 2026-03-16

alter table public.orders
  alter column member_id drop not null,
  alter column seller_id drop not null;

alter table public.orders
  drop constraint if exists orders_member_id_fkey,
  add constraint orders_member_id_fkey
    foreign key (member_id) references public.profiles(user_id) on delete set null,
  drop constraint if exists orders_seller_id_fkey,
  add constraint orders_seller_id_fkey
    foreign key (seller_id) references public.profiles(user_id) on delete set null;

alter table public.order_items
  alter column product_id drop not null,
  alter column seller_id drop not null;

alter table public.order_items
  drop constraint if exists order_items_product_id_fkey,
  add constraint order_items_product_id_fkey
    foreign key (product_id) references public.products(id) on delete set null,
  drop constraint if exists order_items_seller_id_fkey,
  add constraint order_items_seller_id_fkey
    foreign key (seller_id) references public.profiles(user_id) on delete set null;

alter table public.subscriptions
  alter column member_id drop not null,
  alter column coach_id drop not null;

alter table public.subscriptions
  drop constraint if exists subscriptions_member_id_fkey,
  add constraint subscriptions_member_id_fkey
    foreign key (member_id) references public.profiles(user_id) on delete set null,
  drop constraint if exists subscriptions_coach_id_fkey,
  add constraint subscriptions_coach_id_fkey
    foreign key (coach_id) references public.coach_profiles(user_id) on delete set null;

create or replace function public.list_member_subscriptions_detailed()
returns table (
  id uuid,
  member_id uuid,
  coach_id uuid,
  coach_name text,
  package_id uuid,
  package_title text,
  plan_name text,
  billing_cycle text,
  amount numeric,
  status text,
  payment_method text,
  starts_at timestamptz,
  ends_at timestamptz,
  activated_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.id,
    s.member_id,
    s.coach_id,
    coalesce(nullif(p.full_name, ''), 'Deleted coach') as coach_name,
    s.package_id,
    coalesce(cp.title, nullif(s.plan_name, ''), 'Archived subscription') as package_title,
    s.plan_name,
    s.billing_cycle,
    s.amount,
    s.status,
    s.payment_method,
    s.starts_at,
    s.ends_at,
    s.activated_at,
    s.cancelled_at,
    s.created_at
  from public.subscriptions s
  left join public.profiles p on p.user_id = s.coach_id
  left join public.coach_packages cp on cp.id = s.package_id
  where s.member_id = auth.uid()
  order by s.created_at desc;
$$;

create or replace function public.list_member_orders_detailed()
returns table (
  id uuid,
  seller_id uuid,
  seller_name text,
  status text,
  total_amount numeric,
  currency text,
  payment_method text,
  item_count integer,
  shipping_address_json jsonb,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    o.id,
    o.seller_id,
    coalesce(nullif(sp.store_name, ''), nullif(p.full_name, ''), 'Deleted seller') as seller_name,
    o.status,
    o.total_amount,
    o.currency,
    o.payment_method,
    coalesce(count(oi.id), 0)::integer as item_count,
    o.shipping_address_json,
    o.created_at
  from public.orders o
  left join public.order_items oi on oi.order_id = o.id
  left join public.seller_profiles sp on sp.user_id = o.seller_id
  left join public.profiles p on p.user_id = o.seller_id
  where o.member_id = auth.uid()
  group by o.id, sp.store_name, p.full_name
  order by o.created_at desc;
$$;

create or replace function public.list_seller_orders_detailed()
returns table (
  id uuid,
  member_id uuid,
  member_name text,
  status text,
  total_amount numeric,
  currency text,
  payment_method text,
  item_count integer,
  shipping_address_json jsonb,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    o.id,
    o.member_id,
    coalesce(nullif(p.full_name, ''), 'Deleted member') as member_name,
    o.status,
    o.total_amount,
    o.currency,
    o.payment_method,
    coalesce(count(oi.id), 0)::integer as item_count,
    o.shipping_address_json,
    o.created_at
  from public.orders o
  left join public.order_items oi on oi.order_id = o.id
  left join public.profiles p on p.user_id = o.member_id
  where o.seller_id = auth.uid()
  group by o.id, p.full_name
  order by o.created_at desc;
$$;

create or replace function public.list_coach_clients()
returns table (
  subscription_id uuid,
  member_id uuid,
  member_name text,
  package_title text,
  status text,
  started_at timestamptz,
  active_plan_count integer,
  last_session_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with plan_counts as (
    select
      wp.member_id,
      count(*) filter (where wp.status = 'active')::integer as active_plan_count
    from public.workout_plans wp
    where wp.coach_id = auth.uid()
      and wp.member_id is not null
    group by wp.member_id
  ),
  session_stats as (
    select
      ws.member_id,
      max(ws.performed_at) as last_session_at
    from public.workout_sessions ws
    where ws.coach_id = auth.uid()
      and ws.member_id is not null
    group by ws.member_id
  )
  select
    s.id as subscription_id,
    s.member_id,
    coalesce(nullif(p.full_name, ''), 'Deleted member') as member_name,
    coalesce(cp.title, nullif(s.plan_name, ''), 'Subscription') as package_title,
    s.status,
    coalesce(s.activated_at, s.starts_at, s.created_at) as started_at,
    coalesce(pc.active_plan_count, 0) as active_plan_count,
    ss.last_session_at
  from public.subscriptions s
  left join public.profiles p on p.user_id = s.member_id
  left join public.coach_packages cp on cp.id = s.package_id
  left join plan_counts pc on pc.member_id = s.member_id
  left join session_stats ss on ss.member_id = s.member_id
  where s.coach_id = auth.uid()
    and s.member_id is not null
  order by s.created_at desc;
$$;

create or replace function public.update_store_order_status(
  target_order_id uuid,
  new_status text,
  note text default null
)
returns table (
  order_id uuid,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_order public.orders%rowtype;
  allowed boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'seller' then
    raise exception 'Only sellers can update order status.';
  end if;

  if new_status not in ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled') then
    raise exception 'The requested status transition is not allowed.';
  end if;

  select *
  into existing_order
  from public.orders
  where id = target_order_id
    and seller_id = auth.uid();

  if existing_order.id is null then
    raise exception 'Order not found for this seller.';
  end if;

  allowed := (
    (existing_order.status = 'pending' and new_status in ('paid', 'cancelled'))
    or (existing_order.status = 'paid' and new_status in ('processing', 'cancelled'))
    or (existing_order.status = 'processing' and new_status in ('shipped', 'cancelled'))
    or (existing_order.status = 'shipped' and new_status = 'delivered')
  );

  if not allowed then
    raise exception 'The requested status transition is not allowed.';
  end if;

  if new_status = 'cancelled' then
    update public.products p
    set stock_qty = p.stock_qty + oi.quantity,
        updated_at = timezone('utc', now())
    from public.order_items oi
    where oi.order_id = existing_order.id
      and oi.product_id is not null
      and p.id = oi.product_id;
  end if;

  update public.orders
  set status = new_status,
      updated_at = timezone('utc', now())
  where id = existing_order.id;

  insert into public.order_status_history (
    order_id,
    status,
    actor_user_id,
    note
  )
  values (
    existing_order.id,
    new_status,
    auth.uid(),
    coalesce(note, 'Order status updated by seller.')
  );

  if existing_order.member_id is not null then
    insert into public.notifications (
      user_id,
      type,
      title,
      body,
      data
    )
    values (
      existing_order.member_id,
      'orders',
      'Order status updated',
      'Your order is now ' || replace(new_status, '_', ' ') || '.',
      jsonb_build_object('order_id', existing_order.id, 'status', new_status)
    );
  end if;

  order_id := existing_order.id;
  status := new_status;
  return next;
end;
$$;

create or replace function public.update_coach_subscription_status(
  target_subscription_id uuid,
  new_status text,
  note text default null
)
returns table (
  subscription_id uuid,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_subscription public.subscriptions%rowtype;
  allowed boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'coach' then
    raise exception 'Only coaches can update subscription status.';
  end if;

  select *
  into existing_subscription
  from public.subscriptions
  where id = target_subscription_id
    and coach_id = auth.uid();

  if existing_subscription.id is null then
    raise exception 'Subscription not found for this coach.';
  end if;

  allowed := (
    (existing_subscription.status = 'pending_payment' and new_status in ('active', 'cancelled'))
    or (existing_subscription.status = 'active' and new_status in ('completed', 'cancelled'))
  );

  if not allowed then
    raise exception 'The requested subscription transition is not allowed.';
  end if;

  update public.subscriptions
  set status = new_status,
      activated_at = case
        when new_status = 'active' and activated_at is null
          then timezone('utc', now())
        else activated_at
      end,
      cancelled_at = case
        when new_status = 'cancelled'
          then timezone('utc', now())
        else cancelled_at
      end,
      ends_at = case
        when new_status in ('completed', 'cancelled')
          then timezone('utc', now())
        else ends_at
      end,
      updated_at = timezone('utc', now())
  where id = existing_subscription.id;

  if existing_subscription.member_id is not null then
    insert into public.notifications (
      user_id,
      type,
      title,
      body,
      data
    )
    values (
      existing_subscription.member_id,
      'coaching',
      'Subscription updated',
      coalesce(note, 'Your subscription is now ' || replace(new_status, '_', ' ') || '.'),
      jsonb_build_object('subscription_id', existing_subscription.id, 'status', new_status)
    );
  end if;

  subscription_id := existing_subscription.id;
  status := new_status;
  return next;
end;
$$;

create or replace function public.prepare_account_for_hard_delete(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_timestamp timestamptz := timezone('utc', now());
begin
  if target_user_id is null then
    raise exception 'target_user_id is required';
  end if;

  delete from public.notifications
  where user_id = target_user_id;

  delete from public.device_tokens
  where user_id = target_user_id;

  delete from public.user_preferences
  where user_id = target_user_id;

  delete from public.member_weight_entries
  where member_id = target_user_id;

  delete from public.member_body_measurements
  where member_id = target_user_id;

  delete from public.workout_sessions
  where member_id = target_user_id;

  delete from public.coach_availability_slots
  where coach_id = target_user_id;

  delete from public.coach_reviews
  where member_id = target_user_id
     or coach_id = target_user_id;

  delete from public.ai_user_memories
  where user_id = target_user_id;

  delete from public.ai_session_state
  where user_id = target_user_id;

  delete from public.ai_plan_drafts
  where user_id = target_user_id;

  delete from public.store_checkout_requests
  where member_id = target_user_id;

  delete from public.shipping_addresses
  where user_id = target_user_id;

  delete from public.store_carts
  where member_id = target_user_id;

  delete from public.product_favorites
  where member_id = target_user_id;

  delete from public.subscription_entitlements
  where user_id = target_user_id;

  delete from public.store_transactions
  where user_id = target_user_id;

  delete from public.billing_customers
  where user_id = target_user_id;

  update public.billing_sync_events
  set user_id = null
  where user_id = target_user_id;

  update public.orders
  set member_id = case when member_id = target_user_id then null else member_id end,
      seller_id = case when seller_id = target_user_id then null else seller_id end,
      updated_at = deleted_timestamp
  where member_id = target_user_id
     or seller_id = target_user_id;

  update public.subscriptions
  set member_id = case when member_id = target_user_id then null else member_id end,
      coach_id = case when coach_id = target_user_id then null else coach_id end,
      status = case
        when status in ('pending_payment', 'active') then 'cancelled'
        else status
      end,
      cancelled_at = case
        when status in ('pending_payment', 'active') then coalesce(cancelled_at, deleted_timestamp)
        else cancelled_at
      end,
      ends_at = case
        when status in ('pending_payment', 'active') then coalesce(ends_at, deleted_timestamp)
        else ends_at
      end,
      updated_at = deleted_timestamp
  where member_id = target_user_id
     or coach_id = target_user_id;

  delete from public.workout_plans
  where member_id = target_user_id;

  update public.workout_plans
  set coach_id = null,
      status = 'archived',
      completed_at = coalesce(completed_at, deleted_timestamp),
      updated_at = deleted_timestamp
  where coach_id = target_user_id;

  delete from public.coach_packages
  where coach_id = target_user_id;

  delete from public.products
  where seller_id = target_user_id;

  delete from public.chat_sessions
  where user_id = target_user_id;

  delete from public.member_profiles
  where user_id = target_user_id;

  delete from public.seller_profiles
  where user_id = target_user_id;

  return jsonb_build_object(
    'deleted_at', deleted_timestamp,
    'user_id', target_user_id
  );
end;
$$;

revoke all on function public.prepare_account_for_hard_delete(uuid) from public;
revoke all on function public.prepare_account_for_hard_delete(uuid) from anon;
revoke all on function public.prepare_account_for_hard_delete(uuid) from authenticated;
