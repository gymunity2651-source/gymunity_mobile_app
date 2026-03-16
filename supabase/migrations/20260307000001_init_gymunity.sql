-- GymUnity initial production schema
-- Date: 2026-03-07

create extension if not exists "pgcrypto";

create table if not exists public.roles (
  id smallint primary key,
  code text not null unique check (code in ('member', 'coach', 'seller')),
  name text not null
);

insert into public.roles (id, code, name)
values
  (1, 'member', 'Member'),
  (2, 'coach', 'Coach'),
  (3, 'seller', 'Seller')
on conflict (id) do update set
  code = excluded.code,
  name = excluded.name;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  created_at timestamptz not null default timezone('utc', now()),
  last_login_at timestamptz,
  is_active boolean not null default true
);

create table if not exists public.profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  role_id smallint references public.roles(id),
  full_name text,
  avatar_path text,
  phone text,
  country text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_profiles (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  bio text,
  specialties text[] not null default '{}',
  years_experience integer not null default 0,
  hourly_rate numeric(10,2) not null default 0,
  is_verified boolean not null default false,
  rating_avg numeric(3,2) not null default 0,
  rating_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(user_id) on delete restrict,
  title text not null,
  description text,
  category text not null,
  price numeric(10,2) not null check (price >= 0),
  stock_qty integer not null default 0 check (stock_qty >= 0),
  image_paths text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete restrict,
  seller_id uuid not null references public.profiles(user_id) on delete restrict,
  status text not null default 'pending',
  total_amount numeric(12,2) not null check (total_amount >= 0),
  currency text not null default 'USD',
  items_json jsonb not null default '[]'::jsonb,
  shipping_address_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete restrict,
  coach_id uuid not null references public.coach_profiles(user_id) on delete restrict,
  plan_name text not null,
  billing_cycle text not null default 'monthly',
  amount numeric(10,2) not null check (amount >= 0),
  status text not null default 'active',
  starts_at timestamptz not null default timezone('utc', now()),
  ends_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.chat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  title text not null default 'New chat',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.chat_sessions(id) on delete cascade,
  sender text not null check (sender in ('user', 'assistant', 'system')),
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.workout_plans (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete restrict,
  coach_id uuid references public.coach_profiles(user_id) on delete set null,
  source text not null check (source in ('coach', 'ai')),
  title text not null,
  plan_json jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  start_date date,
  end_date date,
  created_at timestamptz not null default timezone('utc', now())
);

-- Scalability indexes
create index if not exists idx_profiles_role_id on public.profiles(role_id);
create index if not exists idx_products_seller_id on public.products(seller_id);
create index if not exists idx_orders_member_id on public.orders(member_id);
create index if not exists idx_orders_seller_id on public.orders(seller_id);
create index if not exists idx_chat_messages_session_created
  on public.chat_messages(session_id, created_at);

-- Role helper
create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select r.code
  from public.profiles p
  join public.roles r on r.id = p.role_id
  where p.user_id = auth.uid()
$$;

grant execute on function public.current_role() to authenticated;

-- RLS
alter table public.roles enable row level security;
alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.coach_profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.subscriptions enable row level security;
alter table public.chat_sessions enable row level security;
alter table public.chat_messages enable row level security;
alter table public.workout_plans enable row level security;

-- roles
drop policy if exists roles_read_all on public.roles;
create policy roles_read_all
on public.roles for select
to authenticated
using (true);

-- users
drop policy if exists users_read_own on public.users;
create policy users_read_own
on public.users for select
to authenticated
using (id = auth.uid());

drop policy if exists users_upsert_own on public.users;
create policy users_upsert_own
on public.users for all
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- profiles
drop policy if exists profiles_read_own on public.profiles;
create policy profiles_read_own
on public.profiles for select
to authenticated
using (user_id = auth.uid());

drop policy if exists profiles_upsert_own on public.profiles;
create policy profiles_upsert_own
on public.profiles for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- coach profiles
drop policy if exists coach_profiles_read_all on public.coach_profiles;
create policy coach_profiles_read_all
on public.coach_profiles for select
to authenticated
using (true);

drop policy if exists coach_profiles_manage_own on public.coach_profiles;
create policy coach_profiles_manage_own
on public.coach_profiles for all
to authenticated
using (user_id = auth.uid() and public.current_role() = 'coach')
with check (user_id = auth.uid() and public.current_role() = 'coach');

-- products
drop policy if exists products_read_active_or_own on public.products;
create policy products_read_active_or_own
on public.products for select
to authenticated
using (is_active = true or seller_id = auth.uid());

drop policy if exists products_insert_own_seller on public.products;
create policy products_insert_own_seller
on public.products for insert
to authenticated
with check (seller_id = auth.uid() and public.current_role() = 'seller');

drop policy if exists products_update_own_seller on public.products;
create policy products_update_own_seller
on public.products for update
to authenticated
using (seller_id = auth.uid() and public.current_role() = 'seller')
with check (seller_id = auth.uid() and public.current_role() = 'seller');

drop policy if exists products_delete_own_seller on public.products;
create policy products_delete_own_seller
on public.products for delete
to authenticated
using (seller_id = auth.uid() and public.current_role() = 'seller');

-- orders
drop policy if exists orders_read_member_or_seller on public.orders;
create policy orders_read_member_or_seller
on public.orders for select
to authenticated
using (member_id = auth.uid() or seller_id = auth.uid());

drop policy if exists orders_insert_member on public.orders;
create policy orders_insert_member
on public.orders for insert
to authenticated
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists orders_update_owner_side on public.orders;
create policy orders_update_owner_side
on public.orders for update
to authenticated
using (member_id = auth.uid() or seller_id = auth.uid())
with check (member_id = auth.uid() or seller_id = auth.uid());

-- subscriptions
drop policy if exists subscriptions_read_member_or_coach on public.subscriptions;
create policy subscriptions_read_member_or_coach
on public.subscriptions for select
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists subscriptions_insert_member on public.subscriptions;
create policy subscriptions_insert_member
on public.subscriptions for insert
to authenticated
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists subscriptions_update_member_or_coach on public.subscriptions;
create policy subscriptions_update_member_or_coach
on public.subscriptions for update
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid())
with check (member_id = auth.uid() or coach_id = auth.uid());

