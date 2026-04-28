-- Harden coach/member messaging and check-in feedback.
-- Keeps coach feedback insertable, prevents role spoofing in direct message
-- inserts, and routes check-in feedback through a verified coach-owned RPC.

alter table public.coach_messages
  drop constraint if exists coach_messages_message_type_check;

alter table public.coach_messages
  add constraint coach_messages_message_type_check check (
    message_type in ('text', 'checkin_prompt', 'checkin_feedback', 'system')
  );

drop policy if exists coach_messages_insert_participants on public.coach_messages;
create policy coach_messages_insert_participants
on public.coach_messages for insert
to authenticated
with check (
  sender_user_id = auth.uid()
  and (
    (
      sender_role = 'member'
      and exists (
        select 1
        from public.coach_member_threads t
        where t.id = coach_messages.thread_id
          and t.member_id = auth.uid()
      )
    )
    or (
      sender_role = 'coach'
      and exists (
        select 1
        from public.coach_member_threads t
        where t.id = coach_messages.thread_id
          and t.coach_id = auth.uid()
      )
    )
  )
);

drop policy if exists weekly_checkins_update_participants on public.weekly_checkins;
create policy weekly_checkins_update_coach_feedback
on public.weekly_checkins for update
to authenticated
using (coach_id = auth.uid() and public.current_role() = 'coach')
with check (coach_id = auth.uid() and public.current_role() = 'coach');

create or replace function public.submit_coach_checkin_feedback(
  target_checkin_id uuid,
  target_thread_id uuid default null,
  input_feedback text default ''
)
returns public.weekly_checkins
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  checkin_record public.weekly_checkins%rowtype;
  resolved_thread_id uuid;
  cleaned_feedback text := trim(coalesce(input_feedback, ''));
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'coach' then
    raise exception 'Only coaches can submit check-in feedback.';
  end if;

  if cleaned_feedback = '' then
    raise exception 'Feedback cannot be empty.';
  end if;

  select *
  into checkin_record
  from public.weekly_checkins
  where id = target_checkin_id
    and coach_id = requester
  for update;

  if checkin_record.id is null then
    raise exception 'Check-in not found for this coach.';
  end if;

  if target_thread_id is not null
     and target_thread_id <> checkin_record.thread_id then
    raise exception 'Thread does not match this check-in.';
  end if;

  resolved_thread_id := coalesce(
    checkin_record.thread_id,
    public.ensure_coach_member_thread(checkin_record.subscription_id)
  );

  update public.weekly_checkins
  set coach_reply = cleaned_feedback,
      thread_id = resolved_thread_id,
      updated_at = timezone('utc', now())
  where id = checkin_record.id
  returning * into checkin_record;

  insert into public.coach_messages (
    thread_id,
    sender_user_id,
    sender_role,
    message_type,
    content
  )
  values (
    resolved_thread_id,
    requester,
    'coach',
    'checkin_feedback',
    cleaned_feedback
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    checkin_record.member_id,
    'coaching',
    'Coach feedback received',
    'Your coach replied to your weekly check-in.',
    jsonb_build_object(
      'subscription_id', checkin_record.subscription_id,
      'checkin_id', checkin_record.id,
      'thread_id', resolved_thread_id
    )
  );

  return checkin_record;
end;
$$;

grant execute on function public.submit_coach_checkin_feedback(uuid, uuid, text) to authenticated;
