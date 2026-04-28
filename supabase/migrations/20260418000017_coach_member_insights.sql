-- Coach Member Insights: consent-based visibility, audit trail, and aggregated RPCs
-- Date: 2026-04-18

-- ─── 1. Consent / visibility settings ────────────────────────────────────────

create table if not exists public.coach_member_visibility_settings (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  share_ai_plan_summary boolean not null default false,
  share_workout_adherence boolean not null default false,
  share_progress_metrics boolean not null default false,
  share_nutrition_summary boolean not null default false,
  share_product_recommendations boolean not null default false,
  share_relevant_purchases boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (member_id, coach_id, subscription_id)
);

create index if not exists idx_visibility_settings_member
  on public.coach_member_visibility_settings(member_id);
create index if not exists idx_visibility_settings_coach
  on public.coach_member_visibility_settings(coach_id);
create index if not exists idx_visibility_settings_subscription
  on public.coach_member_visibility_settings(subscription_id);

-- ─── 2. Audit trail ─────────────────────────────────────────────────────────

create table if not exists public.coach_member_visibility_audit (
  id uuid primary key default gen_random_uuid(),
  visibility_settings_id uuid not null references public.coach_member_visibility_settings(id) on delete cascade,
  changed_by_member_id uuid not null references public.profiles(user_id) on delete cascade,
  change_type text not null check (
    change_type in ('initial_grant', 'updated', 'revoked_all')
  ),
  old_value_json jsonb not null default '{}'::jsonb,
  new_value_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_visibility_audit_settings
  on public.coach_member_visibility_audit(visibility_settings_id, created_at desc);

-- ─── 3. Product recommendation tracking ─────────────────────────────────────

create table if not exists public.member_product_recommendations (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  recommendation_context text not null check (
    recommendation_context in (
      'ai_plan_accessory',
      'nutrition_goal',
      'equipment_gap',
      'coach_suggestion'
    )
  ),
  plan_id uuid references public.workout_plans(id) on delete set null,
  status text not null default 'suggested' check (
    status in ('suggested', 'viewed', 'saved', 'purchased', 'dismissed')
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_product_recommendations_member
  on public.member_product_recommendations(member_id, created_at desc);

-- ─── 4. RLS ─────────────────────────────────────────────────────────────────

alter table public.coach_member_visibility_settings enable row level security;
alter table public.coach_member_visibility_audit enable row level security;
alter table public.member_product_recommendations enable row level security;

-- Visibility settings: member can manage own rows
drop policy if exists visibility_settings_member_manage on public.coach_member_visibility_settings;
create policy visibility_settings_member_manage
on public.coach_member_visibility_settings for all
to authenticated
using (member_id = auth.uid())
with check (member_id = auth.uid());

-- Visibility settings: coach can only SELECT for their active subscriptions
drop policy if exists visibility_settings_coach_read on public.coach_member_visibility_settings;
create policy visibility_settings_coach_read
on public.coach_member_visibility_settings for select
to authenticated
using (
  coach_id = auth.uid()
  and exists (
    select 1
    from public.subscriptions s
    where s.id = coach_member_visibility_settings.subscription_id
      and s.coach_id = auth.uid()
      and s.status = 'active'
  )
);

-- Audit: member can read own audit history
drop policy if exists visibility_audit_member_read on public.coach_member_visibility_audit;
create policy visibility_audit_member_read
on public.coach_member_visibility_audit for select
to authenticated
using (changed_by_member_id = auth.uid());

-- Product recommendations: member can manage own
drop policy if exists product_recommendations_member_manage on public.member_product_recommendations;
create policy product_recommendations_member_manage
on public.member_product_recommendations for all
to authenticated
using (member_id = auth.uid())
with check (member_id = auth.uid());

-- ─── 5. Auto-updated_at triggers ────────────────────────────────────────────

drop trigger if exists touch_visibility_settings_updated_at on public.coach_member_visibility_settings;
create trigger touch_visibility_settings_updated_at
before update on public.coach_member_visibility_settings
for each row execute function public.touch_updated_at();

drop trigger if exists touch_product_recommendations_updated_at on public.member_product_recommendations;
create trigger touch_product_recommendations_updated_at
before update on public.member_product_recommendations
for each row execute function public.touch_updated_at();

-- ─── 6. Member RPC: upsert visibility settings ─────────────────────────────

create or replace function public.upsert_coach_member_visibility(
  target_subscription_id uuid,
  target_coach_id uuid,
  input_share_ai_plan_summary boolean default false,
  input_share_workout_adherence boolean default false,
  input_share_progress_metrics boolean default false,
  input_share_nutrition_summary boolean default false,
  input_share_product_recommendations boolean default false,
  input_share_relevant_purchases boolean default false
)
returns public.coach_member_visibility_settings
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  existing_record public.coach_member_visibility_settings%rowtype;
  result_record public.coach_member_visibility_settings%rowtype;
  change_kind text;
  old_json jsonb;
  new_json jsonb;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  -- Verify the subscription belongs to the requester (member)
  if not exists (
    select 1
    from public.subscriptions s
    where s.id = target_subscription_id
      and s.member_id = requester
      and s.coach_id = target_coach_id
  ) then
    raise exception 'Subscription not found or does not belong to you.';
  end if;

  -- Check for existing settings
  select *
  into existing_record
  from public.coach_member_visibility_settings
  where member_id = requester
    and coach_id = target_coach_id
    and subscription_id = target_subscription_id;

  if existing_record.id is null then
    change_kind := 'initial_grant';
    old_json := '{}'::jsonb;
  else
    old_json := jsonb_build_object(
      'share_ai_plan_summary', existing_record.share_ai_plan_summary,
      'share_workout_adherence', existing_record.share_workout_adherence,
      'share_progress_metrics', existing_record.share_progress_metrics,
      'share_nutrition_summary', existing_record.share_nutrition_summary,
      'share_product_recommendations', existing_record.share_product_recommendations,
      'share_relevant_purchases', existing_record.share_relevant_purchases
    );

    -- Determine change type
    if not input_share_ai_plan_summary
       and not input_share_workout_adherence
       and not input_share_progress_metrics
       and not input_share_nutrition_summary
       and not input_share_product_recommendations
       and not input_share_relevant_purchases then
      change_kind := 'revoked_all';
    else
      change_kind := 'updated';
    end if;
  end if;

  -- Upsert the settings
  insert into public.coach_member_visibility_settings (
    member_id,
    coach_id,
    subscription_id,
    share_ai_plan_summary,
    share_workout_adherence,
    share_progress_metrics,
    share_nutrition_summary,
    share_product_recommendations,
    share_relevant_purchases
  )
  values (
    requester,
    target_coach_id,
    target_subscription_id,
    input_share_ai_plan_summary,
    input_share_workout_adherence,
    input_share_progress_metrics,
    input_share_nutrition_summary,
    input_share_product_recommendations,
    input_share_relevant_purchases
  )
  on conflict (member_id, coach_id, subscription_id) do update
    set share_ai_plan_summary = excluded.share_ai_plan_summary,
        share_workout_adherence = excluded.share_workout_adherence,
        share_progress_metrics = excluded.share_progress_metrics,
        share_nutrition_summary = excluded.share_nutrition_summary,
        share_product_recommendations = excluded.share_product_recommendations,
        share_relevant_purchases = excluded.share_relevant_purchases
  returning * into result_record;

  new_json := jsonb_build_object(
    'share_ai_plan_summary', result_record.share_ai_plan_summary,
    'share_workout_adherence', result_record.share_workout_adherence,
    'share_progress_metrics', result_record.share_progress_metrics,
    'share_nutrition_summary', result_record.share_nutrition_summary,
    'share_product_recommendations', result_record.share_product_recommendations,
    'share_relevant_purchases', result_record.share_relevant_purchases
  );

  -- Write audit trail
  insert into public.coach_member_visibility_audit (
    visibility_settings_id,
    changed_by_member_id,
    change_type,
    old_value_json,
    new_value_json
  )
  values (
    result_record.id,
    requester,
    change_kind,
    old_json,
    new_json
  );

  return result_record;
end;
$$;

grant execute on function public.upsert_coach_member_visibility(
  uuid, uuid, boolean, boolean, boolean, boolean, boolean, boolean
) to authenticated;

-- ─── 7. Member RPC: get own visibility settings ────────────────────────────

create or replace function public.get_member_visibility_settings(
  target_subscription_id uuid
)
returns table (
  id uuid,
  member_id uuid,
  coach_id uuid,
  subscription_id uuid,
  share_ai_plan_summary boolean,
  share_workout_adherence boolean,
  share_progress_metrics boolean,
  share_nutrition_summary boolean,
  share_product_recommendations boolean,
  share_relevant_purchases boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    vs.id,
    vs.member_id,
    vs.coach_id,
    vs.subscription_id,
    vs.share_ai_plan_summary,
    vs.share_workout_adherence,
    vs.share_progress_metrics,
    vs.share_nutrition_summary,
    vs.share_product_recommendations,
    vs.share_relevant_purchases,
    vs.created_at,
    vs.updated_at
  from public.coach_member_visibility_settings vs
  where vs.subscription_id = target_subscription_id
    and vs.member_id = auth.uid();
$$;

grant execute on function public.get_member_visibility_settings(uuid) to authenticated;

-- ─── 8. Coach RPC: get single member insight (consent-gated) ────────────────

create or replace function public.get_coach_member_insight(
  target_member_id uuid,
  target_subscription_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  vis public.coach_member_visibility_settings%rowtype;
  sub_record record;
  result jsonb := '{}'::jsonb;
  plan_data jsonb;
  adherence_data jsonb;
  progress_data jsonb;
  nutrition_data jsonb;
  product_data jsonb;
  risk_flags text[] := '{}';
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  -- Verify active coaching subscription
  select
    s.id,
    s.status,
    s.member_id,
    s.coach_id,
    s.package_id,
    p.full_name as member_name,
    p.avatar_path as member_avatar_path,
    mp.goal as current_goal,
    s.activated_at,
    coalesce(pkg.title, s.plan_name) as package_title
  into sub_record
  from public.subscriptions s
  join public.profiles p on p.user_id = s.member_id
  left join public.member_profiles mp on mp.user_id = s.member_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  where s.id = target_subscription_id
    and s.member_id = target_member_id
    and s.coach_id = requester
    and s.status = 'active';

  if sub_record.id is null then
    return null;
  end if;

  -- Build header (always visible for an active subscription)
  result := jsonb_build_object(
    'member_id', sub_record.member_id,
    'member_name', sub_record.member_name,
    'member_avatar_path', sub_record.member_avatar_path,
    'current_goal', sub_record.current_goal,
    'subscription_status', sub_record.status,
    'package_title', sub_record.package_title,
    'last_active_at', sub_record.activated_at
  );

  -- Load visibility settings
  select *
  into vis
  from public.coach_member_visibility_settings
  where member_id = target_member_id
    and coach_id = requester
    and subscription_id = target_subscription_id;

  -- If no visibility settings exist, return header only
  if vis.id is null then
    result := result || jsonb_build_object(
      'plan_insight', null,
      'adherence_insight', null,
      'progress_insight', null,
      'nutrition_insight', null,
      'product_insight', null,
      'risk_flags', to_jsonb(risk_flags)
    );
    return result;
  end if;

  -- ── AI Plan Summary ──
  if vis.share_ai_plan_summary then
    select jsonb_build_object(
      'plan_id', wp.id,
      'plan_title', wp.title,
      'plan_source', wp.source,
      'plan_status', wp.status,
      'start_date', wp.start_date,
      'end_date', wp.end_date,
      'plan_version', wp.plan_version,
      'duration_weeks', coalesce((wp.plan_json ->> 'duration_weeks')::integer, 1),
      'level', wp.plan_json ->> 'level',
      'summary', wp.plan_json ->> 'summary',
      'total_days', (select count(*) from public.workout_plan_days d where d.workout_plan_id = wp.id),
      'total_tasks', (select count(*) from public.workout_plan_tasks t where t.workout_plan_id = wp.id)
    )
    into plan_data
    from public.workout_plans wp
    where wp.member_id = target_member_id
      and wp.status = 'active'
    order by wp.assigned_at desc
    limit 1;

    result := result || jsonb_build_object('plan_insight', coalesce(plan_data, 'null'::jsonb));
  else
    result := result || jsonb_build_object('plan_insight', null);
  end if;

  -- ── Workout Adherence ──
  if vis.share_workout_adherence then
    select jsonb_build_object(
      'total_tasks', coalesce(total_tasks, 0),
      'completed_tasks', coalesce(completed_tasks, 0),
      'partial_tasks', coalesce(partial_tasks, 0),
      'skipped_tasks', coalesce(skipped_tasks, 0),
      'missed_tasks', coalesce(missed_tasks, 0),
      'completion_rate', case when total_tasks > 0 then round((completed_tasks::numeric / total_tasks) * 100, 1) else 0 end,
      'streak_days', coalesce(streak_days, 0),
      'last_completed_at', last_completed_at
    )
    into adherence_data
    from (
      select
        count(t.id) as total_tasks,
        count(l.id) filter (where l.completion_status = 'completed') as completed_tasks,
        count(l.id) filter (where l.completion_status = 'partial') as partial_tasks,
        count(l.id) filter (where l.completion_status = 'skipped') as skipped_tasks,
        count(t.id) filter (where l.id is null and t.scheduled_date < current_date) as missed_tasks,
        max(l.logged_at) as last_completed_at,
        0 as streak_days  -- simplified; real streak would be a separate computation
      from public.workout_plan_tasks t
      join public.workout_plans wp on wp.id = t.workout_plan_id
      left join public.workout_task_logs l on l.task_id = t.id
      where t.member_id = target_member_id
        and wp.status = 'active'
    ) stats;

    -- Risk flag: low adherence
    if (adherence_data ->> 'completion_rate')::numeric < 40 then
      risk_flags := array_append(risk_flags, 'low_adherence');
    end if;
    if (adherence_data ->> 'missed_tasks')::integer > 5 then
      risk_flags := array_append(risk_flags, 'many_missed_sessions');
    end if;

    result := result || jsonb_build_object('adherence_insight', coalesce(adherence_data, 'null'::jsonb));
  else
    result := result || jsonb_build_object('adherence_insight', null);
  end if;

  -- ── Progress Metrics ──
  if vis.share_progress_metrics then
    select jsonb_build_object(
      'latest_weight', latest_w.weight_kg,
      'latest_weight_at', latest_w.recorded_at,
      'weight_4w_ago', older_w.weight_kg,
      'weight_trend', case
        when latest_w.weight_kg is not null and older_w.weight_kg is not null then
          case
            when latest_w.weight_kg < older_w.weight_kg then 'decreasing'
            when latest_w.weight_kg > older_w.weight_kg then 'increasing'
            else 'stable'
          end
        else 'insufficient_data'
      end,
      'latest_measurement', (
        select jsonb_build_object(
          'waist_cm', bm.waist_cm,
          'chest_cm', bm.chest_cm,
          'arm_cm', bm.arm_cm,
          'body_fat_percent', bm.body_fat_percent,
          'recorded_at', bm.recorded_at
        )
        from public.member_body_measurements bm
        where bm.member_id = target_member_id
        order by bm.recorded_at desc
        limit 1
      ),
      'last_checkin_at', (
        select max(wc.created_at)
        from public.weekly_checkins wc
        where wc.member_id = target_member_id
          and wc.coach_id = requester
      ),
      'latest_checkin_adherence', (
        select wc.adherence_score
        from public.weekly_checkins wc
        where wc.member_id = target_member_id
          and wc.coach_id = requester
        order by wc.created_at desc
        limit 1
      )
    )
    into progress_data
    from (
      select weight_kg, recorded_at
      from public.member_weight_entries
      where member_id = target_member_id
      order by recorded_at desc
      limit 1
    ) latest_w
    left join lateral (
      select weight_kg
      from public.member_weight_entries
      where member_id = target_member_id
        and recorded_at <= (current_date - interval '28 days')
      order by recorded_at desc
      limit 1
    ) older_w on true;

    -- Risk flag: no recent checkin
    if coalesce((
      select max(wc.created_at)
      from public.weekly_checkins wc
      where wc.member_id = target_member_id
        and wc.coach_id = requester
    ), '1970-01-01'::timestamptz) < (now() - interval '14 days') then
      risk_flags := array_append(risk_flags, 'no_recent_checkin');
    end if;

    result := result || jsonb_build_object('progress_insight', coalesce(progress_data, 'null'::jsonb));
  else
    result := result || jsonb_build_object('progress_insight', null);
  end if;

  -- ── Nutrition Summary ──
  if vis.share_nutrition_summary then
    select jsonb_build_object(
      'target_calories', nt.target_calories,
      'target_protein_g', nt.protein_g,
      'target_carbs_g', nt.carbs_g,
      'target_fats_g', nt.fats_g,
      'latest_adherence_score', (
        select nc.adherence_score
        from public.nutrition_checkins nc
        where nc.member_id = target_member_id
        order by nc.week_start desc
        limit 1
      ),
      'has_active_meal_plan', exists (
        select 1
        from public.member_meal_plans mmp
        where mmp.member_id = target_member_id
          and mmp.status = 'active'
      )
    )
    into nutrition_data
    from public.nutrition_targets nt
    where nt.member_id = target_member_id
      and nt.status = 'active'
    limit 1;

    result := result || jsonb_build_object('nutrition_insight', coalesce(nutrition_data, 'null'::jsonb));
  else
    result := result || jsonb_build_object('nutrition_insight', null);
  end if;

  -- ── Product Intelligence ──
  if vis.share_product_recommendations or vis.share_relevant_purchases then
    select jsonb_build_object(
      'recommended_products', coalesce(
        case when vis.share_product_recommendations then (
          select jsonb_agg(jsonb_build_object(
            'product_id', pr.product_id,
            'product_title', prod.title,
            'context', pr.recommendation_context,
            'status', pr.status,
            'created_at', pr.created_at
          ) order by pr.created_at desc)
          from public.member_product_recommendations pr
          join public.products prod on prod.id = pr.product_id
          where pr.member_id = target_member_id
          limit 10
        ) else null end,
        '[]'::jsonb
      ),
      'purchased_relevant', coalesce(
        case when vis.share_relevant_purchases then (
          select jsonb_agg(jsonb_build_object(
            'product_id', oi.product_id,
            'product_title', oi.product_title_snapshot,
            'quantity', oi.quantity,
            'purchased_at', o.created_at
          ) order by o.created_at desc)
          from public.order_items oi
          join public.orders o on o.id = oi.order_id
          where o.member_id = target_member_id
            and o.status in ('confirmed', 'shipped', 'delivered')
            and exists (
              select 1
              from public.member_product_recommendations mpr
              where mpr.member_id = target_member_id
                and mpr.product_id = oi.product_id
            )
          limit 10
        ) else null end,
        '[]'::jsonb
      )
    )
    into product_data;

    result := result || jsonb_build_object('product_insight', coalesce(product_data, 'null'::jsonb));
  else
    result := result || jsonb_build_object('product_insight', null);
  end if;

  -- ── Final risk flags ──
  result := result || jsonb_build_object('risk_flags', to_jsonb(risk_flags));

  return result;
end;
$$;

grant execute on function public.get_coach_member_insight(uuid, uuid) to authenticated;

-- ─── 9. Coach RPC: list client insight summaries ────────────────────────────

create or replace function public.list_coach_member_insight_summaries()
returns table (
  subscription_id uuid,
  member_id uuid,
  member_name text,
  member_avatar_path text,
  current_goal text,
  package_title text,
  status text,
  started_at timestamptz,
  has_visibility_settings boolean,
  any_data_shared boolean,
  completion_rate numeric,
  last_checkin_at timestamptz,
  risk_flags text[]
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  return query
  select
    s.id as subscription_id,
    s.member_id,
    coalesce(nullif(p.full_name, ''), 'Member') as member_name,
    p.avatar_path as member_avatar_path,
    mp.goal as current_goal,
    coalesce(pkg.title, s.plan_name) as package_title,
    s.status,
    coalesce(s.activated_at, s.starts_at, s.created_at) as started_at,
    (vs.id is not null) as has_visibility_settings,
    coalesce(
      vs.share_ai_plan_summary or vs.share_workout_adherence or
      vs.share_progress_metrics or vs.share_nutrition_summary or
      vs.share_product_recommendations or vs.share_relevant_purchases,
      false
    ) as any_data_shared,
    case
      when vs.share_workout_adherence = true then
        coalesce((
          select
            case when count(t.id) > 0
              then round(
                (count(l.id) filter (where l.completion_status = 'completed')::numeric / count(t.id)) * 100,
                1
              )
              else 0
            end
          from public.workout_plan_tasks t
          join public.workout_plans wp on wp.id = t.workout_plan_id
          left join public.workout_task_logs l on l.task_id = t.id
          where t.member_id = s.member_id
            and wp.status = 'active'
        ), 0)
      else null
    end as completion_rate,
    case
      when vs.share_progress_metrics = true then (
        select max(wc.created_at)
        from public.weekly_checkins wc
        where wc.member_id = s.member_id
          and wc.coach_id = requester
      )
      else null
    end as last_checkin_at,
    array_remove(array[
      case
        when vs.share_workout_adherence = true and coalesce((
          select case when count(t.id) > 0
            then round((count(l.id) filter (where l.completion_status = 'completed')::numeric / count(t.id)) * 100, 1)
            else 0 end
          from public.workout_plan_tasks t
          join public.workout_plans wp on wp.id = t.workout_plan_id
          left join public.workout_task_logs l on l.task_id = t.id
          where t.member_id = s.member_id and wp.status = 'active'
        ), 0) < 40 then 'low_adherence'
        else null
      end,
      case
        when vs.share_progress_metrics = true and (
          select max(wc.created_at) from public.weekly_checkins wc
          where wc.member_id = s.member_id and wc.coach_id = requester
        ) < (now() - interval '14 days') then 'no_recent_checkin'
        else null
      end
    ], null) as risk_flags
  from public.subscriptions s
  join public.profiles p on p.user_id = s.member_id
  left join public.member_profiles mp on mp.user_id = s.member_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  left join public.coach_member_visibility_settings vs
    on vs.member_id = s.member_id
    and vs.coach_id = requester
    and vs.subscription_id = s.id
  where s.coach_id = requester
    and s.status = 'active'
  order by
    case when coalesce(
      vs.share_workout_adherence and coalesce((
        select case when count(t.id) > 0
          then round((count(l.id) filter (where l.completion_status = 'completed')::numeric / count(t.id)) * 100, 1)
          else 0 end
        from public.workout_plan_tasks t
        join public.workout_plans wp on wp.id = t.workout_plan_id
        left join public.workout_task_logs l on l.task_id = t.id
        where t.member_id = s.member_id and wp.status = 'active'
      ), 0) < 40, false) then 0 else 1 end,
    s.created_at desc;
end;
$$;

grant execute on function public.list_coach_member_insight_summaries() to authenticated;

-- ─── 10. List visibility audit (member-only) ────────────────────────────────

create or replace function public.list_visibility_audit(
  target_subscription_id uuid
)
returns table (
  id uuid,
  change_type text,
  old_value_json jsonb,
  new_value_json jsonb,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    a.id,
    a.change_type,
    a.old_value_json,
    a.new_value_json,
    a.created_at
  from public.coach_member_visibility_audit a
  join public.coach_member_visibility_settings vs on vs.id = a.visibility_settings_id
  where vs.subscription_id = target_subscription_id
    and a.changed_by_member_id = auth.uid()
  order by a.created_at desc;
$$;

grant execute on function public.list_visibility_audit(uuid) to authenticated;
