-- Out-of-service spaces: an admin can take car or motorcycle spots out of the
-- usable pool (maintenance, painting, a blocked area). They keep counting in
-- the configured capacity but are never offered: the capacity guard, the
-- dashboard snapshot and the visual board subtract them.

alter table public.parking_settings
    add column if not exists car_out_of_service integer not null default 0,
    add column if not exists moto_out_of_service integer not null default 0;

alter table public.parking_settings
    drop constraint if exists parking_settings_out_of_service_positive;
alter table public.parking_settings
    add constraint parking_settings_out_of_service_positive check (
        car_out_of_service >= 0 and moto_out_of_service >= 0
    );

-- Usable spots: configured capacity minus the ones out of service. `0`
-- capacity still means "no limit" and ignores the counter.
create or replace function public.usable_capacity(
    p_capacity integer,
    p_out_of_service integer
)
returns integer
language sql
immutable
as $$
    select case
        when coalesce(p_capacity, 0) <= 0 then 0
        else greatest(coalesce(p_capacity, 0) - coalesce(p_out_of_service, 0), 0)
    end;
$$;

grant execute on function public.usable_capacity(integer, integer) to authenticated;

-- Capacity guard: a group with every spot out of service is full, not
-- unlimited, so the `group_capacity > 0` shortcut is now "configured".
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
    car_out integer := 0;
    moto_out integer := 0;
    group_configured boolean := false;
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
           coalesce(ps.key_capacity, 0),
           coalesce(ps.car_out_of_service, 0),
           coalesce(ps.moto_out_of_service, 0)
      into car_capacity, moto_capacity, key_capacity, car_out, moto_out
      from public.parking_settings ps
     where ps.lot_id = new.lot_id;

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

    if group_configured then
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

-- Dashboard snapshot: the counters join the existing capacity numbers.
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
    key_capacity integer := 0;
    car_out integer := 0;
    moto_out integer := 0;
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

    return jsonb_build_object(
        'car_open', car_open,
        'car_capacity', coalesce(car_capacity, 0),
        'car_available', public.usable_capacity(car_capacity, car_out),
        'car_out_of_service', coalesce(car_out, 0),
        'moto_open', moto_open,
        'moto_capacity', coalesce(moto_capacity, 0),
        'moto_available', public.usable_capacity(moto_capacity, moto_out),
        'moto_out_of_service', coalesce(moto_out, 0),
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

-- Space board: the striped cells need the counters too.
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
    car_out integer := 0;
    moto_out integer := 0;
    sessions jsonb := '[]'::jsonb;
    holds jsonb := '[]'::jsonb;
begin
    perform public.require_app_user();

    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.car_out_of_service, 0),
           coalesce(ps.moto_out_of_service, 0)
      into car_capacity, moto_capacity, car_out, moto_out
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
        'car_out_of_service', coalesce(car_out, 0),
        'moto_out_of_service', coalesce(moto_out, 0),
        'sessions', sessions,
        'holds', holds
    );
end;
$$;

grant execute on function public.slot_board() to authenticated;
