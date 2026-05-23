-- Fix PL/pgSQL name-resolution issues reported by `supabase db lint`.
-- Several legacy RPCs return tables with columns named `id`, `coach_id`,
-- or `member_id`; unqualified SQL inside those functions can then be
-- interpreted as an output variable instead of a table column.

do $$
declare
  fn text;
  target regprocedure;
begin
  foreach target in array array[
    'public.request_coach_subscription(uuid,text,jsonb)'::regprocedure,
    'public.activate_coach_subscription_with_starter_plan(uuid,date,time,text)'::regprocedure,
    'public.submit_coach_review(uuid,uuid,smallint,text)'::regprocedure,
    'public.pause_coach_subscription(uuid,boolean)'::regprocedure,
    'public.switch_coach_request(uuid,uuid,text)'::regprocedure,
    'public.list_coach_bookable_slots(uuid,uuid,date,date)'::regprocedure,
    'public.submit_weekly_checkin(uuid,date,numeric,numeric,integer,integer,integer,text,text,text,jsonb,integer,integer,text,integer,integer,text,integer,integer,text,text,jsonb)'::regprocedure
  ]
  loop
    fn := pg_get_functiondef(target);

    if position('#variable_conflict use_column' in fn) = 0 then
      fn := regexp_replace(
        fn,
        '(AS \$[^$]*\$\r?\n)',
        E'\\1#variable_conflict use_column\n',
        'i'
      );
    end if;

    if position('#variable_conflict use_column' in fn) = 0 then
      raise exception 'Could not inject variable conflict directive into %', target;
    end if;

    execute fn;
  end loop;
end $$;

do $$
declare
  fn text;
begin
  fn := pg_get_functiondef(
    'public.admin_verify_coach_payout_account(uuid,boolean,text)'::regprocedure
  );

  fn := replace(
    fn,
    'values (coach_id, is_verified, nullif(trim(coalesce(note, '''')), ''''))',
    'values ($1, $2, nullif(trim(coalesce(note, '''')), ''''))'
  );
  fn := replace(
    fn,
    'jsonb_build_object(''coach_id'', coach_id, ''is_verified'', is_verified, ''note'', note)',
    'jsonb_build_object(''coach_id'', $1, ''is_verified'', $2, ''note'', note)'
  );

  if position('values ($1, $2,' in fn) = 0 then
    raise exception 'Could not update admin_verify_coach_payout_account arguments';
  end if;

  execute fn;
end $$;

do $$
declare
  fn text;
begin
  fn := pg_get_functiondef(
    'public.admin_get_coach_settlement_details(uuid)'::regprocedure
  );

  fn := replace(fn, 'where u.id = coach_id', 'where u.id = $1');
  fn := replace(fn, 'where o.coach_id = coach_id', 'where o.coach_id = $1');
  fn := replace(fn, 'where p.coach_id = coach_id', 'where p.coach_id = $1');

  if position('where u.id = $1' in fn) = 0
     or position('where o.coach_id = $1' in fn) = 0
     or position('where p.coach_id = $1' in fn) = 0 then
    raise exception 'Could not update admin_get_coach_settlement_details arguments';
  end if;

  execute fn;
end $$;

do $$
declare
  fn text;
begin
  fn := pg_get_functiondef(
    'public.sync_member_task_notifications(text,integer)'::regprocedure
  );
  fn := replace(fn, 'reminder_keys text[] := ''{}'';', 'reminder_keys text[] := array[]::text[];');
  execute fn;

  fn := pg_get_functiondef(
    'public.build_member_ai_weekly_summary(date)'::regprocedure
  );
  fn := replace(fn, 'wins text[] := ''{}'';', 'wins text[] := array[]::text[];');
  fn := replace(fn, 'blockers text[] := ''{}'';', 'blockers text[] := array[]::text[];');
  execute fn;

  fn := pg_get_functiondef(
    'public.get_coach_member_insight(uuid,uuid)'::regprocedure
  );
  fn := replace(fn, 'risk_flags text[] := ''{}'';', 'risk_flags text[] := array[]::text[];');
  execute fn;
end $$;
