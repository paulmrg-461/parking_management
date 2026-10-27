-- Dashboard numbers for the space configuration from 0047: how many cars
-- (cars + pickups), motorcycles and cars with keys are inside, next to each
-- limit. `0` capacity means "no limit" and the client hides the bar.

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
    car_capacity integer := 0;
    moto_capacity integer := 0;
    key_capacity integer := 0;
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

    select count(*) into keys_open
      from public.parking_sessions s
     where s.status = 'open'
       and s.lot_id = lot
       and s.left_keys;

    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.key_capacity, 0)
      into car_capacity, moto_capacity, key_capacity
      from public.parking_settings ps
     where ps.lot_id = lot;

    return jsonb_build_object(
        'car_open', car_open,
        'car_capacity', coalesce(car_capacity, 0),
        'moto_open', moto_open,
        'moto_capacity', coalesce(moto_capacity, 0),
        'car_reserved', car_reserved,
        'moto_reserved', moto_reserved,
        'keys_open', keys_open,
        'key_capacity', coalesce(key_capacity, 0)
    );
end;
$$;

grant execute on function public.capacity_snapshot() to authenticated;
