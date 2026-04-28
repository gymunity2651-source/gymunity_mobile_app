-- Coach calendar, session types, booking rules, and self-booking hooks
-- Date: 2026-04-21

create table if not exists public.coach_session_types (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  title text not null,
  session_kind text not null check (
    session_kind in ('consultation', 'weekly_checkin_call', 'video_coaching_session', 'in_person_training_session')
  ),
  duration_minutes integer not null default 45 check (duration_minutes between 10 and 240),
  buffer_before_minutes integer not null default 0 check (buffer_before_minutes between 0 and 120),
  buffer_after_minutes integer not null default 10 check (buffer_after_minutes between 0 and 120),
  delivery_mode text not null default 'online' check (delivery_mode in ('online', 'in_person', 'hybrid')),
  location_note text,
  cancellation_notice_hours integer not null default 12 check (cancellation_notice_hours between 0 and 168),
  reschedule_notice_hours integer not null default 12 check (reschedule_notice_hours between 0 and 168),
  is_self_bookable boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.coach_availability_slots
  add column if not exists session_type_ids uuid[] not null default '{}',
  add column if not exists default_session_duration_minutes integer not null default 45 check (default_session_duration_minutes between 10 and 240),
  add column if not exists buffer_before_minutes integer not null default 0 check (buffer_before_minutes between 0 and 120),
  add column if not exists buffer_after_minutes integer not null default 10 check (buffer_after_minutes between 0 and 120),
  add column if not exists min_booking_notice_hours integer not null default 12 check (min_booking_notice_hours between 0 and 720),
  add column if not exists cancellation_notice_hours integer not null default 12 check (cancellation_notice_hours between 0 and 168),
  add column if not exists reschedule_notice_hours integer not null default 12 check (reschedule_notice_hours between 0 and 168),
  add column if not exists delivery_mode text not null default 'online' check (delivery_mode in ('online', 'in_person', 'hybrid'));

create table if not exists public.coach_bookings (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  session_type_id uuid references public.coach_session_types(id) on delete set null,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  timezone text not null default 'UTC',
  status text not null default 'scheduled' check (
    status in ('scheduled', 'confirmed', 'completed', 'cancelled', 'rescheduled', 'no_show')
  ),
  delivery_mode text not null default 'online' check (delivery_mode in ('online', 'in_person', 'hybrid')),
  location_note text,
  cancellation_reason text,
  rescheduled_from_booking_id uuid references public.coach_bookings(id) on delete set null,
  video_provider text,
  video_join_url text,
  video_room_id text,
  reminder_sent_at timestamptz,
  metadata_json jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(user_id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (ends_at > starts_at)
);

create index if not exists idx_coach_session_types_coach_active
  on public.coach_session_types(coach_id, is_active, created_at desc);
create unique index if not exists idx_coach_session_types_coach_kind_unique
  on public.coach_session_types(coach_id, session_kind);
create index if not exists idx_coach_bookings_coach_start
  on public.coach_bookings(coach_id, starts_at desc);
create index if not exists idx_coach_bookings_member_start
  on public.coach_bookings(member_id, starts_at desc);
create index if not exists idx_coach_bookings_subscription
  on public.coach_bookings(subscription_id, starts_at desc);

alter table public.coach_session_types enable row level security;
alter table public.coach_bookings enable row level security;

drop policy if exists coach_session_types_read_public_or_own on public.coach_session_types;
create policy coach_session_types_read_public_or_own
on public.coach_session_types for select
to authenticated
using (is_active = true or coach_id = auth.uid());

drop policy if exists coach_session_types_manage_own on public.coach_session_types;
create policy coach_session_types_manage_own
on public.coach_session_types for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists coach_bookings_read_participants on public.coach_bookings;
create policy coach_bookings_read_participants
on public.coach_bookings for select
to authenticated
using (coach_id = auth.uid() or member_id = auth.uid());

drop policy if exists coach_bookings_manage_participants on public.coach_bookings;
create policy coach_bookings_manage_participants
on public.coach_bookings for all
to authenticated
using (coach_id = auth.uid() or member_id = auth.uid())
with check (coach_id = auth.uid() or member_id = auth.uid());

drop trigger if exists touch_coach_session_types_updated_at on public.coach_session_types;
create trigger touch_coach_session_types_updated_at
before update on public.coach_session_types
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_bookings_updated_at on public.coach_bookings;
create trigger touch_coach_bookings_updated_at
before update on public.coach_bookings
for each row execute function public.touch_updated_at();

create or replace function public.seed_default_coach_session_types(target_coach_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.coach_session_types (coach_id, title, session_kind, duration_minutes, delivery_mode)
  values
    (target_coach_id, 'Consultation', 'consultation', 30, 'online'),
    (target_coach_id, 'Weekly check-in call', 'weekly_checkin_call', 30, 'online'),
    (target_coach_id, 'Video coaching session', 'video_coaching_session', 45, 'online'),
    (target_coach_id, 'In-person training session', 'in_person_training_session', 60, 'in_person')
  on conflict (coach_id, session_kind) do nothing;
end;
$$;

create or replace function public.list_coach_session_types()
returns table (
  id uuid,
  coach_id uuid,
  title text,
  session_kind text,
  duration_minutes integer,
  buffer_before_minutes integer,
  buffer_after_minutes integer,
  delivery_mode text,
  location_note text,
  cancellation_notice_hours integer,
  reschedule_notice_hours integer,
  is_self_bookable boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() = 'coach' then
    perform public.seed_default_coach_session_types(requester);
  end if;

  return query
  select st.id, st.coach_id, st.title, st.session_kind, st.duration_minutes,
         st.buffer_before_minutes, st.buffer_after_minutes, st.delivery_mode,
         st.location_note, st.cancellation_notice_hours,
         st.reschedule_notice_hours, st.is_self_bookable, st.is_active,
         st.created_at, st.updated_at
  from public.coach_session_types st
  where st.coach_id = requester
    and st.is_active = true
  order by st.created_at asc;
end;
$$;

create or replace function public.save_coach_session_type(
  input_session_type_id uuid default null,
  input_title text default 'Session',
  input_session_kind text default 'consultation',
  input_duration_minutes integer default 45,
  input_buffer_before_minutes integer default 0,
  input_buffer_after_minutes integer default 10,
  input_delivery_mode text default 'online',
  input_location_note text default null,
  input_cancellation_notice_hours integer default 12,
  input_reschedule_notice_hours integer default 12,
  input_is_self_bookable boolean default true
)
returns public.coach_session_types
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  result_record public.coach_session_types%rowtype;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can save session types.';
  end if;

  insert into public.coach_session_types (
    id, coach_id, title, session_kind, duration_minutes, buffer_before_minutes,
    buffer_after_minutes, delivery_mode, location_note, cancellation_notice_hours,
    reschedule_notice_hours, is_self_bookable
  )
  values (
    coalesce(input_session_type_id, gen_random_uuid()), requester, trim(input_title), input_session_kind,
    input_duration_minutes, input_buffer_before_minutes, input_buffer_after_minutes,
    input_delivery_mode, input_location_note, input_cancellation_notice_hours,
    input_reschedule_notice_hours, coalesce(input_is_self_bookable, true)
  )
  on conflict (coach_id, session_kind) do update
    set title = excluded.title,
        session_kind = excluded.session_kind,
        duration_minutes = excluded.duration_minutes,
        buffer_before_minutes = excluded.buffer_before_minutes,
        buffer_after_minutes = excluded.buffer_after_minutes,
        delivery_mode = excluded.delivery_mode,
        location_note = excluded.location_note,
        cancellation_notice_hours = excluded.cancellation_notice_hours,
        reschedule_notice_hours = excluded.reschedule_notice_hours,
        is_self_bookable = excluded.is_self_bookable
  where coach_session_types.coach_id = requester
  returning * into result_record;

  return result_record;
end;
$$;

create or replace function public.list_coach_bookings(
  input_date_from timestamptz default null,
  input_date_to timestamptz default null,
  target_subscription_id uuid default null
)
returns table (
  id uuid,
  coach_id uuid,
  member_id uuid,
  member_name text,
  subscription_id uuid,
  session_type_id uuid,
  session_type_title text,
  title text,
  starts_at timestamptz,
  ends_at timestamptz,
  timezone text,
  status text,
  delivery_mode text,
  location_note text,
  video_provider text,
  video_join_url text,
  created_at timestamptz,
  updated_at timestamptz
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
    raise exception 'Authentication is required.';
  end if;

  return query
  select b.id, b.coach_id, b.member_id, coalesce(nullif(p.full_name, ''), 'Member'),
         b.subscription_id, b.session_type_id, st.title,
         b.title, b.starts_at, b.ends_at, b.timezone, b.status,
         b.delivery_mode, b.location_note, b.video_provider, b.video_join_url,
         b.created_at, b.updated_at
  from public.coach_bookings b
  join public.profiles p on p.user_id = b.member_id
  left join public.coach_session_types st on st.id = b.session_type_id
  where (b.coach_id = requester or b.member_id = requester)
    and (target_subscription_id is null or b.subscription_id = target_subscription_id)
    and (input_date_from is null or b.starts_at >= input_date_from)
    and (input_date_to is null or b.starts_at <= input_date_to)
  order by b.starts_at asc;
end;
$$;

create or replace function public.list_coach_bookable_slots(
  target_coach_id uuid,
  target_session_type_id uuid,
  input_date_from date default current_date,
  input_date_to date default (current_date + 14)
)
returns table (
  coach_id uuid,
  session_type_id uuid,
  starts_at timestamptz,
  ends_at timestamptz,
  timezone text,
  delivery_mode text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  session_type_record public.coach_session_types%rowtype;
  slot_record public.coach_availability_slots%rowtype;
  day_cursor date;
  start_ts timestamptz;
  end_ts timestamptz;
begin
  select *
  into session_type_record
  from public.coach_session_types
  where id = target_session_type_id
    and coach_id = target_coach_id
    and is_active = true
    and is_self_bookable = true;

  if session_type_record.id is null then
    raise exception 'Session type is not bookable.';
  end if;

  for slot_record in
    select *
    from public.coach_availability_slots
    where coach_id = target_coach_id
      and is_active = true
      and (
        session_type_ids = '{}'::uuid[]
        or session_type_ids @> array[target_session_type_id]
      )
  loop
    day_cursor := coalesce(input_date_from, current_date);
    while day_cursor <= coalesce(input_date_to, current_date + 14) loop
      if extract(dow from day_cursor)::integer = slot_record.weekday then
        start_ts := make_timestamptz(
          extract(year from day_cursor)::integer,
          extract(month from day_cursor)::integer,
          extract(day from day_cursor)::integer,
          extract(hour from slot_record.start_time)::integer,
          extract(minute from slot_record.start_time)::integer,
          0,
          slot_record.timezone
        );
        end_ts := start_ts + make_interval(mins => session_type_record.duration_minutes);

        while end_ts <= make_timestamptz(
          extract(year from day_cursor)::integer,
          extract(month from day_cursor)::integer,
          extract(day from day_cursor)::integer,
          extract(hour from slot_record.end_time)::integer,
          extract(minute from slot_record.end_time)::integer,
          0,
          slot_record.timezone
        ) loop
          if start_ts >= now() + make_interval(hours => slot_record.min_booking_notice_hours)
             and not exists (
               select 1
               from public.coach_bookings b
               where b.coach_id = target_coach_id
                 and b.status in ('scheduled', 'confirmed')
                 and tstzrange(b.starts_at, b.ends_at, '[)') &&
                     tstzrange(
                       start_ts - make_interval(mins => session_type_record.buffer_before_minutes),
                       end_ts + make_interval(mins => session_type_record.buffer_after_minutes),
                       '[)'
                     )
             ) then
            coach_id := target_coach_id;
            session_type_id := target_session_type_id;
            starts_at := start_ts;
            ends_at := end_ts;
            timezone := slot_record.timezone;
            delivery_mode := session_type_record.delivery_mode;
            return next;
          end if;

          start_ts := end_ts + make_interval(mins => greatest(session_type_record.buffer_after_minutes, 0));
          end_ts := start_ts + make_interval(mins => session_type_record.duration_minutes);
        end loop;
      end if;
      day_cursor := day_cursor + 1;
    end loop;
  end loop;
end;
$$;

create or replace function public.create_coach_booking(
  target_subscription_id uuid,
  target_session_type_id uuid,
  input_starts_at timestamptz,
  input_timezone text default 'UTC',
  input_note text default null
)
returns public.coach_bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  session_type_record public.coach_session_types%rowtype;
  booking_record public.coach_bookings%rowtype;
  computed_ends_at timestamptz;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and (member_id = requester or coach_id = requester)
    and status in ('active', 'paused');

  if subscription_record.id is null then
    raise exception 'Active subscription not found.';
  end if;

  select *
  into session_type_record
  from public.coach_session_types
  where id = target_session_type_id
    and coach_id = subscription_record.coach_id
    and is_active = true;

  if session_type_record.id is null then
    raise exception 'Session type not found.';
  end if;

  if requester = subscription_record.member_id and session_type_record.is_self_bookable = false then
    raise exception 'This session type is not self-bookable.';
  end if;

  computed_ends_at := input_starts_at + make_interval(mins => session_type_record.duration_minutes);

  if exists (
    select 1
    from public.coach_bookings b
    where b.coach_id = subscription_record.coach_id
      and b.status in ('scheduled', 'confirmed')
      and tstzrange(b.starts_at, b.ends_at, '[)') &&
          tstzrange(
            input_starts_at - make_interval(mins => session_type_record.buffer_before_minutes),
            computed_ends_at + make_interval(mins => session_type_record.buffer_after_minutes),
            '[)'
          )
  ) then
    raise exception 'This time is no longer available.';
  end if;

  insert into public.coach_bookings (
    coach_id, member_id, subscription_id, session_type_id, title, starts_at,
    ends_at, timezone, status, delivery_mode, location_note, created_by,
    metadata_json
  )
  values (
    subscription_record.coach_id,
    subscription_record.member_id,
    subscription_record.id,
    session_type_record.id,
    session_type_record.title,
    input_starts_at,
    computed_ends_at,
    coalesce(input_timezone, 'UTC'),
    'scheduled',
    session_type_record.delivery_mode,
    session_type_record.location_note,
    requester,
    jsonb_build_object('note', input_note)
  )
  returning * into booking_record;

  insert into public.notifications (user_id, type, title, body, data)
  values
    (subscription_record.coach_id, 'coaching', 'Session booked', 'A coaching session was booked.', jsonb_build_object('booking_id', booking_record.id, 'subscription_id', subscription_record.id)),
    (subscription_record.member_id, 'coaching', 'Session booked', 'Your coaching session is scheduled.', jsonb_build_object('booking_id', booking_record.id, 'subscription_id', subscription_record.id));

  return booking_record;
end;
$$;

create or replace function public.update_coach_booking_status(
  target_booking_id uuid,
  input_status text,
  input_reason text default null
)
returns public.coach_bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  booking_record public.coach_bookings%rowtype;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if input_status not in ('scheduled', 'confirmed', 'completed', 'cancelled', 'rescheduled', 'no_show') then
    raise exception 'Unsupported booking status.';
  end if;

  update public.coach_bookings
  set status = input_status,
      cancellation_reason = case when input_status = 'cancelled' then input_reason else cancellation_reason end,
      updated_at = timezone('utc', now())
  where id = target_booking_id
    and (coach_id = requester or member_id = requester)
  returning * into booking_record;

  if booking_record.id is null then
    raise exception 'Booking not found.';
  end if;

  return booking_record;
end;
$$;

grant execute on function public.seed_default_coach_session_types(uuid) to authenticated;
grant execute on function public.list_coach_session_types() to authenticated;
grant execute on function public.save_coach_session_type(uuid, text, text, integer, integer, integer, text, text, integer, integer, boolean) to authenticated;
grant execute on function public.list_coach_bookings(timestamptz, timestamptz, uuid) to authenticated;
grant execute on function public.list_coach_bookable_slots(uuid, uuid, date, date) to authenticated;
grant execute on function public.create_coach_booking(uuid, uuid, timestamptz, text, text) to authenticated;
grant execute on function public.update_coach_booking_status(uuid, text, text) to authenticated;
