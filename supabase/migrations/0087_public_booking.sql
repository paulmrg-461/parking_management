-- Public booking: an anonymous customer page needs to see real availability
-- and create a hold without an app account. The capacity rules are shared with
-- the operator path (reservation_capacity_check), so both can never oversell.
--
-- Abuse guards on the public path: one active hold per plate/lot, at most two
-- active public holds per phone, a 10-minute minimum window and 24-hour cap,
-- and a required phone number for contact. A public page can still be hit by
-- someone cycling phones; add a captcha/proof-of-work at the edge if the site
-- is exposed to the open internet.

alter table public.category_reservations
    add column if not exists customer_name varchar(120);
alter table public.category_reservations
    add column if not exists customer_phone varchar(20);
alter table public.category_reservations
    add column if not exists source text not null default 'app';

alter table public.category_reservations
    drop constraint if exists category_reservations_phone_check;
alter table public.category_reservations
    add constraint category_reservations_phone_check
    check (
        customer_phone is null
        or length(regexp_replace(customer_phone, '\D', '', 'g')) between 7 and 15
    );

alter table public.category_reservations
    drop constraint if exists category_reservations_source_check;
alter table public.category_reservations
    add constraint category_reservations_source_check
    check (source in ('app', 'public'));

create index if not exists ix_reservations_phone_active
    on public.category_reservations(lot_id, customer_phone)
    where status = 'active';
create index if not exists ix_reservations_plate_active
    on public.category_reservations(lot_id, plate)
    where status = 'active';

-- ---------------------------------------------------------------------------
-- Shared capacity check: category + group (cars/pickups, motorcycles), with
-- the same locks and order as check-in. Raises the existing domain errors.
-- ---------------------------------------------------------------------------
create or replace function public.reservation_capacity_check(
    p_lot integer,
    p_category_id integer,
    p_plate text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    capacity integer;
    open_count integer;
    reserved_count integer;
    category_name text;
    car_capacity integer := 0;
    moto_capacity integer := 0;
    car_out integer := 0;
    moto_out integer := 0;
    spots_total integer := 0;
    spots_active integer := 0;
    spot_group text;
    group_configured boolean := false;
    group_capacity integer := 0;
    is_car boolean;
    is_moto boolean;
begin
    if normalized = '' then
        raise exception 'InvalidPlateError';
    end if;
    if p_lot is null or p_category_id is null then
        raise exception 'CategoryNotFoundError';
    end if;

    select lower(c.name) into category_name
      from public.categories c
     where c.id = p_category_id
       and c.lot_id = p_lot;
    if not found then
        raise exception 'CategoryNotFoundError';
    end if;
    spot_group := public.category_group(category_name);

    -- Same keys and order as check_in → enforce_category_capacity:
    -- group first, then category (no ABBA deadlock, no oversell).
    perform pg_advisory_xact_lock(hashtext('group:' || p_lot || ':' || spot_group));
    perform pg_advisory_xact_lock(hashtext('category:' || p_category_id));

    select c.capacity into capacity
      from public.categories c
     where c.id = p_category_id;

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
           and s.lot_id = p_lot;
        select count(*) into reserved_count
          from public.category_reservations r
         where r.category_id = p_category_id
           and r.lot_id = p_lot
           and r.status = 'active'
           and r.reserved_until > now();
        if open_count + reserved_count >= capacity then
            raise exception 'CategoryFullError';
        end if;
    end if;

    is_car := category_name in ('car', 'carro', 'auto', 'camioneta', 'suv');
    is_moto := category_name in ('moto', 'motos', 'motorcycle');
    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.car_out_of_service, 0),
           coalesce(ps.moto_out_of_service, 0)
      into car_capacity, moto_capacity, car_out, moto_out
      from public.parking_settings ps
     where ps.lot_id = p_lot;

    select count(*), count(*) filter (where status = 'active')
      into spots_total, spots_active
      from public.parking_spots sp
     where sp.lot_id = p_lot
       and sp.group_name = spot_group;

    if spots_total > 0 then
        group_configured := true;
        group_capacity := spots_active;
    else
        group_configured := case
            when is_car then car_capacity > 0
            when is_moto then moto_capacity > 0
            else false
        end;
        group_capacity := case
            when is_car then public.usable_capacity(car_capacity, car_out)
            when is_moto then public.usable_capacity(moto_capacity, moto_out)
            else 0
        end;
    end if;

    if group_configured then
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.status = 'open'
           and s.lot_id = p_lot
           and public.category_group(c.name) = spot_group;
        select count(*) into reserved_count
          from public.category_reservations r
          join public.categories c on c.id = r.category_id
         where r.lot_id = p_lot
           and r.status = 'active'
           and r.reserved_until > now()
           and public.category_group(c.name) = spot_group;
        if open_count + reserved_count >= group_capacity then
            raise exception 'ParkingFullError';
        end if;
    end if;
