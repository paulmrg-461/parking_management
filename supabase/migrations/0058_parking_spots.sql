-- Physical spots: the site's real map. An admin lays out the bays once
-- (code + grid position + vehicle group), and every check-in takes one:
-- the chosen spot when the operator picks it, otherwise the first free spot
-- (top-left first). A group with spots derives its capacity from them.

create table if not exists public.parking_spots (
    id          serial primary key,
    lot_id      integer     not null references public.parking_lots(id) on delete cascade,
    code        varchar(16) not null,
    group_name  text        not null check (group_name in ('car', 'moto', 'heavy')),
    grid_row    integer     not null default 0 check (grid_row between 0 and 200),
    grid_col    integer     not null default 0 check (grid_col between 0 and 200),
    status      text        not null default 'active'
                check (status in ('active', 'out_of_service')),
    created_at  timestamptz not null default now(),
    unique (lot_id, code)
);
create unique index if not exists uq_spot_cell
    on public.parking_spots(lot_id, grid_row, grid_col);

alter table public.parking_spots enable row level security;
grant select on public.parking_spots to authenticated;

drop policy if exists spots_select_lot on public.parking_spots;
create policy spots_select_lot on public.parking_spots
    for select to authenticated
    using (lot_id = public.current_lot_id());

-- Writes go through the RPCs below (no insert/update/delete grants).

alter table public.parking_sessions
    add column if not exists spot_id integer;

-- Deleting a bay keeps the session history (the reference is cleared).
alter table public.parking_sessions
    drop constraint if exists parking_sessions_spot_id_fkey;
alter table public.parking_sessions
    add constraint parking_sessions_spot_id_fkey
    foreign key (spot_id) references public.parking_spots(id) on delete set null;

create unique index if not exists uq_open_session_spot
    on public.parking_sessions(spot_id)
    where status = 'open' and spot_id is not null;

-- Reference data is audited (actor from auth.uid()).
drop trigger if exists trg_audit_row on public.parking_spots;
create trigger trg_audit_row after insert or update or delete
    on public.parking_spots for each row
    execute function public.record_audit();

-- Category name -> capacity group.
create or replace function public.category_group(p_name text)
returns text
language sql
immutable
as $$
    select case
        when lower(coalesce(p_name, '')) in ('car', 'carro', 'auto', 'camioneta', 'suv')
            then 'car'
        when lower(coalesce(p_name, '')) in ('moto', 'motos', 'motorcycle')
            then 'moto'
        else 'heavy'
    end;
$$;

grant execute on function public.category_group(text) to authenticated;

