-- Offers created from the coach onboarding/editor flow were previously saved
-- as private drafts by default, which left the member-facing offers page empty.
-- Publish complete draft offers for coaches that do not already have a live
-- offer so existing accounts get a usable public storefront.
update public.coach_packages cp
set
  visibility_status = 'published',
  is_active = true,
  updated_at = timezone('utc', now())
where coalesce(cp.visibility_status, 'draft') = 'draft'
  and coalesce(cp.is_active, false) = false
  and nullif(trim(cp.title), '') is not null
  and nullif(trim(coalesce(cp.description, '')), '') is not null
  and cp.price > 0
  and not exists (
    select 1
    from public.coach_packages live
    where live.coach_id = cp.coach_id
      and live.visibility_status = 'published'
  );
