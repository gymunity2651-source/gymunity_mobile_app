-- Coach Relationship Core parity audit.
-- Run against local or linked Supabase to verify object-level backend parity.
-- This script is read-only.

with required_tables(name) as (
  values
    ('coach_checkout_requests'),
    ('coach_payment_receipts'),
    ('coach_payment_audit_events'),
    ('coach_member_threads'),
    ('coach_messages'),
    ('weekly_checkins'),
    ('progress_photos'),
    ('coach_client_records'),
    ('coach_client_notes'),
    ('coach_automation_events'),
    ('coach_program_templates'),
    ('coach_exercise_library'),
    ('member_habit_assignments'),
    ('coach_resources'),
    ('coach_resource_assignments'),
    ('coach_onboarding_templates'),
    ('coach_onboarding_applications'),
    ('coach_session_types'),
    ('coach_bookings'),
    ('coach_member_visibility_settings'),
    ('coach_member_visibility_audit'),
    ('member_product_recommendations')
)
select
  'table' as object_type,
  rt.name as object_name,
  case when c.oid is null then 'missing' else 'exists' end as status,
  coalesce(c.relrowsecurity, false) as rls_enabled
from required_tables rt
left join pg_class c
  on c.relname = rt.name
 and c.relnamespace = 'public'::regnamespace
 and c.relkind in ('r', 'p')
order by rt.name;

with required_functions(name, args) as (
  values
    ('create_coach_checkout', 'uuid, text, text, jsonb'),
    ('submit_coach_payment_receipt', 'uuid, text, text, numeric'),
    ('verify_coach_payment', 'uuid, text'),
    ('fail_coach_payment', 'uuid, text'),
    ('ensure_coach_member_thread', 'uuid'),
    ('send_coaching_message', 'uuid, text'),
    ('submit_weekly_checkin', 'uuid, date, numeric, numeric, integer, integer, integer, text, text, text, jsonb'),
    ('submit_coach_checkin_feedback', 'uuid, uuid, text'),
    ('upsert_coach_member_visibility', 'uuid, uuid, boolean, boolean, boolean, boolean, boolean, boolean'),
    ('get_member_visibility_settings', 'uuid'),
    ('get_coach_member_insight', 'uuid, uuid'),
    ('list_coach_member_insight_summaries', ''),
    ('list_visibility_audit', 'uuid'),
    ('save_coach_resource', 'uuid, text, text, text, text, text, text[]'),
    ('assign_resource_to_client', 'uuid, uuid, text'),
    ('save_coach_session_type', 'uuid, text, text, integer, integer, integer, text, text, integer, integer, boolean'),
    ('create_coach_booking', 'uuid, uuid, timestamptz, text, text'),
    ('update_coach_booking_status', 'uuid, text, text'),
    ('upsert_coach_client_record', 'uuid, text, text, text, text[], text, text, timestamptz'),
    ('add_coach_client_note', 'uuid, text, text, boolean'),
    ('save_coach_program_template', 'uuid, text, text, text, integer, text, text, text[], jsonb'),
    ('assign_program_template_to_client', 'uuid, uuid, date, time'),
    ('assign_client_habits', 'uuid, jsonb'),
    ('apply_coach_onboarding_flow', 'uuid, uuid'),
    ('dismiss_coach_action_item', 'uuid')
)
select
  'function' as object_type,
  rf.name || '(' || rf.args || ')' as object_name,
  case when p.oid is null then 'missing' else 'exists' end as status,
  p.prosecdef as security_definer
from required_functions rf
left join pg_proc p
  on p.proname = rf.name
 and p.pronamespace = 'public'::regnamespace
 and pg_get_function_identity_arguments(p.oid) = rf.args
order by rf.name, rf.args;

select
  'bucket' as object_type,
  expected.id as object_name,
  case when b.id is null then 'missing' else 'exists' end as status,
  coalesce(b.public, true) as is_public
from (values ('coach-payment-receipts'), ('coach-resources')) expected(id)
left join storage.buckets b on b.id = expected.id
order by expected.id;

select
  'policy' as object_type,
  schemaname || '.' || tablename || ':' || policyname as object_name,
  cmd as status,
  permissive,
  roles
from pg_policies
where schemaname in ('public', 'storage')
  and (
    tablename in (
      'coach_checkout_requests',
      'coach_payment_receipts',
      'coach_payment_audit_events',
      'coach_member_threads',
      'coach_messages',
      'weekly_checkins',
      'progress_photos',
      'coach_member_visibility_settings',
      'coach_member_visibility_audit',
      'coach_resources',
      'coach_resource_assignments',
      'coach_bookings'
    )
    or (schemaname = 'storage' and tablename = 'objects')
  )
order by schemaname, tablename, policyname;

select
  'constraint' as object_type,
  conrelid::regclass::text || ':' || conname as object_name,
  contype::text as status,
  pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid in (
  'public.subscriptions'::regclass,
  'public.coach_member_threads'::regclass,
  'public.weekly_checkins'::regclass,
  'public.coach_messages'::regclass,
  'public.coach_payment_receipts'::regclass
)
order by conrelid::regclass::text, conname;

select
  'index' as object_type,
  schemaname || '.' || indexname as object_name,
  tablename as status,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename in (
    'subscriptions',
    'coach_checkout_requests',
    'coach_payment_receipts',
    'coach_payment_audit_events',
    'coach_member_threads',
    'coach_messages',
    'weekly_checkins',
    'progress_photos'
  )
order by tablename, indexname;
