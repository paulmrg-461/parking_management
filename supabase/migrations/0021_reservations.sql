-- Capacity holds: a reservation takes a slot of its category until it is
-- used by a check-in, cancelled or expires. The capacity guard counts open
-- sessions plus active reservations, and `occupancy_snapshot` reports both so
-- the client can disable full categories before submitting.

create table if not exists public.category_reservations (
    id             bigserial   primary key,
    plate          varchar(20) not null,
    category_id    integer     not null references public.categories(id),
    reserved_from  timestamptz not null default now(),
    reserved_until timestamptz not null,
    status         text        not null default 'active'
                   check (status in ('active', 'cancelled', 'used')),
    notes          text,
    created_by     integer     references public.users(id),
    created_at     timestamptz not null default now(),
    constraint category_reservations_window_check
        check (reserved_until > reserved_from)
);
create index if not exists ix_reservations_active
    on public.category_reservations(category_id, reserved_until)
    where status = 'active';

alter table public.category_reservations enable row level security;
grant select on public.category_reservations to authenticated;

drop policy if exists reservation_read on public.category_reservations;
create policy reservation_read on public.category_reservations
    for select to authenticated using (true);

create or replace function public.check_in(
    p_plate text,
    p_category_id integer default null,
    p_color text default null,
    p_brand text default null,
    p_photos jsonb default '[]'::jsonb,
    p_idempotency_key text default null,
    p_client_entry_time timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    operator_id integer := public.require_app_user();
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
        if not exists (select 1 from public.categories c where c.id = p_category_id) then
            raise exception 'CategoryNotFoundError';
        end if;
        insert into public.vehicles (plate, category_id, color, brand, created_by)
        values (normalized_plate, p_category_id, p_color, p_brand, operator_id)
        on conflict (plate) do update set plate = excluded.plate
        returning * into vehicle;
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
       and status = 'active'
       and reserved_until > now();

    begin
        insert into public.parking_sessions (vehicle_id, operator_id, entry_time, status)
        values (vehicle.id, operator_id, entry_at, 'open')
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
        'photo_count', photo_count
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, operator_id, 'rpc/check_in', 201, response);
    end if;

    return response;
end;
$$;

-- ---------------------------------------------------------------------------
-- Capacity now counts reservations too.
-- ---------------------------------------------------------------------------
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
    reserved_count integer;
begin
    select v.category_id into category from public.vehicles v where v.id = new.vehicle_id;
    if category is null then
        return new;
    end if;
    perform pg_advisory_xact_lock(hashtext('category:' || category));
    select c.capacity into capacity from public.categories c where c.id = category;
    if coalesce(capacity, 0) > 0 then
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where v.category_id = category
           and s.status = 'open';
        select count(*) into reserved_count
          from public.category_reservations r
         where r.category_id = category
           and r.status = 'active'
           and r.reserved_until > now();
        if open_count + reserved_count >= capacity then
            raise exception 'CategoryFullError';
        end if;
    end if;
    return new;
end;
$$;

create or replace function public.occupancy_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    total bigint;
    total_capacity bigint;
    total_reserved bigint;
    by_category jsonb;
begin
    perform public.require_app_user();

    select count(*) into total
      from public.parking_sessions s where s.status = 'open';

    select coalesce(sum(c.capacity), 0) into total_capacity
      from public.categories c where c.capacity > 0;

    select count(*) into total_reserved
      from public.category_reservations r
     where r.status = 'active' and r.reserved_until > now();

    select coalesce(jsonb_agg(item order by item ->> 'category_name'), '[]'::jsonb)
      into by_category
      from (
        select jsonb_build_object(
                   'category_id', c.id,
                   'category_name', c.name,
                   'count', count(s.id),
                   'capacity', c.capacity,
                   'reserved', coalesce((
                       select count(*) from public.category_reservations r
                        where r.category_id = c.id
                          and r.status = 'active'
                          and r.reserved_until > now()
                   ), 0),
                   'available', greatest(
                       c.capacity
                       - count(s.id)
                       - coalesce((
                           select count(*) from public.category_reservations r
                            where r.category_id = c.id
                              and r.status = 'active'
                              and r.reserved_until > now()
                         ), 0),
                       0
                   ),
                   'is_full', (
                       c.capacity > 0
                       and count(s.id) + coalesce((
                           select count(*) from public.category_reservations r
                            where r.category_id = c.id
                              and r.status = 'active'
                              and r.reserved_until > now()
                         ), 0) >= c.capacity
                   )
               ) as item
          from public.categories c
          left join public.vehicles v on v.category_id = c.id
          left join public.parking_sessions s
            on s.vehicle_id = v.id and s.status = 'open'
         group by c.id, c.name, c.capacity
      ) categories;

    return jsonb_build_object(
        'total_open', total,
        'total_reserved', total_reserved,
        'total_capacity', total_capacity,
        'by_category', by_category
    );
end;
$$;

grant execute on function public.occupancy_snapshot() to authenticated;

-- ---------------------------------------------------------------------------
-- Create/cancel a reservation. Creating enforces the remaining capacity.
-- ---------------------------------------------------------------------------
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

    select c.capacity into capacity from public.categories c where c.id = p_category_id;
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
         where v.category_id = p_category_id and s.status = 'open';
        select count(*) into reserved_count
          from public.category_reservations r
         where r.category_id = p_category_id
           and r.status = 'active'
           and r.reserved_until > now();
        if open_count + reserved_count >= capacity then
            raise exception 'CategoryFullError';
        end if;
    end if;

    insert into public.category_reservations (
        plate, category_id, reserved_until, notes, created_by
    )
    values (normalized, p_category_id, p_until, nullif(btrim(coalesce(p_notes, '')), ''), actor)
    returning * into reservation;

    return jsonb_build_object(
        'id', reservation.id,
        'plate', reservation.plate,
        'category_id', reservation.category_id,
        'reserved_from', reservation.reserved_from,
        'reserved_until', reservation.reserved_until,
        'status', reservation.status,
        'notes', reservation.notes
    );
end;
$$;

create or replace function public.cancel_reservation(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    reservation public.category_reservations%rowtype;
begin
    perform public.require_app_user();
    select * into reservation
      from public.category_reservations r
     where r.id = p_id
     for update;
    if not found then
        raise exception 'ReservationNotFoundError';
    end if;
    if reservation.status <> 'active' then
        raise exception 'ReservationNotActiveError';
    end if;
    update public.category_reservations
       set status = 'cancelled'
     where id = reservation.id
     returning * into reservation;
    return jsonb_build_object('id', reservation.id, 'status', reservation.status);
end;
$$;

grant execute on function public.create_reservation(text, integer, timestamptz, text) to authenticated;
grant execute on function public.cancel_reservation(bigint) to authenticated;
