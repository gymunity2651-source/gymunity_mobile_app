do $$
declare
  fn text;
begin
  fn := pg_get_functiondef(
    'public.submit_weekly_checkin(uuid,date,numeric,numeric,integer,integer,integer,text,text,text,jsonb,integer,integer,text,integer,integer,text,integer,integer,text,text,jsonb)'::regprocedure
  );

  fn := regexp_replace(
    fn,
    'from public\.subscriptions\s+where id = target_subscription_id\s+and member_id = requester\s+and status = ''active''',
    'from public.subscriptions s' || chr(10) ||
    '  where s.id = target_subscription_id' || chr(10) ||
    '    and s.member_id = requester' || chr(10) ||
    '    and s.status = ''active''',
    'i'
  );

  if position('where s.id = target_subscription_id' in fn) = 0 then
    raise exception 'Could not qualify submit_weekly_checkin subscription lookup';
  end if;

  execute fn;
end $$;
