-- The check-out list flags cars covered by an active monthly pass, so the
-- operator sees it before opening the payment dialog. Same rule as
-- check_out_preview, evaluated at read time.

create or replace view public.open_sessions_view
with (security_invoker = true) as
select
    s.id,
    s.vehicle_id,
    v.plate,
    s.entry_time,
    s.status,
    (select count(*) from public.evidence_photos p where p.session_id = s.id) as photo_count,
    exists (
        select 1
          from public.monthly_passes mp
         where mp.vehicle_id = s.vehicle_id
           and mp.active
           and mp.start_date <= (now() at time zone coalesce(tz.name, 'America/Bogota'))::date
           and mp.end_date >= (now() at time zone coalesce(tz.name, 'America/Bogota'))::date
    ) as has_pass
from public.parking_sessions s
join public.vehicles v on v.id = s.vehicle_id
left join lateral (
    select ps.business_timezone as name
      from public.parking_settings ps
     where ps.lot_id = s.lot_id
) tz on true
where s.status = 'open';

grant select on public.open_sessions_view to authenticated;
