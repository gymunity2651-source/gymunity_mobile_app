-- Paymob test-mode coach subscription payments and admin settlement.
-- Date: 2026-04-26
--
-- Non-destructive migration. Keeps the legacy manual receipt flow available,
-- but adds a server-authoritative Paymob state machine for coach subscriptions.

create extension if not exists "pgcrypto";

create table if not exists public.app_admins (
  user_id uuid primary key references public.users(id) on delete cascade,
  role text not null default 'admin' check (
    role in ('admin', 'super_admin', 'finance_admin', 'support_admin')
  ),
  permissions jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.admin_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.subscriptions
  add column if not exists payment_gateway text,
  add column if not exists payment_order_id uuid,
  add column if not exists amount_cents integer,
  add column if not exists currency text not null default 'EGP',
  add column if not exists platform_fee_cents integer not null default 0,
  add column if not exists coach_net_cents integer not null default 0,
  add column if not exists current_period_start timestamptz,
  add column if not exists current_period_end timestamptz,
  add column if not exists next_renewal_at timestamptz,
  add column if not exists activated_at timestamptz;

alter table public.subscriptions
  drop constraint if exists subscriptions_currency_check;
alter table public.subscriptions
  add constraint subscriptions_currency_check check (currency = 'EGP') not valid;

alter table public.subscriptions
  drop constraint if exists subscriptions_checkout_status_check;
alter table public.subscriptions
  add constraint subscriptions_checkout_status_check check (
    checkout_status in (
      'not_started',
      'checkout_pending',
      'payment_pending',
      'submitted',
      'receipt_uploaded',
      'under_verification',
      'paid',
      'failed',
      'refunded'
    )
  ) not valid;

create table if not exists public.coach_payment_orders (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  member_id uuid not null references public.users(id) on delete cascade,
  coach_id uuid not null references public.users(id) on delete cascade,
  package_id uuid references public.coach_packages(id) on delete set null,
  currency text not null default 'EGP',
  amount_gross_cents integer not null,
  platform_fee_cents integer not null default 0,
  gateway_fee_cents integer not null default 0,
  coach_net_cents integer not null default 0,
  payment_gateway text not null default 'paymob',
  mode text not null default 'test',
  status text not null default 'created',
  paymob_intention_id text,
  paymob_order_id text,
  paymob_transaction_id text,
  paymob_client_secret_hash text,
  special_reference text not null unique,
  checkout_url text,
  failure_reason text,
  raw_create_intention_response jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  paid_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  constraint coach_payment_orders_amount_check check (amount_gross_cents > 0),
  constraint coach_payment_orders_fee_check check (
    platform_fee_cents >= 0 and gateway_fee_cents >= 0 and coach_net_cents >= 0
  ),
  constraint coach_payment_orders_currency_check check (currency = 'EGP'),
  constraint coach_payment_orders_mode_check check (mode in ('test', 'live')),
  constraint coach_payment_orders_gateway_check check (payment_gateway = 'paymob'),
  constraint coach_payment_orders_status_check check (
    status in (
      'created',
      'pending',
      'paid',
      'failed',
      'cancelled',
      'refunded',
      'partially_refunded'
    )
  )
);

alter table public.subscriptions
  drop constraint if exists subscriptions_payment_order_id_fkey;
alter table public.subscriptions
  add constraint subscriptions_payment_order_id_fkey
  foreign key (payment_order_id)
  references public.coach_payment_orders(id)
  on delete set null
  not valid;

create table if not exists public.coach_payment_transactions (
  id uuid primary key default gen_random_uuid(),
  payment_order_id uuid references public.coach_payment_orders(id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  member_id uuid references public.users(id) on delete set null,
  coach_id uuid references public.users(id) on delete set null,
  mode text not null default 'test',
  gateway text not null default 'paymob',
  paymob_transaction_id text,
  paymob_order_id text,
  paymob_intention_id text,
  special_reference text,
  success boolean,
  pending boolean,
  is_voided boolean,
  is_refunded boolean,
  amount_cents integer,
  currency text,
  source_data_type text,
  hmac_verified boolean not null default false,
  processing_result text,
  raw_payload jsonb not null,
  received_at timestamptz not null default timezone('utc', now()),
  constraint coach_payment_transactions_mode_check check (mode in ('test', 'live')),
  constraint coach_payment_transactions_gateway_check check (gateway = 'paymob')
);

create unique index if not exists idx_coach_payment_transactions_paymob_tx_unique
  on public.coach_payment_transactions(paymob_transaction_id)
  where paymob_transaction_id is not null;

create table if not exists public.coach_payout_accounts (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null unique references public.users(id) on delete cascade,
  method text not null default 'manual' check (
    method in ('manual', 'bank', 'wallet', 'instapay')
  ),
  account_holder_name text,
  bank_name text,
  bank_account_last4 text,
  wallet_phone_last4 text,
  instapay_handle_masked text,
  is_verified boolean not null default false,
  admin_note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.coach_payouts
  add column if not exists amount_cents integer not null default 0,
  add column if not exists currency text not null default 'EGP',
  add column if not exists status text not null default 'pending',
  add column if not exists method text not null default 'manual',
  add column if not exists admin_id uuid references public.users(id) on delete set null,
  add column if not exists external_reference text,
  add column if not exists admin_note text,
  add column if not exists transfer_proof_path text,
  add column if not exists updated_at timestamptz,
  add column if not exists ready_at timestamptz,
  add column if not exists failed_at timestamptz,
  add column if not exists cancelled_at timestamptz;

alter table public.coach_payouts
  drop constraint if exists coach_payouts_amount_cents_check;
alter table public.coach_payouts
  add constraint coach_payouts_amount_cents_check check (amount_cents >= 0) not valid;
alter table public.coach_payouts
  drop constraint if exists coach_payouts_currency_check;
alter table public.coach_payouts
  add constraint coach_payouts_currency_check check (currency = 'EGP') not valid;
alter table public.coach_payouts
  drop constraint if exists coach_payouts_status_check;
alter table public.coach_payouts
  add constraint coach_payouts_status_check check (
    status in ('pending', 'on_hold', 'ready', 'processing', 'paid', 'failed', 'cancelled')
  ) not valid;
alter table public.coach_payouts
  drop constraint if exists coach_payouts_method_check;
alter table public.coach_payouts
  add constraint coach_payouts_method_check check (
    method in ('manual', 'bank', 'wallet', 'instapay')
  ) not valid;

create table if not exists public.coach_payout_items (
  id uuid primary key default gen_random_uuid(),
  payout_id uuid not null references public.coach_payouts(id) on delete cascade,
  payment_order_id uuid not null references public.coach_payment_orders(id) on delete restrict,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  gross_cents integer not null,
  platform_fee_cents integer not null,
  gateway_fee_cents integer not null,
  coach_net_cents integer not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint coach_payout_items_amounts_check check (
    gross_cents >= 0
    and platform_fee_cents >= 0
    and gateway_fee_cents >= 0
    and coach_net_cents >= 0
  ),
  constraint coach_payout_items_payment_order_unique unique (payment_order_id)
);

create index if not exists idx_coach_payment_orders_subscription
  on public.coach_payment_orders(subscription_id);
create index if not exists idx_coach_payment_orders_member
  on public.coach_payment_orders(member_id);
create index if not exists idx_coach_payment_orders_coach
  on public.coach_payment_orders(coach_id);
create index if not exists idx_coach_payment_orders_package
  on public.coach_payment_orders(package_id);
create index if not exists idx_coach_payment_orders_status
  on public.coach_payment_orders(status);
create index if not exists idx_coach_payment_orders_special_reference
  on public.coach_payment_orders(special_reference);
create index if not exists idx_coach_payment_orders_paymob_order
  on public.coach_payment_orders(paymob_order_id);
create index if not exists idx_coach_payment_orders_paymob_tx
  on public.coach_payment_orders(paymob_transaction_id);
create index if not exists idx_coach_payment_orders_created
  on public.coach_payment_orders(created_at desc);

create index if not exists idx_coach_payment_transactions_order
  on public.coach_payment_transactions(payment_order_id);
create index if not exists idx_coach_payment_transactions_subscription
  on public.coach_payment_transactions(subscription_id);
create index if not exists idx_coach_payment_transactions_paymob_order
  on public.coach_payment_transactions(paymob_order_id);
create index if not exists idx_coach_payment_transactions_special_reference
  on public.coach_payment_transactions(special_reference);
create index if not exists idx_coach_payment_transactions_received
  on public.coach_payment_transactions(received_at desc);

create index if not exists idx_coach_payouts_coach_status
  on public.coach_payouts(coach_id, status, created_at desc);
create index if not exists idx_coach_payout_items_payout
  on public.coach_payout_items(payout_id);
create index if not exists idx_admin_audit_events_target
  on public.admin_audit_events(target_type, target_id, created_at desc);

alter table public.app_admins enable row level security;
alter table public.admin_audit_events enable row level security;
alter table public.coach_payment_orders enable row level security;
alter table public.coach_payment_transactions enable row level security;
alter table public.coach_payout_accounts enable row level security;
alter table public.coach_payouts enable row level security;
alter table public.coach_payout_items enable row level security;

create or replace function public.current_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid()
$$;

create or replace function public.is_admin()
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
  )
$$;

create or replace function public.assert_admin()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Admin access is required.';
  end if;
end;
$$;

create or replace function public.admin_create_audit_event(
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
  requester uuid := auth.uid();
  created_id uuid;
begin
  perform public.assert_admin();

  insert into public.admin_audit_events (
    actor_user_id,
    action,
    target_type,
    target_id,
    metadata
  )
  values (
    requester,
    input_action,
    input_target_type,
    input_target_id,
    coalesce(input_metadata, '{}'::jsonb)
  )
  returning id into created_id;

  return created_id;
end;
$$;

create or replace function public.is_subscription_member(target_subscription_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.subscriptions s
    where s.id = target_subscription_id
      and s.member_id = auth.uid()
  )
$$;

create or replace function public.is_subscription_coach(target_subscription_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.subscriptions s
    where s.id = target_subscription_id
      and s.coach_id = auth.uid()
  )
$$;

drop policy if exists app_admins_read_admins on public.app_admins;
create policy app_admins_read_admins
on public.app_admins for select
to authenticated
using (public.is_admin());

drop policy if exists app_admins_no_public_write on public.app_admins;
create policy app_admins_no_public_write
on public.app_admins for update
to authenticated
using (
  exists (
    select 1
    from public.app_admins a
    where a.user_id = auth.uid()
      and a.role = 'super_admin'
      and a.is_active = true
  )
)
with check (
  exists (
    select 1
    from public.app_admins a
    where a.user_id = auth.uid()
      and a.role = 'super_admin'
      and a.is_active = true
  )
);

drop policy if exists admin_audit_events_read_admins on public.admin_audit_events;
create policy admin_audit_events_read_admins
on public.admin_audit_events for select
to authenticated
using (public.is_admin());

drop policy if exists coach_payment_orders_read_participants_or_admin on public.coach_payment_orders;
create policy coach_payment_orders_read_participants_or_admin
on public.coach_payment_orders for select
to authenticated
using (
  member_id = auth.uid()
  or coach_id = auth.uid()
  or public.is_admin()
);

drop policy if exists coach_payment_transactions_read_participants_or_admin on public.coach_payment_transactions;
create policy coach_payment_transactions_read_participants_or_admin
on public.coach_payment_transactions for select
to authenticated
using (
  member_id = auth.uid()
  or coach_id = auth.uid()
  or public.is_admin()
);

drop policy if exists coach_payout_accounts_coach_read_own on public.coach_payout_accounts;
create policy coach_payout_accounts_coach_read_own
on public.coach_payout_accounts for select
to authenticated
using (coach_id = auth.uid() or public.is_admin());

drop policy if exists coach_payout_accounts_coach_upsert_own on public.coach_payout_accounts;
create policy coach_payout_accounts_coach_upsert_own
on public.coach_payout_accounts for all
to authenticated
using (coach_id = auth.uid() or public.is_admin())
with check (coach_id = auth.uid() or public.is_admin());

drop policy if exists coach_payouts_read_coach_or_admin on public.coach_payouts;
create policy coach_payouts_read_coach_or_admin
on public.coach_payouts for select
to authenticated
using (coach_id = auth.uid() or public.is_admin());

drop policy if exists coach_payouts_admin_update on public.coach_payouts;
create policy coach_payouts_admin_update
on public.coach_payouts for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists coach_payout_items_read_coach_or_admin on public.coach_payout_items;
create policy coach_payout_items_read_coach_or_admin
on public.coach_payout_items for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.coach_payment_orders o
    where o.id = coach_payout_items.payment_order_id
      and o.coach_id = auth.uid()
  )
);

revoke all on public.coach_payment_orders from anon, authenticated;
revoke all on public.coach_payment_transactions from anon, authenticated;
grant select (
  id,
  subscription_id,
  member_id,
  coach_id,
  package_id,
  currency,
  amount_gross_cents,
  platform_fee_cents,
  gateway_fee_cents,
  coach_net_cents,
  payment_gateway,
  mode,
  status,
  paymob_intention_id,
  paymob_order_id,
  paymob_transaction_id,
  special_reference,
  checkout_url,
  failure_reason,
  created_at,
  updated_at,
  paid_at,
  failed_at,
  cancelled_at
) on public.coach_payment_orders to authenticated;
grant select (
  id,
  payment_order_id,
  subscription_id,
  member_id,
  coach_id,
  mode,
  gateway,
  paymob_transaction_id,
  paymob_order_id,
  paymob_intention_id,
  special_reference,
  success,
  pending,
  is_voided,
  is_refunded,
  amount_cents,
  currency,
  source_data_type,
  hmac_verified,
  processing_result,
  received_at
) on public.coach_payment_transactions to authenticated;

create or replace function public.coach_billing_state(
  subscription_status text,
  checkout_status text,
  latest_receipt_status text
)
returns text
language sql
immutable
as $$
  select case
    when subscription_status = 'active' or latest_receipt_status = 'activated' or checkout_status = 'paid' then 'activated'
    when latest_receipt_status = 'failed' or checkout_status = 'failed' then 'failed_needs_follow_up'
    when checkout_status = 'payment_pending' then 'payment_pending'
    when latest_receipt_status = 'under_verification' then 'under_verification'
    when latest_receipt_status = 'receipt_uploaded' then 'receipt_uploaded'
    when latest_receipt_status = 'submitted' then 'payment_submitted'
    when subscription_status in ('checkout_pending', 'pending_payment', 'pending_activation') or checkout_status = 'checkout_pending' then 'awaiting_payment'
    else 'not_started'
  end;
$$;

create or replace function public.ensure_coach_member_thread(target_subscription_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  jwt_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
  existing_thread_id uuid;
  subscription_record public.subscriptions%rowtype;
begin
  select *
  into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and (
      requester is null and jwt_role = 'service_role'
      or member_id = requester
      or coach_id = requester
      or public.is_admin()
    );

  if subscription_record.id is null then
    raise exception 'Subscription not found.';
  end if;

  if subscription_record.status <> 'active' then
    raise exception 'Coaching thread is available only for active subscriptions.';
  end if;

  select id
  into existing_thread_id
  from public.coach_member_threads
  where subscription_id = target_subscription_id;

  if existing_thread_id is not null then
    return existing_thread_id;
  end if;

  insert into public.coach_member_threads (
    subscription_id,
    member_id,
    coach_id,
    last_message_preview,
    last_message_at
  )
  values (
    subscription_record.id,
    subscription_record.member_id,
    subscription_record.coach_id,
    'Your coaching thread is ready.',
    timezone('utc', now())
  )
  on conflict (subscription_id) do update
  set updated_at = public.coach_member_threads.updated_at
  returning id into existing_thread_id;

  insert into public.coach_messages (
    thread_id,
    sender_user_id,
    sender_role,
    message_type,
    content
  )
  select
    existing_thread_id,
    subscription_record.coach_id,
    'system',
    'system',
    'Your coaching thread is ready.'
  where not exists (
    select 1
    from public.coach_messages m
    where m.thread_id = existing_thread_id
      and m.sender_role = 'system'
      and m.message_type = 'system'
      and m.content = 'Your coaching thread is ready.'
  );

  return existing_thread_id;
end;
$$;

create or replace function public.get_coach_payment_order_status(target_payment_order_id uuid)
returns table (
  id uuid,
  subscription_id uuid,
  member_id uuid,
  coach_id uuid,
  package_id uuid,
  amount_gross_cents integer,
  platform_fee_cents integer,
  gateway_fee_cents integer,
  coach_net_cents integer,
  currency text,
  payment_gateway text,
  mode text,
  status text,
  checkout_url text,
  failure_reason text,
  paid_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    o.id,
    o.subscription_id,
    o.member_id,
    o.coach_id,
    o.package_id,
    o.amount_gross_cents,
    o.platform_fee_cents,
    o.gateway_fee_cents,
    o.coach_net_cents,
    o.currency,
    o.payment_gateway,
    o.mode,
    o.status,
    o.checkout_url,
    o.failure_reason,
    o.paid_at,
    o.failed_at,
    o.cancelled_at,
    o.created_at,
    o.updated_at
  from public.coach_payment_orders o
  where o.id = target_payment_order_id
    and (
      o.member_id = auth.uid()
      or o.coach_id = auth.uid()
      or public.is_admin()
    );
$$;

create or replace function public.create_pending_coach_payout_for_payment(
  target_payment_order_id uuid,
  input_hold_days integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
  order_record public.coach_payment_orders%rowtype;
  existing_item public.coach_payout_items%rowtype;
  payout_id uuid;
  hold_days integer := greatest(coalesce(input_hold_days, 0), 0);
  resolved_status text;
  resolved_legacy_status text;
  resolved_ready_at timestamptz;
begin
  if jwt_role <> 'service_role' and not public.is_admin() then
    raise exception 'Service role or admin access is required.';
  end if;

  select *
  into order_record
  from public.coach_payment_orders
  where id = target_payment_order_id
    and status = 'paid'
  for update;

  if order_record.id is null then
    raise exception 'Paid payment order not found.';
  end if;

  select *
  into existing_item
  from public.coach_payout_items
  where payment_order_id = order_record.id;

  if existing_item.id is not null then
    return existing_item.payout_id;
  end if;

  resolved_status := case when hold_days > 0 then 'on_hold' else 'ready' end;
  resolved_legacy_status := case when hold_days > 0 then 'held' else 'eligible' end;
  resolved_ready_at := timezone('utc', now()) + make_interval(days => hold_days);

  select p.id
  into payout_id
  from public.coach_payouts p
  where p.coach_id = order_record.coach_id
    and p.status = resolved_status
    and p.currency = order_record.currency
  order by p.created_at asc
  limit 1
  for update;

  if payout_id is null then
    insert into public.coach_payouts (
      coach_id,
      subscription_id,
      gross_amount,
      commission_amount,
      net_amount,
      payout_status,
      eligible_at,
      amount_cents,
      currency,
      status,
      method,
      ready_at,
      updated_at
    )
    values (
      order_record.coach_id,
      order_record.subscription_id,
      (order_record.amount_gross_cents::numeric / 100.0),
      (order_record.platform_fee_cents::numeric / 100.0),
      (order_record.coach_net_cents::numeric / 100.0),
      resolved_legacy_status,
      resolved_ready_at,
      order_record.coach_net_cents,
      order_record.currency,
      resolved_status,
      'manual',
      resolved_ready_at,
      timezone('utc', now())
    )
    returning id into payout_id;
  else
    update public.coach_payouts
    set amount_cents = amount_cents + order_record.coach_net_cents,
        gross_amount = gross_amount + (order_record.amount_gross_cents::numeric / 100.0),
        commission_amount = commission_amount + (order_record.platform_fee_cents::numeric / 100.0),
        net_amount = net_amount + (order_record.coach_net_cents::numeric / 100.0),
        eligible_at = coalesce(eligible_at, resolved_ready_at),
        ready_at = coalesce(ready_at, resolved_ready_at),
        updated_at = timezone('utc', now())
    where id = payout_id;
  end if;

  insert into public.coach_payout_items (
    payout_id,
    payment_order_id,
    subscription_id,
    gross_cents,
    platform_fee_cents,
    gateway_fee_cents,
    coach_net_cents
  )
  values (
    payout_id,
    order_record.id,
    order_record.subscription_id,
    order_record.amount_gross_cents,
    order_record.platform_fee_cents,
    order_record.gateway_fee_cents,
    order_record.coach_net_cents
  )
  on conflict (payment_order_id) do nothing;

  return payout_id;
end;
$$;

create or replace function public.admin_record_coach_payout_paid(
  target_payout_id uuid,
  input_method text default 'manual',
  input_external_reference text default null,
  input_admin_note text default null,
  input_transfer_proof_path text default null
)
returns public.coach_payouts
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  payout_record public.coach_payouts%rowtype;
begin
  perform public.assert_admin();

  if input_method not in ('manual', 'bank', 'wallet', 'instapay') then
    raise exception 'Unsupported payout method.';
  end if;

  update public.coach_payouts
  set status = 'paid',
      payout_status = 'paid',
      method = input_method,
      admin_id = requester,
      external_reference = nullif(trim(coalesce(input_external_reference, '')), ''),
      admin_note = nullif(trim(coalesce(input_admin_note, '')), ''),
      transfer_proof_path = nullif(trim(coalesce(input_transfer_proof_path, '')), ''),
      paid_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = target_payout_id
    and status in ('pending', 'on_hold', 'ready', 'processing')
  returning * into payout_record;

  if payout_record.id is null then
    raise exception 'Payout not found or cannot be marked paid.';
  end if;

  insert into public.admin_audit_events (
    actor_user_id,
    action,
    target_type,
    target_id,
    metadata
  )
  values (
    requester,
    'coach_payout_mark_paid',
    'coach_payout',
    payout_record.id,
    jsonb_build_object(
      'coach_id', payout_record.coach_id,
      'amount_cents', payout_record.amount_cents,
      'method', input_method,
      'external_reference', input_external_reference
    )
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    payout_record.coach_id,
    'coaching',
    'Coach payout recorded',
    'GymUnity recorded a manual payout for your coaching earnings.',
    jsonb_build_object('payout_id', payout_record.id, 'amount_cents', payout_record.amount_cents)
  );

  return payout_record;
end;
$$;

create or replace function public.process_coach_paymob_callback(
  input_raw_payload jsonb,
  input_hmac_verified boolean,
  input_paymob_transaction_id text default null,
  input_paymob_order_id text default null,
  input_paymob_intention_id text default null,
  input_special_reference text default null,
  input_success boolean default null,
  input_pending boolean default null,
  input_is_voided boolean default null,
  input_is_refunded boolean default null,
  input_amount_cents integer default null,
  input_currency text default null,
  input_source_data_type text default null,
  input_failure_reason text default null,
  input_payout_hold_days integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
  order_record public.coach_payment_orders%rowtype;
  subscription_record public.subscriptions%rowtype;
  package_record public.coach_packages%rowtype;
  transaction_id uuid;
  inserted_transaction boolean := false;
  result_text text;
  effective_start timestamptz := timezone('utc', now());
  computed_next_renewal timestamptz;
  computed_end timestamptz;
  thread_id uuid;
  payout_id uuid;
  admin_user uuid;
begin
  if jwt_role <> 'service_role' then
    raise exception 'Service role access is required.';
  end if;

  select *
  into order_record
  from public.coach_payment_orders o
  where (
      input_special_reference is not null
      and o.special_reference = input_special_reference
    )
    or (
      input_special_reference is null
      and input_paymob_order_id is not null
      and o.paymob_order_id = input_paymob_order_id
    )
    or (
      input_special_reference is null
      and input_paymob_order_id is null
      and input_paymob_intention_id is not null
      and o.paymob_intention_id = input_paymob_intention_id
    )
  order by
    case
      when input_special_reference is not null and o.special_reference = input_special_reference then 0
      when input_paymob_order_id is not null and o.paymob_order_id = input_paymob_order_id then 1
      else 2
    end,
    o.created_at desc
  limit 1
  for update;

  insert into public.coach_payment_transactions (
    payment_order_id,
    subscription_id,
    member_id,
    coach_id,
    mode,
    gateway,
    paymob_transaction_id,
    paymob_order_id,
    paymob_intention_id,
    special_reference,
    success,
    pending,
    is_voided,
    is_refunded,
    amount_cents,
    currency,
    source_data_type,
    hmac_verified,
    processing_result,
    raw_payload
  )
  values (
    order_record.id,
    order_record.subscription_id,
    order_record.member_id,
    order_record.coach_id,
    coalesce(order_record.mode, 'test'),
    'paymob',
    nullif(input_paymob_transaction_id, ''),
    nullif(input_paymob_order_id, ''),
    nullif(input_paymob_intention_id, ''),
    nullif(coalesce(input_special_reference, order_record.special_reference), ''),
    input_success,
    input_pending,
    input_is_voided,
    input_is_refunded,
    input_amount_cents,
    input_currency,
    input_source_data_type,
    input_hmac_verified,
    case when input_hmac_verified then 'received' else 'invalid_hmac' end,
    coalesce(input_raw_payload, '{}'::jsonb)
  )
  on conflict (paymob_transaction_id) where paymob_transaction_id is not null
  do nothing
  returning id into transaction_id;

  inserted_transaction := transaction_id is not null;

  if not inserted_transaction and input_paymob_transaction_id is not null then
    return jsonb_build_object('ok', true, 'duplicate', true, 'processing_result', 'duplicate');
  end if;

  if not input_hmac_verified then
    return jsonb_build_object('ok', false, 'processing_result', 'invalid_hmac');
  end if;

  if order_record.id is null then
    update public.coach_payment_transactions
    set processing_result = 'payment_order_not_found'
    where id = transaction_id;
    return jsonb_build_object('ok', false, 'processing_result', 'payment_order_not_found');
  end if;

  if order_record.mode <> 'test' then
    result_text := 'mode_mismatch';
  elsif input_amount_cents is distinct from order_record.amount_gross_cents then
    result_text := 'amount_mismatch';
  elsif upper(coalesce(input_currency, '')) <> order_record.currency then
    result_text := 'currency_mismatch';
  end if;

  if result_text is not null then
    update public.coach_payment_orders
    set status = 'failed',
        failure_reason = result_text,
        failed_at = coalesce(failed_at, effective_start),
        updated_at = effective_start
    where id = order_record.id
      and status <> 'paid';

    update public.subscriptions
    set checkout_status = 'failed',
        updated_at = effective_start
    where id = order_record.subscription_id
      and checkout_status <> 'paid';

    update public.coach_payment_transactions
    set processing_result = result_text
    where id = transaction_id;

    return jsonb_build_object('ok', false, 'payment_order_id', order_record.id, 'processing_result', result_text);
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = order_record.subscription_id
  for update;

  if subscription_record.id is null then
    update public.coach_payment_transactions
    set processing_result = 'subscription_not_found'
    where id = transaction_id;
    return jsonb_build_object('ok', false, 'payment_order_id', order_record.id, 'processing_result', 'subscription_not_found');
  end if;

  if input_success = true and coalesce(input_is_voided, false) = false and coalesce(input_is_refunded, false) = false then
    if subscription_record.status = 'active'
       and subscription_record.payment_order_id is not null
       and subscription_record.payment_order_id <> order_record.id then
      update public.coach_payment_transactions
      set processing_result = 'subscription_active_different_order'
      where id = transaction_id;
      return jsonb_build_object('ok', false, 'payment_order_id', order_record.id, 'processing_result', 'subscription_active_different_order');
    end if;

    select *
    into package_record
    from public.coach_packages
    where id = subscription_record.package_id;

    computed_next_renewal := case subscription_record.billing_cycle
      when 'weekly' then effective_start + interval '7 days'
      when 'quarterly' then effective_start + interval '3 months'
      when 'one_time' then null
      else effective_start + interval '1 month'
    end;

    computed_end := case subscription_record.billing_cycle
      when 'one_time' then effective_start + make_interval(days => greatest(coalesce(package_record.duration_weeks, 1) * 7, 1))
      else computed_next_renewal
    end;

    update public.coach_payment_orders
    set status = 'paid',
        paymob_transaction_id = coalesce(nullif(input_paymob_transaction_id, ''), paymob_transaction_id),
        paymob_order_id = coalesce(nullif(input_paymob_order_id, ''), paymob_order_id),
        paymob_intention_id = coalesce(nullif(input_paymob_intention_id, ''), paymob_intention_id),
        paid_at = coalesce(paid_at, effective_start),
        failed_at = null,
        failure_reason = null,
        updated_at = effective_start
    where id = order_record.id
    returning * into order_record;

    update public.subscriptions
    set status = 'active',
        checkout_status = 'paid',
        payment_gateway = 'paymob',
        payment_method = 'paymob',
        payment_order_id = order_record.id,
        amount_cents = order_record.amount_gross_cents,
        currency = order_record.currency,
        platform_fee_cents = order_record.platform_fee_cents,
        coach_net_cents = order_record.coach_net_cents,
        starts_at = coalesce(starts_at, effective_start),
        ends_at = coalesce(ends_at, computed_end),
        activated_at = coalesce(activated_at, effective_start),
        current_period_start = coalesce(current_period_start, effective_start),
        current_period_end = coalesce(current_period_end, computed_end),
        next_renewal_at = computed_next_renewal,
        updated_at = effective_start
    where id = subscription_record.id
    returning * into subscription_record;

    thread_id := public.ensure_coach_member_thread(subscription_record.id);
    payout_id := public.create_pending_coach_payout_for_payment(order_record.id, input_payout_hold_days);

    update public.coach_payment_transactions
    set processing_result = 'paid'
    where id = transaction_id;

    insert into public.notifications (user_id, type, title, body, data)
    values
      (
        subscription_record.coach_id,
        'coaching',
        'Payment confirmed by GymUnity',
        'A client payment was confirmed and the coaching relationship is now active.',
        jsonb_build_object('subscription_id', subscription_record.id, 'payment_order_id', order_record.id, 'thread_id', thread_id, 'payout_id', payout_id)
      ),
      (
        subscription_record.member_id,
        'coaching',
        'Payment successful',
        'Your coaching subscription is active. Your coaching thread is ready.',
        jsonb_build_object('subscription_id', subscription_record.id, 'payment_order_id', order_record.id, 'thread_id', thread_id)
      );

    for admin_user in
      select a.user_id
      from public.app_admins a
      where a.is_active = true
    loop
      insert into public.notifications (user_id, type, title, body, data)
      values (
        admin_user,
        'payment',
        'Coach payment received',
        'A Paymob test payment was confirmed and a coach payout is pending.',
        jsonb_build_object('subscription_id', subscription_record.id, 'payment_order_id', order_record.id, 'payout_id', payout_id, 'mode', order_record.mode)
      );
    end loop;

    return jsonb_build_object(
      'ok', true,
      'processing_result', 'paid',
      'payment_order_id', order_record.id,
      'subscription_id', subscription_record.id,
      'thread_id', thread_id,
      'payout_id', payout_id
    );
  end if;

  if coalesce(input_is_refunded, false) = true then
    result_text := 'refunded';
  elsif coalesce(input_is_voided, false) = true then
    result_text := 'voided';
  else
    result_text := 'failed';
  end if;

  update public.coach_payment_orders
  set status = case
        when result_text = 'refunded' then 'refunded'
        else 'failed'
      end,
      paymob_transaction_id = coalesce(nullif(input_paymob_transaction_id, ''), paymob_transaction_id),
      failure_reason = coalesce(nullif(input_failure_reason, ''), result_text),
      failed_at = case when result_text = 'failed' or result_text = 'voided' then coalesce(failed_at, effective_start) else failed_at end,
      updated_at = effective_start
  where id = order_record.id
    and status <> 'paid'
  returning * into order_record;

  update public.subscriptions
  set checkout_status = case when result_text = 'refunded' then 'refunded' else 'failed' end,
      updated_at = effective_start
  where id = subscription_record.id
    and checkout_status <> 'paid';

  update public.coach_payment_transactions
  set processing_result = result_text
  where id = transaction_id;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    subscription_record.member_id,
    'coaching',
    'Payment was not completed',
    coalesce(nullif(input_failure_reason, ''), 'Paymob did not confirm this payment.'),
    jsonb_build_object('subscription_id', subscription_record.id, 'payment_order_id', order_record.id, 'status', result_text)
  );

  for admin_user in
    select a.user_id
    from public.app_admins a
    where a.is_active = true
  loop
    insert into public.notifications (user_id, type, title, body, data)
    values (
      admin_user,
      'payment',
      'Coach payment failed',
      'A Paymob test payment callback was processed as failed.',
      jsonb_build_object('subscription_id', subscription_record.id, 'payment_order_id', order_record.id, 'status', result_text)
    );
  end loop;

  return jsonb_build_object(
    'ok', true,
    'processing_result', result_text,
    'payment_order_id', order_record.id,
    'subscription_id', subscription_record.id
  );
end;
$$;

drop function if exists public.list_coach_payment_queue();
create function public.list_coach_payment_queue()
returns table (
  receipt_id uuid,
  subscription_id uuid,
  member_id uuid,
  member_name text,
  package_title text,
  amount numeric,
  currency text,
  payment_reference text,
  receipt_storage_path text,
  receipt_status text,
  billing_state text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  failure_reason text,
  payment_gateway text,
  payment_order_id uuid,
  payment_order_status text,
  payout_status text
)
language sql
stable
security definer
set search_path = public
as $$
  with latest_receipts as (
    select distinct on (r.subscription_id)
      r.*
    from public.coach_payment_receipts r
    where r.coach_id = auth.uid()
    order by r.subscription_id, r.created_at desc
  ),
  latest_orders as (
    select distinct on (o.subscription_id)
      o.*
    from public.coach_payment_orders o
    where o.coach_id = auth.uid()
    order by o.subscription_id, o.created_at desc
  ),
  payout_state as (
    select
      i.payment_order_id,
      max(p.status) as status
    from public.coach_payout_items i
    join public.coach_payouts p on p.id = i.payout_id
    group by i.payment_order_id
  )
  select
    r.id as receipt_id,
    s.id as subscription_id,
    s.member_id,
    coalesce(nullif(p.full_name, ''), 'Member') as member_name,
    coalesce(pkg.title, s.plan_name, 'Coaching') as package_title,
    coalesce(r.amount, (o.amount_gross_cents::numeric / 100.0), s.amount) as amount,
    coalesce(r.currency, o.currency, s.currency, 'EGP') as currency,
    coalesce(r.payment_reference, s.payment_reference, o.special_reference) as payment_reference,
    r.receipt_storage_path,
    coalesce(r.status, o.status, 'awaiting_payment') as receipt_status,
    case
      when coalesce(s.payment_gateway, s.payment_method) = 'paymob' and o.status = 'paid' then 'activated'
      when coalesce(s.payment_gateway, s.payment_method) = 'paymob' and o.status = 'failed' then 'failed_needs_follow_up'
      when coalesce(s.payment_gateway, s.payment_method) = 'paymob' and o.status in ('created', 'pending') then 'payment_pending'
      else public.coach_billing_state(s.status, s.checkout_status, r.status)
    end as billing_state,
    coalesce(r.created_at, o.created_at, s.created_at) as submitted_at,
    r.reviewed_at,
    coalesce(r.failure_reason, o.failure_reason) as failure_reason,
    coalesce(s.payment_gateway, o.payment_gateway, s.payment_method) as payment_gateway,
    o.id as payment_order_id,
    o.status as payment_order_status,
    ps.status as payout_status
  from public.subscriptions s
  join public.profiles p on p.user_id = s.member_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  left join latest_receipts r on r.subscription_id = s.id
  left join latest_orders o on o.subscription_id = s.id
  left join payout_state ps on ps.payment_order_id = o.id
  where s.coach_id = auth.uid()
    and (
      s.status in ('checkout_pending', 'pending_payment', 'pending_activation')
      or r.status in ('submitted', 'receipt_uploaded', 'under_verification', 'failed')
      or o.id is not null
    )
  order by
    case
      when coalesce(s.payment_gateway, s.payment_method) = 'paymob' and o.status in ('created', 'pending') then 0
      when public.coach_billing_state(s.status, s.checkout_status, r.status) = 'under_verification' then 1
      when public.coach_billing_state(s.status, s.checkout_status, r.status) = 'receipt_uploaded' then 2
      when public.coach_billing_state(s.status, s.checkout_status, r.status) = 'payment_submitted' then 3
      when public.coach_billing_state(s.status, s.checkout_status, r.status) = 'awaiting_payment' then 4
      else 5
    end,
    coalesce(r.created_at, o.created_at, s.created_at) desc;
$$;

drop function if exists public.list_member_subscriptions_live();
create function public.list_member_subscriptions_live()
returns table (
  id uuid,
  member_id uuid,
  coach_id uuid,
  coach_name text,
  coach_city text,
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
  next_renewal_at timestamptz,
  cancel_at_period_end boolean,
  trial_days integer,
  renewal_price_egp numeric,
  response_sla_hours integer,
  verification_status text,
  weekly_checkin_type text,
  delivery_mode text,
  location_mode text,
  thread_id uuid,
  payment_gateway text,
  payment_order_id uuid,
  amount_cents integer,
  currency text,
  platform_fee_cents integer,
  coach_net_cents integer
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
    cp.city as coach_city,
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
    s.next_renewal_at,
    s.cancel_at_period_end,
    pkg.trial_days,
    pkg.renewal_price_egp,
    cp.response_sla_hours,
    cp.verification_status,
    pkg.weekly_checkin_type,
    pkg.delivery_mode,
    pkg.location_mode,
    thread.id as thread_id,
    s.payment_gateway,
    s.payment_order_id,
    s.amount_cents,
    s.currency,
    s.platform_fee_cents,
    s.coach_net_cents
  from public.subscriptions s
  left join public.profiles p on p.user_id = s.coach_id
  left join public.coach_profiles cp on cp.user_id = s.coach_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  left join public.coach_member_threads thread on thread.subscription_id = s.id
  where s.member_id = auth.uid()
  order by
    case
      when s.status = 'active' then 0
      when s.status in ('checkout_pending', 'pending_payment', 'pending_activation') then 1
      else 2
    end,
    s.created_at desc;
$$;

grant execute on function public.current_user_id() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.assert_admin() to authenticated;
grant execute on function public.admin_create_audit_event(text, text, uuid, jsonb) to authenticated;
grant execute on function public.is_subscription_member(uuid) to authenticated;
grant execute on function public.is_subscription_coach(uuid) to authenticated;
grant execute on function public.get_coach_payment_order_status(uuid) to authenticated;
grant execute on function public.list_coach_payment_queue() to authenticated;
grant execute on function public.list_member_subscriptions_live() to authenticated;
grant execute on function public.ensure_coach_member_thread(uuid) to authenticated, service_role;
grant execute on function public.create_pending_coach_payout_for_payment(uuid, integer) to service_role;
grant execute on function public.process_coach_paymob_callback(jsonb, boolean, text, text, text, text, boolean, boolean, boolean, boolean, integer, text, text, text, integer) to service_role;
grant execute on function public.admin_record_coach_payout_paid(uuid, text, text, text, text) to authenticated;
