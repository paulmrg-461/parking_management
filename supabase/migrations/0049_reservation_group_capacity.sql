-- Space holds: active reservations also consume the configured group spaces.
-- A walk-in check-in and a new reservation both see the spots already promised
-- to reservations, so a site cannot oversell its car or motorcycle spaces.

create or replace function public.enforce_category_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    category integer;
    capacity integer;
    open_count integer;
    category_name text;
    reserved_count integer := 0;
    car_capacity integer := 0;
    moto_capacity integer := 0;
    key_capacity integer := 0;
    group_capacity integer := 0;
    is_car boolean;
    is_moto boolean;
begin
    select v.category_id into category from public.vehicles v where v.id = new.vehicle_id;
    if category is null then
        return new;
    end if;
    perform pg_advisory_xact_lock(hashtext('category:' || category));

    select c.capacity, lower(c.name) into capacity, category_name
      from public.categories c where c.id = category;

    if coalesce(capacity, 0) > 0 then
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where v.category_id = category
           and s.status = 'open';
        -- Active holds also consume the category's capacity.
        select count(*) into reserved_count
          from public.category_reservations r
         where r.category_id = category
           and r.lot_id = new.lot_id
           and r.status = 'active'
           and r.reserved_until > now();
        if open_count + reserved_count >= capacity then
            raise exception 'CategoryFullError';
        end if;
    end if;

    is_car := category_name in ('car', 'carro', 'auto', 'camioneta', 'suv');
    is_moto := category_name in ('moto', 'motos', 'motorcycle');

    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.key_capacity, 0)
      into car_capacity, moto_capacity, key_capacity
      from public.parking_settings ps
     where ps.lot_id = new.lot_id;

    group_capacity := case
        when is_car then car_capacity
        when is_moto then moto_capacity
        else 0
    end;

    if group_capacity > 0 then
        perform pg_advisory_xact_lock(
            hashtext('group:' || new.lot_id || ':' || category_name)
        );
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.status = 'open'
           and s.lot_id = new.lot_id
           and (
               (is_car and lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv'))
               or (is_moto and lower(c.name) in ('moto', 'motos', 'motorcycle'))
           );
        -- Holds for the same group are spots already promised to someone.
        select count(*) into reserved_count
          from public.category_reservations r
          join public.categories c on c.id = r.category_id
         where r.lot_id = new.lot_id
           and r.status = 'active'
           and r.reserved_until > now()
           and (
               (is_car and lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv'))
               or (is_moto and lower(c.name) in ('moto', 'motos', 'motorcycle'))
           );
        if open_count + reserved_count >= group_capacity then
            raise exception 'ParkingFullError';
        end if;
    end if;

    if new.left_keys and key_capacity > 0 then
        perform pg_advisory_xact_lock(hashtext('keys:' || new.lot_id));
        select count(*) into open_count
          from public.parking_sessions s
         where s.status = 'open'
           and s.lot_id = new.lot_id
           and s.left_keys;
        if open_count >= key_capacity then
            raise exception 'KeysFullError';
        end if;
    end if;

    return new;
end;
$$;

create or replace function public.create_reservation(
    p_plate text,
    p_category_id integer,
    p_until timestamptz,
    p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    capacity integer;
    open_count integer;
    reserved_count integer;
    category_name text;
    car_capacity integer := 0;
    moto_capacity integer := 0;
    group_capacity integer := 0;
    is_car boolean;
    is_moto boolean;
    reservation public.category_reservations%rowtype;
begin
    if normalized = '' then
        raise exception 'InvalidPlateError';
    end if;
    if p_category_id is null then
        raise exception 'CategoryNotFoundError';
    end if;
    if p_until is null or p_until <= now() then
        raise exception 'InvalidReservationWindowError';
    end if;

    perform pg_advisory_xact_lock(hashtext('category:' || p_category_id));

    select c.capacity, lower(c.name) into capacity, category_name
      from public.categories c
     where c.id = p_category_id
       and c.lot_id = public.current_lot_id();
    if not found then
        raise exception 'CategoryNotFoundError';
    end if;

    if exists (
        select 1 from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where v.plate = normalized and s.status = 'open'
    ) then
        raise exception 'VehicleAlreadyInsideError';
    end if;

    if coalesce(capacity, 0) > 0 then
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where v.category_id = p_category_id
           and s.status = 'open'
           and s.lot_id = public.current_lot_id();
        select count(*) into reserved_count
          from public.category_reservations r
         where r.category_id = p_category_id
           and r.lot_id = public.current_lot_id()
           and r.status = 'active'
           and r.reserved_until > now();
        if open_count + reserved_count >= capacity then
            raise exception 'CategoryFullError';
        end if;
    end if;

    is_car := category_name in ('car', 'carro', 'auto', 'camioneta', 'suv');
    is_moto := category_name in ('moto', 'motos', 'motorcycle');
    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0)
      into car_capacity, moto_capacity
      from public.parking_settings ps
     where ps.lot_id = public.current_lot_id();
    group_capacity := case
        when is_car then car_capacity
        when is_moto then moto_capacity
        else 0
    end;

    if group_capacity > 0 then
        perform pg_advisory_xact_lock(
            hashtext('group:' || public.current_lot_id() || ':' || category_name)
        );
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.status = 'open'
           and s.lot_id = public.current_lot_id()
           and (
               (is_car and lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv'))
               or (is_moto and lower(c.name) in ('moto', 'motos', 'motorcycle'))
           );
        select count(*) into reserved_count
          from public.category_reservations r
          join public.categories c on c.id = r.category_id
         where r.lot_id = public.current_lot_id()
           and r.status = 'active'
           and r.reserved_until > now()
           and (
               (is_car and lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv'))
               or (is_moto and lower(c.name) in ('moto', 'motos', 'motorcycle'))
           );
        if open_count + reserved_count >= group_capacity then
            raise exception 'ParkingFullError';
        end if;
    end if;

    insert into public.category_reservations (
        plate, category_id, reserved_until, notes, created_by, lot_id
    )
    values (
        normalized, p_category_id, p_until,
        nullif(btrim(coalesce(p_notes, '')), ''), actor, public.current_lot_id()
    )
    returning * into reservation;

    return jsonb_build_object(
        'id', reservation.id,
        'plate', reservation.plate,
        'category_id', reservation.category_id,
        'reserved_from', reservation.reserved_from,
        'reserved_until', reservation.reserved_until,
        'status', reservation.status,
        'lot_id', reservation.lot_id,
        'notes', reservation.notes
    );
end;
$$;
