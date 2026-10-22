-- Storage buckets replacing the local evidence/logo volumes once the client
-- uploads directly to Supabase Storage.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
    ('evidence', 'evidence', false, 5242880, array['image/jpeg', 'image/png']),
    ('branding', 'branding', true,  5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update
    set file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

-- Evidence photos: any signed-in operator may upload/read. Per-session
-- folder restrictions are added with the check-in RPC.
drop policy if exists evidence_objects_read on storage.objects;
create policy evidence_objects_read on storage.objects
    for select to authenticated
    using (bucket_id = 'evidence');

drop policy if exists evidence_objects_insert on storage.objects;
create policy evidence_objects_insert on storage.objects
    for insert to authenticated
    with check (bucket_id = 'evidence');

-- Branding: public read (login screen before auth), admin-only writes.
drop policy if exists branding_objects_public_read on storage.objects;
create policy branding_objects_public_read on storage.objects
    for select to public
    using (bucket_id = 'branding');

drop policy if exists branding_objects_admin_write on storage.objects;
create policy branding_objects_admin_write on storage.objects
    for all to authenticated
    using (bucket_id = 'branding' and public.is_admin())
    with check (bucket_id = 'branding' and public.is_admin());
