-- Coach program templates, exercise library, habit assignments, and task extensions
-- Date: 2026-04-21

create table if not exists public.coach_exercise_library (
  id uuid primary key default gen_random_uuid(),
  owner_coach_id uuid references public.coach_profiles(user_id) on delete cascade,
  title text not null,
  category text not null default 'strength',
  primary_muscles text[] not null default '{}',
  equipment_tags text[] not null default '{}',
  difficulty_level text not null default 'beginner' check (
    difficulty_level in ('beginner', 'intermediate', 'advanced')
  ),
  instructions text not null default '',
  video_url text,
  substitution_options_json jsonb not null default '[]'::jsonb,
  progression_rule text not null default '',
  regression_rule text not null default '',
  rest_guidance_seconds integer check (rest_guidance_seconds is null or rest_guidance_seconds >= 0),
  coaching_cues_json jsonb not null default '[]'::jsonb,
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (is_system = true or owner_coach_id is not null)
);

create table if not exists public.coach_program_templates (
  id uuid primary key default gen_random_uuid(),
  owner_coach_id uuid references public.coach_profiles(user_id) on delete cascade,
  title text not null,
  goal_type text not null check (
    goal_type in ('fat_loss', 'muscle_gain', 'beginner', 'general_fitness', 'home_training', 'womens_coaching', 'ramadan_lifestyle', 'custom')
  ),
  description text not null default '',
  duration_weeks integer not null default 4 check (duration_weeks between 1 and 52),
  difficulty_level text not null default 'beginner' check (
    difficulty_level in ('beginner', 'intermediate', 'advanced')
  ),
  location_mode text not null default 'online' check (
    location_mode in ('online', 'in_person', 'hybrid')
  ),
  weekly_structure_json jsonb not null default '[]'::jsonb,
  resources_json jsonb not null default '[]'::jsonb,
  tags text[] not null default '{}',
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (is_system = true or owner_coach_id is not null)
);

alter table public.workout_plan_tasks
  add column if not exists exercise_id uuid references public.coach_exercise_library(id) on delete set null,
  add column if not exists rest_seconds integer check (rest_seconds is null or rest_seconds >= 0),
  add column if not exists substitution_options_json jsonb not null default '[]'::jsonb,
  add column if not exists progression_rule text not null default '',
  add column if not exists coach_cues_json jsonb not null default '[]'::jsonb,
  add column if not exists block_label text;

create table if not exists public.coach_habit_templates (
  id uuid primary key default gen_random_uuid(),
  owner_coach_id uuid references public.coach_profiles(user_id) on delete cascade,
  title text not null,
  habit_type text not null check (
    habit_type in ('water', 'sleep', 'steps', 'recovery', 'protein', 'mobility', 'mindset', 'custom')
  ),
  description text not null default '',
  target_value numeric(10,2),
  target_unit text,
  frequency text not null default 'daily' check (frequency in ('daily', 'weekly', 'custom')),
  tags text[] not null default '{}',
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (is_system = true or owner_coach_id is not null)
);

create table if not exists public.member_habit_assignments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  habit_template_id uuid references public.coach_habit_templates(id) on delete set null,
  title text not null,
  habit_type text not null default 'custom',
  description text not null default '',
  target_value numeric(10,2),
  target_unit text,
  frequency text not null default 'daily',
  status text not null default 'active' check (status in ('active', 'paused', 'completed', 'archived')),
  start_date date not null default current_date,
  end_date date,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (end_date is null or end_date >= start_date)
);

