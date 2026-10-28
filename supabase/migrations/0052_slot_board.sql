-- Visual board of the site's spaces: open sessions (with plate/time/flags) and
-- active holds, grouped as cars+pickups, motorcycles and heavy vehicles.
-- Spaces are capacity counts today (no physical bay numbers yet), so the
-- client renders capacity cells and fills them with sessions and holds.

create or replace function public.slot_board()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    car_capacity integer := 0;
    moto_capacity integer := 0;
    sessions jsonb := '[]'::jsonb;
    holds jsonb := '[]'::jsonb;
begin
    perform public.require_app_user();

    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0)
      into car_capacity, moto_capacity
      from public.parking_settings ps
     where ps.lot_id = lot;

    select coalesce(
               jsonb_agg(item order by (item ->> 'entry_time')::timestamptz),
               '[]'::jsonb
           )
      into sessions
      from (
        select jsonb_build_object(
                   'session_id', s.id,
                   'plate', v.plate,
                   'entry_time', s.entry_time,
                   'left_keys', s.left_keys,
                   'photo_count', (
                       select count(*) from public.evidence_photos p
                        where p.session_id = s.id
                   ),
                   'has_pass', exists (
                       select 1 from public.monthly_passes mp
                        where mp.vehicle_id = s.vehicle_id
                          and mp.active
                          and mp.start_date <= (now() at time zone tz.name)::date
                          and mp.end_date >= (now() at time zone tz.name)::date
                   ),
                   'group', case
                       when lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv')
                           then 'car'
                       when lower(c.name) in ('moto', 'motos', 'motorcycle')
                           then 'moto'
                       else 'heavy'
                   end
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
          left join lateral (
              select coalesce(ps.business_timezone, 'America/Bogota') as name
                from public.parking_settings ps
               where ps.lot_id = s.lot_id
          ) tz on true
         where s.status = 'open'
           and s.lot_id = lot
      ) rows;

    select coalesce(
               jsonb_agg(item order by (item ->> 'reserved_until')::timestamptz),
               '[]'::jsonb
           )
      into holds
      from (
        select jsonb_build_object(
                   'plate', r.plate,
                   'reserved_until', r.reserved_until,
                   'group', case
                       when lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv')
                           then 'car'
                       when lower(c.name) in ('moto', 'motos', 'motorcycle')
                           then 'moto'
                       else 'heavy'
                   end
               ) as item
          from public.category_reservations r
          join public.categories c on c.id = r.category_id
         where r.lot_id = lot
           and r.status = 'active'
           and r.reserved_until > now()
      ) rows;

    return jsonb_build_object(
        'car_capacity', coalesce(car_capacity, 0),
        'moto_capacity', coalesce(moto_capacity, 0),
        'sessions', sessions,
        'holds', holds
    );
end;
$$;

grant execute on function public.slot_board() to authenticated;
