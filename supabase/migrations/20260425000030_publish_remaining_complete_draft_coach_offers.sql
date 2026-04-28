-- Follow-up backfill for complete coach offers that were saved as drafts by
-- the previous client default. A complete offer should be visible to members
-- unless the coach explicitly archives it later.
update public.coach_packages cp
set
  visibility_status = 'published',
  is_active = true,
  updated_at = timezone('utc', now())
where coalesce(cp.visibility_status, 'draft') = 'draft'
  and nullif(trim(cp.title), '') is not null
  and nullif(trim(coalesce(cp.description, '')), '') is not null
  and cp.price > 0;
