-- The map editor needs the configured target, not the derived capacity: once
-- bays exist, `car_capacity` reports how many are drawn. Expose both.

create or replace function public.capacity_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    car_open bigint;
    moto_open bigint;
    keys_open bigint;
    car_reserved bigint;
    moto_reserved bigint;
    reservations_active bigint;
    reservations_expiring bigint;
    car_capacity integer := 0;
    moto_capacity integer := 0;
    car_settings integer := 0;
    moto_settings integer := 0;
    key_capacity integer := 0;
    car_out integer := 0;
    moto_out integer := 0;
    car_spots integer := 0;
    car_active integer := 0;
    moto_spots integer := 0;
    moto_active integer := 0;
begin
    perform public.require_app_user();

    select count(*) into car_open
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.categories c on c.id = v.category_id
     where s.status = 'open'
       and s.lot_id = lot
       and lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv');

    select count(*) into moto_open
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.categories c on c.id = v.category_id
     where s.status = 'open'
       and s.lot_id = lot
       and lower(c.name) in ('moto', 'motos', 'motorcycle');

    select count(*) into car_reserved
      from public.category_reservations r
      join public.categories c on c.id = r.category_id
     where r.status = 'active'
       and r.reserved_until > now()
       and r.lot_id = lot
       and lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv');

    select count(*) into moto_reserved
      from public.category_reservations r
      join public.categories c on c.id = r.category_id
     where r.status = 'active'
       and r.reserved_until > now()
       and r.lot_id = lot
       and lower(c.name) in ('moto', 'motos', 'motorcycle');

    select count(*) into reservations_active
      from public.category_reservations r
     where r.status = 'active'
       and r.reserved_until > now()
       and r.lot_id = lot;

    select count(*) into reservations_expiring
      from public.category_reservations r
     where r.status = 'active'
       and r.reserved_until > now()
       and r.reserved_until <= now() + interval '2 hours'
       and r.lot_id = lot;

    select count(*) into keys_open
      from public.parking_sessions s
     where s.status = 'open'
       and s.lot_id = lot
       and s.left_keys;

    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.key_capacity, 0),
           coalesce(ps.car_out_of_service, 0),
           coalesce(ps.moto_out_of_service, 0)
      into car_capacity, moto_capacity, key_capacity, car_out, moto_out
      from public.parking_settings ps
     where ps.lot_id = lot;

    select count(*), count(*) filter (where status = 'active')
      into car_spots, car_active
      from public.parking_spots sp
     where sp.lot_id = lot and sp.group_name = 'car';

    select count(*), count(*) filter (where status = 'active')
      into moto_spots, moto_active
      from public.parking_spots sp
     where sp.lot_id = lot and sp.group_name = 'moto';

    car_settings := car_capacity;
    moto_settings := moto_capacity;

    if car_spots > 0 then
        car_capacity := car_spots;
        car_out := car_spots - car_active;
    end if;
    if moto_spots > 0 then
        moto_capacity := moto_spots;
        moto_out := moto_spots - moto_active;
    end if;

    return jsonb_build_object(
        'car_open', car_open,
        'car_capacity', coalesce(car_capacity, 0),
        'car_available', case
            when car_spots > 0 then car_active
            else public.usable_capacity(car_capacity, car_out)
        end,
        'car_out_of_service', coalesce(car_out, 0),
        'car_target_capacity', coalesce(car_settings, 0),
        'moto_open', moto_open,
        'moto_capacity', coalesce(moto_capacity, 0),
        'moto_available', case
            when moto_spots > 0 then moto_active
            else public.usable_capacity(moto_capacity, moto_out)
        end,
        'moto_out_of_service', coalesce(moto_out, 0),
        'moto_target_capacity', coalesce(moto_settings, 0),
        'reservations_active', reservations_active,
        'reservations_expiring', reservations_expiring,
        'car_reserved', car_reserved,
        'moto_reserved', moto_reserved,
        'keys_open', keys_open,
        'key_capacity', coalesce(key_capacity, 0)
    );
end;
$$;

grant execute on function public.capacity_snapshot() to authenticated;