create table if not exists public.member_habit_logs (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.member_habit_assignments(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  log_date date not null default current_date,
  completion_status text not null check (completion_status in ('completed', 'partial', 'skipped')),
  value numeric(10,2),
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (assignment_id, log_date)
);

create index if not exists idx_coach_program_templates_owner_goal
  on public.coach_program_templates(owner_coach_id, goal_type, created_at desc);
create index if not exists idx_coach_exercises_owner_category
  on public.coach_exercise_library(owner_coach_id, category, created_at desc);
create index if not exists idx_habit_assignments_subscription
  on public.member_habit_assignments(subscription_id, status, created_at desc);
create index if not exists idx_habit_logs_member_date
  on public.member_habit_logs(member_id, log_date desc);

alter table public.coach_exercise_library enable row level security;
alter table public.coach_program_templates enable row level security;
alter table public.coach_habit_templates enable row level security;
alter table public.member_habit_assignments enable row level security;
alter table public.member_habit_logs enable row level security;

drop policy if exists coach_exercises_read_system_or_own on public.coach_exercise_library;
create policy coach_exercises_read_system_or_own
on public.coach_exercise_library for select
to authenticated
using (is_system = true or owner_coach_id = auth.uid());

drop policy if exists coach_exercises_manage_own on public.coach_exercise_library;
create policy coach_exercises_manage_own
on public.coach_exercise_library for all
to authenticated
using (owner_coach_id = auth.uid() and is_system = false)
with check (owner_coach_id = auth.uid() and is_system = false);

drop policy if exists coach_program_templates_read_system_or_own on public.coach_program_templates;
create policy coach_program_templates_read_system_or_own
on public.coach_program_templates for select
to authenticated
using (is_system = true or owner_coach_id = auth.uid());

drop policy if exists coach_program_templates_manage_own on public.coach_program_templates;
create policy coach_program_templates_manage_own
on public.coach_program_templates for all
to authenticated
using (owner_coach_id = auth.uid() and is_system = false)
with check (owner_coach_id = auth.uid() and is_system = false);

drop policy if exists coach_habit_templates_read_system_or_own on public.coach_habit_templates;
create policy coach_habit_templates_read_system_or_own
on public.coach_habit_templates for select
to authenticated
using (is_system = true or owner_coach_id = auth.uid());

drop policy if exists coach_habit_templates_manage_own on public.coach_habit_templates;
create policy coach_habit_templates_manage_own
on public.coach_habit_templates for all
to authenticated
using (owner_coach_id = auth.uid() and is_system = false)
with check (owner_coach_id = auth.uid() and is_system = false);

drop policy if exists habit_assignments_read_participants on public.member_habit_assignments;
create policy habit_assignments_read_participants
on public.member_habit_assignments for select
to authenticated
using (coach_id = auth.uid() or member_id = auth.uid());

drop policy if exists habit_assignments_manage_coach on public.member_habit_assignments;
create policy habit_assignments_manage_coach
on public.member_habit_assignments for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists habit_logs_read_participants on public.member_habit_logs;
create policy habit_logs_read_participants
on public.member_habit_logs for select
to authenticated
using (
  member_id = auth.uid()
  or exists (
    select 1
    from public.member_habit_assignments a
    where a.id = member_habit_logs.assignment_id
      and a.coach_id = auth.uid()
  )
);

drop policy if exists habit_logs_manage_member on public.member_habit_logs;
create policy habit_logs_manage_member
on public.member_habit_logs for all
to authenticated
using (member_id = auth.uid())
with check (member_id = auth.uid());

drop trigger if exists touch_coach_exercise_library_updated_at on public.coach_exercise_library;
create trigger touch_coach_exercise_library_updated_at
before update on public.coach_exercise_library
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_program_templates_updated_at on public.coach_program_templates;
create trigger touch_coach_program_templates_updated_at
before update on public.coach_program_templates
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_habit_templates_updated_at on public.coach_habit_templates;
create trigger touch_coach_habit_templates_updated_at
before update on public.coach_habit_templates
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_habit_assignments_updated_at on public.member_habit_assignments;
create trigger touch_member_habit_assignments_updated_at
before update on public.member_habit_assignments
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_habit_logs_updated_at on public.member_habit_logs;
create trigger touch_member_habit_logs_updated_at
before update on public.member_habit_logs
for each row execute function public.touch_updated_at();

insert into public.coach_exercise_library (
  title, category, primary_muscles, equipment_tags, difficulty_level,
  instructions, substitution_options_json, progression_rule, regression_rule,
  rest_guidance_seconds, coaching_cues_json, is_system
) values
  ('Goblet Squat', 'strength', '{quads,glutes,core}', '{dumbbell,kettlebell}', 'beginner', 'Hold one weight at chest height, sit between the hips, keep ribs stacked, then drive up through the full foot.', '[{"title":"Bodyweight squat"},{"title":"Leg press"}]'::jsonb, 'Add reps first, then load when all sets are smooth.', 'Reduce range or use box squat.', 90, '["Brace before descent","Knees track toes","Control the bottom"]'::jsonb, true),
  ('Incline Push-up', 'strength', '{chest,shoulders,triceps}', '{bench,bodyweight}', 'beginner', 'Place hands on an elevated surface, keep body long, lower under control, and press away.', '[{"title":"Wall push-up"},{"title":"Dumbbell bench press"}]'::jsonb, 'Lower the incline before adding load.', 'Increase incline or reduce reps.', 75, '["Long body line","Soft elbows at top","Control every rep"]'::jsonb, true),
  ('Zone 2 Walk', 'cardio', '{cardiorespiratory}', '{bodyweight}', 'beginner', 'Walk at a pace where talking is possible but breathing is elevated.', '[{"title":"Bike zone 2"},{"title":"Elliptical zone 2"}]'::jsonb, 'Increase time by 5 minutes each week.', 'Split into shorter bouts.', 0, '["Nasal breathing if possible","Keep pace sustainable"]'::jsonb, true)
on conflict do nothing;

insert into public.coach_habit_templates (
  title, habit_type, description, target_value, target_unit, frequency, tags, is_system
) values
  ('Daily water target', 'water', 'Hit the agreed hydration target for the day.', 2500, 'ml', 'daily', '{hydration,accountability}', true),
  ('Sleep window', 'sleep', 'Protect a consistent bedtime and wake time.', 7, 'hours', 'daily', '{recovery,sleep}', true),
  ('Step baseline', 'steps', 'Complete the daily step target without turning it into extra fatigue.', 8000, 'steps', 'daily', '{steps,fat_loss}', true),
  ('Recovery check', 'recovery', 'Log soreness, stress, and recovery quality.', null, null, 'daily', '{recovery,readiness}', true)
on conflict do nothing;

insert into public.coach_program_templates (
  title, goal_type, description, duration_weeks, difficulty_level, location_mode, tags, is_system, weekly_structure_json
) values
  (
    'Fat Loss Foundation',
    'fat_loss',
    'A balanced starter block with strength, zone 2, steps, hydration, and recovery habits.',
    4,
    'beginner',
    'hybrid',
    '{fat_loss,beginner,hybrid}',
    true,
    '[
      {"week_number":1,"days":[
        {"week_number":1,"day_number":1,"label":"Strength A","focus":"Full body strength","tasks":[{"type":"workout","title":"Full body strength A","instructions":"Squat, push, hinge, row, carry. Keep 2 reps in reserve.","sets":3,"reps":10,"rest_seconds":90,"block_label":"Strength"},{"type":"steps","title":"Step target","instructions":"Complete your agreed step baseline.","target_value":8000,"target_unit":"steps"}]},
        {"week_number":1,"day_number":2,"label":"Zone 2","focus":"Conditioning","tasks":[{"type":"cardio","title":"Zone 2 walk","instructions":"Sustainable pace, 30 minutes.","duration_minutes":30,"block_label":"Cardio"},{"type":"hydration","title":"Water target","instructions":"Hit your daily water target.","target_value":2500,"target_unit":"ml"}]},
        {"week_number":1,"day_number":3,"label":"Strength B","focus":"Full body strength","tasks":[{"type":"workout","title":"Full body strength B","instructions":"Lunge, press, pull, hip thrust, core. Smooth reps only.","sets":3,"reps":10,"rest_seconds":90,"block_label":"Strength"}]}
      ]}
    ]'::jsonb
  ),
  (
    'Muscle Gain Base',
    'muscle_gain',
    'A progressive hypertrophy block with repeatable lifts and recovery targets.',
    6,
    'intermediate',
    'hybrid',
    '{muscle_gain,hypertrophy}',
    true,
    '[
      {"week_number":1,"days":[
        {"week_number":1,"day_number":1,"label":"Upper Push/Pull","focus":"Upper hypertrophy","tasks":[{"type":"workout","title":"Upper hypertrophy","instructions":"Press, row, incline press, pulldown, arms. Add reps week to week.","sets":4,"reps":8,"rest_seconds":120,"block_label":"Hypertrophy"}]},
        {"week_number":1,"day_number":2,"label":"Lower Strength","focus":"Lower body","tasks":[{"type":"workout","title":"Lower strength","instructions":"Squat pattern, hinge, split squat, calves, core.","sets":4,"reps":8,"rest_seconds":150,"block_label":"Strength"}]},
        {"week_number":1,"day_number":4,"label":"Upper Volume","focus":"Upper volume","tasks":[{"type":"workout","title":"Upper volume","instructions":"Higher-rep accessories, controlled tempo, no failure early.","sets":3,"reps":12,"rest_seconds":90,"block_label":"Volume"}]}
      ]}
    ]'::jsonb
  ),
  (
    'Ramadan Lifestyle-Aware',
    'ramadan_lifestyle',
    'Lower-friction training around fasting windows with hydration, sleep, and recovery emphasis.',
    4,
    'beginner',
    'hybrid',
    '{ramadan,lifestyle,recovery}',
    true,
    '[
      {"week_number":1,"days":[
        {"week_number":1,"day_number":1,"label":"Post-Iftar Strength","focus":"Low volume strength","tasks":[{"type":"workout","title":"Post-Iftar strength","instructions":"Short full-body session after food and fluids. Stop before grindy reps.","sets":2,"reps":8,"rest_seconds":120,"block_label":"Strength"}]},
        {"week_number":1,"day_number":3,"label":"Mobility + Walk","focus":"Recovery","tasks":[{"type":"mobility","title":"Mobility reset","instructions":"20 minutes of easy mobility and breathing.","duration_minutes":20},{"type":"hydration","title":"Hydration window","instructions":"Spread fluids between iftar and suhoor.","target_value":2500,"target_unit":"ml"}]}
      ]}
    ]'::jsonb
  )
