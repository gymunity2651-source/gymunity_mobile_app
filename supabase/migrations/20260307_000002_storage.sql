-- GymUnity storage buckets and policies

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', false),
  ('product-images', 'product-images', true)
on conflict (id) do update set
  name = excluded.name,
  public = excluded.public;

-- avatars: owner-only access
drop policy if exists avatars_select_own on storage.objects;
create policy avatars_select_own
on storage.objects for select
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
);

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
);

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
);

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 2) = auth.uid()::text
);

-- product-images: seller-owned writes, public reads
drop policy if exists product_images_public_read on storage.objects;
create policy product_images_public_read
on storage.objects for select
to public
using (bucket_id = 'product-images');

drop policy if exists product_images_insert_own on storage.objects;
create policy product_images_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists product_images_update_own on storage.objects;
create policy product_images_update_own
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-images'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'product-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists product_images_delete_own on storage.objects;
create policy product_images_delete_own
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

