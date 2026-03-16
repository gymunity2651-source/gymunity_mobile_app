-- GymUnity consolidated bootstrap schema
-- Run this file only on a fresh Supabase project.
-- If you already applied incremental migrations, do not run this file afterward.

-- 20260307000001_init_gymunity.sql
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

-- 20260307000002_storage.sql
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

-- 20260307000003_notifications.sql
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

-- 20260311000004_coach_directory_rpc.sql
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

-- 20260312000005_account_deletion.sql
alter table public.users
  add column if not exists deleted_at timestamptz,
  add column if not exists deletion_reason text;

alter table public.profiles
  add column if not exists deleted_at timestamptz;

-- 20260312000006_core_role_flows.sql
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


-- Appended from 20260316000011_hard_delete_account.sql

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

-- 20260312000007_store_orders_hardening.sql
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


-- Appended from 20260313000009_ai_member_planner.sql

-- AI member planner foundation
-- Date: 2026-03-13

alter table public.chat_sessions
  add column if not exists session_type text not null default 'general' check (
    session_type in ('general', 'planner')
  ),
  add column if not exists planner_status text not null default 'idle' check (
    planner_status in (
      'idle',
      'collecting_info',
      'plan_ready',
      'plan_updated',
      'unsafe_request',
      'error'
    )
  ),
  add column if not exists planner_profile_json jsonb not null default '{}'::jsonb;

create index if not exists idx_chat_sessions_user_type_updated
  on public.chat_sessions(user_id, session_type, updated_at desc);

