do $$
declare
  fn text;
begin
  fn := pg_get_functiondef(
    'public.submit_weekly_checkin(uuid,date,numeric,numeric,integer,integer,integer,text,text,text,jsonb)'::regprocedure
  );

  if position('#variable_conflict use_column' in fn) = 0 then
    fn := regexp_replace(
      fn,
      '(AS \$[^$]*\$\r?\n)',
      E'\\1#variable_conflict use_column\n',
      'i'
    );
  end if;

  fn := regexp_replace(
    fn,
    'from public\.subscriptions\s+where id = target_subscription_id\s+and member_id = requester',
    'from public.subscriptions s' || chr(10) ||
    '  where s.id = target_subscription_id' || chr(10) ||
    '    and s.member_id = requester',
    'i'
  );

  if position('where s.id = target_subscription_id' in fn) = 0 then
    raise exception 'Could not qualify legacy submit_weekly_checkin subscription lookup';
  end if;

  execute fn;
end $$;
