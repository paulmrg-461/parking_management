-- The storage policy runs as `authenticated`, so an inline subquery over
-- `evidence_photos` would be filtered by that table's RLS (which requires the
-- x-lot-id header Storage cannot forward). A security-definer helper keeps the
-- check inside trusted code.

create or replace function public.can_read_evidence(p_path text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
          from public.evidence_photos p
          join public.parking_sessions s on s.id = p.session_id
         where p.file_path = p_path
           and public.is_lot_member(s.lot_id)
    );
$$;

grant execute on function public.can_read_evidence(text) to authenticated;

drop policy if exists evidence_objects_read on storage.objects;
create policy evidence_objects_read on storage.objects
    for select to authenticated
    using (bucket_id = 'evidence' and public.can_read_evidence(name));
