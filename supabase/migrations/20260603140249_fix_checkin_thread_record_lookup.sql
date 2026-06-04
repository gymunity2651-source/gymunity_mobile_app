-- Fix check-in thread lookup after ensure_coach_member_thread().
--
-- ensure_coach_member_thread returns a uuid, not a coach_member_threads row.
-- Selecting its scalar result into a coach_member_threads%rowtype variable
-- produces a PL/pgSQL "too few attributes for composite variable" warning and
-- can break member check-in submission or coach feedback at runtime.

do $$
declare
  fn text;
  original_fn text;
begin
  fn := pg_get_functiondef(
    'public.submit_weekly_checkin(uuid,date,numeric,numeric,integer,integer,integer,text,text,text,jsonb,integer,integer,text,integer,integer,text,integer,integer,text,text,jsonb)'::regprocedure
  );
  original_fn := fn;

  fn := regexp_replace(
    fn,
    'select\s+\*\s+into\s+thread_record\s+from\s+public\.ensure_coach_member_thread\(subscription_record\.id\);',
    'select *' || chr(10) ||
    '  into thread_record' || chr(10) ||
    '  from public.coach_member_threads' || chr(10) ||
    '  where id = public.ensure_coach_member_thread(subscription_record.id);',
    'i'
  );

  if fn = original_fn then
    raise exception 'Could not update submit_weekly_checkin thread lookup';
  end if;

  execute fn;
end $$;

do $$
declare
  fn text;
  original_fn text;
begin
  fn := pg_get_functiondef(
    'public.submit_coach_checkin_feedback(uuid,uuid,text,text,text,text,text,text,text,date)'::regprocedure
  );
  original_fn := fn;

  fn := regexp_replace(
    fn,
    'select\s+\*\s+into\s+thread_record\s+from\s+public\.ensure_coach_member_thread\(checkin_record\.subscription_id\);',
    'select *' || chr(10) ||
    '  into thread_record' || chr(10) ||
    '  from public.coach_member_threads' || chr(10) ||
    '  where id = public.ensure_coach_member_thread(checkin_record.subscription_id);',
    'i'
  );

  if fn = original_fn then
    raise exception 'Could not update submit_coach_checkin_feedback thread lookup';
  end if;

  execute fn;
end $$;
