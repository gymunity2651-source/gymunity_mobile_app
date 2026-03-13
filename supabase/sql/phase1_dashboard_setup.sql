-- GymUnity consolidated bootstrap schema
-- Run this file only on a fresh Supabase project.
-- If you already applied incremental migrations, do not run this file afterward.

-- 20260307_000001_init_gymunity.sql
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

create index if not exists idx_profiles_role_id on public.profiles(role_id);
create index if not exists idx_products_seller_id on public.products(seller_id);
create index if not exists idx_orders_member_id on public.orders(member_id);
create index if not exists idx_orders_seller_id on public.orders(seller_id);
create index if not exists idx_chat_messages_session_created
  on public.chat_messages(session_id, created_at);

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

drop policy if exists roles_read_all on public.roles;
create policy roles_read_all
on public.roles for select
to authenticated
using (true);

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

drop policy if exists chat_sessions_manage_own on public.chat_sessions;
create policy chat_sessions_manage_own
on public.chat_sessions for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

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

-- 20260307_000002_storage.sql
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', false),
  ('product-images', 'product-images', true)
on conflict (id) do update set
  name = excluded.name,
  public = excluded.public;

-- avatars: owner-only access
drop policy if exists avatars_select_own on storage.objects;
create policy avatars_select_own
on storage.objects for select
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
);

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
);

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
);

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
);

-- product-images: seller-owned writes, public reads
drop policy if exists product_images_public_read on storage.objects;
create policy product_images_public_read
on storage.objects for select
to public
using (bucket_id = 'product-images');

drop policy if exists product_images_insert_own on storage.objects;
create policy product_images_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists product_images_update_own on storage.objects;
create policy product_images_update_own
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-images'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'product-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists product_images_delete_own on storage.objects;
create policy product_images_delete_own
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

-- 20260307_000003_notifications.sql
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  token text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique(user_id, token)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_notifications_user_created
  on public.notifications(user_id, created_at desc);

alter table public.device_tokens enable row level security;
alter table public.notifications enable row level security;