-- chat sessions
drop policy if exists chat_sessions_manage_own on public.chat_sessions;
create policy chat_sessions_manage_own
on public.chat_sessions for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- chat messages
drop policy if exists chat_messages_read_own_session on public.chat_messages;
create policy chat_messages_read_own_session
on public.chat_messages for select
to authenticated
using (
  exists (
    select 1
    from public.chat_sessions s
    where s.id = chat_messages.session_id
      and s.user_id = auth.uid()
  )
);

drop policy if exists chat_messages_insert_own_session on public.chat_messages;
create policy chat_messages_insert_own_session
on public.chat_messages for insert
to authenticated
with check (
  exists (
    select 1
    from public.chat_sessions s
    where s.id = chat_messages.session_id
      and s.user_id = auth.uid()
  )
);

-- workout plans
drop policy if exists workout_plans_read_member_or_coach on public.workout_plans;
create policy workout_plans_read_member_or_coach
on public.workout_plans for select
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists workout_plans_insert_member_or_coach on public.workout_plans;
create policy workout_plans_insert_member_or_coach
on public.workout_plans for insert
to authenticated
with check (
  (member_id = auth.uid() and public.current_role() = 'member')
  or (coach_id = auth.uid() and public.current_role() = 'coach')
);

drop policy if exists workout_plans_update_member_or_coach on public.workout_plans;
create policy workout_plans_update_member_or_coach
on public.workout_plans for update
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid())
with check (member_id = auth.uid() or coach_id = auth.uid());

