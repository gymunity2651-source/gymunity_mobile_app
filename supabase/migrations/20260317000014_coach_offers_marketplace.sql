-- Coach offers marketplace, structured intake, and starter-plan activation
-- Date: 2026-03-17

alter table public.coach_packages
  add column if not exists subtitle text not null default '',
  add column if not exists outcome_summary text not null default '',
  add column if not exists ideal_for text[] not null default '{}',
  add column if not exists duration_weeks integer not null default 4 check (duration_weeks >= 1),
  add column if not exists sessions_per_week integer not null default 3 check (sessions_per_week between 1 and 7),
  add column if not exists difficulty_level text not null default 'beginner' check (
    difficulty_level in ('beginner', 'intermediate', 'advanced')
  ),
  add column if not exists equipment_tags text[] not null default '{}',
  add column if not exists included_features text[] not null default '{}',
  add column if not exists check_in_frequency text not null default '',
  add column if not exists support_summary text not null default '',
  add column if not exists faq_json jsonb not null default '[]'::jsonb,
  add column if not exists visibility_status text not null default 'draft' check (
    visibility_status in ('draft', 'published', 'archived')
  ),
  add column if not exists plan_preview_json jsonb not null default '{}'::jsonb;

update public.coach_packages
set visibility_status = case
  when is_active = true then 'published'
  else 'archived'
end
where visibility_status not in ('draft', 'published', 'archived')
   or visibility_status is null
   or visibility_status = 'draft';

alter table public.subscriptions
  add column if not exists intake_snapshot_json jsonb not null default '{}'::jsonb;

create unique index if not exists idx_subscriptions_member_package_open
  on public.subscriptions(member_id, package_id)
  where package_id is not null and status in ('pending_payment', 'active');

