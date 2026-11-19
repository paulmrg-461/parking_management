-- Public booking, part 11: the grace window is a site setting. `0` turns it
-- off (a hold stops counting exactly on time), 120 is the ceiling. The value
-- lives once, in `parking_settings`, and every rule reads it: capacity,
-- public availability, check-in and the board.

alter table public.parking_settings
    add column if not exists reservation_grace_minutes integer not null default 15;

alter table public.parking_settings
    drop constraint if exists parking_settings_grace_check;
alter table public.parking_settings
    add constraint parking_settings_grace_check
    check (reservation_grace_minutes between 0 and 120);

drop function if exists public.reservation_grace();

create or replace function public.reservation_grace(p_lot integer)
returns interval
language sql
stable
set search_path = public
as $$
    select make_interval(mins => coalesce((
        select ps.reservation_grace_minutes
          from public.parking_settings ps
         where ps.lot_id = p_lot
    ), 15));
$$;

create or replace function public.check_in(p_plate text, p_category_id integer DEFAULT NULL::integer, p_color text DEFAULT NULL::text, p_brand text DEFAULT NULL::text, p_photos jsonb DEFAULT '[]'::jsonb, p_idempotency_key text DEFAULT NULL::text, p_client_entry_time timestamp with time zone DEFAULT NULL::timestamp with time zone, p_lot_id integer DEFAULT NULL::integer, p_left_keys boolean DEFAULT false, p_spot_id integer DEFAULT NULL::integer, p_videos jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
declare
    operator_id integer := public.require_app_user();
    lot_value integer := public.resolve_lot(p_lot_id);
    normalized_plate text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    vehicle public.vehicles%rowtype;
    session public.parking_sessions%rowtype;
    entry_at timestamptz;
    response jsonb;
    replay jsonb;
    photo jsonb;
    photo_count integer := 0;
    video jsonb;
    video_count integer := 0;
    category_name text;
    spot_group text;
    spot public.parking_spots%rowtype;
    chosen_spot integer;
    spots_total integer := 0;
begin
    if normalized_plate = '' then
        raise exception 'VehicleNotFoundError';
    end if;

    if p_idempotency_key is not null then
        replay := public.replay_idempotent(p_idempotency_key, operator_id, 'rpc/check_in');
        if replay is not null then
            return replay;
        end if;
    end if;

    if p_client_entry_time is not null and p_client_entry_time > now() + interval '5 minutes' then
        raise exception 'InvalidEntryTimeError';
    end if;
    entry_at := coalesce(p_client_entry_time, now());

    select * into vehicle from public.vehicles v where v.plate = normalized_plate;
    if not found then
        if p_category_id is null then
            raise exception 'VehicleNotRegisteredError';
        end if;
        if not exists (
            select 1 from public.categories c
             where c.id = p_category_id
               and c.lot_id = lot_value
        ) then
            raise exception 'CategoryNotFoundError';
        end if;
        insert into public.vehicles (plate, category_id, color, brand, created_by)
        values (normalized_plate, p_category_id, p_color, p_brand, operator_id)
        on conflict (plate) do update set plate = excluded.plate
        returning * into vehicle;
    end if;

    if not exists (
        select 1 from public.categories c
         where c.id = vehicle.category_id
           and c.lot_id = lot_value
    ) then
        if p_category_id is not null and exists (
            select 1 from public.categories c
             where c.id = p_category_id
               and c.lot_id = lot_value
        ) then
            vehicle.category_id := p_category_id;
        else
            select c2.id into vehicle.category_id
              from public.categories c2
              join public.categories c1 on c1.name = c2.name
             where c1.id = vehicle.category_id
               and c2.lot_id = lot_value
             limit 1;
            if vehicle.category_id is null then
                raise exception 'CategoryNotFoundError';
            end if;
        end if;
        update public.vehicles
           set category_id = vehicle.category_id
         where id = vehicle.id;
    end if;

    if vehicle.is_blacklisted then
        raise exception 'VehicleBlacklistedError';
    end if;

    if exists (
        select 1 from public.parking_sessions s
         where s.vehicle_id = vehicle.id and s.status = 'open'
    ) then
        raise exception 'DuplicateOpenSessionError';
    end if;

    select c.name into category_name
      from public.categories c
     where c.id = vehicle.category_id;
    spot_group := public.category_group(category_name);

    -- Serialize spot selection for the group (the capacity guard locks the
    -- same key later, so ordering is stable).
    perform pg_advisory_xact_lock(
        hashtext('group:' || lot_value || ':' || spot_group)
    );

    if p_spot_id is not null then
        select * into spot
          from public.parking_spots sp
         where sp.id = p_spot_id
           and sp.lot_id = lot_value
         for update;
        if not found then
            raise exception 'SpotNotFoundError';
        end if;
        if spot.group_name <> spot_group then
            raise exception 'SpotGroupMismatchError';
        end if;
        if spot.status <> 'active' then
            raise exception 'SpotOutOfServiceError';
        end if;
        if exists (
            select 1 from public.parking_sessions s
             where s.status = 'open' and s.spot_id = spot.id
        ) then
            raise exception 'SpotTakenError';
        end if;
        chosen_spot := spot.id;
    else
        select count(*) into spots_total
          from public.parking_spots sp
         where sp.lot_id = lot_value
           and sp.group_name = spot_group;

        if spots_total > 0 then
            select sp.* into spot
              from public.parking_spots sp
             where sp.lot_id = lot_value
               and sp.group_name = spot_group
               and sp.status = 'active'
               and not exists (
                   select 1 from public.parking_sessions s
                    where s.status = 'open' and s.spot_id = sp.id
               )
             order by sp.grid_row, sp.grid_col
             limit 1
             for update;
            if not found then
                raise exception 'ParkingFullError';
            end if;
            chosen_spot := spot.id;
        end if;
    end if;

    -- A reservation for this plate holds a slot: close it before the capacity
    -- trigger counts active reservations, so the car converts its hold into
    -- an occupied slot instead of being rejected.
    update public.category_reservations
       set status = 'used'
     where plate = vehicle.plate
       and lot_id = lot_value
       and status = 'active'
       and reserved_until + public.reservation_grace(lot_value) > now();

    begin
        insert into public.parking_sessions (
            vehicle_id, operator_id, entry_time, status, lot_id, left_keys, spot_id
        )
        values (
            vehicle.id, operator_id, entry_at, 'open', lot_value,
            coalesce(p_left_keys, false), chosen_spot
        )
        returning * into session;
    exception when unique_violation then
        raise exception 'DuplicateOpenSessionError';
    end;

    for photo in select * from jsonb_array_elements(coalesce(p_photos, '[]'::jsonb)) loop
        perform public.require_evidence_object(photo ->> 'path');
        insert into public.evidence_photos (session_id, file_path, taken_at)
        values (
            session.id,
            photo ->> 'path',
            coalesce((photo ->> 'taken_at')::timestamptz, now())
        );
        photo_count := photo_count + 1;
    end loop;

    for video in select * from jsonb_array_elements(coalesce(p_videos, '[]'::jsonb)) loop
        perform public.require_evidence_object(video ->> 'path');
        insert into public.evidence_photos (
            session_id, file_path, taken_at, kind, duration_seconds
        )
        values (
            session.id,
            video ->> 'path',
            coalesce((video ->> 'taken_at')::timestamptz, now()),
            'video',
            nullif(video ->> 'duration_seconds', '')::integer
        );
        video_count := video_count + 1;
    end loop;

    response := jsonb_build_object(
        'id', session.id,
        'vehicle_id', vehicle.id,
        'plate', vehicle.plate,
        'status', session.status,
        'entry_time', session.entry_time,
        'lot_id', session.lot_id,
        'left_keys', session.left_keys,
        'photo_count', photo_count,
        'video_count', video_count,
        'spot_id', session.spot_id,
        'spot_code', (
            select ps.code from public.parking_spots ps where ps.id = session.spot_id
        )
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, operator_id, 'rpc/check_in', 201, response);
    end if;

    return response;
end;
$$;

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
           and r.reserved_until + public.reservation_grace(p_lot) > now();
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
           and r.reserved_until + public.reservation_grace(p_lot) > now()
           and public.category_group(c.name) = spot_group;
        if open_count + reserved_count >= group_capacity then
            raise exception 'ParkingFullError';
        end if;
    end if;
end;
$$;

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
           and r.reserved_until + public.reservation_grace(p_lot_id) > now();

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
               and r.reserved_until + public.reservation_grace(p_lot_id) > now()
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
            'hourly_amount', coalesce((
                select t.amount
                  from public.tariffs t
                 where t.category_id = category.id
                   and t.type = 'hourly'
                   and t.active
                 order by t.id
                 limit 1
            ), 0),
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

create or replace function public.list_active_reservations()
returns table (
    id bigint,
    plate text,
    category_id integer,
    category_name text,
    reserved_until timestamp with time zone,
    status text,
    notes text,
    customer_name text,
    customer_phone text,
    source text,
    in_grace boolean
)
language sql
stable
security invoker
set search_path = public
as $$
    select
        r.id,
        r.plate::text,
        r.category_id,
        coalesce(c.name, '')::text as category_name,
        r.reserved_until,
        r.status,
        r.notes,
        r.customer_name,
        r.customer_phone,
        r.source,
        (
            r.reserved_until <= now()
            and r.reserved_until + public.reservation_grace(r.lot_id) > now()
        ) as in_grace
      from public.category_reservations r
      left join public.categories c on c.id = r.category_id
     where r.status = 'active'
       and r.reserved_until + public.reservation_grace(r.lot_id) > now()
     order by r.reserved_until;
$$;

grant execute on function public.check_in(
    text, integer, text, text, jsonb, text, timestamp with time zone,
    integer, boolean, integer, jsonb
) to authenticated;

revoke all on function public.reservation_capacity_check(integer, integer, text)
    from public;
grant execute on function public.reservation_capacity_check(integer, integer, text)
    to authenticated;

grant execute on function public.public_availability(integer) to anon, authenticated;

revoke all on function public.list_active_reservations() from public;
grant execute on function public.list_active_reservations() to authenticated;
