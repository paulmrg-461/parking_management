-- Vehicle notes and a blacklist flag. A blacklisted vehicle cannot check in
-- until an admin clears the flag; notes are free text for incidents.

alter table public.vehicles
    add column if not exists is_blacklisted boolean not null default false;
alter table public.vehicles
    add column if not exists notes text;

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
-- Flags: any signed-in user may write notes, only admins toggle the blacklist.
-- `p_notes` null keeps the current value; an empty string clears it.
-- ---------------------------------------------------------------------------
create or replace function public.update_vehicle_flags(
    p_plate text,
    p_blacklisted boolean default null,
    p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    vehicle public.vehicles%rowtype;
begin
    perform public.require_app_user();
    if normalized = '' then
        raise exception 'VehicleNotFoundError';
    end if;
    if p_blacklisted is not null
       and public.current_app_role() is distinct from 'admin' then
        raise exception 'AdminRequiredError';
    end if;

    select * into vehicle
      from public.vehicles v
     where v.plate = normalized
     for update;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;

    update public.vehicles
       set is_blacklisted = coalesce(p_blacklisted, is_blacklisted),
           notes = case
               when p_notes is null then notes
               else nullif(btrim(p_notes), '')
           end
     where id = vehicle.id
     returning * into vehicle;

    return jsonb_build_object(
        'plate', vehicle.plate,
        'is_blacklisted', vehicle.is_blacklisted,
        'notes', vehicle.notes
    );
end;
$$;

grant execute on function public.update_vehicle_flags(text, boolean, text) to authenticated;

create or replace function public.vehicle_history(p_plate text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    vehicle public.vehicles%rowtype;
    category_name text;
    result jsonb;
begin
    perform public.require_app_user();
    if normalized = '' then
        raise exception 'VehicleNotFoundError';
    end if;

    select * into vehicle from public.vehicles v where v.plate = normalized;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;
    select c.name into category_name
      from public.categories c where c.id = vehicle.category_id;

    select jsonb_build_object(
        'plate', vehicle.plate,
        'vehicle_id', vehicle.id,
        'category_id', vehicle.category_id,
        'category_name', category_name,
        'color', vehicle.color,
        'brand', vehicle.brand,
        'is_blacklisted', vehicle.is_blacklisted,
        'notes', vehicle.notes,
        'visits', count(*),
        'total_spent', coalesce(sum(s.amount_charged) filter (where s.status = 'closed'), 0),
        'open_sessions', count(*) filter (where s.status = 'open'),
        'sessions', coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'id', s.id,
                    'entry_time', s.entry_time,
                    'exit_time', s.exit_time,
                    'status', s.status,
                    'amount_charged', s.amount_charged,
                    'ticket_number', s.ticket_number,
                    'payment_method', s.payment_method,
                    'lost_ticket', s.lost_ticket,
                    'duration_seconds', case
                        when s.exit_time is not null
                            then extract(epoch from s.exit_time - s.entry_time)::bigint
                        else extract(epoch from now() - s.entry_time)::bigint
                    end
                )
                order by s.entry_time desc
            ),
            '[]'::jsonb
        )
    ) into result
      from public.parking_sessions s
     where s.vehicle_id = vehicle.id;

    return result;
end;
$$;

grant execute on function public.vehicle_history(text) to authenticated;
