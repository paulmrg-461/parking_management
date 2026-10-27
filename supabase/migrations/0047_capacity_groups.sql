-- Space configuration per site: cars (cars + pickups share the same spots),
-- motorcycles, and how many cars may leave their keys. Trucks and buses are
-- not limited here. `0` means "no limit", so existing sites keep behaving as
-- before until an admin fills the fields in Ajustes.

alter table public.parking_settings
    add column if not exists car_capacity integer not null default 0,
    add column if not exists moto_capacity integer not null default 0,
    add column if not exists key_capacity integer not null default 0;

alter table public.parking_settings
    drop constraint if exists parking_settings_capacity_positive;
alter table public.parking_settings
    add constraint parking_settings_capacity_positive check (
        car_capacity >= 0 and moto_capacity >= 0 and key_capacity >= 0
    );

alter table public.parking_sessions
    add column if not exists left_keys boolean not null default false;

-- The check-in list shows whether the car left its keys.
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
    ) as has_pass,
    s.left_keys
from public.parking_sessions s
join public.vehicles v on v.id = s.vehicle_id
left join lateral (
    select ps.business_timezone as name
      from public.parking_settings ps
     where ps.lot_id = s.lot_id
) tz on true
where s.status = 'open';

grant select on public.open_sessions_view to authenticated;

-- Capacity guard: per category (existing), per space group (cars/pickups and
-- motorcycles) and for cars that leave their keys. Serialized with advisory
-- locks so two concurrent check-ins cannot exceed a limit.
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
        if open_count >= capacity then
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
        if open_count >= group_capacity then
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

-- The new parameter changes the signature: drop the old overload first (two
-- overloads would make 8-argument RPC calls ambiguous).
drop function if exists public.check_in(text, integer, text, text, jsonb, text, timestamptz, integer);

create or replace function public.check_in(
    p_plate text,
    p_category_id integer default null,
    p_color text default null,
    p_brand text default null,
    p_photos jsonb default '[]'::jsonb,
    p_idempotency_key text default null,
    p_client_entry_time timestamptz default null,
    p_lot_id integer default null,
    p_left_keys boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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

    -- Categories are per lot: reuse the plate's category when it belongs to
    -- this lot, otherwise map it by name or take the operator's choice.
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

    -- A reservation for this plate holds a slot: close it before the capacity
    -- trigger counts active reservations, so the car converts its hold into
    -- an occupied slot instead of being rejected.
    update public.category_reservations
       set status = 'used'
     where plate = vehicle.plate
       and lot_id = lot_value
       and status = 'active'
       and reserved_until > now();

    begin
        insert into public.parking_sessions (
            vehicle_id, operator_id, entry_time, status, lot_id, left_keys
        )
        values (
            vehicle.id, operator_id, entry_at, 'open', lot_value,
            coalesce(p_left_keys, false)
        )
        returning * into session;
    exception when unique_violation then
        raise exception 'DuplicateOpenSessionError';
    end;

    for photo in select * from jsonb_array_elements(coalesce(p_photos, '[]'::jsonb)) loop
        insert into public.evidence_photos (session_id, file_path, taken_at)
        values (
            session.id,
            photo ->> 'path',
            coalesce((photo ->> 'taken_at')::timestamptz, now())
        );
        photo_count := photo_count + 1;
    end loop;

    response := jsonb_build_object(
        'id', session.id,
        'vehicle_id', vehicle.id,
        'plate', vehicle.plate,
        'status', session.status,
        'entry_time', session.entry_time,
        'lot_id', session.lot_id,
        'left_keys', session.left_keys,
        'photo_count', photo_count
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, operator_id, 'rpc/check_in', 201, response);
    end if;

    return response;
end;
$$;

grant execute on function public.check_in(text, integer, text, text, jsonb, text, timestamptz, integer, boolean) to authenticated;
