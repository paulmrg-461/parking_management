-- Optional walk-around video evidence: same bucket/table as the photos (the
-- archive job and the membership read policy already cover them), with a kind
-- column and a larger size limit. A check-in may attach one short video.
--
-- Storage accepts videos up to 50 MB; the client keeps them optional and caps
-- the recording at 60 s.

update storage.buckets
   set file_size_limit = 52428800,
       allowed_mime_types = array['image/jpeg', 'image/png', 'video/mp4', 'video/quicktime', 'video/webm']
 where id = 'evidence';

alter table public.evidence_photos
    add column if not exists kind text not null default 'photo'
        check (kind in ('photo', 'video')),
    add column if not exists duration_seconds integer;

-- Signature change: the 10-argument version must go so PostgREST never faces
-- two candidates.
alter function public.check_in(
    text, integer, text, text, jsonb, text, timestamptz, integer, boolean, integer
) owner to postgres;

drop function if exists public.check_in(
    text, integer, text, text, jsonb, text, timestamptz, integer, boolean, integer
);

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
    p_spot_id integer default null,
    p_videos jsonb default '[]'::jsonb
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

    for video in select * from jsonb_array_elements(coalesce(p_videos, '[]'::jsonb)) loop
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

grant execute on function public.check_in(text, integer, text, text, jsonb, text, timestamptz, integer, boolean, integer, jsonb)
    to authenticated;


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
                        where p.session_id = s.id and p.kind = 'photo'
                   ),
                   'video_count', (
                       select count(*) from public.evidence_photos p
                        where p.session_id = s.id and p.kind = 'video'
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
