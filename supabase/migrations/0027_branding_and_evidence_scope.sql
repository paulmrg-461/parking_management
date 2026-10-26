-- Branding and evidence were still global after the lot migration.
--
-- 1. The logo is per lot: the RPC updates the active lot's settings row and is
--    restricted to that lot's admins (platform admins included).
-- 2. Evidence photos live in a shared bucket; reads are now limited to
--    sessions of the active lot instead of every authenticated user.

create or replace function public.set_branding_logo(p_path text)
returns public.parking_settings
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    updated public.parking_settings%rowtype;
begin
    if nullif(btrim(coalesce(p_path, '')), '') is null then
        raise exception 'InvalidDataError';
    end if;

    update public.parking_settings
       set logo_path = btrim(p_path),
           logo_version = logo_version + 1,
           updated_at = now()
     where lot_id = lot
     returning * into updated;

    if not found then
        raise exception 'NotFoundError';
    end if;
    return updated;
end;
$$;

grant execute on function public.set_branding_logo(text) to authenticated;

-- Evidence objects are readable only when the path belongs to a session of
-- the active lot; a stolen path is useless outside its site.
drop policy if exists evidence_objects_read on storage.objects;
create policy evidence_objects_read on storage.objects
    for select to authenticated
    using (
        bucket_id = 'evidence'
        and exists (
            select 1
              from public.evidence_photos p
              join public.parking_sessions s on s.id = p.session_id
             where p.file_path = storage.objects.name
               and s.lot_id = public.current_lot_id()
        )
    );

-- Uploads happen BEFORE the session row exists (the check-in RPC stores the
-- paths), so the insert policy stays per-authenticated-user but is limited to
-- the evidence bucket and a sane path shape.
drop policy if exists evidence_objects_insert on storage.objects;
create policy evidence_objects_insert on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'evidence'
        and name ~ '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'
    );