create or replace function public.list_coach_directory(
  specialty_filter text default null,
  limit_count integer default 20
)
returns table (
  user_id uuid,
  full_name text,
  specialties text[],
  hourly_rate numeric,
  pricing_currency text,
  rating_avg numeric,
  rating_count integer,
  is_verified boolean,
  starting_package_price numeric,
  starting_package_billing_cycle text,
  active_package_count integer
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
    cp.pricing_currency,
    cp.rating_avg,
    cp.rating_count,
    cp.is_verified,
    offer.starting_package_price,
    offer.starting_package_billing_cycle,
    coalesce(offer.active_package_count, 0)::integer as active_package_count
  from public.coach_profiles cp
  join public.profiles p on p.user_id = cp.user_id
  left join lateral (
    select
      min(pkg.price) as starting_package_price,
      (
        select pkg2.billing_cycle
        from public.coach_packages pkg2
        where pkg2.coach_id = cp.user_id
          and pkg2.visibility_status = 'published'
        order by pkg2.price asc, pkg2.created_at asc
        limit 1
      ) as starting_package_billing_cycle,
      count(*) filter (where pkg.visibility_status = 'published') as active_package_count
    from public.coach_packages pkg
    where pkg.coach_id = cp.user_id
      and pkg.visibility_status = 'published'
  ) offer on true
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

create or replace function public.list_coach_public_packages(target_coach_id uuid)
returns table (
  id uuid,
  coach_id uuid,
  title text,
  description text,
  billing_cycle text,
  price numeric,
  subtitle text,
  outcome_summary text,
  ideal_for text[],
  duration_weeks integer,
  sessions_per_week integer,
  difficulty_level text,
  equipment_tags text[],
  included_features text[],
  check_in_frequency text,
  support_summary text,
  faq_json jsonb,
  plan_preview_json jsonb,
  visibility_status text,
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
    cp.subtitle,
    cp.outcome_summary,
    cp.ideal_for,
    cp.duration_weeks,
    cp.sessions_per_week,
    cp.difficulty_level,
    cp.equipment_tags,
    cp.included_features,
    cp.check_in_frequency,
    cp.support_summary,
    cp.faq_json,
    cp.plan_preview_json,
    cp.visibility_status,
    cp.is_active,
    cp.created_at
  from public.coach_packages cp
  where cp.coach_id = target_coach_id
    and cp.visibility_status = 'published'
  order by cp.price asc, cp.created_at asc;
$$;

drop function if exists public.request_coach_subscription(uuid, text);

create or replace function public.request_coach_subscription(
  target_package_id uuid,
  input_member_note text default null,
  input_intake_snapshot jsonb default '{}'::jsonb
)
returns table (
  id uuid,
  member_id uuid,
  member_name text,
  coach_id uuid,
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
  created_at timestamptz,
  member_note text,
  intake_snapshot_json jsonb
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
    and visibility_status = 'published';

  if package_record.id is null then
    raise exception 'Coach package not found.';
  end if;

  if exists (
    select 1
    from public.subscriptions s
    where s.member_id = requester
      and s.package_id = package_record.id
      and s.status in ('pending_payment', 'active')
  ) then
    raise exception 'You already have an open request for this coaching offer.';
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
    member_note,
    intake_snapshot_json
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
    input_member_note,
    coalesce(input_intake_snapshot, '{}'::jsonb)
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
    'A member requested the coaching offer "' || package_record.title || '".',
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
    'Your coaching request is pending manual payment confirmation.',
    jsonb_build_object(
      'subscription_id', created_subscription.id,
      'package_id', package_record.id,
      'status', 'pending_payment'
    )
  );

  return query
  select
    created_subscription.id,
    created_subscription.member_id,
    coalesce(nullif(p.full_name, ''), 'Member') as member_name,
    created_subscription.coach_id,
    created_subscription.package_id,
    coalesce(package_record.title, created_subscription.plan_name) as package_title,
    created_subscription.plan_name,
    created_subscription.billing_cycle,
    created_subscription.amount,
    created_subscription.status,
    created_subscription.payment_method,
    created_subscription.starts_at,
    created_subscription.ends_at,
    created_subscription.activated_at,
    created_subscription.cancelled_at,
    created_subscription.created_at,
    created_subscription.member_note,
    created_subscription.intake_snapshot_json
  from public.profiles p
  where p.user_id = created_subscription.member_id;
end;
$$;

create or replace function public.list_coach_subscription_requests()
returns table (
  id uuid,
  member_id uuid,
  member_name text,
  coach_id uuid,
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
  created_at timestamptz,
  member_note text,
  intake_snapshot_json jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.id,
    s.member_id,
    coalesce(nullif(p.full_name, ''), 'Deleted member') as member_name,
    s.coach_id,
    s.package_id,
    coalesce(pkg.title, nullif(s.plan_name, ''), 'Coaching Offer') as package_title,
    s.plan_name,
    s.billing_cycle,
    s.amount,
    s.status,
    s.payment_method,
    s.starts_at,
    s.ends_at,
    s.activated_at,
    s.cancelled_at,
    s.created_at,
    s.member_note,
    s.intake_snapshot_json
  from public.subscriptions s
  left join public.profiles p on p.user_id = s.member_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  where s.coach_id = auth.uid()
  order by
    case s.status
      when 'pending_payment' then 0
      when 'active' then 1
      when 'completed' then 2
      else 3
    end,
    s.created_at desc;
$$;

create or replace function public.activate_coach_subscription_with_starter_plan(
  target_subscription_id uuid,
  input_start_date date default current_date,
  input_default_reminder_time time default null,
  note text default null
)
returns table (
  id uuid,
  member_id uuid,
  member_name text,
  coach_id uuid,
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
  created_at timestamptz,
  member_note text,
  intake_snapshot_json jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  existing_subscription public.subscriptions%rowtype;
  package_record public.coach_packages%rowtype;
  created_plan_id uuid;
  computed_start_date date := coalesce(input_start_date, current_date);
  duration_weeks integer;
  current_week jsonb;
  current_day jsonb;
  created_day_id uuid;
  computed_day_index integer;
  computed_week_number integer;
  computed_day_number integer;
  computed_date date;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'coach' then
    raise exception 'Only coaches can activate subscriptions.';
  end if;

  select *
  into existing_subscription
  from public.subscriptions
  where id = target_subscription_id
    and coach_id = requester;

  if existing_subscription.id is null then
    raise exception 'Subscription not found.';
  end if;

  if existing_subscription.status <> 'pending_payment' then
    raise exception 'Only pending coaching requests can be activated.';
  end if;

  select *
  into package_record
  from public.coach_packages
  where id = existing_subscription.package_id
    and coach_id = requester;

  if package_record.id is null then
    raise exception 'Coaching offer not found.';
  end if;

  if coalesce(package_record.plan_preview_json, '{}'::jsonb) = '{}'::jsonb then
    raise exception 'This coaching offer does not have a starter plan preview.';
  end if;

  update public.workout_plans
  set status = 'archived',
      completed_at = coalesce(completed_at, timezone('utc', now()))
  where member_id = existing_subscription.member_id
    and coach_id = requester
    and source = 'coach'
    and status = 'active';

  duration_weeks := greatest(
    coalesce((package_record.plan_preview_json ->> 'duration_weeks')::integer, package_record.duration_weeks, 1),
    1
  );

  insert into public.workout_plans (
    member_id,
    coach_id,
    source,
    title,
    plan_json,
    status,
    start_date,
    end_date,
    assigned_at,
    plan_version,
    default_reminder_time
  )
  values (
    existing_subscription.member_id,
    requester,
    'coach',
    coalesce(nullif(package_record.title, ''), existing_subscription.plan_name),
    package_record.plan_preview_json,
    'active',
    computed_start_date,
    computed_start_date + ((duration_weeks * 7) - 1),
    timezone('utc', now()),
    coalesce((
      select max(plan_version) + 1
      from public.workout_plans
      where member_id = existing_subscription.member_id
        and source = 'coach'
    ), 1),
    input_default_reminder_time
  )
  returning id into created_plan_id;

  for current_week in
    select value
    from jsonb_array_elements(coalesce(package_record.plan_preview_json -> 'weekly_structure', '[]'::jsonb))
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
        existing_subscription.member_id,
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
        existing_subscription.member_id,
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

  update public.subscriptions
  set status = 'active',
      starts_at = coalesce(starts_at, computed_start_date::timestamptz),
      activated_at = coalesce(activated_at, timezone('utc', now())),
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
    'Coaching subscription activated',
    coalesce(note, 'Your coaching subscription is now active and your starter plan has been assigned.'),
    jsonb_build_object(
      'subscription_id', existing_subscription.id,
      'workout_plan_id', created_plan_id,
      'status', 'active'
    )
  );

  return query
  select
    s.id,
    s.member_id,
    coalesce(nullif(p.full_name, ''), 'Member') as member_name,
    s.coach_id,
    s.package_id,
    coalesce(pkg.title, nullif(s.plan_name, ''), 'Coaching Offer') as package_title,
    s.plan_name,
    s.billing_cycle,
    s.amount,
    s.status,
    s.payment_method,
    s.starts_at,
    s.ends_at,
    s.activated_at,
    s.cancelled_at,
    s.created_at,
    s.member_note,
    s.intake_snapshot_json
  from public.subscriptions s
  join public.profiles p on p.user_id = s.member_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  where s.id = existing_subscription.id;
end;
$$;

grant execute on function public.request_coach_subscription(uuid, text, jsonb) to authenticated;
grant execute on function public.list_coach_subscription_requests() to authenticated;
grant execute on function public.activate_coach_subscription_with_starter_plan(uuid, date, time, text) to authenticated;
