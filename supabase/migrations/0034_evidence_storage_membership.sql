-- Storage API requests do not forward the `x-lot-id` header, so a policy that
-- calls `current_lot_id()` breaks authenticated downloads (LotRequiredError).
-- Evidence access is scoped by membership instead: the object must belong to a
-- session of a lot the signed-in user belongs to.

create or replace function public.is_lot_member(p_lot_id integer)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.lot_members lm
         where lm.user_id = public.current_app_user_id()
           and lm.lot_id = p_lot_id
    );
$$;

grant execute on function public.is_lot_member(integer) to authenticated;

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
               and public.is_lot_member(s.lot_id)
        )
    );