drop policy if exists device_tokens_manage_own on public.device_tokens;
create policy device_tokens_manage_own
on public.device_tokens for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists notifications_read_own on public.notifications;
create policy notifications_read_own
on public.notifications for select
to authenticated
using (user_id = auth.uid());

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
on public.notifications for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- 20260311_000004_coach_directory_rpc.sql
create or replace function public.list_coach_directory(
  specialty_filter text default null,
  limit_count integer default 20
)
returns table (
  user_id uuid,
  full_name text,
  specialties text[],
  hourly_rate numeric,
  rating_avg numeric,
  rating_count integer,
  is_verified boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    cp.user_id,
    coalesce(p.full_name, 'Coach') as full_name,
    cp.specialties,
    cp.hourly_rate,
    cp.rating_avg,
    cp.rating_count,
    cp.is_verified
  from public.coach_profiles cp
  join public.profiles p on p.user_id = cp.user_id
  where (
    specialty_filter is null
    or specialty_filter = ''
    or specialty_filter = 'All'
    or exists (
      select 1
      from unnest(cp.specialties) specialty
      where lower(specialty) = lower(specialty_filter)
    )
  )
  order by cp.rating_avg desc, cp.rating_count desc, cp.created_at desc
  limit greatest(limit_count, 1);
$$;

grant execute
on function public.list_coach_directory(text, integer)
to authenticated;

-- 20260312_000005_account_deletion.sql
alter table public.users
  add column if not exists deleted_at timestamptz,
  add column if not exists deletion_reason text;

alter table public.profiles
  add column if not exists deleted_at timestamptz;

-- 20260312_000006_core_role_flows.sql
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.member_profiles (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  goal text,
  age integer check (age is null or age between 13 and 120),
  gender text check (
    gender is null
    or gender in ('male', 'female', 'non_binary', 'prefer_not_to_say')
  ),
  height_cm numeric(6,2) check (height_cm is null or height_cm > 0),
  current_weight_kg numeric(6,2) check (
    current_weight_kg is null or current_weight_kg > 0
  ),
  training_frequency text check (
    training_frequency is null
    or training_frequency in (
      '1_2_days_per_week',
      '3_4_days_per_week',
      '5_6_days_per_week',
      'daily'
    )
  ),
  experience_level text check (
    experience_level is null
    or experience_level in ('beginner', 'intermediate', 'advanced', 'athlete')
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.seller_profiles (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  store_name text,
  store_description text,
  primary_category text,
  shipping_scope text check (
    shipping_scope is null
    or shipping_scope in (
      'local_only',
      'national',
      'international',
      'digital_products'
    )
  ),
  support_email text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.user_preferences (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  push_notifications_enabled boolean not null default true,
  ai_tips_enabled boolean not null default true,
  order_updates_enabled boolean not null default true,
  measurement_unit text not null default 'metric' check (
    measurement_unit in ('metric', 'imperial')
  ),
  language text not null default 'english' check (
    language in ('english', 'arabic')
  ),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.member_weight_entries (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  weight_kg numeric(6,2) not null check (weight_kg > 0),
  recorded_at timestamptz not null default timezone('utc', now()),
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.member_body_measurements (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  recorded_at timestamptz not null default timezone('utc', now()),
  waist_cm numeric(6,2),
  chest_cm numeric(6,2),
  hips_cm numeric(6,2),
  arm_cm numeric(6,2),
  thigh_cm numeric(6,2),
  body_fat_percent numeric(5,2),
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (
    coalesce(
      waist_cm,
      chest_cm,
      hips_cm,
      arm_cm,
      thigh_cm,
      body_fat_percent
    ) is not null
  )
);

create table if not exists public.coach_packages (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  title text not null,
  description text,
  billing_cycle text not null default 'monthly' check (
    billing_cycle in ('weekly', 'monthly', 'quarterly', 'one_time')
  ),
  price numeric(10,2) not null check (price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_availability_slots (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  timezone text not null default 'UTC',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (start_time < end_time)
);

alter table public.workout_plans
  add column if not exists updated_at timestamptz not null default timezone('utc', now()),
  add column if not exists assigned_at timestamptz not null default timezone('utc', now()),
  add column if not exists completed_at timestamptz;

create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  workout_plan_id uuid references public.workout_plans(id) on delete set null,
  coach_id uuid references public.coach_profiles(user_id) on delete set null,
  title text not null,
  performed_at timestamptz not null default timezone('utc', now()),
  duration_minutes integer not null default 0 check (duration_minutes >= 0),
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.coach_profiles
  add column if not exists delivery_mode text check (
    delivery_mode is null or delivery_mode in ('remote', 'in_person', 'hybrid')
  ),
  add column if not exists service_summary text,
  add column if not exists verified_at timestamptz,
  add column if not exists pricing_currency text not null default 'USD';

alter table public.products
  add column if not exists low_stock_threshold integer not null default 5 check (
    low_stock_threshold >= 0
  ),
  add column if not exists deleted_at timestamptz;

update public.orders
set status = 'pending_payment'
where status = 'pending';

alter table public.orders
  alter column status set default 'pending_payment';

alter table public.orders
  add column if not exists payment_method text not null default 'manual';

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  seller_id uuid not null references public.profiles(user_id) on delete restrict,
  product_title_snapshot text not null,
  unit_price numeric(10,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity > 0),
  line_total numeric(12,2) not null check (line_total >= 0),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  actor_user_id uuid references public.profiles(user_id) on delete set null,
  note text,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.subscriptions
  add column if not exists package_id uuid references public.coach_packages(id) on delete set null,
  add column if not exists payment_method text not null default 'manual',
  add column if not exists activated_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists member_note text,
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

create table if not exists public.coach_reviews (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  review_text text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (coach_id, member_id)
);

create index if not exists idx_member_weight_entries_member_recorded
  on public.member_weight_entries(member_id, recorded_at desc);
create index if not exists idx_member_measurements_member_recorded
  on public.member_body_measurements(member_id, recorded_at desc);
create index if not exists idx_workout_sessions_member_performed
  on public.workout_sessions(member_id, performed_at desc);
create index if not exists idx_workout_sessions_coach_performed
  on public.workout_sessions(coach_id, performed_at desc);
create index if not exists idx_coach_packages_coach_active
  on public.coach_packages(coach_id, is_active, created_at desc);
create index if not exists idx_coach_availability_coach_weekday
  on public.coach_availability_slots(coach_id, weekday, start_time);
create index if not exists idx_coach_reviews_coach_created
  on public.coach_reviews(coach_id, created_at desc);
create index if not exists idx_products_seller_active_low_stock
  on public.products(seller_id, is_active, stock_qty);
create index if not exists idx_order_items_order
  on public.order_items(order_id);
create index if not exists idx_order_items_seller
  on public.order_items(seller_id, created_at desc);
create index if not exists idx_order_status_history_order
  on public.order_status_history(order_id, created_at desc);
create index if not exists idx_subscriptions_member_status
  on public.subscriptions(member_id, status, created_at desc);
create index if not exists idx_subscriptions_coach_status
  on public.subscriptions(coach_id, status, created_at desc);
create index if not exists idx_workout_plans_member_status
  on public.workout_plans(member_id, status, assigned_at desc);
create index if not exists idx_workout_plans_coach_status
  on public.workout_plans(coach_id, status, assigned_at desc);

alter table public.member_profiles enable row level security;
alter table public.seller_profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.member_weight_entries enable row level security;
alter table public.member_body_measurements enable row level security;
alter table public.coach_packages enable row level security;
alter table public.coach_availability_slots enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.coach_reviews enable row level security;

drop policy if exists member_profiles_read_own on public.member_profiles;
create policy member_profiles_read_own
on public.member_profiles for select
to authenticated
using (user_id = auth.uid());

drop policy if exists member_profiles_manage_own on public.member_profiles;
create policy member_profiles_manage_own
on public.member_profiles for all
to authenticated
using (user_id = auth.uid() and public.current_role() = 'member')
with check (user_id = auth.uid() and public.current_role() = 'member');

drop policy if exists seller_profiles_read_own on public.seller_profiles;
create policy seller_profiles_read_own
on public.seller_profiles for select
to authenticated
using (user_id = auth.uid());

drop policy if exists seller_profiles_manage_own on public.seller_profiles;
create policy seller_profiles_manage_own
on public.seller_profiles for all
to authenticated
using (user_id = auth.uid() and public.current_role() = 'seller')
with check (user_id = auth.uid() and public.current_role() = 'seller');

drop policy if exists user_preferences_read_own on public.user_preferences;
create policy user_preferences_read_own
on public.user_preferences for select
to authenticated
using (user_id = auth.uid());

drop policy if exists user_preferences_manage_own on public.user_preferences;
create policy user_preferences_manage_own
on public.user_preferences for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists member_weight_entries_read_own on public.member_weight_entries;
create policy member_weight_entries_read_own
on public.member_weight_entries for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_weight_entries_manage_own on public.member_weight_entries;
create policy member_weight_entries_manage_own
on public.member_weight_entries for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_measurements_read_own on public.member_body_measurements;
create policy member_measurements_read_own
on public.member_body_measurements for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_measurements_manage_own on public.member_body_measurements;
create policy member_measurements_manage_own
on public.member_body_measurements for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists coach_packages_read_active_or_own on public.coach_packages;
create policy coach_packages_read_active_or_own
on public.coach_packages for select
to authenticated
using (is_active = true or coach_id = auth.uid());

drop policy if exists coach_packages_manage_own on public.coach_packages;
create policy coach_packages_manage_own
on public.coach_packages for all
to authenticated
using (coach_id = auth.uid() and public.current_role() = 'coach')
with check (coach_id = auth.uid() and public.current_role() = 'coach');

drop policy if exists coach_availability_read_active_or_own on public.coach_availability_slots;
create policy coach_availability_read_active_or_own
on public.coach_availability_slots for select
to authenticated
using (is_active = true or coach_id = auth.uid());

drop policy if exists coach_availability_manage_own on public.coach_availability_slots;
create policy coach_availability_manage_own
on public.coach_availability_slots for all
to authenticated
using (coach_id = auth.uid() and public.current_role() = 'coach')
with check (coach_id = auth.uid() and public.current_role() = 'coach');

drop policy if exists workout_sessions_read_member_or_coach on public.workout_sessions;
create policy workout_sessions_read_member_or_coach
on public.workout_sessions for select
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists workout_sessions_insert_member on public.workout_sessions;
create policy workout_sessions_insert_member
on public.workout_sessions for insert
to authenticated
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists workout_sessions_update_member on public.workout_sessions;
create policy workout_sessions_update_member
on public.workout_sessions for update
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists workout_sessions_delete_member on public.workout_sessions;
create policy workout_sessions_delete_member
on public.workout_sessions for delete
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists order_items_read_member_or_seller on public.order_items;
create policy order_items_read_member_or_seller
on public.order_items for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and (o.member_id = auth.uid() or o.seller_id = auth.uid())
  )
);

drop policy if exists order_status_history_read_member_or_seller on public.order_status_history;
create policy order_status_history_read_member_or_seller
on public.order_status_history for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_status_history.order_id
      and (o.member_id = auth.uid() or o.seller_id = auth.uid())
  )
);

drop policy if exists coach_reviews_read_all on public.coach_reviews;
create policy coach_reviews_read_all
on public.coach_reviews for select
to authenticated
using (true);

drop trigger if exists touch_profiles_updated_at on public.profiles;
create trigger touch_profiles_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_profiles_updated_at on public.coach_profiles;
create trigger touch_coach_profiles_updated_at
before update on public.coach_profiles
for each row execute function public.touch_updated_at();

drop trigger if exists touch_products_updated_at on public.products;
create trigger touch_products_updated_at
before update on public.products
for each row execute function public.touch_updated_at();

drop trigger if exists touch_orders_updated_at on public.orders;
create trigger touch_orders_updated_at
before update on public.orders
for each row execute function public.touch_updated_at();

drop trigger if exists touch_subscriptions_updated_at on public.subscriptions;
create trigger touch_subscriptions_updated_at
before update on public.subscriptions
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_profiles_updated_at on public.member_profiles;
create trigger touch_member_profiles_updated_at
before update on public.member_profiles
for each row execute function public.touch_updated_at();

drop trigger if exists touch_seller_profiles_updated_at on public.seller_profiles;
create trigger touch_seller_profiles_updated_at
before update on public.seller_profiles
for each row execute function public.touch_updated_at();

drop trigger if exists touch_user_preferences_updated_at on public.user_preferences;
create trigger touch_user_preferences_updated_at
before update on public.user_preferences
for each row execute function public.touch_updated_at();

drop trigger if exists touch_weight_entries_updated_at on public.member_weight_entries;
create trigger touch_weight_entries_updated_at
before update on public.member_weight_entries
for each row execute function public.touch_updated_at();

drop trigger if exists touch_measurements_updated_at on public.member_body_measurements;
create trigger touch_measurements_updated_at
before update on public.member_body_measurements
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_packages_updated_at on public.coach_packages;
create trigger touch_coach_packages_updated_at
before update on public.coach_packages
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_availability_updated_at on public.coach_availability_slots;
create trigger touch_coach_availability_updated_at
before update on public.coach_availability_slots
for each row execute function public.touch_updated_at();

drop trigger if exists touch_workout_plans_updated_at on public.workout_plans;
create trigger touch_workout_plans_updated_at
before update on public.workout_plans
for each row execute function public.touch_updated_at();

drop trigger if exists touch_workout_sessions_updated_at on public.workout_sessions;
create trigger touch_workout_sessions_updated_at
before update on public.workout_sessions
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_reviews_updated_at on public.coach_reviews;
create trigger touch_coach_reviews_updated_at
before update on public.coach_reviews
for each row execute function public.touch_updated_at();

create or replace function public.refresh_coach_rating_aggregate(target_coach_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  avg_rating numeric(3,2);
  total_reviews integer;
begin
  select
    coalesce(round(avg(rating)::numeric, 2), 0),
    count(*)
  into avg_rating, total_reviews
  from public.coach_reviews
  where coach_id = target_coach_id;

  update public.coach_profiles
  set rating_avg = avg_rating,
      rating_count = total_reviews,
      updated_at = timezone('utc', now())
  where user_id = target_coach_id;
end;
$$;

create or replace function public.handle_coach_review_aggregate()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_coach_rating_aggregate(old.coach_id);
    return old;
  end if;

  perform public.refresh_coach_rating_aggregate(new.coach_id);

  if tg_op = 'UPDATE' and old.coach_id <> new.coach_id then
    perform public.refresh_coach_rating_aggregate(old.coach_id);
  end if;

  return new;
end;
$$;

drop trigger if exists coach_reviews_aggregate_trigger on public.coach_reviews;
create trigger coach_reviews_aggregate_trigger
after insert or update or delete on public.coach_reviews
for each row execute function public.handle_coach_review_aggregate();

create or replace function public.get_coach_public_profile(target_coach_id uuid)
returns table (
  user_id uuid,
  full_name text,
  avatar_path text,
  bio text,
  specialties text[],
  years_experience integer,
  hourly_rate numeric,
  pricing_currency text,
  delivery_mode text,
  service_summary text,
  rating_avg numeric,
  rating_count integer,
  is_verified boolean,
  verified_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    cp.user_id,
    coalesce(p.full_name, 'Coach') as full_name,
    p.avatar_path,
    cp.bio,
    cp.specialties,
    cp.years_experience,
    cp.hourly_rate,
    cp.pricing_currency,
    cp.delivery_mode,
    cp.service_summary,
    cp.rating_avg,
    cp.rating_count,
    cp.is_verified,
    cp.verified_at
  from public.coach_profiles cp
  join public.profiles p on p.user_id = cp.user_id
  where cp.user_id = target_coach_id;
$$;

create or replace function public.list_coach_public_packages(target_coach_id uuid)
returns table (
  id uuid,
  coach_id uuid,
  title text,
  description text,
  billing_cycle text,
  price numeric,
  is_active boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    cp.id,
    cp.coach_id,
    cp.title,
    cp.description,
    cp.billing_cycle,
    cp.price,
    cp.is_active,
    cp.created_at
  from public.coach_packages cp
  where cp.coach_id = target_coach_id
    and cp.is_active = true
  order by cp.price asc, cp.created_at asc;
$$;

create or replace function public.list_coach_public_reviews(target_coach_id uuid)
returns table (
  id uuid,
  member_display_name text,
  rating smallint,
  review_text text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    cr.id,
    coalesce(nullif(p.full_name, ''), 'GymUnity Member') as member_display_name,
    cr.rating,
    cr.review_text,
    cr.created_at
  from public.coach_reviews cr
  join public.profiles p on p.user_id = cr.member_id
  where cr.coach_id = target_coach_id
  order by cr.created_at desc;
$$;

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
    coalesce(p.full_name, 'Coach') as coach_name,
    s.package_id,
    cp.title as package_title,
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
  join public.profiles p on p.user_id = s.coach_id
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
    coalesce(sp.store_name, p.full_name, 'Seller') as seller_name,
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
    coalesce(p.full_name, 'Member') as member_name,
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
    group by wp.member_id
  ),
  session_stats as (
    select
      ws.member_id,
      max(ws.performed_at) as last_session_at
    from public.workout_sessions ws
    where ws.coach_id = auth.uid()
    group by ws.member_id
  )
  select
    s.id as subscription_id,
    s.member_id,
    coalesce(p.full_name, 'Member') as member_name,
    coalesce(cp.title, s.plan_name) as package_title,
    s.status,
    coalesce(s.activated_at, s.starts_at, s.created_at) as started_at,
    coalesce(pc.active_plan_count, 0) as active_plan_count,
    ss.last_session_at
  from public.subscriptions s
  join public.profiles p on p.user_id = s.member_id
  left join public.coach_packages cp on cp.id = s.package_id
  left join plan_counts pc on pc.member_id = s.member_id
  left join session_stats ss on ss.member_id = s.member_id
  where s.coach_id = auth.uid()
  order by s.created_at desc;
$$;

create or replace function public.seller_dashboard_summary()
returns table (
  total_products integer,
  active_products integer,
  low_stock_products integer,
  pending_payment_orders integer,
  in_progress_orders integer,
  delivered_orders integer,
  gross_revenue numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((select count(*) from public.products p where p.seller_id = auth.uid()), 0)::integer as total_products,
    coalesce((select count(*) from public.products p where p.seller_id = auth.uid() and p.is_active = true and p.deleted_at is null), 0)::integer as active_products,
    coalesce((select count(*) from public.products p where p.seller_id = auth.uid() and p.is_active = true and p.stock_qty <= p.low_stock_threshold and p.deleted_at is null), 0)::integer as low_stock_products,
    coalesce((select count(*) from public.orders o where o.seller_id = auth.uid() and o.status = 'pending_payment'), 0)::integer as pending_payment_orders,
    coalesce((select count(*) from public.orders o where o.seller_id = auth.uid() and o.status in ('payment_confirmed', 'processing', 'shipped')), 0)::integer as in_progress_orders,
    coalesce((select count(*) from public.orders o where o.seller_id = auth.uid() and o.status = 'delivered'), 0)::integer as delivered_orders,
    coalesce((select sum(o.total_amount) from public.orders o where o.seller_id = auth.uid() and o.status in ('payment_confirmed', 'processing', 'shipped', 'delivered')), 0)::numeric as gross_revenue;
$$;

create or replace function public.coach_dashboard_summary()
returns table (
  active_clients integer,
  pending_requests integer,
  active_packages integer,
  active_plans integer,
  rating_avg numeric,
  rating_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((select count(distinct s.member_id) from public.subscriptions s where s.coach_id = auth.uid() and s.status = 'active'), 0)::integer as active_clients,
    coalesce((select count(*) from public.subscriptions s where s.coach_id = auth.uid() and s.status = 'pending_payment'), 0)::integer as pending_requests,
    coalesce((select count(*) from public.coach_packages cp where cp.coach_id = auth.uid() and cp.is_active = true), 0)::integer as active_packages,
    coalesce((select count(*) from public.workout_plans wp where wp.coach_id = auth.uid() and wp.status = 'active'), 0)::integer as active_plans,
    coalesce((select cp.rating_avg from public.coach_profiles cp where cp.user_id = auth.uid()), 0)::numeric as rating_avg,
    coalesce((select cp.rating_count from public.coach_profiles cp where cp.user_id = auth.uid()), 0)::integer as rating_count;
$$;

create or replace function public.create_store_order(cart_items jsonb, shipping_snapshot jsonb)
returns table (
  order_id uuid,
  seller_id uuid,
  status text,
  total_amount numeric,
  currency text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  seller_record record;
  item_record record;
  created_order_id uuid;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can create store orders.';
  end if;

  if cart_items is null or jsonb_typeof(cart_items) <> 'array' or jsonb_array_length(cart_items) = 0 then
    raise exception 'Cart items are required.';
  end if;

  if exists (
    with requested_items as (
      select product_id, sum(quantity)::integer as quantity
      from jsonb_to_recordset(cart_items) as input(product_id uuid, quantity integer)
      group by product_id
    )
    select 1
    from requested_items ri
    left join public.products p on p.id = ri.product_id
    where ri.quantity <= 0
      or p.id is null
      or p.is_active = false
      or p.deleted_at is not null
      or p.stock_qty < ri.quantity
  ) then
    raise exception 'One or more products are unavailable or out of stock.';
  end if;

  for seller_record in
    with requested_items as (
      select product_id, sum(quantity)::integer as quantity
      from jsonb_to_recordset(cart_items) as input(product_id uuid, quantity integer)
      group by product_id
    )
    select
      p.seller_id,
      jsonb_agg(
        jsonb_build_object(
          'product_id', p.id,
          'title', p.title,
          'quantity', ri.quantity,
          'unit_price', p.price,
          'line_total', p.price * ri.quantity
        )
        order by p.created_at desc
      ) as items_json,
      sum(p.price * ri.quantity)::numeric as total_amount
    from requested_items ri
    join public.products p on p.id = ri.product_id
    group by p.seller_id
  loop
    insert into public.orders (
      member_id,
      seller_id,
      status,
      total_amount,
      currency,
      payment_method,
      items_json,
      shipping_address_json
    )
    values (
      requester,
      seller_record.seller_id,
      'pending_payment',
      seller_record.total_amount,
      'USD',
      'manual',
      seller_record.items_json,
      coalesce(shipping_snapshot, '{}'::jsonb)
    )
    returning id into created_order_id;

    insert into public.order_status_history (
      order_id,
      status,
      actor_user_id,
      note
    )
    values (
      created_order_id,
      'pending_payment',
      requester,
      'Order created by member.'
    );

    for item_record in
      with requested_items as (
        select product_id, sum(quantity)::integer as quantity
        from jsonb_to_recordset(cart_items) as input(product_id uuid, quantity integer)
        group by product_id
      )
      select
        p.id as product_id,
        p.title,
        p.price,
        ri.quantity,
        (p.price * ri.quantity)::numeric as line_total
      from requested_items ri
      join public.products p on p.id = ri.product_id
      where p.seller_id = seller_record.seller_id
    loop
      insert into public.order_items (
        order_id,
        product_id,
        seller_id,
        product_title_snapshot,
        unit_price,
        quantity,
        line_total
      )
      values (
        created_order_id,
        item_record.product_id,
        seller_record.seller_id,
        item_record.title,
        item_record.price,
        item_record.quantity,
        item_record.line_total
      );

      update public.products
      set stock_qty = stock_qty - item_record.quantity,
          updated_at = timezone('utc', now())
      where id = item_record.product_id;
    end loop;

    insert into public.notifications (
      user_id,
      type,
      title,
      body,
      data
    )
    values (
      seller_record.seller_id,
      'orders',
      'New order request',
      'A new order is waiting for payment confirmation.',
      jsonb_build_object('order_id', created_order_id, 'status', 'pending_payment')
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
      'orders',
      'Order submitted',
      'Your order was created and is pending manual payment confirmation.',
      jsonb_build_object('order_id', created_order_id, 'status', 'pending_payment')
    );

    order_id := created_order_id;
    seller_id := seller_record.seller_id;
    status := 'pending_payment';
    total_amount := seller_record.total_amount;
    currency := 'USD';
    return next;
  end loop;
end;
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

  select *
  into existing_order
  from public.orders
  where id = target_order_id
    and seller_id = auth.uid();

  if existing_order.id is null then
    raise exception 'Order not found for this seller.';
  end if;

  allowed := (
    (existing_order.status = 'pending_payment' and new_status in ('payment_confirmed', 'cancelled'))
    or (existing_order.status = 'payment_confirmed' and new_status in ('processing', 'cancelled'))
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

  order_id := existing_order.id;
  status := new_status;
  return next;
end;
$$;

create or replace function public.request_coach_subscription(
  target_package_id uuid,
  input_member_note text default null
)
returns table (
  id uuid,
  coach_id uuid,
  package_id uuid,
  plan_name text,
  billing_cycle text,
  amount numeric,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  package_record public.coach_packages%rowtype;
  created_subscription public.subscriptions%rowtype;
  requester uuid := auth.uid();
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can request coach subscriptions.';
  end if;

  select *
  into package_record
  from public.coach_packages
  where id = target_package_id
    and is_active = true;

  if package_record.id is null then
    raise exception 'Coach package not found.';
  end if;

  insert into public.subscriptions (
    member_id,
    coach_id,
    package_id,
    plan_name,
    billing_cycle,
    amount,
    status,
    payment_method,
    member_note
  )
  values (
    requester,
    package_record.coach_id,
    package_record.id,
    package_record.title,
    package_record.billing_cycle,
    package_record.price,
    'pending_payment',
    'manual',
    input_member_note
  )
  returning * into created_subscription;

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
    'New subscription request',
    'A member requested the package "' || package_record.title || '".',
    jsonb_build_object(
      'subscription_id', created_subscription.id,
      'package_id', package_record.id,
      'status', 'pending_payment'
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
    'Subscription request submitted',
    'Your request is pending manual payment confirmation.',
    jsonb_build_object(
      'subscription_id', created_subscription.id,
      'package_id', package_record.id,
      'status', 'pending_payment'
    )
  );

  id := created_subscription.id;
  coach_id := created_subscription.coach_id;
  package_id := created_subscription.package_id;
  plan_name := created_subscription.plan_name;
  billing_cycle := created_subscription.billing_cycle;
  amount := created_subscription.amount;
  status := created_subscription.status;
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

  subscription_id := existing_subscription.id;
  status := new_status;
  return next;
end;
$$;

create or replace function public.submit_coach_review(
  target_coach_id uuid,
  target_subscription_id uuid,
  input_rating smallint,
  input_review_text text default ''
)
returns table (
  id uuid,
  coach_id uuid,
  member_id uuid,
  subscription_id uuid,
  rating smallint,
  review_text text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_subscription public.subscriptions%rowtype;
  saved_review public.coach_reviews%rowtype;
  requester uuid := auth.uid();
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can submit coach reviews.';
  end if;

  if input_rating < 1 or input_rating > 5 then
    raise exception 'Rating must be between 1 and 5.';
  end if;

  select *
  into existing_subscription
  from public.subscriptions
  where id = target_subscription_id
    and member_id = requester
    and coach_id = target_coach_id
    and status <> 'pending_payment';

  if existing_subscription.id is null then
    raise exception 'A completed or active subscription is required before reviewing this coach.';
  end if;

  insert into public.coach_reviews (
    coach_id,
    member_id,
    subscription_id,
    rating,
    review_text
  )
  values (
    target_coach_id,
    requester,
    target_subscription_id,
    input_rating,
    coalesce(input_review_text, '')
  )
  on conflict (coach_id, member_id)
  do update set
    subscription_id = excluded.subscription_id,
    rating = excluded.rating,
    review_text = excluded.review_text,
    updated_at = timezone('utc', now())
  returning * into saved_review;

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    target_coach_id,
    'coaching',
    'New coach review',
    'A member submitted a new review.',
    jsonb_build_object('coach_review_id', saved_review.id, 'rating', input_rating)
  );

  id := saved_review.id;
  coach_id := saved_review.coach_id;
  member_id := saved_review.member_id;
  subscription_id := saved_review.subscription_id;
  rating := saved_review.rating;
  review_text := saved_review.review_text;
  return next;
end;
$$;

grant execute on function public.get_coach_public_profile(uuid) to authenticated;
grant execute on function public.list_coach_public_packages(uuid) to authenticated;
grant execute on function public.list_coach_public_reviews(uuid) to authenticated;
grant execute on function public.list_member_subscriptions_detailed() to authenticated;
grant execute on function public.list_member_orders_detailed() to authenticated;
grant execute on function public.list_seller_orders_detailed() to authenticated;
grant execute on function public.list_coach_clients() to authenticated;
grant execute on function public.seller_dashboard_summary() to authenticated;
grant execute on function public.coach_dashboard_summary() to authenticated;
grant execute on function public.create_store_order(jsonb, jsonb) to authenticated;
grant execute on function public.update_store_order_status(uuid, text, text) to authenticated;
grant execute on function public.request_coach_subscription(uuid, text) to authenticated;
grant execute on function public.update_coach_subscription_status(uuid, text, text) to authenticated;
grant execute on function public.submit_coach_review(uuid, uuid, smallint, text) to authenticated;

revoke all on function public.refresh_coach_rating_aggregate(uuid) from public;

create or replace function public.soft_delete_account(target_user_id uuid, deleted_email text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_deleted_email text := nullif(trim(deleted_email), '');
  deleted_timestamp timestamptz := timezone('utc', now());
  result jsonb;
begin
  if target_user_id is null then
    raise exception 'target_user_id is required';
  end if;

  if normalized_deleted_email is null then
    normalized_deleted_email :=
      'deleted+' || replace(target_user_id::text, '-', '') || '@deleted.gymunity.invalid';
  end if;

  update public.users
  set email = normalized_deleted_email,
      is_active = false,
      deleted_at = deleted_timestamp,
      deletion_reason = 'user_requested'
  where id = target_user_id;

  update public.profiles
  set full_name = 'Deleted GymUnity account',
      phone = null,
      country = null,
      avatar_path = null,
      onboarding_completed = false,
      deleted_at = deleted_timestamp,
      updated_at = deleted_timestamp
  where user_id = target_user_id;

  delete from public.user_preferences where user_id = target_user_id;
  delete from public.member_weight_entries where member_id = target_user_id;
  delete from public.member_body_measurements where member_id = target_user_id;
  delete from public.workout_sessions where member_id = target_user_id;
  delete from public.coach_availability_slots where coach_id = target_user_id;
  delete from public.coach_reviews where member_id = target_user_id or coach_id = target_user_id;

  update public.member_profiles
  set goal = null,
      age = null,
      gender = null,
      height_cm = null,
      current_weight_kg = null,
      training_frequency = null,
      experience_level = null,
      updated_at = deleted_timestamp
  where user_id = target_user_id;

  update public.seller_profiles
  set store_name = 'Archived Store',
      store_description = null,
      primary_category = null,
      shipping_scope = null,
      support_email = null,
      updated_at = deleted_timestamp
  where user_id = target_user_id;

  update public.coach_profiles
  set bio = 'Deleted account',
      specialties = '{}'::text[],
      years_experience = 0,
      hourly_rate = 0,
      delivery_mode = null,
      service_summary = null,
      is_verified = false,
      verified_at = null,
      rating_avg = 0,
      rating_count = 0,
      updated_at = deleted_timestamp
  where user_id = target_user_id;

  update public.coach_packages
  set is_active = false,
      updated_at = deleted_timestamp
  where coach_id = target_user_id;

  update public.products
  set is_active = false,
      deleted_at = deleted_timestamp,
      updated_at = deleted_timestamp
  where seller_id = target_user_id;

  update public.subscriptions
  set status = case
        when status = 'pending_payment' then 'cancelled'
        when status = 'active' then 'completed'
        else status
      end,
      cancelled_at = case
        when coach_id = target_user_id or member_id = target_user_id then deleted_timestamp
        else cancelled_at
      end,
      ends_at = case
        when coach_id = target_user_id or member_id = target_user_id then deleted_timestamp
        else ends_at
      end,
      updated_at = deleted_timestamp
  where coach_id = target_user_id or member_id = target_user_id;

  update public.workout_plans
  set status = 'archived',
      completed_at = coalesce(completed_at, deleted_timestamp),
      updated_at = deleted_timestamp
  where coach_id = target_user_id or member_id = target_user_id;

  delete from public.notifications where user_id = target_user_id;
  delete from public.device_tokens where user_id = target_user_id;
  delete from public.chat_sessions where user_id = target_user_id;

  result := jsonb_build_object(
    'deleted_at', deleted_timestamp,
    'user_id', target_user_id
  );

  return result;
end;
$$;

revoke all on function public.soft_delete_account(uuid, text) from public;
revoke all on function public.soft_delete_account(uuid, text) from anon;
revoke all on function public.soft_delete_account(uuid, text) from authenticated;

-- 20260312_000007_store_orders_hardening.sql
alter table public.products
  add column if not exists currency text not null default 'USD';

update public.products
set currency = 'USD'
where currency is null or btrim(currency) = '';

update public.orders
set status = 'pending'
where status = 'pending_payment';

update public.orders
set status = 'paid'
where status = 'payment_confirmed';

update public.order_status_history
set status = 'pending'
where status = 'pending_payment';

update public.order_status_history
set status = 'paid'
where status = 'payment_confirmed';

alter table public.orders
  alter column status set default 'pending';

alter table public.orders
  drop constraint if exists orders_status_allowed;

alter table public.orders
  add constraint orders_status_allowed check (
    status in ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled')
  );

alter table public.order_status_history
  drop constraint if exists order_status_history_status_allowed;

alter table public.order_status_history
  add constraint order_status_history_status_allowed check (
    status in ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled')
  );

create table if not exists public.store_carts (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null unique references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.store_cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.store_carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (cart_id, product_id)
);

create table if not exists public.product_favorites (
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (member_id, product_id)
);

create table if not exists public.shipping_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  recipient_name text not null,
  phone text not null,
  line1 text not null,
  line2 text,
  city text not null,
  state_region text not null,
  postal_code text not null,
  country_code text not null,
  delivery_notes text,
  is_default boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (btrim(recipient_name) <> ''),
  check (btrim(phone) <> ''),
  check (btrim(line1) <> ''),
  check (btrim(city) <> ''),
  check (btrim(state_region) <> ''),
  check (btrim(postal_code) <> ''),
  check (btrim(country_code) <> '')
);

create table if not exists public.store_checkout_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  idempotency_key text not null,
  order_ids_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  unique (member_id, idempotency_key),
  check (btrim(idempotency_key) <> '')
);

create unique index if not exists idx_shipping_addresses_default_per_user
  on public.shipping_addresses(user_id)
  where is_default = true;

create index if not exists idx_store_cart_items_cart
  on public.store_cart_items(cart_id, created_at desc);

create index if not exists idx_store_cart_items_product
  on public.store_cart_items(product_id);

create index if not exists idx_product_favorites_member_created
  on public.product_favorites(member_id, created_at desc);

create index if not exists idx_shipping_addresses_user_updated
  on public.shipping_addresses(user_id, is_default desc, updated_at desc);

create index if not exists idx_checkout_requests_member_created
  on public.store_checkout_requests(member_id, created_at desc);

create index if not exists idx_orders_member_status_created
  on public.orders(member_id, status, created_at desc);

create index if not exists idx_orders_seller_status_created
  on public.orders(seller_id, status, created_at desc);

alter table public.store_carts enable row level security;
alter table public.store_cart_items enable row level security;
alter table public.product_favorites enable row level security;
alter table public.shipping_addresses enable row level security;
alter table public.store_checkout_requests enable row level security;

drop policy if exists products_read_active_or_own on public.products;
create policy products_read_active_or_own
on public.products for select
to authenticated
using (
  is_active = true
  or seller_id = auth.uid()
  or exists (
    select 1
    from public.store_carts sc
    join public.store_cart_items sci on sci.cart_id = sc.id
    where sc.member_id = auth.uid()
      and sci.product_id = products.id
  )
  or exists (
    select 1
    from public.product_favorites pf
    where pf.member_id = auth.uid()
      and pf.product_id = products.id
  )
  or exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.product_id = products.id
      and (o.member_id = auth.uid() or o.seller_id = auth.uid())
  )
);

drop policy if exists store_carts_read_own on public.store_carts;
create policy store_carts_read_own
on public.store_carts for select
to authenticated
using (member_id = auth.uid());

drop policy if exists store_carts_insert_own on public.store_carts;
create policy store_carts_insert_own
on public.store_carts for insert
to authenticated
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists store_carts_update_own on public.store_carts;
create policy store_carts_update_own
on public.store_carts for update
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists store_carts_delete_own on public.store_carts;
create policy store_carts_delete_own
on public.store_carts for delete
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists store_cart_items_read_own on public.store_cart_items;
create policy store_cart_items_read_own
on public.store_cart_items for select
to authenticated
using (
  exists (
    select 1
    from public.store_carts sc
    where sc.id = store_cart_items.cart_id
      and sc.member_id = auth.uid()
  )
);

drop policy if exists store_cart_items_manage_own on public.store_cart_items;
create policy store_cart_items_manage_own
on public.store_cart_items for all
to authenticated
using (
  exists (
    select 1
    from public.store_carts sc
    where sc.id = store_cart_items.cart_id
      and sc.member_id = auth.uid()
      and public.current_role() = 'member'
  )
)
with check (
  exists (
    select 1
    from public.store_carts sc
    where sc.id = store_cart_items.cart_id
      and sc.member_id = auth.uid()
      and public.current_role() = 'member'
  )
);

drop policy if exists product_favorites_read_own on public.product_favorites;
create policy product_favorites_read_own
on public.product_favorites for select
to authenticated
using (member_id = auth.uid());

drop policy if exists product_favorites_insert_own on public.product_favorites;
create policy product_favorites_insert_own
on public.product_favorites for insert
to authenticated
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists product_favorites_delete_own on public.product_favorites;
create policy product_favorites_delete_own
on public.product_favorites for delete
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists shipping_addresses_read_own on public.shipping_addresses;
create policy shipping_addresses_read_own
on public.shipping_addresses for select
to authenticated
using (user_id = auth.uid());

drop policy if exists shipping_addresses_manage_own on public.shipping_addresses;
create policy shipping_addresses_manage_own
on public.shipping_addresses for all
to authenticated
using (user_id = auth.uid() and public.current_role() = 'member')
with check (user_id = auth.uid() and public.current_role() = 'member');

drop policy if exists store_checkout_requests_read_own on public.store_checkout_requests;
create policy store_checkout_requests_read_own
on public.store_checkout_requests for select
to authenticated
using (member_id = auth.uid());

drop policy if exists orders_insert_member on public.orders;
drop policy if exists orders_update_owner_side on public.orders;

drop trigger if exists touch_store_carts_updated_at on public.store_carts;
create trigger touch_store_carts_updated_at
before update on public.store_carts
for each row execute function public.touch_updated_at();

drop trigger if exists touch_store_cart_items_updated_at on public.store_cart_items;
create trigger touch_store_cart_items_updated_at
before update on public.store_cart_items
for each row execute function public.touch_updated_at();

drop trigger if exists touch_shipping_addresses_updated_at on public.shipping_addresses;
create trigger touch_shipping_addresses_updated_at
before update on public.shipping_addresses
for each row execute function public.touch_updated_at();

drop function if exists public.create_store_order(jsonb, jsonb);
drop function if exists public.seller_dashboard_summary();

create function public.seller_dashboard_summary()
returns table (
  total_products integer,
  active_products integer,
  low_stock_products integer,
  pending_orders integer,
  in_progress_orders integer,
  delivered_orders integer,
  gross_revenue numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((select count(*) from public.products p where p.seller_id = auth.uid()), 0)::integer as total_products,
    coalesce((select count(*) from public.products p where p.seller_id = auth.uid() and p.is_active = true and p.deleted_at is null), 0)::integer as active_products,
    coalesce((select count(*) from public.products p where p.seller_id = auth.uid() and p.is_active = true and p.stock_qty <= p.low_stock_threshold and p.deleted_at is null), 0)::integer as low_stock_products,
    coalesce((select count(*) from public.orders o where o.seller_id = auth.uid() and o.status = 'pending'), 0)::integer as pending_orders,
    coalesce((select count(*) from public.orders o where o.seller_id = auth.uid() and o.status in ('paid', 'processing', 'shipped')), 0)::integer as in_progress_orders,
    coalesce((select count(*) from public.orders o where o.seller_id = auth.uid() and o.status = 'delivered'), 0)::integer as delivered_orders,
    coalesce((select sum(o.total_amount) from public.orders o where o.seller_id = auth.uid() and o.status in ('paid', 'processing', 'shipped', 'delivered')), 0)::numeric as gross_revenue;
$$;

create or replace function public.create_store_order(
  target_shipping_address_id uuid,
  client_idempotency_key text
)
returns table (
  order_id uuid,
  seller_id uuid,
  status text,
  total_amount numeric,
  currency text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  cart_record public.store_carts%rowtype;
  shipping_record public.shipping_addresses%rowtype;
  checkout_record public.store_checkout_requests%rowtype;
  seller_record record;
  item_record record;
  created_order_id uuid;
  created_order_ids uuid[] := '{}'::uuid[];
  expected_stock_rows integer;
  updated_stock_rows integer;
  shipping_snapshot jsonb;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can create store orders.';
  end if;

  if target_shipping_address_id is null then
    raise exception 'Shipping address is required.';
  end if;

  if btrim(coalesce(client_idempotency_key, '')) = '' then
    raise exception 'Checkout request key is required.';
  end if;

  select *
  into shipping_record
  from public.shipping_addresses
  where id = target_shipping_address_id
    and user_id = requester;

  if shipping_record.id is null then
    raise exception 'Shipping address was not found.';
  end if;

  if btrim(coalesce(shipping_record.recipient_name, '')) = ''
      or btrim(coalesce(shipping_record.phone, '')) = ''
      or btrim(coalesce(shipping_record.line1, '')) = ''
      or btrim(coalesce(shipping_record.city, '')) = ''
      or btrim(coalesce(shipping_record.state_region, '')) = ''
      or btrim(coalesce(shipping_record.postal_code, '')) = ''
      or btrim(coalesce(shipping_record.country_code, '')) = '' then
    raise exception 'Shipping address is incomplete.';
  end if;

  select *
  into cart_record
  from public.store_carts
  where member_id = requester;

  if cart_record.id is null then
    raise exception 'Your cart is empty.';
  end if;

  if not exists (
    select 1
    from public.store_cart_items sci
    where sci.cart_id = cart_record.id
  ) then
    raise exception 'Your cart is empty.';
  end if;

  insert into public.store_checkout_requests (
    member_id,
    idempotency_key
  )
  values (
    requester,
    btrim(client_idempotency_key)
  )
  on conflict (member_id, idempotency_key)
  do update set
    member_id = excluded.member_id
  returning * into checkout_record;

  if checkout_record.completed_at is not null
      and jsonb_typeof(checkout_record.order_ids_json) = 'array'
      and jsonb_array_length(checkout_record.order_ids_json) > 0 then
    return query
    select
      o.id,
      o.seller_id,
      o.status,
      o.total_amount,
      o.currency
    from public.orders o
    join jsonb_array_elements_text(checkout_record.order_ids_json) as ids(order_id_text)
      on o.id = ids.order_id_text::uuid
    order by o.created_at asc;
    return;
  end if;

  perform 1
  from public.products p
  join public.store_cart_items sci on sci.product_id = p.id
  where sci.cart_id = cart_record.id
  order by p.id
  for update;

  if exists (
    select 1
    from public.store_cart_items sci
    left join public.products p on p.id = sci.product_id
    where sci.cart_id = cart_record.id
      and (
        sci.quantity <= 0
        or p.id is null
        or p.is_active = false
        or p.deleted_at is not null
        or p.stock_qty < sci.quantity
        or p.currency is null
        or btrim(p.currency) = ''
      )
  ) then
    raise exception 'One or more products are unavailable or out of stock.';
  end if;

  shipping_snapshot := jsonb_build_object(
    'shipping_address_id', shipping_record.id,
    'recipient_name', shipping_record.recipient_name,
    'phone', shipping_record.phone,
    'line1', shipping_record.line1,
    'line2', shipping_record.line2,
    'city', shipping_record.city,
    'state_region', shipping_record.state_region,
    'postal_code', shipping_record.postal_code,
    'country_code', shipping_record.country_code,
    'delivery_notes', shipping_record.delivery_notes
  );

  for seller_record in
    select
      p.seller_id,
      p.currency,
      jsonb_agg(
        jsonb_build_object(
          'product_id', p.id,
          'title', p.title,
          'quantity', sci.quantity,
          'unit_price', p.price,
          'line_total', p.price * sci.quantity
        )
        order by p.created_at desc
      ) as items_json,
      sum(p.price * sci.quantity)::numeric as total_amount
    from public.store_cart_items sci
    join public.products p on p.id = sci.product_id
    where sci.cart_id = cart_record.id
    group by p.seller_id, p.currency
  loop
    insert into public.orders (
      member_id,
      seller_id,
      status,
      total_amount,
      currency,
      payment_method,
      items_json,
      shipping_address_json
    )
    values (
      requester,
      seller_record.seller_id,
      'pending',
      seller_record.total_amount,
      seller_record.currency,
      'manual',
      seller_record.items_json,
      shipping_snapshot
    )
    returning id into created_order_id;

    insert into public.order_status_history (
      order_id,
      status,
      actor_user_id,
      note
    )
    values (
      created_order_id,
      'pending',
      requester,
      'Order created by member.'
    );

    for item_record in
      select
        p.id as product_id,
        p.title,
        p.price,
        sci.quantity,
        (p.price * sci.quantity)::numeric as line_total
      from public.store_cart_items sci
      join public.products p on p.id = sci.product_id
      where sci.cart_id = cart_record.id
        and p.seller_id = seller_record.seller_id
        and p.currency = seller_record.currency
    loop
      insert into public.order_items (
        order_id,
        product_id,
        seller_id,
        product_title_snapshot,
        unit_price,
        quantity,
        line_total
      )
      values (
        created_order_id,
        item_record.product_id,
        seller_record.seller_id,
        item_record.title,
        item_record.price,
        item_record.quantity,
        item_record.line_total
      );
    end loop;

    select count(*)::integer
    into expected_stock_rows
    from (
      select sci.product_id
      from public.store_cart_items sci
      join public.products p on p.id = sci.product_id
      where sci.cart_id = cart_record.id
        and p.seller_id = seller_record.seller_id
        and p.currency = seller_record.currency
      group by sci.product_id
    ) grouped_items;

    update public.products p
    set stock_qty = p.stock_qty - source.quantity,
        updated_at = timezone('utc', now())
    from (
      select
        sci.product_id,
        sum(sci.quantity)::integer as quantity
      from public.store_cart_items sci
      join public.products p2 on p2.id = sci.product_id
      where sci.cart_id = cart_record.id
        and p2.seller_id = seller_record.seller_id
        and p2.currency = seller_record.currency
      group by sci.product_id
    ) as source
    where p.id = source.product_id
      and p.stock_qty >= source.quantity;

    get diagnostics updated_stock_rows = row_count;

    if updated_stock_rows <> expected_stock_rows then
      raise exception 'One or more products are unavailable or out of stock.';
    end if;

    insert into public.notifications (
      user_id,
      type,
      title,
      body,
      data
    )
    values (
      seller_record.seller_id,
      'orders',
      'New order request',
      'A new order was placed and is awaiting payment confirmation.',
      jsonb_build_object('order_id', created_order_id, 'status', 'pending')
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
      'orders',
      'Order submitted',
      'Your order was created and is awaiting manual payment confirmation.',
      jsonb_build_object('order_id', created_order_id, 'status', 'pending')
    );

    created_order_ids := array_append(created_order_ids, created_order_id);
  end loop;

  if array_length(created_order_ids, 1) is null then
    raise exception 'Your cart is empty.';
  end if;

  delete from public.store_cart_items
  where cart_id = cart_record.id;

  update public.store_checkout_requests
  set order_ids_json = to_jsonb(created_order_ids),
      completed_at = timezone('utc', now())
  where id = checkout_record.id;

  return query
  select
    o.id,
    o.seller_id,
    o.status,
    o.total_amount,
    o.currency
  from public.orders o
  where o.id = any(created_order_ids)
  order by o.created_at asc;
end;
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

  order_id := existing_order.id;
  status := new_status;
  return next;
end;
$$;

revoke all on function public.create_store_order(uuid, text) from public;
revoke all on function public.create_store_order(uuid, text) from anon;
grant execute on function public.create_store_order(uuid, text) to authenticated;

revoke all on function public.seller_dashboard_summary() from public;
grant execute on function public.seller_dashboard_summary() to authenticated;

grant execute on function public.update_store_order_status(uuid, text, text) to authenticated;