create table if not exists public.ai_plan_drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  session_id uuid not null references public.chat_sessions(id) on delete cascade,
  status text not null check (
    status in (
      'collecting_info',
      'plan_ready',
      'plan_updated',
      'unsafe_request',
      'error',
      'activated'
    )
  ),
  assistant_message text not null default '',
  missing_fields text[] not null default '{}',
  extracted_profile_json jsonb not null default '{}'::jsonb,
  plan_json jsonb not null default '{}'::jsonb,
  source_plan_id uuid references public.workout_plans(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_plan_drafts_user_session_updated
  on public.ai_plan_drafts(user_id, session_id, updated_at desc);

alter table public.chat_sessions
  add column if not exists latest_draft_id uuid references public.ai_plan_drafts(id) on delete set null;

alter table public.workout_plans
  add column if not exists conversation_session_id uuid references public.chat_sessions(id) on delete set null,
  add column if not exists generated_from_draft_id uuid references public.ai_plan_drafts(id) on delete set null,
  add column if not exists plan_version integer not null default 1 check (plan_version >= 1),
  add column if not exists default_reminder_time time;

create table if not exists public.workout_plan_days (
  id uuid primary key default gen_random_uuid(),
  workout_plan_id uuid not null references public.workout_plans(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  week_number integer not null check (week_number >= 1),
  day_number integer not null check (day_number >= 1),
  day_index integer not null check (day_index >= 1),
  scheduled_date date not null,
  label text not null,
  focus text,
  is_rest_day boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (workout_plan_id, day_index),
  unique (workout_plan_id, scheduled_date)
);

create table if not exists public.workout_plan_tasks (
  id uuid primary key default gen_random_uuid(),
  day_id uuid not null references public.workout_plan_days(id) on delete cascade,
  workout_plan_id uuid not null references public.workout_plans(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  scheduled_date date not null,
  task_type text not null check (
    task_type in (
      'workout',
      'cardio',
      'mobility',
      'nutrition',
      'hydration',
      'sleep',
      'steps',
      'recovery',
      'measurement'
    )
  ),
  title text not null,
  instructions text not null default '',
  sets integer check (sets is null or sets >= 0),
  reps integer check (reps is null or reps >= 0),
  duration_minutes integer check (duration_minutes is null or duration_minutes >= 0),
  target_value numeric(10,2) check (target_value is null or target_value >= 0),
  target_unit text,
  scheduled_time time,
  reminder_time time,
  is_required boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.workout_task_logs (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null unique references public.workout_plan_tasks(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  completion_status text not null check (
    completion_status in ('completed', 'partial', 'skipped')
  ),
  completion_percent integer check (
    completion_percent is null
    or (completion_percent >= 0 and completion_percent <= 100)
  ),
  note text,
  duration_minutes integer check (duration_minutes is null or duration_minutes >= 0),
  logged_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_workout_plan_days_member_scheduled
  on public.workout_plan_days(member_id, scheduled_date);

create index if not exists idx_workout_plan_tasks_member_scheduled
  on public.workout_plan_tasks(member_id, scheduled_date, reminder_time, sort_order);

create index if not exists idx_workout_task_logs_member_logged
  on public.workout_task_logs(member_id, logged_at desc);

alter table public.notifications
  add column if not exists external_key text,
  add column if not exists available_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'notifications_user_external_key_unique'
      and conrelid = 'public.notifications'::regclass
  ) then
    alter table public.notifications
      add constraint notifications_user_external_key_unique
      unique (user_id, external_key);
  end if;
end
$$;

create index if not exists idx_notifications_user_available
  on public.notifications(user_id, available_at desc);

alter table public.ai_plan_drafts enable row level security;
alter table public.workout_plan_days enable row level security;
alter table public.workout_plan_tasks enable row level security;
alter table public.workout_task_logs enable row level security;

drop policy if exists ai_plan_drafts_read_own on public.ai_plan_drafts;
create policy ai_plan_drafts_read_own
on public.ai_plan_drafts for select
to authenticated
using (user_id = auth.uid());

drop policy if exists workout_plan_days_read_own on public.workout_plan_days;
create policy workout_plan_days_read_own
on public.workout_plan_days for select
to authenticated
using (member_id = auth.uid());

drop policy if exists workout_plan_tasks_read_own on public.workout_plan_tasks;
create policy workout_plan_tasks_read_own
on public.workout_plan_tasks for select
to authenticated
using (member_id = auth.uid());

drop policy if exists workout_task_logs_read_own on public.workout_task_logs;
create policy workout_task_logs_read_own
on public.workout_task_logs for select
to authenticated
using (member_id = auth.uid());

drop policy if exists workout_task_logs_manage_own on public.workout_task_logs;
create policy workout_task_logs_manage_own
on public.workout_task_logs for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop trigger if exists touch_ai_plan_drafts_updated_at on public.ai_plan_drafts;
create trigger touch_ai_plan_drafts_updated_at
before update on public.ai_plan_drafts
for each row execute function public.touch_updated_at();

drop trigger if exists touch_workout_plan_days_updated_at on public.workout_plan_days;
create trigger touch_workout_plan_days_updated_at
before update on public.workout_plan_days
for each row execute function public.touch_updated_at();

drop trigger if exists touch_workout_plan_tasks_updated_at on public.workout_plan_tasks;
create trigger touch_workout_plan_tasks_updated_at
before update on public.workout_plan_tasks
for each row execute function public.touch_updated_at();

drop trigger if exists touch_workout_task_logs_updated_at on public.workout_task_logs;
create trigger touch_workout_task_logs_updated_at
before update on public.workout_task_logs
for each row execute function public.touch_updated_at();

create or replace function public.activate_ai_workout_plan(
  input_draft_id uuid,
  input_start_date date default current_date,
  input_default_reminder_time time default null
)
returns table (
  plan_id uuid,
  created boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  draft_record public.ai_plan_drafts%rowtype;
  existing_plan_id uuid;
  created_plan_id uuid;
  current_week jsonb;
  current_day jsonb;
  created_day_id uuid;
  plan_title text;
  plan_json jsonb;
  duration_weeks integer;
  computed_start_date date := coalesce(input_start_date, current_date);
  computed_day_index integer;
  computed_week_number integer;
  computed_day_number integer;
  computed_date date;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can activate AI plans.';
  end if;

  select *
  into draft_record
  from public.ai_plan_drafts
  where id = input_draft_id
    and user_id = requester;

  if not found then
    raise exception 'AI plan draft not found.';
  end if;

  if draft_record.status not in ('plan_ready', 'plan_updated', 'activated') then
    raise exception 'This AI plan draft is not ready for activation.';
  end if;

  select id
  into existing_plan_id
  from public.workout_plans
  where generated_from_draft_id = input_draft_id
    and member_id = requester
  limit 1;

  if existing_plan_id is not null then
    return query
    select existing_plan_id, false;
    return;
  end if;

  plan_json := coalesce(draft_record.plan_json, '{}'::jsonb);
  plan_title := coalesce(nullif(plan_json ->> 'title', ''), 'AI Workout Plan');
  duration_weeks := greatest(coalesce((plan_json ->> 'duration_weeks')::integer, 1), 1);

  update public.workout_plans
  set status = 'archived',
      completed_at = coalesce(completed_at, timezone('utc', now()))
  where member_id = requester
    and source = 'ai'
    and status = 'active';

  insert into public.workout_plans (
    member_id,
    source,
    title,
    plan_json,
    status,
    start_date,
    end_date,
    assigned_at,
    conversation_session_id,
    generated_from_draft_id,
    plan_version,
    default_reminder_time
  )
  values (
    requester,
    'ai',
    plan_title,
    plan_json,
    'active',
    computed_start_date,
    computed_start_date + ((duration_weeks * 7) - 1),
    timezone('utc', now()),
    draft_record.session_id,
    draft_record.id,
    coalesce((
      select max(plan_version) + 1
      from public.workout_plans
      where member_id = requester
        and source = 'ai'
    ), 1),
    input_default_reminder_time
  )
  returning id into created_plan_id;

  for current_week in
    select value
    from jsonb_array_elements(coalesce(plan_json -> 'weekly_structure', '[]'::jsonb))
  loop
    computed_week_number := greatest(coalesce((current_week ->> 'week_number')::integer, 1), 1);

    for current_day in
      select value
      from jsonb_array_elements(coalesce(current_week -> 'days', '[]'::jsonb))
    loop
      computed_day_number := greatest(coalesce((current_day ->> 'day_number')::integer, 1), 1);
      computed_day_index := ((computed_week_number - 1) * 7) + computed_day_number;
      computed_date := computed_start_date + (computed_day_index - 1);

      insert into public.workout_plan_days (
        workout_plan_id,
        member_id,
        week_number,
        day_number,
        day_index,
        scheduled_date,
        label,
        focus,
        is_rest_day
      )
      values (
        created_plan_id,
        requester,
        computed_week_number,
        computed_day_number,
        computed_day_index,
        computed_date,
        coalesce(nullif(current_day ->> 'label', ''), 'Day ' || computed_day_index::text),
        nullif(current_day ->> 'focus', ''),
        jsonb_array_length(coalesce(current_day -> 'tasks', '[]'::jsonb)) = 0
      )
      returning id into created_day_id;

      insert into public.workout_plan_tasks (
        day_id,
        workout_plan_id,
        member_id,
        scheduled_date,
        task_type,
        title,
        instructions,
        sets,
        reps,
        duration_minutes,
        target_value,
        target_unit,
        scheduled_time,
        reminder_time,
        is_required,
        sort_order
      )
      select
        created_day_id,
        created_plan_id,
        requester,
        computed_date,
        coalesce(nullif(task_item.value ->> 'type', ''), 'workout'),
        coalesce(nullif(task_item.value ->> 'title', ''), 'Task'),
        coalesce(task_item.value ->> 'instructions', ''),
        case
          when coalesce(task_item.value ->> 'sets', '') = '' then null
          else (task_item.value ->> 'sets')::integer
        end,
        case
          when coalesce(task_item.value ->> 'reps', '') = '' then null
          else (task_item.value ->> 'reps')::integer
        end,
        case
          when coalesce(task_item.value ->> 'duration_minutes', '') = '' then null
          else (task_item.value ->> 'duration_minutes')::integer
        end,
        case
          when coalesce(task_item.value ->> 'target_value', '') = '' then null
          else (task_item.value ->> 'target_value')::numeric
        end,
        nullif(task_item.value ->> 'target_unit', ''),
        case
          when coalesce(task_item.value ->> 'scheduled_time', '') = '' then null
          else (task_item.value ->> 'scheduled_time')::time
        end,
        case
          when coalesce(task_item.value ->> 'reminder_time', '') <> '' then
            (task_item.value ->> 'reminder_time')::time
          when input_default_reminder_time is not null then
            input_default_reminder_time
          else null
        end,
        coalesce((task_item.value ->> 'is_required')::boolean, true),
        task_item.ordinality::integer - 1
      from jsonb_array_elements(coalesce(current_day -> 'tasks', '[]'::jsonb))
        with ordinality as task_item(value, ordinality);
    end loop;
  end loop;

  update public.ai_plan_drafts
  set status = 'activated'
  where id = draft_record.id;

  update public.chat_sessions
  set planner_status = 'plan_ready',
      latest_draft_id = draft_record.id,
      updated_at = timezone('utc', now())
  where id = draft_record.session_id;

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data,
    external_key,
    available_at
  )
  values (
    requester,
    'ai',
    'AI plan activated',
    'Your AI plan "' || plan_title || '" is now active.',
    jsonb_build_object(
      'kind', 'plan_activation',
      'workout_plan_id', created_plan_id,
      'draft_id', draft_record.id
    ),
    'ai-plan-activation:' || created_plan_id::text,
    timezone('utc', now())
  )
  on conflict (user_id, external_key) do update
    set title = excluded.title,
        body = excluded.body,
        data = excluded.data,
        available_at = excluded.available_at,
        is_read = false;

  return query
  select created_plan_id, true;
end;
$$;

grant execute on function public.activate_ai_workout_plan(uuid, date, time) to authenticated;

create or replace function public.upsert_workout_task_log(
  input_task_id uuid,
  input_completion_status text,
  input_completion_percent integer default null,
  input_note text default null,
  input_duration_minutes integer default null,
  input_logged_at timestamptz default timezone('utc', now())
)
returns public.workout_task_logs
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  task_record public.workout_plan_tasks%rowtype;
  log_record public.workout_task_logs%rowtype;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can update task progress.';
  end if;

  if input_completion_status not in ('completed', 'partial', 'skipped') then
    raise exception 'Unsupported completion status.';
  end if;

  select *
  into task_record
  from public.workout_plan_tasks
  where id = input_task_id
    and member_id = requester;

  if not found then
    raise exception 'Workout task not found.';
  end if;

  insert into public.workout_task_logs (
    task_id,
    member_id,
    completion_status,
    completion_percent,
    note,
    duration_minutes,
    logged_at
  )
  values (
    input_task_id,
    requester,
    input_completion_status,
    input_completion_percent,
    input_note,
    input_duration_minutes,
    coalesce(input_logged_at, timezone('utc', now()))
  )
  on conflict (task_id) do update
    set completion_status = excluded.completion_status,
        completion_percent = excluded.completion_percent,
        note = excluded.note,
        duration_minutes = excluded.duration_minutes,
        logged_at = excluded.logged_at,
        updated_at = timezone('utc', now())
  returning * into log_record;

  return log_record;
end;
$$;

grant execute on function public.upsert_workout_task_log(
  uuid,
  text,
  integer,
  text,
  integer,
  timestamptz
) to authenticated;

create or replace function public.list_member_plan_agenda(
  input_plan_id uuid default null,
  input_date_from date default current_date,
  input_date_to date default (current_date + 14)
)
returns table (
  plan_id uuid,
  plan_title text,
  plan_status text,
  plan_source text,
  plan_start_date date,
  plan_end_date date,
  day_id uuid,
  week_number integer,
  day_number integer,
  day_index integer,
  day_label text,
  day_focus text,
  scheduled_date date,
  task_id uuid,
  task_type text,
  task_title text,
  task_instructions text,
  sets integer,
  reps integer,
  duration_minutes integer,
  target_value numeric,
  target_unit text,
  scheduled_time time,
  reminder_time time,
  is_required boolean,
  sort_order integer,
  log_id uuid,
  completion_status text,
  completion_percent integer,
  log_note text,
  logged_at timestamptz,
  effective_status text
)
language sql
security definer
set search_path = public
as $$
  with scoped_tasks as (
    select
      wp.id as plan_id,
      wp.title as plan_title,
      wp.status as plan_status,
      wp.source as plan_source,
      wp.start_date as plan_start_date,
      wp.end_date as plan_end_date,
      d.id as day_id,
      d.week_number,
      d.day_number,
      d.day_index,
      d.label as day_label,
      d.focus as day_focus,
      t.scheduled_date,
      t.id as task_id,
      t.task_type,
      t.title as task_title,
      t.instructions as task_instructions,
      t.sets,
      t.reps,
      t.duration_minutes,
      t.target_value,
      t.target_unit,
      t.scheduled_time,
      t.reminder_time,
      t.is_required,
      t.sort_order,
      l.id as log_id,
      l.completion_status,
      l.completion_percent,
      l.note as log_note,
      l.logged_at
    from public.workout_plan_tasks t
    join public.workout_plan_days d on d.id = t.day_id
    join public.workout_plans wp on wp.id = t.workout_plan_id
    left join public.workout_task_logs l on l.task_id = t.id
    where t.member_id = auth.uid()
      and t.scheduled_date between coalesce(input_date_from, current_date)
      and coalesce(input_date_to, current_date + 14)
      and (input_plan_id is null or t.workout_plan_id = input_plan_id)
  )
  select
    plan_id,
    plan_title,
    plan_status,
    plan_source,
    plan_start_date,
    plan_end_date,
    day_id,
    week_number,
    day_number,
    day_index,
    day_label,
    day_focus,
    scheduled_date,
    task_id,
    task_type,
    task_title,
    task_instructions,
    sets,
    reps,
    duration_minutes,
    target_value,
    target_unit,
    scheduled_time,
    reminder_time,
    is_required,
    sort_order,
    log_id,
    completion_status,
    completion_percent,
    log_note,
    logged_at,
    case
      when completion_status is not null then completion_status
      when scheduled_date < current_date then 'missed'
      else 'pending'
    end as effective_status
  from scoped_tasks
  order by scheduled_date, sort_order, task_title;
$$;

grant execute on function public.list_member_plan_agenda(uuid, date, date) to authenticated;

create or replace function public.sync_member_task_notifications(
  input_time_zone text default 'UTC',
  input_limit integer default 50
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  task_record record;
  synced_count integer := 0;
  reminder_keys text[] := '{}';
  computed_available_at timestamptz;
  computed_key text;
  computed_title text;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can sync planner reminders.';
  end if;

  for task_record in
    select
      t.id as task_id,
      t.title as task_title,
      t.scheduled_date,
      t.reminder_time,
      t.workout_plan_id,
      t.day_id,
      wp.title as plan_title
    from public.workout_plan_tasks t
    join public.workout_plans wp on wp.id = t.workout_plan_id
    left join public.workout_task_logs l on l.task_id = t.id
    where t.member_id = requester
      and wp.source = 'ai'
      and wp.status = 'active'
      and t.reminder_time is not null
      and l.id is null
      and t.scheduled_date >= current_date
    order by t.scheduled_date, t.reminder_time, t.sort_order
    limit greatest(coalesce(input_limit, 50), 1)
  loop
    computed_available_at := make_timestamptz(
      extract(year from task_record.scheduled_date)::integer,
      extract(month from task_record.scheduled_date)::integer,
      extract(day from task_record.scheduled_date)::integer,
      extract(hour from task_record.reminder_time)::integer,
      extract(minute from task_record.reminder_time)::integer,
      0,
      coalesce(nullif(input_time_zone, ''), 'UTC')
    );

    computed_key :=
      'task-reminder:' || task_record.task_id::text || ':' ||
      to_char(computed_available_at at time zone 'UTC', 'YYYYMMDDHH24MISS');
    reminder_keys := array_append(reminder_keys, computed_key);

    computed_title := case
      when task_record.scheduled_date = current_date then 'Today''s AI task'
      else 'Upcoming AI task'
    end;

    insert into public.notifications (
      user_id,
      type,
      title,
      body,
      data,
      external_key,
      available_at
    )
    values (
      requester,
      'ai',
      computed_title,
      task_record.task_title || ' from "' || task_record.plan_title || '".',
      jsonb_build_object(
        'kind', 'task_reminder',
        'task_id', task_record.task_id,
        'workout_plan_id', task_record.workout_plan_id,
        'day_id', task_record.day_id,
        'scheduled_date', task_record.scheduled_date,
        'reminder_time', task_record.reminder_time,
        'time_zone', input_time_zone
      ),
      computed_key,
      computed_available_at
    )
    on conflict (user_id, external_key) do update
      set title = excluded.title,
          body = excluded.body,
          data = excluded.data,
          available_at = excluded.available_at,
          is_read = false;

    synced_count := synced_count + 1;
  end loop;

  delete from public.notifications n
  where n.user_id = requester
    and n.type = 'ai'
    and coalesce(n.data ->> 'kind', '') = 'task_reminder'
    and n.external_key is not null
    and not (n.external_key = any(reminder_keys));

  return synced_count;
end;
$$;

grant execute on function public.sync_member_task_notifications(text, integer) to authenticated;

create or replace function public.update_ai_plan_reminder_time(
  input_plan_id uuid,
  input_reminder_time time,
  input_time_zone text default 'UTC'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  updated_count integer := 0;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can update AI plan reminders.';
  end if;

  update public.workout_plans
  set default_reminder_time = input_reminder_time,
      updated_at = timezone('utc', now())
  where id = input_plan_id
    and member_id = requester
    and source = 'ai';

  if not found then
    raise exception 'AI workout plan not found.';
  end if;

  update public.workout_plan_tasks t
  set reminder_time = input_reminder_time,
      updated_at = timezone('utc', now())
  where t.workout_plan_id = input_plan_id
    and t.member_id = requester
    and t.scheduled_date >= current_date
    and not exists (
      select 1
      from public.workout_task_logs l
      where l.task_id = t.id
    );

  get diagnostics updated_count = row_count;
  perform public.sync_member_task_notifications(input_time_zone, 50);
  return updated_count;
end;
$$;

grant execute on function public.update_ai_plan_reminder_time(uuid, time, text) to authenticated;

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

-- Appended from 20260316000012_personalized_news.sql
-- Personalized health/news recommendation system
-- Date: 2026-03-16

create table if not exists public.news_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  base_url text not null,
  feed_url text,
  api_endpoint text,
  source_type text not null check (source_type in ('rss', 'api', 'manual')),
  language text not null default 'english',
  country text,
  category text,
  is_active boolean not null default true,
  trust_score numeric(5,2) not null default 80 check (
    trust_score >= 0 and trust_score <= 100
  ),
  source_weight numeric(5,2) not null default 1 check (
    source_weight > 0 and source_weight <= 5
  ),
  last_synced_at timestamptz,
  last_error_at timestamptz,
  last_error_message text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (
    feed_url is not null
    or api_endpoint is not null
    or source_type = 'manual'
  )
);

create table if not exists public.news_articles (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.news_sources(id) on delete restrict,
  canonical_url text not null,
  external_id text,
  title text not null,
  summary text not null default '',
  content text,
  author_name text,
  image_url text,
  published_at timestamptz not null,
  fetched_at timestamptz not null default timezone('utc', now()),
  language text not null default 'english',
  category text,
  tags jsonb not null default '[]'::jsonb,
  target_roles jsonb not null default '[]'::jsonb,
  target_goals jsonb not null default '[]'::jsonb,
  target_levels jsonb not null default '[]'::jsonb,
  trust_score numeric(5,2) not null default 70 check (
    trust_score >= 0 and trust_score <= 100
  ),
  evidence_level text check (
    evidence_level is null
    or evidence_level in (
      'expert_reviewed',
      'source_reported',
      'educational',
      'unknown'
    )
  ),
  safety_level text not null default 'general' check (
    safety_level in ('general', 'caution', 'restricted')
  ),
  quality_score numeric(5,2) not null default 50 check (
    quality_score >= 0 and quality_score <= 100
  ),
  dedupe_hash text,
  is_active boolean not null default true,
  is_featured boolean not null default false,
  ingestion_notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (canonical_url),
  check (jsonb_typeof(tags) = 'array'),
  check (jsonb_typeof(target_roles) = 'array'),
  check (jsonb_typeof(target_goals) = 'array'),
  check (jsonb_typeof(target_levels) = 'array')
);

create table if not exists public.news_article_topics (
  article_id uuid not null references public.news_articles(id) on delete cascade,
  topic_code text not null,
  score numeric(5,3) not null check (score > 0 and score <= 1),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (article_id, topic_code)
);

create table if not exists public.user_news_interests (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  topic_code text not null,
  score numeric(5,3) not null check (score >= -1 and score <= 1),
  source text not null check (
    source in (
      'onboarding',
      'explicit_preference',
      'inferred_from_behavior',
      'inferred_from_ai_memory',
      'inferred_from_activity'
    )
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, topic_code, source)
);

create table if not exists public.news_article_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  article_id uuid not null references public.news_articles(id) on delete cascade,
  interaction_type text not null check (
    interaction_type in (
      'impression',
      'click',
      'open',
      'save',
      'dismiss',
      'share',
      'mark_not_interested'
    )
  ),
  created_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb,
  check (jsonb_typeof(metadata) = 'object')
);

create table if not exists public.news_article_bookmarks (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  article_id uuid not null references public.news_articles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, article_id)
);

create index if not exists idx_news_sources_active_synced
  on public.news_sources(is_active, last_synced_at desc);

create unique index if not exists idx_news_articles_source_external
  on public.news_articles(source_id, external_id)
  where external_id is not null;

create unique index if not exists idx_news_articles_dedupe_hash
  on public.news_articles(dedupe_hash)
  where dedupe_hash is not null;

create index if not exists idx_news_articles_published
  on public.news_articles(published_at desc);

create index if not exists idx_news_articles_source_published
  on public.news_articles(source_id, published_at desc);

create index if not exists idx_news_articles_active_published
  on public.news_articles(is_active, published_at desc);

create index if not exists idx_news_articles_active_feed
  on public.news_articles(published_at desc)
  where is_active = true and safety_level <> 'restricted';

create index if not exists idx_news_articles_safety_published
  on public.news_articles(safety_level, published_at desc);

create index if not exists idx_news_articles_category_published
  on public.news_articles(category, published_at desc);

create index if not exists idx_news_articles_language_published
  on public.news_articles(language, published_at desc);

create index if not exists idx_news_articles_target_roles
  on public.news_articles using gin(target_roles jsonb_path_ops);

create index if not exists idx_news_articles_target_goals
  on public.news_articles using gin(target_goals jsonb_path_ops);

create index if not exists idx_news_articles_target_levels
  on public.news_articles using gin(target_levels jsonb_path_ops);

create index if not exists idx_news_article_topics_article
  on public.news_article_topics(article_id);

create index if not exists idx_news_article_topics_topic
  on public.news_article_topics(topic_code, score desc);

create index if not exists idx_user_news_interests_user_updated
  on public.user_news_interests(user_id, updated_at desc);

create index if not exists idx_news_article_interactions_user_created
  on public.news_article_interactions(user_id, created_at desc);

create index if not exists idx_news_article_interactions_lookup
  on public.news_article_interactions(
    user_id,
    article_id,
    interaction_type,
    created_at desc
  );

create index if not exists idx_news_article_bookmarks_user_created
  on public.news_article_bookmarks(user_id, created_at desc);

drop trigger if exists touch_news_sources_updated_at on public.news_sources;
create trigger touch_news_sources_updated_at
before update on public.news_sources
for each row execute function public.touch_updated_at();

drop trigger if exists touch_news_articles_updated_at on public.news_articles;
create trigger touch_news_articles_updated_at
before update on public.news_articles
for each row execute function public.touch_updated_at();

drop trigger if exists touch_user_news_interests_updated_at on public.user_news_interests;
create trigger touch_user_news_interests_updated_at
before update on public.user_news_interests
for each row execute function public.touch_updated_at();

insert into public.news_sources (
  id,
  name,
  base_url,
  feed_url,
  source_type,
  language,
  country,
  category,
  is_active,
  trust_score,
  source_weight,
  notes
)
values
  (
    '4be51e3b-91be-4c6c-a9cb-09fd9cdd2380',
    'NIH News Releases',
    'https://www.nih.gov',
    'https://www.nih.gov/news-releases/feed.xml',
    'rss',
    'english',
    'US',
    'research_news',
    true,
    92,
    1.00,
    'Official National Institutes of Health news releases.'
  ),
  (
    'd69771c2-9c13-4a65-a67d-4742219cbb94',
    'NIH News in Health',
    'https://newsinhealth.nih.gov',
    'https://newsinhealth.nih.gov/rss',
    'rss',
    'english',
    'US',
    'health_education',
    true,
    88,
    1.05,
    'Official NIH consumer health education articles.'
  ),
  (
    'b838cb56-852a-4b1b-9878-263f4e433433',
    'WHO News (English)',
    'https://www.who.int',
    'https://www.who.int/rss-feeds/news-english.xml',
    'rss',
    'english',
    'INT',
    'public_health',
    true,
    90,
    1.10,
    'Official World Health Organization English news feed.'
  )
on conflict (id) do update set
  name = excluded.name,
  base_url = excluded.base_url,
  feed_url = excluded.feed_url,
  source_type = excluded.source_type,
  language = excluded.language,
  country = excluded.country,
  category = excluded.category,
  is_active = excluded.is_active,
  trust_score = excluded.trust_score,
  source_weight = excluded.source_weight,
  notes = excluded.notes;

alter table public.news_sources enable row level security;
alter table public.news_articles enable row level security;
alter table public.news_article_topics enable row level security;
alter table public.user_news_interests enable row level security;
alter table public.news_article_interactions enable row level security;
alter table public.news_article_bookmarks enable row level security;

drop policy if exists news_sources_read_active on public.news_sources;
create policy news_sources_read_active
on public.news_sources for select
to authenticated
using (is_active = true);

drop policy if exists news_articles_read_safe_active on public.news_articles;
create policy news_articles_read_safe_active
on public.news_articles for select
to authenticated
using (
  is_active = true
  and safety_level <> 'restricted'
  and exists (
    select 1
    from public.news_sources source_row
    where source_row.id = news_articles.source_id
      and source_row.is_active = true
  )
);

drop policy if exists news_article_topics_read_safe_articles on public.news_article_topics;
create policy news_article_topics_read_safe_articles
on public.news_article_topics for select
to authenticated
using (
  exists (
    select 1
    from public.news_articles article_row
    join public.news_sources source_row on source_row.id = article_row.source_id
    where article_row.id = news_article_topics.article_id
      and article_row.is_active = true
      and article_row.safety_level <> 'restricted'
      and source_row.is_active = true
  )
);

drop policy if exists user_news_interests_read_own on public.user_news_interests;
create policy user_news_interests_read_own
on public.user_news_interests for select
to authenticated
using (user_id = auth.uid());

drop policy if exists news_article_interactions_read_own on public.news_article_interactions;
create policy news_article_interactions_read_own
on public.news_article_interactions for select
to authenticated
using (user_id = auth.uid());

drop policy if exists news_article_interactions_insert_own on public.news_article_interactions;
create policy news_article_interactions_insert_own
on public.news_article_interactions for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists news_article_bookmarks_read_own on public.news_article_bookmarks;
create policy news_article_bookmarks_read_own
on public.news_article_bookmarks for select
to authenticated
using (user_id = auth.uid());

drop policy if exists news_article_bookmarks_manage_own on public.news_article_bookmarks;
create policy news_article_bookmarks_manage_own
on public.news_article_bookmarks for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace function public.news_safe_jsonb_array(input jsonb)
returns jsonb
language sql
immutable
as $$
  select case
    when jsonb_typeof(input) = 'array' then input
    else '[]'::jsonb
  end
$$;

create or replace function public.news_target_matches(targets jsonb, desired text)
returns boolean
language sql
immutable
as $$
  select
    desired is null
    or jsonb_array_length(public.news_safe_jsonb_array(targets)) = 0
    or public.news_safe_jsonb_array(targets) @> to_jsonb(array['all']::text[])
    or public.news_safe_jsonb_array(targets) @> to_jsonb(array[lower(desired)]::text[])
$$;

create or replace function public.normalize_news_goal(input_goal text)
returns text
language sql
immutable
as $$
  select case trim(lower(coalesce(input_goal, '')))
    when '' then null
    when 'build_muscle' then 'muscle_gain'
    when 'muscle_gain' then 'muscle_gain'
    when 'lose_weight' then 'fat_loss'
    when 'fat_loss' then 'fat_loss'
    when 'endurance' then 'endurance'
    when 'mobility' then 'mobility'
    when 'recovery' then 'recovery'
    when 'functional' then 'general_fitness'
    when 'sports' then 'sports_performance'
    when 'general_fitness' then 'general_fitness'
    else replace(trim(lower(input_goal)), ' ', '_')
  end
$$;

create or replace function public.normalize_news_level(input_level text)
returns text
language sql
immutable
as $$
  select case trim(lower(coalesce(input_level, '')))
    when '' then null
    when 'beginner' then 'beginner'
    when 'intermediate' then 'intermediate'
    when 'advanced' then 'advanced'
    when 'athlete' then 'advanced'
    when 'all' then 'all'
    else replace(trim(lower(input_level)), ' ', '_')
  end
$$;

create or replace function public.upsert_user_news_interest(
  p_user_id uuid,
  p_topic_code text,
  p_score numeric,
  p_source text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null
     or nullif(trim(coalesce(p_topic_code, '')), '') is null
     or nullif(trim(coalesce(p_source, '')), '') is null then
    return;
  end if;

  insert into public.user_news_interests (
    user_id,
    topic_code,
    score,
    source,
    created_at,
    updated_at
  )
  values (
    p_user_id,
    lower(trim(p_topic_code)),
    greatest(-1::numeric, least(1::numeric, coalesce(p_score, 0))),
    lower(trim(p_source)),
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (user_id, topic_code, source) do update
  set score = excluded.score,
      updated_at = excluded.updated_at;
end;
$$;

create or replace function public.bump_user_news_interest(
  p_user_id uuid,
  p_topic_code text,
  p_delta numeric,
  p_source text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null
     or nullif(trim(coalesce(p_topic_code, '')), '') is null
     or nullif(trim(coalesce(p_source, '')), '') is null
     or coalesce(p_delta, 0) = 0 then
    return;
  end if;

  insert into public.user_news_interests (
    user_id,
    topic_code,
    score,
    source,
    created_at,
    updated_at
  )
  values (
    p_user_id,
    lower(trim(p_topic_code)),
    greatest(-1::numeric, least(1::numeric, coalesce(p_delta, 0))),
    lower(trim(p_source)),
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (user_id, topic_code, source) do update
  set score = greatest(
        -1::numeric,
        least(1::numeric, public.user_news_interests.score + excluded.score)
      ),
      updated_at = excluded.updated_at;
end;
$$;

create or replace function public.sync_member_news_interests(p_user_id uuid default auth.uid())
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := coalesce(p_user_id, auth.uid());
  role_code text;
  goal_code text;
  level_code text;
  sessions_last_30d integer := 0;
  days_since_last_workout integer;
  memory_text text := '';
begin
  if requester is null then
    return;
  end if;

  select
    r.code,
    public.normalize_news_goal(mp.goal),
    public.normalize_news_level(mp.experience_level)
  into role_code, goal_code, level_code
  from public.profiles profile_row
  left join public.roles r on r.id = profile_row.role_id
  left join public.member_profiles mp on mp.user_id = profile_row.user_id
  where profile_row.user_id = requester;

  delete from public.user_news_interests
  where user_id = requester
    and source in (
      'onboarding',
      'inferred_from_activity',
      'inferred_from_ai_memory'
    );

  if coalesce(role_code, '') <> 'member' then
    return;
  end if;

  case goal_code
    when 'muscle_gain' then
      perform public.upsert_user_news_interest(requester, 'muscle_gain', 0.95, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'strength_training', 0.75, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'nutrition_basics', 0.45, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.35, 'onboarding');
    when 'fat_loss' then
      perform public.upsert_user_news_interest(requester, 'fat_loss', 0.95, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'nutrition_basics', 0.75, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.60, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'general_wellness', 0.35, 'onboarding');
    when 'endurance' then
      perform public.upsert_user_news_interest(requester, 'endurance', 0.95, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'heart_health', 0.60, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'hydration', 0.45, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.40, 'onboarding');
    when 'mobility' then
      perform public.upsert_user_news_interest(requester, 'mobility', 0.95, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.70, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'injury_prevention', 0.65, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'general_wellness', 0.30, 'onboarding');
    when 'sports_performance' then
      perform public.upsert_user_news_interest(requester, 'endurance', 0.60, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'strength_training', 0.60, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.50, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'injury_prevention', 0.45, 'onboarding');
    when 'general_fitness' then
      perform public.upsert_user_news_interest(requester, 'general_wellness', 0.70, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'strength_training', 0.45, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'mobility', 0.40, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.50, 'onboarding');
  end case;

  case level_code
    when 'beginner' then
      perform public.upsert_user_news_interest(requester, 'beginner_training', 0.85, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'injury_prevention', 0.50, 'onboarding');
    when 'intermediate' then
      perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.30, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.25, 'onboarding');
    when 'advanced' then
      perform public.upsert_user_news_interest(requester, 'recovery', 0.45, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'hydration', 0.30, 'onboarding');
  end case;

  select count(*)
  into sessions_last_30d
  from public.workout_sessions
  where member_id = requester
    and performed_at >= timezone('utc', now()) - interval '30 days';

  select (current_date - max(performed_at::date))::integer
  into days_since_last_workout
  from public.workout_sessions
  where member_id = requester;

  if coalesce(sessions_last_30d, 0) = 0 then
    perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.75, 'inferred_from_activity');
    perform public.upsert_user_news_interest(requester, 'beginner_training', 0.35, 'inferred_from_activity');
  elsif sessions_last_30d between 1 and 5 then
    perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.45, 'inferred_from_activity');
    perform public.upsert_user_news_interest(requester, 'recovery', 0.25, 'inferred_from_activity');
  else
    perform public.upsert_user_news_interest(requester, 'recovery', 0.55, 'inferred_from_activity');
    perform public.upsert_user_news_interest(requester, 'hydration', 0.40, 'inferred_from_activity');
    perform public.upsert_user_news_interest(requester, 'sleep', 0.35, 'inferred_from_activity');
  end if;

  if coalesce(days_since_last_workout, 0) >= 10 then
    perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.65, 'inferred_from_activity');
  end if;

  select lower(
           coalesce(
             string_agg(memory_key || ' ' || coalesce(memory_value_json::text, ''), ' ' order by updated_at desc),
             ''
           )
         )
  into memory_text
  from public.ai_user_memories
  where user_id = requester;

  if memory_text like '%sleep%' then
    perform public.upsert_user_news_interest(requester, 'sleep', 0.50, 'inferred_from_ai_memory');
  end if;

  if memory_text like '%hydrat%' then
    perform public.upsert_user_news_interest(requester, 'hydration', 0.45, 'inferred_from_ai_memory');
  end if;

  if memory_text like '%recover%' then
    perform public.upsert_user_news_interest(requester, 'recovery', 0.55, 'inferred_from_ai_memory');
  end if;

  if memory_text like '%injur%'
     or memory_text like '%pain%'
     or memory_text like '%knee%'
     or memory_text like '%back%' then
    perform public.upsert_user_news_interest(requester, 'injury_prevention', 0.60, 'inferred_from_ai_memory');
    perform public.upsert_user_news_interest(requester, 'mobility', 0.40, 'inferred_from_ai_memory');
  end if;

  if memory_text like '%nutrition%'
     or memory_text like '%protein%'
     or memory_text like '%meal%' then
    perform public.upsert_user_news_interest(requester, 'nutrition_basics', 0.55, 'inferred_from_ai_memory');
  end if;
end;
$$;

create or replace function public.track_news_interaction(
  p_article_id uuid,
  p_interaction_type text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  interaction_id uuid;
  topic_row record;
  applied_delta numeric := 0;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if lower(trim(coalesce(p_interaction_type, ''))) not in (
    'impression',
    'click',
    'open',
    'save',
    'dismiss',
    'share',
    'mark_not_interested'
  ) then
    raise exception 'Unsupported interaction type.';
  end if;

  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    raise exception 'Interaction metadata must be a JSON object.';
  end if;

  if not exists (
    select 1
    from public.news_articles article_row
    join public.news_sources source_row on source_row.id = article_row.source_id
    where article_row.id = p_article_id
      and article_row.is_active = true
      and article_row.safety_level <> 'restricted'
      and source_row.is_active = true
  ) then
    raise exception 'Article not found.';
  end if;

  insert into public.news_article_interactions (
    user_id,
    article_id,
    interaction_type,
    metadata
  )
  values (
    requester,
    p_article_id,
    lower(trim(p_interaction_type)),
    p_metadata
  )
  returning id into interaction_id;

  applied_delta := case lower(trim(p_interaction_type))
    when 'save' then 0.18
    when 'share' then 0.15
    when 'open' then 0.12
    when 'click' then 0.10
    when 'impression' then 0.02
    when 'dismiss' then -0.15
    when 'mark_not_interested' then -0.30
    else 0
  end;

  if applied_delta <> 0 then
    for topic_row in
      select topic_code, score
      from public.news_article_topics
      where article_id = p_article_id
    loop
      perform public.bump_user_news_interest(
        requester,
        topic_row.topic_code,
        applied_delta * greatest(topic_row.score, 0.15),
        'inferred_from_behavior'
      );
    end loop;
  end if;

  return interaction_id;
end;
$$;

create or replace function public.save_news_article(p_article_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if exists (
    select 1
    from public.news_article_bookmarks
    where user_id = requester
      and article_id = p_article_id
  ) then
    return false;
  end if;

  insert into public.news_article_bookmarks (user_id, article_id)
  values (requester, p_article_id);

  perform public.track_news_interaction(
    p_article_id,
    'save',
    '{"origin":"bookmark"}'::jsonb
  );

  return true;
end;
$$;

create or replace function public.dismiss_news_article(p_article_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.track_news_interaction(
    p_article_id,
    'dismiss',
    '{"origin":"feed"}'::jsonb
  );
  return true;
end;
$$;

create or replace function public.list_news_article_topics(p_article_id uuid)
returns table (
  topic_code text,
  score numeric
)
language sql
security definer
set search_path = public
as $$
  select
    topic_code,
    score
  from public.news_article_topics
  where article_id = p_article_id
  order by score desc, topic_code asc
$$;

create or replace function public.list_saved_news_articles()
returns table (
  article_id uuid,
  source_id uuid,
  source_name text,
  source_base_url text,
  canonical_url text,
  title text,
  summary text,
  image_url text,
  published_at timestamptz,
  language text,
  category text,
  safety_level text,
  evidence_level text,
  trust_score numeric,
  quality_score numeric,
  topic_codes text[],
  is_saved boolean,
  saved_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    article_row.id as article_id,
    article_row.source_id,
    source_row.name as source_name,
    source_row.base_url as source_base_url,
    article_row.canonical_url,
    article_row.title,
    article_row.summary,
    article_row.image_url,
    article_row.published_at,
    article_row.language,
    article_row.category,
    article_row.safety_level,
    article_row.evidence_level,
    article_row.trust_score,
    article_row.quality_score,
    coalesce(topic_rollup.topic_codes, '{}'::text[]) as topic_codes,
    true as is_saved,
    bookmark_row.created_at as saved_at
  from public.news_article_bookmarks bookmark_row
  join public.news_articles article_row on article_row.id = bookmark_row.article_id
  join public.news_sources source_row on source_row.id = article_row.source_id
  left join (
    select
      article_id,
      array_agg(topic_code order by score desc, topic_code asc) as topic_codes
    from public.news_article_topics
    group by article_id
  ) topic_rollup on topic_rollup.article_id = article_row.id
  where bookmark_row.user_id = auth.uid()
    and article_row.is_active = true
    and article_row.safety_level <> 'restricted'
    and source_row.is_active = true
  order by bookmark_row.created_at desc
$$;

create or replace function public.list_personalized_news(
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  article_id uuid,
  source_id uuid,
  source_name text,
  source_base_url text,
  canonical_url text,
  title text,
  summary text,
  image_url text,
  published_at timestamptz,
  language text,
  category text,
  safety_level text,
  evidence_level text,
  trust_score numeric,
  quality_score numeric,
  topic_codes text[],
  relevance_reason text,
  relevance_tags text[],
  ranking_score numeric,
  is_saved boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  role_code text := 'member';
  goal_code text;
  level_code text;
  preferred_language text := 'english';
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  select
    coalesce(role_row.code, 'member'),
    public.normalize_news_goal(member_row.goal),
    public.normalize_news_level(member_row.experience_level),
    coalesce(preferences_row.language, 'english')
  into role_code, goal_code, level_code, preferred_language
  from public.profiles profile_row
  left join public.roles role_row on role_row.id = profile_row.role_id
  left join public.member_profiles member_row on member_row.user_id = profile_row.user_id
  left join public.user_preferences preferences_row on preferences_row.user_id = profile_row.user_id
  where profile_row.user_id = requester;

  perform public.sync_member_news_interests(requester);

  return query
  with aggregated_interests as (
    select
      topic_code,
      max(score) as score
    from public.user_news_interests
    where user_id = requester
    group by topic_code
  ),
  interaction_topic_rollup as (
    select
      topic_row.topic_code,
      count(*) filter (
        where interaction_row.interaction_type in ('open', 'click', 'save', 'share')
      )::numeric as positive_events,
      count(*) filter (
        where interaction_row.interaction_type in ('dismiss', 'mark_not_interested')
      )::numeric as negative_events
    from public.news_article_interactions interaction_row
    join public.news_article_topics topic_row on topic_row.article_id = interaction_row.article_id
    where interaction_row.user_id = requester
      and interaction_row.created_at >= timezone('utc', now()) - interval '120 days'
    group by topic_row.topic_code
  ),
  article_topics as (
    select
      topic_row.article_id,
      array_agg(topic_row.topic_code order by topic_row.score desc, topic_row.topic_code asc) as topic_codes,
      coalesce(sum(topic_row.score * greatest(coalesce(interest_row.score, 0), 0)), 0) as interest_alignment,
      coalesce(sum(topic_row.score * coalesce(interaction_row.positive_events, 0)), 0) as positive_alignment,
      coalesce(sum(topic_row.score * coalesce(interaction_row.negative_events, 0)), 0) as negative_alignment
    from public.news_article_topics topic_row
    left join aggregated_interests interest_row on interest_row.topic_code = topic_row.topic_code
    left join interaction_topic_rollup interaction_row on interaction_row.topic_code = topic_row.topic_code
    group by topic_row.article_id
  ),
  article_user_state as (
    select
      interaction_row.article_id,
      bool_or(interaction_row.interaction_type = 'dismiss') as dismissed,
      bool_or(interaction_row.interaction_type = 'mark_not_interested') as marked_not_interested,
      max(interaction_row.created_at) filter (
        where interaction_row.interaction_type in ('open', 'click')
      ) as last_opened_at
    from public.news_article_interactions interaction_row
    where interaction_row.user_id = requester
    group by interaction_row.article_id
  ),
  candidate_articles as (
    select
      article_row.id as article_id,
      article_row.source_id,
      source_row.name as source_name,
      source_row.base_url as source_base_url,
      article_row.canonical_url,
      article_row.title,
      article_row.summary,
      article_row.image_url,
      article_row.published_at,
      article_row.language,
      article_row.category,
      article_row.safety_level,
      article_row.evidence_level,
      article_row.trust_score,
      article_row.quality_score,
      article_row.target_goals,
      article_row.target_levels,
      coalesce(topic_rollup.topic_codes, '{}'::text[]) as topic_codes,
      coalesce(topic_rollup.interest_alignment, 0) as interest_alignment,
      coalesce(topic_rollup.positive_alignment, 0) as positive_alignment,
      coalesce(topic_rollup.negative_alignment, 0) as negative_alignment,
      coalesce(article_state.dismissed, false) as dismissed,
      coalesce(article_state.marked_not_interested, false) as marked_not_interested,
      article_state.last_opened_at,
      exists (
        select 1
        from public.news_article_bookmarks bookmark_row
        where bookmark_row.user_id = requester
          and bookmark_row.article_id = article_row.id
      ) as is_saved,
      (
        case
          when public.news_target_matches(article_row.target_roles, role_code) then 20
          else -1000
        end
        + case
            when goal_code is not null
                 and public.news_target_matches(article_row.target_goals, goal_code) then 18
            when goal_code is null then 4
            when jsonb_array_length(public.news_safe_jsonb_array(article_row.target_goals)) = 0 then 6
            else 0
          end
        + case
            when level_code is not null
                 and public.news_target_matches(article_row.target_levels, level_code) then 10
            when jsonb_array_length(public.news_safe_jsonb_array(article_row.target_levels)) = 0 then 4
            else 0
          end
        + least(coalesce(article_row.trust_score, source_row.trust_score), 100) * 0.18
        + least(coalesce(article_row.quality_score, 0), 100) * 0.12
        + greatest(
            0::numeric,
            21::numeric - extract(epoch from (timezone('utc', now()) - article_row.published_at)) / 86400
          ) * 1.10
        + least(coalesce(topic_rollup.interest_alignment, 0), 4) * 25
        + least(coalesce(topic_rollup.positive_alignment, 0), 4) * 4
        - least(coalesce(topic_rollup.negative_alignment, 0), 4) * 6
        + case
            when lower(coalesce(article_row.language, 'english')) = lower(preferred_language) then 6
            when lower(coalesce(article_row.language, 'english')) = 'english' then 3
            else 0
          end
        + case when article_row.is_featured then 4 else 0 end
        - case
            when article_state.last_opened_at is not null
                 and article_state.last_opened_at >= timezone('utc', now()) - interval '14 days' then 10
            else 0
          end
      )::numeric(10,3) as ranking_score
    from public.news_articles article_row
    join public.news_sources source_row on source_row.id = article_row.source_id
    left join article_topics topic_rollup on topic_rollup.article_id = article_row.id
    left join article_user_state article_state on article_state.article_id = article_row.id
    where article_row.is_active = true
      and article_row.safety_level <> 'restricted'
      and source_row.is_active = true
      and public.news_target_matches(article_row.target_roles, role_code)
      and coalesce(article_row.trust_score, source_row.trust_score) >= 55
      and coalesce(article_row.quality_score, 0) >= 35
  )
  select
    candidate_row.article_id,
    candidate_row.source_id,
    candidate_row.source_name,
    candidate_row.source_base_url,
    candidate_row.canonical_url,
    candidate_row.title,
    candidate_row.summary,
    candidate_row.image_url,
    candidate_row.published_at,
    candidate_row.language,
    candidate_row.category,
    candidate_row.safety_level,
    candidate_row.evidence_level,
    candidate_row.trust_score,
    candidate_row.quality_score,
    candidate_row.topic_codes,
    coalesce(
      (
        array_remove(
          array[
            case
              when goal_code is not null
                   and public.news_target_matches(candidate_row.target_goals, goal_code) then 'Matches your goal'
            end,
            case when candidate_row.interest_alignment > 0.25 then 'Aligned with your interests' end,
            case when candidate_row.positive_alignment > 0 then 'Based on what you open' end,
            case when candidate_row.quality_score >= 75 then 'Trusted, high-quality source' end,
            case
              when candidate_row.published_at >= timezone('utc', now()) - interval '7 days' then 'Fresh this week'
            end,
            case
              when level_code is not null
                   and public.news_target_matches(candidate_row.target_levels, level_code) then 'Fits your training level'
            end
          ],
          null
        )
      )[1],
      'Recommended for you'
    ) as relevance_reason,
    coalesce(
      array_remove(
        array[
          case
            when goal_code is not null
                 and public.news_target_matches(candidate_row.target_goals, goal_code) then 'goal match'
          end,
          case when candidate_row.interest_alignment > 0.25 then 'interest match' end,
          case when candidate_row.positive_alignment > 0 then 'similar to past reads' end,
          case when candidate_row.quality_score >= 75 then 'trusted source' end,
          case
            when candidate_row.published_at >= timezone('utc', now()) - interval '7 days' then 'recent'
          end,
          case
            when level_code is not null
                 and public.news_target_matches(candidate_row.target_levels, level_code) then 'level fit'
          end
        ],
        null
      ),
      '{}'::text[]
    ) as relevance_tags,
    candidate_row.ranking_score,
    candidate_row.is_saved
  from candidate_articles candidate_row
  where candidate_row.marked_not_interested = false
    and candidate_row.dismissed = false
  order by candidate_row.ranking_score desc, candidate_row.published_at desc
  limit greatest(coalesce(p_limit, 20), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.news_safe_jsonb_array(jsonb) from public;
revoke all on function public.news_target_matches(jsonb, text) from public;
revoke all on function public.normalize_news_goal(text) from public;
revoke all on function public.normalize_news_level(text) from public;
revoke all on function public.upsert_user_news_interest(uuid, text, numeric, text) from public;
revoke all on function public.bump_user_news_interest(uuid, text, numeric, text) from public;
revoke all on function public.sync_member_news_interests(uuid) from public;

revoke all on function public.track_news_interaction(uuid, text, jsonb) from public;
grant execute on function public.track_news_interaction(uuid, text, jsonb) to authenticated;

revoke all on function public.save_news_article(uuid) from public;
grant execute on function public.save_news_article(uuid) to authenticated;

revoke all on function public.dismiss_news_article(uuid) from public;
grant execute on function public.dismiss_news_article(uuid) to authenticated;

revoke all on function public.list_news_article_topics(uuid) from public;
grant execute on function public.list_news_article_topics(uuid) to authenticated;

revoke all on function public.list_saved_news_articles() from public;
grant execute on function public.list_saved_news_articles() to authenticated;

revoke all on function public.list_personalized_news(integer, integer) from public;
grant execute on function public.list_personalized_news(integer, integer) to authenticated;

-- Appended from 20260316000013_news_sync_scheduler.sql
-- Scheduled news ingestion infrastructure
-- Date: 2026-03-16

create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists vault;

create schema if not exists private;
revoke all on schema private from public;

create or replace function private.upsert_vault_secret(
  p_name text,
  p_secret text,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = private, vault, public
as $$
declare
  existing_id uuid;
begin
  if p_name is null or btrim(p_name) = '' then
    raise exception 'Vault secret name is required.';
  end if;

  if p_secret is null or btrim(p_secret) = '' then
    raise exception 'Vault secret value is required.';
  end if;

  select id
  into existing_id
  from vault.decrypted_secrets
  where name = p_name
  limit 1;

  if existing_id is null then
    select id
    into existing_id
    from vault.create_secret(p_secret, p_name, p_description);
  else
    perform vault.update_secret(existing_id, p_secret, p_name, p_description);
  end if;

  return existing_id;
end;
$$;

create or replace function private.unschedule_news_sync()
returns void
language plpgsql
security definer
set search_path = private, cron, public
as $$
declare
  existing_job_id bigint;
begin
  select jobid
  into existing_job_id
  from cron.job
  where jobname = 'sync-news-feeds-every-4-hours'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;
end;
$$;

create or replace function private.schedule_news_sync(
  p_project_url text,
  p_sync_secret text,
  p_cron text default '17 */4 * * *'
)
returns bigint
language plpgsql
security definer
set search_path = private, public, vault, cron, net
as $$
declare
  normalized_url text;
  created_job_id bigint;
begin
  normalized_url := regexp_replace(coalesce(btrim(p_project_url), ''), '/+$', '');

  if normalized_url = '' or normalized_url !~ '^https://[A-Za-z0-9.-]+$' then
    raise exception 'Project URL must be a valid https origin.';
  end if;

  if p_sync_secret is null or length(btrim(p_sync_secret)) < 16 then
    raise exception 'Sync secret must be present and sufficiently long.';
  end if;

  if p_cron is null or btrim(p_cron) = '' then
    raise exception 'Cron expression is required.';
  end if;

  perform private.upsert_vault_secret(
    'news_sync_project_url',
    normalized_url,
    'GymUnity project URL used by the scheduled sync-news-feeds cron job.'
  );

  perform private.upsert_vault_secret(
    'news_sync_secret',
    btrim(p_sync_secret),
    'GymUnity shared secret for scheduled sync-news-feeds requests.'
  );

  perform private.unschedule_news_sync();

  select cron.schedule(
    'sync-news-feeds-every-4-hours',
    p_cron,
    $job$
    select
      net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'news_sync_project_url'
        ) || '/functions/v1/sync-news-feeds',
        headers := jsonb_build_object(
          'Content-Type',
          'application/json',
          'x-news-sync-secret',
          (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'news_sync_secret'
          )
        ),
        body := jsonb_build_object('trigger', 'pg_cron')
      ) as request_id;
    $job$
  )
  into created_job_id;

  return created_job_id;
end;
$$;

revoke all on function private.upsert_vault_secret(text, text, text) from public;
revoke all on function private.unschedule_news_sync() from public;
revoke all on function private.schedule_news_sync(text, text, text) from public;

comment on function private.schedule_news_sync(text, text, text) is
  'Configures the recurring sync-news-feeds cron job after NEWS_SYNC_SECRET is set in Edge Function secrets.';
