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
