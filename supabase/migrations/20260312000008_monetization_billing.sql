create table if not exists public.billing_products (
  id uuid primary key default gen_random_uuid(),
  offering_code text not null,
  plan_code text not null,
  store_platform text not null check (store_platform in ('ios', 'android')),
  store_product_id text not null,
  store_base_plan_id text not null default '',
  payment_path text not null default 'store_billing',
  entitlement_code text not null default 'ai_premium_access',
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (store_platform, store_product_id, store_base_plan_id)
);

create table if not exists public.billing_customers (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  app_account_token uuid not null default gen_random_uuid() unique,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.store_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  offering_code text not null,
  plan_code text,
  entitlement_code text not null default 'ai_premium_access',
  source_platform text not null check (source_platform in ('ios', 'android')),
  store_product_id text not null,
  store_base_plan_id text not null default '',
  purchase_state text not null,
  lifecycle_state text not null,
  entitlement_status text not null,
  transaction_id text not null,
  original_transaction_id text,
  purchase_token text not null default '',
  transaction_date timestamptz,
  access_expires_at timestamptz,
  renews_at timestamptz,
  cancellation_requested_at timestamptz,
  grace_period_until timestamptz,
  environment text,
  verification_source text,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  last_verified_at timestamptz not null default timezone('utc', now()),
  unique (source_platform, transaction_id)
);

create table if not exists public.subscription_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  offering_code text not null,
  plan_code text,
  entitlement_code text not null default 'ai_premium_access',
  source_platform text not null check (source_platform in ('ios', 'android')),
  store_product_id text not null,
  store_base_plan_id text not null default '',
  lifecycle_state text not null,
  entitlement_status text not null check (
    entitlement_status in (
      'enabled',
      'disabled',
      'pending',
      'verification_required'
    )
  ),
  latest_transaction_id text,
  latest_purchase_token text not null default '',
  access_expires_at timestamptz,
  renews_at timestamptz,
  cancellation_requested_at timestamptz,
  grace_period_until timestamptz,
  last_verified_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, offering_code)
);

create table if not exists public.billing_sync_events (
  id uuid primary key default gen_random_uuid(),
  source_platform text not null check (source_platform in ('ios', 'android')),
  event_type text not null,
  external_event_id text,
  user_id uuid references public.profiles(user_id) on delete set null,
  offering_code text,
  verification_state text not null default 'pending',
  raw_payload jsonb not null default '{}'::jsonb,
  processed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_billing_products_offering
  on public.billing_products(offering_code, is_active, store_platform);
create index if not exists idx_store_transactions_user_offering
  on public.store_transactions(user_id, offering_code, created_at desc);
create index if not exists idx_store_transactions_token
  on public.store_transactions(source_platform, purchase_token);
create index if not exists idx_subscription_entitlements_user_offering
  on public.subscription_entitlements(user_id, offering_code);
create index if not exists idx_billing_sync_events_platform_created
  on public.billing_sync_events(source_platform, created_at desc);

alter table public.billing_products enable row level security;
alter table public.billing_customers enable row level security;
alter table public.store_transactions enable row level security;
alter table public.subscription_entitlements enable row level security;
alter table public.billing_sync_events enable row level security;

drop policy if exists billing_products_read_active on public.billing_products;
create policy billing_products_read_active
on public.billing_products for select
to authenticated
using (is_active = true);

drop policy if exists billing_customers_read_own on public.billing_customers;
create policy billing_customers_read_own
on public.billing_customers for select
to authenticated
using (user_id = auth.uid());

drop policy if exists store_transactions_read_own on public.store_transactions;
create policy store_transactions_read_own
on public.store_transactions for select
to authenticated
using (user_id = auth.uid());

drop policy if exists subscription_entitlements_read_own on public.subscription_entitlements;
create policy subscription_entitlements_read_own
on public.subscription_entitlements for select
to authenticated
using (user_id = auth.uid());

drop trigger if exists touch_billing_products_updated_at on public.billing_products;
create trigger touch_billing_products_updated_at
before update on public.billing_products
for each row execute function public.touch_updated_at();

drop trigger if exists touch_billing_customers_updated_at on public.billing_customers;
create trigger touch_billing_customers_updated_at
before update on public.billing_customers
for each row execute function public.touch_updated_at();

drop trigger if exists touch_store_transactions_updated_at on public.store_transactions;
create trigger touch_store_transactions_updated_at
before update on public.store_transactions
for each row execute function public.touch_updated_at();

drop trigger if exists touch_subscription_entitlements_updated_at on public.subscription_entitlements;
create trigger touch_subscription_entitlements_updated_at
before update on public.subscription_entitlements
for each row execute function public.touch_updated_at();

create or replace function public.ensure_billing_customer()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  customer_row public.billing_customers%rowtype;
begin
  if current_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  insert into public.billing_customers (user_id)
  values (current_user_id)
  on conflict (user_id)
  do update set updated_at = timezone('utc', now())
  returning * into customer_row;

  return jsonb_build_object(
    'user_id', customer_row.user_id,
    'app_account_token', customer_row.app_account_token::text
  );
end;
$$;

grant execute on function public.ensure_billing_customer() to authenticated;

revoke all on function public.ensure_billing_customer() from public;
revoke all on function public.ensure_billing_customer() from anon;
