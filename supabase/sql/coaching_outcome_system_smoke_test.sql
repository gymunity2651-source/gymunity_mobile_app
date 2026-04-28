-- Smoke checks for the coaching outcome system migration.
-- Run against a seeded local Supabase database after auth test users exist.

begin;

select public.derive_coaching_relationship_stage(id) as relationship_stage
from public.subscriptions
order by created_at desc
limit 5;

select *
from public.get_member_coach_hub(
  (select id from public.subscriptions where status = 'active' limit 1)
);

select *
from public.list_member_coach_agenda(
  (select id from public.subscriptions where status = 'active' limit 1),
  current_date,
  current_date + 7
);

select *
from public.list_member_assigned_habits(
  (select id from public.subscriptions where status = 'active' limit 1),
  current_date
);

select *
from public.list_member_assigned_resources(
  (select id from public.subscriptions where status = 'active' limit 1)
);

select *
from public.list_member_bookable_session_types(
  (select id from public.subscriptions where status = 'active' limit 1)
);

select event_type, severity, title, subscription_id, due_at
from public.list_coach_action_items()
limit 20;

rollback;
