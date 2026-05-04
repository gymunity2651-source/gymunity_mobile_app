alter table public.member_product_recommendations
  add column if not exists why_recommended text,
  add column if not exists priority text check (
    priority is null or priority in ('low', 'medium', 'high')
  ),
  add column if not exists recommendation_payload_json jsonb not null default '{}'::jsonb;