-- Map editor: create or update one spot.
create or replace function public.save_parking_spot(
    p_code text,
    p_group text,
    p_row integer,
    p_col integer,
    p_id integer default null,
    p_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    normalized text := upper(btrim(coalesce(p_code, '')));
    spot public.parking_spots%rowtype;
begin
    perform public.require_admin();

    if normalized !~ '^[A-Z0-9-]{1,16}$' then
        raise exception 'InvalidSpotCodeError';
    end if;
    if p_group not in ('car', 'moto', 'heavy') then
        raise exception 'InvalidSpotGroupError';
    end if;
    if p_row is null or p_col is null or p_row < 0 or p_col < 0 then
        raise exception 'InvalidSpotPositionError';
    end if;

    if exists (
        select 1 from public.parking_spots ps
         where ps.lot_id = lot
           and ps.code = normalized
           and ps.id is distinct from p_id
    ) then
        raise exception 'SpotCodeTakenError';
    end if;
    if exists (
        select 1 from public.parking_spots ps
         where ps.lot_id = lot
           and ps.grid_row = p_row
           and ps.grid_col = p_col
           and ps.id is distinct from p_id
    ) then
        raise exception 'SpotCellTakenError';
    end if;

    if p_id is null then
        insert into public.parking_spots (
            lot_id, code, group_name, grid_row, grid_col, status
        )
        values (
            lot, normalized, p_group, p_row, p_col,
            case when p_active then 'active' else 'out_of_service' end
        )
        returning * into spot;
    else
        update public.parking_spots ps
           set code = normalized,
               group_name = p_group,
               grid_row = p_row,
               grid_col = p_col,
               status = case when p_active then 'active' else 'out_of_service' end
         where ps.id = p_id
           and ps.lot_id = lot
        returning * into spot;
        if not found then
            raise exception 'SpotNotFoundError';
        end if;
    end if;

    return jsonb_build_object(
        'id', spot.id,
        'code', spot.code,
        'group', spot.group_name,
        'row', spot.grid_row,
        'col', spot.grid_col,
        'active', spot.status = 'active'
    );
end;
$$;

grant execute on function public.save_parking_spot(text, text, integer, integer, integer, boolean)
    to authenticated;

create or replace function public.delete_parking_spot(p_id integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
begin
    perform public.require_admin();

    if exists (
        select 1 from public.parking_sessions s
         where s.spot_id = p_id and s.status = 'open'
    ) then
        raise exception 'SpotOccupiedError';
    end if;

    delete from public.parking_spots ps
     where ps.id = p_id and ps.lot_id = lot;
    if not found then
        raise exception 'SpotNotFoundError';
    end if;
end;
$$;

grant execute on function public.delete_parking_spot(integer) to authenticated;

-- Move an open session to another spot (or to the first free one with null).
create or replace function public.assign_session_spot(
    p_session_id integer,
    p_spot_id integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    session public.parking_sessions%rowtype;
    category_name text;
    spot_group text;
    spot public.parking_spots%rowtype;
begin
    perform public.require_app_user();

    select * into session
      from public.parking_sessions s
     where s.id = p_session_id;
    if not found then
        raise exception 'SessionNotFoundError';
    end if;
    if session.lot_id <> lot then
        raise exception 'LotRequiredError';
    end if;
    if session.status <> 'open' then
        raise exception 'SessionAlreadyClosedError';
    end if;

    select c.name into category_name
      from public.vehicles v
      join public.categories c on c.id = v.category_id
     where v.id = session.vehicle_id;
    spot_group := public.category_group(category_name);

    if p_spot_id is null then
        select sp.* into spot
          from public.parking_spots sp
         where sp.lot_id = lot
           and sp.group_name = spot_group
           and sp.status = 'active'
           and not exists (
               select 1 from public.parking_sessions s
                where s.status = 'open'
                  and s.spot_id = sp.id
                  and s.id <> session.id
           )
         order by sp.grid_row, sp.grid_col
         limit 1
         for update;
    else
        select * into spot
          from public.parking_spots sp
         where sp.id = p_spot_id
           and sp.lot_id = lot
         for update;
    end if;

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
         where s.status = 'open'
           and s.spot_id = spot.id
           and s.id <> session.id
    ) then
        raise exception 'SpotTakenError';
    end if;

    update public.parking_sessions
       set spot_id = spot.id
     where id = session.id;

    return jsonb_build_object(
        'session_id', session.id,
        'spot_id', spot.id,
        'spot_code', spot.code
    );
end;
$$;

grant execute on function public.assign_session_spot(integer, integer) to authenticated;

-- Capacity guard: a group with spots is limited by its active spots.
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
    spots_total integer := 0;
    spots_active integer := 0;
    spot_group text;
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
    spot_group := public.category_group(category_name);

    select count(*), count(*) filter (where status = 'active')
      into spots_total, spots_active
      from public.parking_spots sp
     where sp.lot_id = new.lot_id
       and sp.group_name = spot_group;

    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.key_capacity, 0),
           coalesce(ps.car_out_of_service, 0),
           coalesce(ps.moto_out_of_service, 0)
      into car_capacity, moto_capacity, key_capacity, car_out, moto_out
      from public.parking_settings ps
     where ps.lot_id = new.lot_id;

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
        perform pg_advisory_xact_lock(
            hashtext('group:' || new.lot_id || ':' || spot_group)
        );
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.status = 'open'
           and s.lot_id = new.lot_id
           and public.category_group(c.name) = spot_group;
        select count(*) into reserved_count
          from public.category_reservations r
          join public.categories c on c.id = r.category_id
         where r.lot_id = new.lot_id
           and r.status = 'active'
           and r.reserved_until > now()
           and public.category_group(c.name) = spot_group;
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

-- Check-in with an optional spot. Without one it takes the first free spot of
-- the vehicle's group (top-left first); groups without a map keep working with
-- the configured capacity.
-- A previous manual apply left check_in owned by supabase_admin; the migrate
-- user (postgres) must own it to change the signature.
do $$
begin
    alter function public.check_in(
        text, integer, text, text, jsonb, text, timestamptz, integer, boolean
    ) owner to postgres;
exception
    when undefined_function then null;
end $$;

drop function if exists public.check_in(text, integer, text, text, jsonb, text, timestamptz, integer, boolean);

create or replace function public.check_in(
    p_plate text,
    p_category_id integer default null,
    p_color text default null,
    p_brand text default null,
    p_photos jsonb default '[]'::jsonb,
    p_idempotency_key text default null,
    p_client_entry_time timestamptz default null,
    p_lot_id integer default null,
    p_left_keys boolean default false,
    p_spot_id integer default null
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
       and reserved_until > now();

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
        'photo_count', photo_count,
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

grant execute on function public.check_in(text, integer, text, text, jsonb, text, timestamptz, integer, boolean, integer)
    to authenticated;

-- Dashboard snapshot: spots define the group capacity when a map exists.
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
        'moto_open', moto_open,
        'moto_capacity', coalesce(moto_capacity, 0),
        'moto_available', case
            when moto_spots > 0 then moto_active
            else public.usable_capacity(moto_capacity, moto_out)
        end,
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

-- Visual board: the real map plus the open sessions and holds.
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
    spots jsonb := '[]'::jsonb;
begin
    perform public.require_app_user();

    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.car_out_of_service, 0),
           coalesce(ps.moto_out_of_service, 0)
      into car_capacity, moto_capacity, car_out, moto_out
      from public.parking_settings ps
     where ps.lot_id = lot;

    select coalesce(
               jsonb_agg(
                   jsonb_build_object(
                       'id', sp.id,
                       'code', sp.code,
                       'group', sp.group_name,
                       'row', sp.grid_row,
                       'col', sp.grid_col,
                       'active', sp.status = 'active'
                   )
                   order by sp.grid_row, sp.grid_col
               ),
               '[]'::jsonb
           )
      into spots
      from public.parking_spots sp
     where sp.lot_id = lot;

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
                   'spot_id', s.spot_id,
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
                   'group', public.category_group(c.name)
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
                   'group', public.category_group(c.name)
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
        'holds', holds,
        'spots', spots
    );
end;
$$;

grant execute on function public.slot_board() to authenticated;
-- Holds obey the map too: a group with spots is limited by its active spots.
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
    car_out integer := 0;
    moto_out integer := 0;
    spots_total integer := 0;
    spots_active integer := 0;
    spot_group text;
    group_configured boolean := false;
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
    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.car_out_of_service, 0),
           coalesce(ps.moto_out_of_service, 0)
      into car_capacity, moto_capacity, car_out, moto_out
      from public.parking_settings ps
     where ps.lot_id = public.current_lot_id();

    spot_group := public.category_group(category_name);

    select count(*), count(*) filter (where status = 'active')
      into spots_total, spots_active
      from public.parking_spots sp
     where sp.lot_id = public.current_lot_id()
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
        perform pg_advisory_xact_lock(
            hashtext('group:' || public.current_lot_id() || ':' || category_name)
        );
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.status = 'open'
           and s.lot_id = public.current_lot_id()
           and public.category_group(c.name) = spot_group;
        select count(*) into reserved_count
          from public.category_reservations r
          join public.categories c on c.id = r.category_id
         where r.lot_id = public.current_lot_id()
           and r.status = 'active'
           and r.reserved_until > now()
           and public.category_group(c.name) = spot_group;
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
