-- Coach onboarding flows, resources, and resource assignment storage
-- Date: 2026-04-21

insert into storage.buckets (id, name, public)
values ('coach-resources', 'coach-resources', false)
on conflict (id) do nothing;

create table if not exists public.coach_resources (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  title text not null,
  description text not null default '',
  resource_type text not null default 'file' check (
    resource_type in ('pdf', 'video', 'guide', 'meal_plan', 'link', 'file')
  ),
  storage_path text,
  external_url text,
  tags text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (storage_path is not null or external_url is not null)
);

create table if not exists public.coach_resource_assignments (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid not null references public.coach_resources(id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  assigned_by uuid references public.profiles(user_id) on delete set null,
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (resource_id, subscription_id)
);

create table if not exists public.coach_onboarding_templates (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  title text not null,
  client_type text not null default 'general' check (
    client_type in ('general', 'fat_loss', 'muscle_gain', 'beginner', 'home_training', 'hybrid', 'ramadan_lifestyle', 'custom')
  ),
  description text not null default '',
  welcome_message text not null default '',
  intake_form_json jsonb not null default '{}'::jsonb,
  goals_questionnaire_json jsonb not null default '{}'::jsonb,
  starter_program_template_id uuid references public.coach_program_templates(id) on delete set null,
  habit_templates_json jsonb not null default '[]'::jsonb,
  nutrition_tasks_json jsonb not null default '[]'::jsonb,
  checkin_schedule_json jsonb not null default '{}'::jsonb,
  resource_ids uuid[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_onboarding_applications (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.coach_onboarding_templates(id) on delete restrict,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  applied_by uuid references public.profiles(user_id) on delete set null,
  status text not null default 'applied' check (status in ('applied', 'partially_applied', 'failed')),
  result_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  unique (template_id, subscription_id)
);

create index if not exists idx_coach_resources_coach_created
  on public.coach_resources(coach_id, created_at desc);
create index if not exists idx_resource_assignments_subscription
  on public.coach_resource_assignments(subscription_id, created_at desc);
create index if not exists idx_onboarding_templates_coach_type
  on public.coach_onboarding_templates(coach_id, client_type, created_at desc);

alter table public.coach_resources enable row level security;
alter table public.coach_resource_assignments enable row level security;
alter table public.coach_onboarding_templates enable row level security;
alter table public.coach_onboarding_applications enable row level security;

drop policy if exists coach_resources_manage_own on public.coach_resources;
create policy coach_resources_manage_own
on public.coach_resources for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists resource_assignments_read_participants on public.coach_resource_assignments;
create policy resource_assignments_read_participants
on public.coach_resource_assignments for select
to authenticated
using (coach_id = auth.uid() or member_id = auth.uid());

drop policy if exists resource_assignments_manage_coach on public.coach_resource_assignments;
create policy resource_assignments_manage_coach
on public.coach_resource_assignments for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists onboarding_templates_manage_own on public.coach_onboarding_templates;
create policy onboarding_templates_manage_own
on public.coach_onboarding_templates for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists onboarding_applications_read_participants on public.coach_onboarding_applications;
create policy onboarding_applications_read_participants
on public.coach_onboarding_applications for select
to authenticated
using (coach_id = auth.uid() or member_id = auth.uid());

drop policy if exists onboarding_applications_manage_coach on public.coach_onboarding_applications;
create policy onboarding_applications_manage_coach
on public.coach_onboarding_applications for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists coach_resources_storage_select_participants on storage.objects;
create policy coach_resources_storage_select_participants
on storage.objects for select
to authenticated
using (
  bucket_id = 'coach-resources'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1
      from public.coach_resource_assignments ra
      join public.coach_resources cr on cr.id = ra.resource_id
      where cr.storage_path = name
        and (ra.coach_id = auth.uid() or ra.member_id = auth.uid())
    )
  )
);

drop policy if exists coach_resources_storage_insert_own on storage.objects;
create policy coach_resources_storage_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'coach-resources'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists coach_resources_storage_update_own on storage.objects;
create policy coach_resources_storage_update_own
on storage.objects for update
to authenticated
using (
  bucket_id = 'coach-resources'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'coach-resources'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists coach_resources_storage_delete_own on storage.objects;
create policy coach_resources_storage_delete_own
on storage.objects for delete
to authenticated
using (
  bucket_id = 'coach-resources'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop trigger if exists touch_coach_resources_updated_at on public.coach_resources;
create trigger touch_coach_resources_updated_at
before update on public.coach_resources
for each row execute function public.touch_updated_at();

drop trigger if exists touch_onboarding_templates_updated_at on public.coach_onboarding_templates;
create trigger touch_onboarding_templates_updated_at
before update on public.coach_onboarding_templates
for each row execute function public.touch_updated_at();

create or replace function public.list_coach_resources()
returns table (
  id uuid,
  coach_id uuid,
  title text,
  description text,
  resource_type text,
  storage_path text,
  external_url text,
  tags text[],
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select id, coach_id, title, description, resource_type, storage_path,
         external_url, tags, is_active, created_at, updated_at
  from public.coach_resources
  where coach_id = auth.uid()
    and is_active = true
  order by created_at desc;
$$;

create or replace function public.save_coach_resource(
  input_resource_id uuid default null,
  input_title text default 'Resource',
  input_description text default '',
  input_resource_type text default 'file',
  input_storage_path text default null,
  input_external_url text default null,
  input_tags text[] default '{}'
)
returns public.coach_resources
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  result_record public.coach_resources%rowtype;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can save resources.';
  end if;

  if coalesce(input_storage_path, input_external_url, '') = '' then
    raise exception 'A file path or URL is required.';
  end if;

  insert into public.coach_resources (
    id, coach_id, title, description, resource_type, storage_path, external_url, tags
  )
  values (
    coalesce(input_resource_id, gen_random_uuid()), requester, trim(input_title), coalesce(input_description, ''),
    input_resource_type, input_storage_path, input_external_url, coalesce(input_tags, '{}'::text[])
  )
  on conflict (id) do update
    set title = excluded.title,
        description = excluded.description,
        resource_type = excluded.resource_type,
        storage_path = excluded.storage_path,
        external_url = excluded.external_url,
        tags = excluded.tags
  where coach_resources.coach_id = requester
  returning * into result_record;

  return result_record;
end;
$$;

create or replace function public.assign_resource_to_client(
  target_subscription_id uuid,
  target_resource_id uuid,
  input_note text default null
)
returns public.coach_resource_assignments
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  resource_record public.coach_resources%rowtype;
  assignment_record public.coach_resource_assignments%rowtype;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can assign resources.';
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
  into resource_record
  from public.coach_resources
  where id = target_resource_id
    and coach_id = requester
    and is_active = true;

  if resource_record.id is null then
    raise exception 'Resource not found.';
  end if;

  insert into public.coach_resource_assignments (
    resource_id, subscription_id, coach_id, member_id, assigned_by, note
  )
  values (
    resource_record.id, subscription_record.id, requester,
    subscription_record.member_id, requester, input_note
  )
  on conflict (resource_id, subscription_id) do update
    set note = excluded.note
  returning * into assignment_record;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    subscription_record.member_id,
    'coaching',
    'New coaching resource',
    'Your coach shared "' || resource_record.title || '".',
    jsonb_build_object('subscription_id', subscription_record.id, 'resource_id', resource_record.id)
  );

  return assignment_record;
end;
$$;

create or replace function public.list_coach_onboarding_templates()
returns table (
  id uuid,
  coach_id uuid,
  title text,
  client_type text,
  description text,
  welcome_message text,
  intake_form_json jsonb,
  goals_questionnaire_json jsonb,
  starter_program_template_id uuid,
  habit_templates_json jsonb,
  nutrition_tasks_json jsonb,
  checkin_schedule_json jsonb,
  resource_ids uuid[],
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select id, coach_id, title, client_type, description, welcome_message,
         intake_form_json, goals_questionnaire_json, starter_program_template_id,
         habit_templates_json, nutrition_tasks_json, checkin_schedule_json,
         resource_ids, is_active, created_at, updated_at
  from public.coach_onboarding_templates
  where coach_id = auth.uid()
    and is_active = true
  order by created_at desc;
$$;

create or replace function public.save_coach_onboarding_template(
  input_template_id uuid default null,
  input_title text default 'New onboarding flow',
  input_client_type text default 'general',
  input_description text default '',
  input_welcome_message text default '',
  input_intake_form jsonb default '{}'::jsonb,
  input_goals_questionnaire jsonb default '{}'::jsonb,
  input_starter_program_template_id uuid default null,
  input_habit_templates jsonb default '[]'::jsonb,
  input_nutrition_tasks jsonb default '[]'::jsonb,
  input_checkin_schedule jsonb default '{}'::jsonb,
  input_resource_ids uuid[] default '{}'
)
returns public.coach_onboarding_templates
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  result_record public.coach_onboarding_templates%rowtype;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can save onboarding templates.';
  end if;

  insert into public.coach_onboarding_templates (
    id, coach_id, title, client_type, description, welcome_message,
    intake_form_json, goals_questionnaire_json, starter_program_template_id,
    habit_templates_json, nutrition_tasks_json, checkin_schedule_json, resource_ids
  )
  values (
    coalesce(input_template_id, gen_random_uuid()), requester, trim(input_title), input_client_type,
    coalesce(input_description, ''), coalesce(input_welcome_message, ''),
    coalesce(input_intake_form, '{}'::jsonb),
    coalesce(input_goals_questionnaire, '{}'::jsonb),
    input_starter_program_template_id,
    coalesce(input_habit_templates, '[]'::jsonb),
    coalesce(input_nutrition_tasks, '[]'::jsonb),
    coalesce(input_checkin_schedule, '{}'::jsonb),
    coalesce(input_resource_ids, '{}'::uuid[])
  )
  on conflict (id) do update
    set title = excluded.title,
        client_type = excluded.client_type,
        description = excluded.description,
        welcome_message = excluded.welcome_message,
        intake_form_json = excluded.intake_form_json,
        goals_questionnaire_json = excluded.goals_questionnaire_json,
        starter_program_template_id = excluded.starter_program_template_id,
        habit_templates_json = excluded.habit_templates_json,
        nutrition_tasks_json = excluded.nutrition_tasks_json,
        checkin_schedule_json = excluded.checkin_schedule_json,
        resource_ids = excluded.resource_ids
  where coach_onboarding_templates.coach_id = requester
  returning * into result_record;

  return result_record;
end;
$$;

create or replace function public.apply_coach_onboarding_flow(
  target_subscription_id uuid,
  target_template_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  template_record public.coach_onboarding_templates%rowtype;
  thread_id uuid;
  assigned_program jsonb := '{}'::jsonb;
  habit_results jsonb := '[]'::jsonb;
  resource_id uuid;
  assigned_resources integer := 0;
  application_record public.coach_onboarding_applications%rowtype;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can apply onboarding flows.';
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
  from public.coach_onboarding_templates
  where id = target_template_id
    and coach_id = requester
    and is_active = true;

  if template_record.id is null then
    raise exception 'Onboarding template not found.';
  end if;

  thread_id := public.ensure_coach_member_thread(subscription_record.id);

  if coalesce(trim(template_record.welcome_message), '') <> '' then
    insert into public.coach_messages (
      thread_id, sender_user_id, sender_role, message_type, content
    )
    values (
      thread_id, requester, 'coach', 'text', template_record.welcome_message
    );
  end if;

  if template_record.starter_program_template_id is not null then
    select to_jsonb(p)
    into assigned_program
    from public.assign_program_template_to_client(
      subscription_record.id,
      template_record.starter_program_template_id,
      current_date,
      null
    ) p;
  end if;

  if jsonb_typeof(template_record.habit_templates_json) = 'array'
     and jsonb_array_length(template_record.habit_templates_json) > 0 then
    select coalesce(jsonb_agg(to_jsonb(h)), '[]'::jsonb)
    into habit_results
    from public.assign_client_habits(subscription_record.id, template_record.habit_templates_json) h;
  end if;

  foreach resource_id in array template_record.resource_ids
  loop
    perform public.assign_resource_to_client(subscription_record.id, resource_id, 'Assigned by onboarding flow');
    assigned_resources := assigned_resources + 1;
  end loop;

  perform public.upsert_coach_client_record(
    subscription_record.id,
    case when subscription_record.status = 'active' then 'active' else 'pending_payment' end,
    'onboarding',
    null,
    null,
    null,
    null,
    null
  );

  insert into public.coach_onboarding_applications (
    template_id, subscription_id, coach_id, member_id, applied_by, status, result_json
  )
  values (
    template_record.id,
    subscription_record.id,
    requester,
    subscription_record.member_id,
    requester,
    'applied',
    jsonb_build_object(
      'thread_id', thread_id,
      'assigned_program', assigned_program,
      'habit_assignments', habit_results,
      'assigned_resources', assigned_resources
    )
  )
  on conflict (template_id, subscription_id) do update
    set status = excluded.status,
        result_json = excluded.result_json,
        created_at = timezone('utc', now())
  returning * into application_record;

  return application_record.result_json;
end;
$$;

grant execute on function public.list_coach_resources() to authenticated;
grant execute on function public.save_coach_resource(uuid, text, text, text, text, text, text[]) to authenticated;
grant execute on function public.assign_resource_to_client(uuid, uuid, text) to authenticated;
grant execute on function public.list_coach_onboarding_templates() to authenticated;
grant execute on function public.save_coach_onboarding_template(uuid, text, text, text, text, jsonb, jsonb, uuid, jsonb, jsonb, jsonb, uuid[]) to authenticated;
grant execute on function public.apply_coach_onboarding_flow(uuid, uuid) to authenticated;