on conflict do nothing;

create or replace function public.list_coach_program_templates()
returns table (
  id uuid,
  owner_coach_id uuid,
  title text,
  goal_type text,
  description text,
  duration_weeks integer,
  difficulty_level text,
  location_mode text,
  weekly_structure_json jsonb,
  resources_json jsonb,
  tags text[],
  is_system boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    id, owner_coach_id, title, goal_type, description, duration_weeks,
    difficulty_level, location_mode, weekly_structure_json, resources_json,
    tags, is_system, is_active, created_at, updated_at
  from public.coach_program_templates
  where is_active = true
    and (is_system = true or owner_coach_id = auth.uid())
  order by is_system desc, goal_type, title;
$$;

create or replace function public.save_coach_program_template(
  input_template_id uuid default null,
  input_title text default 'Custom program',
  input_goal_type text default 'custom',
  input_description text default '',
  input_duration_weeks integer default 4,
  input_difficulty_level text default 'beginner',
  input_location_mode text default 'online',
  input_weekly_structure jsonb default '[]'::jsonb,
  input_tags text[] default '{}'
)
returns public.coach_program_templates
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  result_record public.coach_program_templates%rowtype;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can save program templates.';
  end if;

  insert into public.coach_program_templates (
    id, owner_coach_id, title, goal_type, description, duration_weeks,
    difficulty_level, location_mode, weekly_structure_json, tags, is_system
  )
  values (
    coalesce(input_template_id, gen_random_uuid()), requester, trim(input_title), input_goal_type,
    coalesce(input_description, ''), greatest(coalesce(input_duration_weeks, 4), 1),
    input_difficulty_level, input_location_mode, coalesce(input_weekly_structure, '[]'::jsonb),
    coalesce(input_tags, '{}'::text[]), false
  )
  on conflict (id) do update
    set title = excluded.title,
        goal_type = excluded.goal_type,
        description = excluded.description,
        duration_weeks = excluded.duration_weeks,
        difficulty_level = excluded.difficulty_level,
        location_mode = excluded.location_mode,
        weekly_structure_json = excluded.weekly_structure_json,
        tags = excluded.tags
  where coach_program_templates.owner_coach_id = requester
    and coach_program_templates.is_system = false
  returning * into result_record;

  return result_record;
end;
$$;

create or replace function public.assign_program_template_to_client(
  target_subscription_id uuid,
  target_template_id uuid,
  input_start_date date default current_date,
  input_default_reminder_time time default null
)
returns table (plan_id uuid, created boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  template_record public.coach_program_templates%rowtype;
  created_plan_id uuid;
  current_week jsonb;
  current_day jsonb;
  created_day_id uuid;
  computed_week_number integer;
  computed_day_number integer;
  computed_day_index integer;
  computed_date date;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can assign programs.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and coach_id = requester;

  if subscription_record.id is null then
    raise exception 'Subscription not found for this coach.';
  end if;

  select *
  into template_record
  from public.coach_program_templates
  where id = target_template_id
    and is_active = true
    and (is_system = true or owner_coach_id = requester);

  if template_record.id is null then
    raise exception 'Program template not found.';
  end if;

  update public.workout_plans
  set status = 'archived',
      updated_at = timezone('utc', now())
  where member_id = subscription_record.member_id
    and coach_id = requester
    and status = 'active';

  insert into public.workout_plans (
    member_id, coach_id, source, title, plan_json, status, start_date, end_date,
    default_reminder_time
  )
  values (
    subscription_record.member_id,
    requester,
    'coach',
    template_record.title,
    jsonb_build_object(
      'title', template_record.title,
      'summary', template_record.description,
      'duration_weeks', template_record.duration_weeks,
      'level', template_record.difficulty_level,
      'weekly_structure', template_record.weekly_structure_json,
      'template_id', template_record.id
    ),
    'active',
    coalesce(input_start_date, current_date),
    coalesce(input_start_date, current_date) + ((template_record.duration_weeks * 7) - 1),
    input_default_reminder_time
  )
  returning id into created_plan_id;

  for current_week in
    select value
    from jsonb_array_elements(coalesce(template_record.weekly_structure_json, '[]'::jsonb))
  loop
    computed_week_number := greatest(coalesce((current_week ->> 'week_number')::integer, 1), 1);

    for current_day in
      select value
      from jsonb_array_elements(coalesce(current_week -> 'days', '[]'::jsonb))
    loop
      computed_day_number := greatest(coalesce((current_day ->> 'day_number')::integer, 1), 1);
      computed_day_index := ((computed_week_number - 1) * 7) + computed_day_number;
      computed_date := coalesce(input_start_date, current_date) + (computed_day_index - 1);

      insert into public.workout_plan_days (
        workout_plan_id, member_id, week_number, day_number, day_index,
        scheduled_date, label, focus, is_rest_day
      )
      values (
        created_plan_id,
        subscription_record.member_id,
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
        day_id, workout_plan_id, member_id, scheduled_date, task_type, title,
        instructions, sets, reps, duration_minutes, target_value, target_unit,
        scheduled_time, reminder_time, is_required, sort_order, rest_seconds,
        substitution_options_json, progression_rule, coach_cues_json, block_label
      )
      select
        created_day_id,
        created_plan_id,
        subscription_record.member_id,
        computed_date,
        coalesce(nullif(task_item.value ->> 'type', ''), 'workout'),
        coalesce(nullif(task_item.value ->> 'title', ''), 'Task'),
        coalesce(task_item.value ->> 'instructions', ''),
        case when coalesce(task_item.value ->> 'sets', '') = '' then null else (task_item.value ->> 'sets')::integer end,
        case when coalesce(task_item.value ->> 'reps', '') = '' then null else (task_item.value ->> 'reps')::integer end,
        case when coalesce(task_item.value ->> 'duration_minutes', '') = '' then null else (task_item.value ->> 'duration_minutes')::integer end,
        case when coalesce(task_item.value ->> 'target_value', '') = '' then null else (task_item.value ->> 'target_value')::numeric end,
        nullif(task_item.value ->> 'target_unit', ''),
        case when coalesce(task_item.value ->> 'scheduled_time', '') = '' then null else (task_item.value ->> 'scheduled_time')::time end,
        case
          when coalesce(task_item.value ->> 'reminder_time', '') <> '' then (task_item.value ->> 'reminder_time')::time
          when input_default_reminder_time is not null then input_default_reminder_time
          else null
        end,
        coalesce((task_item.value ->> 'is_required')::boolean, true),
        task_item.ordinality::integer - 1,
        case when coalesce(task_item.value ->> 'rest_seconds', '') = '' then null else (task_item.value ->> 'rest_seconds')::integer end,
        coalesce(task_item.value -> 'substitution_options', '[]'::jsonb),
        coalesce(task_item.value ->> 'progression_rule', ''),
        coalesce(task_item.value -> 'coach_cues', '[]'::jsonb),
        nullif(task_item.value ->> 'block_label', '')
      from jsonb_array_elements(coalesce(current_day -> 'tasks', '[]'::jsonb))
        with ordinality as task_item(value, ordinality);
    end loop;
  end loop;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    subscription_record.member_id,
    'coaching',
    'New coaching program assigned',
    'Your coach assigned "' || template_record.title || '".',
    jsonb_build_object('subscription_id', subscription_record.id, 'workout_plan_id', created_plan_id)
  );

  return query select created_plan_id, true;
end;
$$;

create or replace function public.list_coach_exercises()
returns table (
  id uuid,
  owner_coach_id uuid,
  title text,
  category text,
  primary_muscles text[],
  equipment_tags text[],
  difficulty_level text,
  instructions text,
  video_url text,
  substitution_options_json jsonb,
  progression_rule text,
  regression_rule text,
  rest_guidance_seconds integer,
  coaching_cues_json jsonb,
  is_system boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.coach_exercise_library
  where is_active = true
    and (is_system = true or owner_coach_id = auth.uid())
  order by is_system desc, category, title;
$$;

create or replace function public.save_coach_exercise(
  input_exercise_id uuid default null,
  input_title text default 'Exercise',
  input_category text default 'strength',
  input_primary_muscles text[] default '{}',
  input_equipment_tags text[] default '{}',
  input_difficulty_level text default 'beginner',
  input_instructions text default '',
  input_video_url text default null,
  input_substitutions jsonb default '[]'::jsonb,
  input_progression_rule text default '',
  input_regression_rule text default '',
  input_rest_guidance_seconds integer default null,
  input_cues jsonb default '[]'::jsonb
)
returns public.coach_exercise_library
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  result_record public.coach_exercise_library%rowtype;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can save exercises.';
  end if;

  insert into public.coach_exercise_library (
    id, owner_coach_id, title, category, primary_muscles, equipment_tags,
    difficulty_level, instructions, video_url, substitution_options_json,
    progression_rule, regression_rule, rest_guidance_seconds, coaching_cues_json,
    is_system
  )
  values (
    coalesce(input_exercise_id, gen_random_uuid()), requester, trim(input_title), input_category,
    coalesce(input_primary_muscles, '{}'::text[]),
    coalesce(input_equipment_tags, '{}'::text[]),
    input_difficulty_level, coalesce(input_instructions, ''), input_video_url,
    coalesce(input_substitutions, '[]'::jsonb), coalesce(input_progression_rule, ''),
    coalesce(input_regression_rule, ''), input_rest_guidance_seconds,
    coalesce(input_cues, '[]'::jsonb), false
  )
  on conflict (id) do update
    set title = excluded.title,
        category = excluded.category,
        primary_muscles = excluded.primary_muscles,
        equipment_tags = excluded.equipment_tags,
        difficulty_level = excluded.difficulty_level,
        instructions = excluded.instructions,
        video_url = excluded.video_url,
        substitution_options_json = excluded.substitution_options_json,
        progression_rule = excluded.progression_rule,
        regression_rule = excluded.regression_rule,
        rest_guidance_seconds = excluded.rest_guidance_seconds,
        coaching_cues_json = excluded.coaching_cues_json
  where coach_exercise_library.owner_coach_id = requester
    and coach_exercise_library.is_system = false
  returning * into result_record;

  return result_record;
end;
$$;

create or replace function public.assign_client_habits(
  target_subscription_id uuid,
  input_habits jsonb default '[]'::jsonb
)
returns setof public.member_habit_assignments
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  habit_item jsonb;
  habit_template public.coach_habit_templates%rowtype;
  assignment_record public.member_habit_assignments%rowtype;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can assign habits.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and coach_id = requester;

  if subscription_record.id is null then
    raise exception 'Subscription not found for this coach.';
  end if;

  for habit_item in
    select value
    from jsonb_array_elements(coalesce(input_habits, '[]'::jsonb))
  loop
    habit_template.id := null;
    habit_template.title := null;
    habit_template.habit_type := null;
    habit_template.description := null;
    habit_template.target_value := null;
    habit_template.target_unit := null;
    habit_template.frequency := null;
    if coalesce(habit_item ->> 'template_id', '') <> '' then
      select *
      into habit_template
      from public.coach_habit_templates
      where id = (habit_item ->> 'template_id')::uuid
        and (is_system = true or owner_coach_id = requester);
    end if;

    insert into public.member_habit_assignments (
      subscription_id, coach_id, member_id, habit_template_id, title,
      habit_type, description, target_value, target_unit, frequency, start_date, end_date
    )
    values (
      subscription_record.id,
      requester,
      subscription_record.member_id,
      habit_template.id,
      coalesce(nullif(habit_item ->> 'title', ''), habit_template.title, 'Habit'),
      coalesce(nullif(habit_item ->> 'habit_type', ''), habit_template.habit_type, 'custom'),
      coalesce(habit_item ->> 'description', habit_template.description, ''),
      case when coalesce(habit_item ->> 'target_value', '') = '' then habit_template.target_value else (habit_item ->> 'target_value')::numeric end,
      coalesce(nullif(habit_item ->> 'target_unit', ''), habit_template.target_unit),
      coalesce(nullif(habit_item ->> 'frequency', ''), habit_template.frequency, 'daily'),
      coalesce(case when coalesce(habit_item ->> 'start_date', '') = '' then null else (habit_item ->> 'start_date')::date end, current_date),
      case when coalesce(habit_item ->> 'end_date', '') = '' then null else (habit_item ->> 'end_date')::date end
    )
    returning * into assignment_record;

    return next assignment_record;
  end loop;
end;
$$;

grant execute on function public.list_coach_program_templates() to authenticated;
grant execute on function public.save_coach_program_template(uuid, text, text, text, integer, text, text, jsonb, text[]) to authenticated;
grant execute on function public.assign_program_template_to_client(uuid, uuid, date, time) to authenticated;
grant execute on function public.list_coach_exercises() to authenticated;
grant execute on function public.save_coach_exercise(uuid, text, text, text[], text[], text, text, text, jsonb, text, text, integer, jsonb) to authenticated;
grant execute on function public.assign_client_habits(uuid, jsonb) to authenticated;