end;
$$;

revoke all on function public.reservation_capacity_check(integer, integer, text)
    from public;
grant execute on function public.reservation_capacity_check(integer, integer, text)
    to authenticated;

-- ---------------------------------------------------------------------------
-- Operator path now delegates the capacity rules to the shared helper.
-- ---------------------------------------------------------------------------
create or replace function public.create_reservation(
    p_plate text,
    p_category_id integer,
    p_until timestamp with time zone,
    p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
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

    perform public.reservation_capacity_check(lot, p_category_id, normalized);

    insert into public.category_reservations (
        plate, category_id, reserved_until, notes, created_by, lot_id
    )
    values (
        normalized, p_category_id, p_until,
        nullif(btrim(coalesce(p_notes, '')), ''), actor, lot
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

grant execute on function public.create_reservation(
    text, integer, timestamp with time zone, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- Public availability for the customer page: site identity (no plates) and
-- one row per active category with the effective category/group availability.
-- ---------------------------------------------------------------------------
create or replace function public.public_availability(p_lot_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot public.parking_lots%rowtype;
    settings public.parking_settings%rowtype;
    category public.categories%rowtype;
    tz text;
    spot_group text;
    group_configured boolean;
    group_capacity integer;
    spots_total integer;
    open_cat integer;
    reserved_cat integer;
    open_group integer;
    reserved_group integer;
    available integer;
    group_available integer;
    items jsonb := '[]'::jsonb;
begin
    select * into lot
      from public.parking_lots l
     where l.id = p_lot_id and l.active;
    if not found then
        return null;
    end if;
    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;
    tz := coalesce(settings.business_timezone, lot.timezone, 'America/Bogota');

    for category in
        select * from public.categories c
         where c.lot_id = p_lot_id
         order by c.id
    loop
        spot_group := public.category_group(category.name);
        select count(*) into spots_total
          from public.parking_spots sp
         where sp.lot_id = p_lot_id
           and sp.group_name = spot_group;
        if spots_total > 0 then
            group_configured := true;
            select count(*) into group_capacity
              from public.parking_spots sp
             where sp.lot_id = p_lot_id
               and sp.group_name = spot_group
               and sp.status = 'active';
        else
            group_configured := case
                when spot_group = 'car' then coalesce(settings.car_capacity, 0) > 0
                when spot_group = 'moto' then coalesce(settings.moto_capacity, 0) > 0
                else false
            end;
            group_capacity := case
                when spot_group = 'car' then public.usable_capacity(
                    coalesce(settings.car_capacity, 0),
                    coalesce(settings.car_out_of_service, 0)
                )
                when spot_group = 'moto' then public.usable_capacity(
                    coalesce(settings.moto_capacity, 0),
                    coalesce(settings.moto_out_of_service, 0)
                )
                else 0
            end;
        end if;

        select count(*) into open_cat
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where s.lot_id = p_lot_id
           and s.status = 'open'
           and v.category_id = category.id;
        select count(*) into reserved_cat
          from public.category_reservations r
         where r.lot_id = p_lot_id
           and r.category_id = category.id
           and r.status = 'active'
           and r.reserved_until > now();

        available := null;
        if coalesce(category.capacity, 0) > 0 then
            available := greatest(category.capacity - open_cat - reserved_cat, 0);
        end if;

        if group_configured then
            select count(*) into open_group
              from public.parking_sessions s
              join public.vehicles v on v.id = s.vehicle_id
              join public.categories c on c.id = v.category_id
             where s.lot_id = p_lot_id
               and s.status = 'open'
               and public.category_group(c.name) = spot_group;
            select count(*) into reserved_group
              from public.category_reservations r
              join public.categories c on c.id = r.category_id
             where r.lot_id = p_lot_id
               and r.status = 'active'
               and r.reserved_until > now()
               and public.category_group(c.name) = spot_group;
            group_available := greatest(group_capacity - open_group - reserved_group, 0);
            if available is null or group_available < available then
                available := group_available;
            end if;
        end if;

        items := items || jsonb_build_object(
            'id', category.id,
            'name', category.name,
            'group', spot_group,
            'category_capacity', coalesce(category.capacity, 0),
            'group_capacity', case when group_configured then group_capacity else 0 end,
            'occupied', open_cat,
            'reserved', reserved_cat,
            'available', available,
            'is_full', available is not null and available <= 0
        );
    end loop;

    return jsonb_build_object(
        'lot', jsonb_build_object(
            'id', lot.id,
            'name', lot.name,
            'address', coalesce(settings.address, ''),
            'schedule', coalesce(settings.schedule, ''),
            'phone', coalesce(settings.phone, ''),
            'whatsapp', coalesce(settings.whatsapp, ''),
            'logo_path', coalesce(settings.logo_path, ''),
            'timezone', tz,
            'currency', coalesce(settings.currency, 'COP')
        ),
        'max_reservation_hours', 24,
        'categories', items
    );
end;
$$;

grant execute on function public.public_availability(integer) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Anonymous reservation creation, with the public abuse guards.
-- ---------------------------------------------------------------------------
create or replace function public.public_create_reservation(
    p_lot_id integer,
    p_plate text,
    p_category_id integer,
    p_until timestamp with time zone,
    p_customer_name text default null,
    p_customer_phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot public.parking_lots%rowtype;
    settings public.parking_settings%rowtype;
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    customer_name text := nullif(btrim(coalesce(p_customer_name, '')), '');
    phone_digits text := regexp_replace(coalesce(p_customer_phone, ''), '\D', '', 'g');
    category_name text;
    reservation public.category_reservations%rowtype;
begin
    select * into lot
      from public.parking_lots l
     where l.id = p_lot_id and l.active;
    if not found then
        raise exception 'LotNotFoundError';
    end if;
    if normalized !~ '^[A-Z0-9-]{3,20}$' then
        raise exception 'InvalidPlateError';
    end if;
    if length(phone_digits) < 7 or length(phone_digits) > 15 then
        raise exception 'InvalidPhoneError';
    end if;
    if customer_name is not null and length(customer_name) > 120 then
        raise exception 'InvalidDataError';
    end if;
    if p_until is null
       or p_until <= now() + interval '10 minutes'
       or p_until > now() + interval '24 hours' then
        raise exception 'InvalidReservationWindowError';
    end if;

    select lower(c.name) into category_name
      from public.categories c
     where c.id = p_category_id
       and c.lot_id = p_lot_id;
    if not found then
        raise exception 'CategoryNotFoundError';
    end if;

    perform public.reservation_capacity_check(p_lot_id, p_category_id, normalized);

    if exists (
        select 1
          from public.category_reservations r
         where r.lot_id = p_lot_id
           and r.plate = normalized
           and r.status = 'active'
           and r.reserved_until > now()
    ) then
        raise exception 'ReservationExistsError';
    end if;

    if (
        select count(*)
          from public.category_reservations r
         where r.lot_id = p_lot_id
           and r.customer_phone = phone_digits
           and r.status = 'active'
           and r.reserved_until > now()
    ) >= 2 then
        raise exception 'ReservationLimitError';
    end if;

    insert into public.category_reservations (
        plate, category_id, reserved_until, notes, created_by, lot_id,
        customer_name, customer_phone, source
    )
    values (
        normalized, p_category_id, p_until, null, null, p_lot_id,
        customer_name, phone_digits, 'public'
    )
    returning * into reservation;

    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;

    return jsonb_build_object(
        'id', reservation.id,
        'plate', reservation.plate,
        'category_id', reservation.category_id,
        'category_name', category_name,
        'reserved_until', reservation.reserved_until,
        'status', reservation.status,
        'lot', jsonb_build_object(
            'id', lot.id,
            'name', lot.name,
            'address', coalesce(settings.address, ''),
            'phone', coalesce(settings.phone, ''),
            'whatsapp', coalesce(settings.whatsapp, '')
        )
    );
end;
$$;

grant execute on function public.public_create_reservation(
    integer, text, integer, timestamp with time zone, text, text
) to anon, authenticated;
