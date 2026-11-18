-- Device gateway RPCs: admin management, the service-role authentication path
-- and the offline/retention jobs. Devices never get a user JWT.

create or replace function public.register_lot_device(
    p_kind text,
    p_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.require_lot_admin();
    clean_name text := btrim(coalesce(p_name, ''));
    key text;
    prefix text;
    device public.lot_devices%rowtype;
    minutes integer;
begin
    if p_kind not in ('camera', 'barrier', 'sensor_hub') then
        raise exception 'InvalidDeviceKindError';
    end if;
    if length(clean_name) < 1 or length(clean_name) > 60 then
        raise exception 'InvalidDeviceNameError';
    end if;
    if (select count(*) from public.lot_devices d where d.lot_id = lot) >= 50 then
        raise exception 'DeviceLimitReachedError';
    end if;

    prefix := encode(gen_random_bytes(6), 'hex');
    key := 'pkd_' || prefix || '_' || encode(gen_random_bytes(32), 'hex');

    begin
        insert into public.lot_devices (
            lot_id, kind, name, key_prefix, key_hash, created_by
        ) values (
            lot, p_kind, clean_name, prefix,
            encode(digest(key, 'sha256'), 'hex'), actor
        ) returning * into device;
    exception when unique_violation then
        raise exception 'DeviceNameTakenError';
    end;

    perform public.device_event(lot, device.id, device.name, 'registered', actor);
    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = lot;
    return public.device_json(device, coalesce(minutes, 5))
        || jsonb_build_object('api_key', key);
end;
$$;

revoke all on function public.register_lot_device(text, text) from public;
grant execute on function public.register_lot_device(text, text) to authenticated;

create or replace function public.rotate_lot_device_key(p_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.require_lot_admin();
    key text;
    prefix text;
    device public.lot_devices%rowtype;
    minutes integer;
begin
    select * into device from public.lot_devices d
     where d.id = p_id and d.lot_id = lot for update;
    if not found then
        raise exception 'DeviceNotFoundError';
    end if;
    prefix := encode(gen_random_bytes(6), 'hex');
    key := 'pkd_' || prefix || '_' || encode(gen_random_bytes(32), 'hex');
    update public.lot_devices
       set key_prefix = prefix,
           key_hash = encode(digest(key, 'sha256'), 'hex'),
           key_rotated_at = now(),
           last_seq = 0,
           offline_notified_at = null
     where id = device.id
     returning * into device;
    perform public.device_event(lot, device.id, device.name, 'key_rotated', actor);
    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = lot;
    return public.device_json(device, coalesce(minutes, 5))
        || jsonb_build_object('api_key', key);
end;
$$;

revoke all on function public.rotate_lot_device_key(integer) from public;
grant execute on function public.rotate_lot_device_key(integer) to authenticated;

create or replace function public.update_lot_device(
    p_id integer,
    p_name text default null,
    p_enabled boolean default null,
    p_rate_per_minute integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.require_lot_admin();
    device public.lot_devices%rowtype;
    clean_name text;
    old_name text;
    minutes integer;
begin
    select * into device from public.lot_devices d
     where d.id = p_id and d.lot_id = lot for update;
    if not found then
        raise exception 'DeviceNotFoundError';
    end if;
    clean_name := case when p_name is null then device.name else btrim(p_name) end;
    old_name := device.name;
    if length(clean_name) < 1 or length(clean_name) > 60 then
        raise exception 'InvalidDeviceNameError';
    end if;
    if p_rate_per_minute is not null
       and (p_rate_per_minute < 6 or p_rate_per_minute > 600) then
        raise exception 'InvalidDataError';
    end if;

    perform 1;
    begin
        update public.lot_devices
           set name = clean_name,
               enabled = coalesce(p_enabled, enabled),
               rate_per_minute = coalesce(p_rate_per_minute, rate_per_minute),
               offline_notified_at = case
                   when p_enabled is true then null
                   else offline_notified_at end
         where id = device.id
         returning * into device;
    exception when unique_violation then
        raise exception 'DeviceNameTakenError';
    end;

    if p_name is not null and clean_name <> old_name then
        perform public.device_event(lot, device.id, device.name, 'renamed', actor,
            jsonb_build_object('from', old_name, 'to', clean_name));
    end if;
    if p_enabled is not null then
        perform public.device_event(lot, device.id, device.name,
            case when p_enabled then 'enabled' else 'disabled' end, actor);
    end if;
    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = lot;
    return public.device_json(device, coalesce(minutes, 5));
end;
$$;

revoke all on function public.update_lot_device(integer, text, boolean, integer) from public;
grant execute on function public.update_lot_device(integer, text, boolean, integer)
    to authenticated;

create or replace function public.delete_lot_device(p_id integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.require_lot_admin();
    device public.lot_devices%rowtype;
begin
    select * into device from public.lot_devices d
     where d.id = p_id and d.lot_id = lot;
    if not found then
        raise exception 'DeviceNotFoundError';
    end if;
    perform public.device_event(lot, device.id, device.name, 'deleted', actor);
    delete from public.lot_devices where id = device.id;
end;
$$;

revoke all on function public.delete_lot_device(integer) from public;
grant execute on function public.delete_lot_device(integer) to authenticated;

create or replace function public.list_lot_devices()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    minutes integer;
begin
    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = lot;
    return jsonb_build_object(
        'offline_minutes', coalesce(minutes, 5),
        'devices', coalesce((
            select jsonb_agg(public.device_json(d, coalesce(minutes, 5))
                             order by d.kind, d.name)
              from public.lot_devices d where d.lot_id = lot
        ), '[]'::jsonb)
    );
end;
$$;

revoke all on function public.list_lot_devices() from public;
grant execute on function public.list_lot_devices() to authenticated;

create or replace function public.list_device_events(
    p_device_id integer default null,
    p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    max_rows integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
    return coalesce((
        select jsonb_agg(jsonb_build_object(
                   'id', e.id,
                   'device_id', e.device_id,
                   'device_name', e.device_name,
                   'event', e.event,
                   'actor_name', u.display_name,
                   'detail', e.detail,
                   'created_at', e.created_at
               ) order by e.created_at desc, e.id desc)
          from (
              select * from public.device_events e
               where e.lot_id = lot
                 and (p_device_id is null or e.device_id = p_device_id)
               order by e.created_at desc, e.id desc
               limit max_rows
          ) e
          left join public.users u on u.id = e.actor_id
    ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_device_events(integer, integer) from public;
grant execute on function public.list_device_events(integer, integer) to authenticated;

create or replace function public.set_device_offline_minutes(p_minutes integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
begin
    if p_minutes is null or p_minutes < 2 or p_minutes > 1440 then
        raise exception 'InvalidDataError';
    end if;
    update public.parking_settings set device_offline_minutes = p_minutes
     where lot_id = lot;
    return jsonb_build_object('offline_minutes', p_minutes);
end;
$$;

revoke all on function public.set_device_offline_minutes(integer) from public;
grant execute on function public.set_device_offline_minutes(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Service-role authentication path.
-- ---------------------------------------------------------------------------
create or replace function public.device_lookup(p_key_prefix text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
begin
    select * into device from public.lot_devices d
     where d.key_prefix = p_key_prefix;
    if not found then
        return null;
    end if;
    return jsonb_build_object('id', device.id, 'key_hash', device.key_hash);
end;
$$;

revoke all on function public.device_lookup(text) from public, anon, authenticated;
grant execute on function public.device_lookup(text) to service_role;

create or replace function public.device_accept_request(
    p_device_id integer,
    p_seq bigint,
    p_sent_at timestamp with time zone,
    p_firmware text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    minutes integer;
    now_time timestamptz := now();
    window_start timestamptz;
    retry integer;
    admins integer;
begin
    select * into device from public.lot_devices d
     where d.id = p_device_id for update;
    if not found then
        return jsonb_build_object('ok', false, 'error', 'DeviceUnauthorizedError',
                                  'server_time', now_time);
    end if;
    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = device.lot_id;
    minutes := coalesce(minutes, 5);

    if not device.enabled then
        perform public.device_event(device.lot_id, device.id, device.name,
            'request_rejected', null, jsonb_build_object('error', 'DeviceDisabledError'));
        return jsonb_build_object('ok', false, 'error', 'DeviceDisabledError',
                                  'server_time', now_time);
    end if;
    if p_sent_at is null
       or abs(extract(epoch from now_time - p_sent_at))
          > extract(epoch from public.max_client_clock_skew()) then
        perform public.device_event(device.lot_id, device.id, device.name,
            'request_rejected', null, jsonb_build_object('error', 'DeviceClockSkewError'));
        return jsonb_build_object('ok', false, 'error', 'DeviceClockSkewError',
                                  'server_time', now_time);
    end if;
    if p_seq is null or p_seq <= device.last_seq then
        perform public.device_event(device.lot_id, device.id, device.name,
            'request_rejected', null, jsonb_build_object('error', 'DeviceReplayError'));
        return jsonb_build_object('ok', false, 'error', 'DeviceReplayError',
                                  'last_seq', device.last_seq, 'server_time', now_time);
    end if;

    window_start := device.rate_window_start;
    if now_time - window_start >= interval '1 minute' then
        window_start := now_time;
        device.rate_window_count := 0;
    end if;
    if device.rate_window_count >= device.rate_per_minute then
        retry := greatest(
            ceil(extract(epoch from window_start + interval '1 minute' - now_time))::integer,
            1);
        return jsonb_build_object('ok', false, 'error', 'DeviceRateLimitedError',
                                  'retry_after_s', retry, 'server_time', now_time);
    end if;

    if device.offline_notified_at is not null then
        perform public.device_event(device.lot_id, device.id, device.name,
            'online', null);
        insert into public.notifications (
            user_id, type, title, body, data, dedupe_key, lot_id
        )
        select u.id, 'device_online', 'Dispositivo en línea',
               device.name || ' volvió a conectarse.',
               jsonb_build_object('device_id', device.id, 'device_name', device.name),
               'device_online:' || device.id || ':user:' || u.id, device.lot_id
          from public.lot_members lm
          join public.users u on u.id = lm.user_id
         where lm.lot_id = device.lot_id and lm.role = 'admin' and u.is_active
        on conflict (dedupe_key) do nothing;
    end if;

    update public.lot_devices
       set last_seen_at = now_time,
           last_seq = p_seq,
           firmware_version = coalesce(
               nullif(left(btrim(p_firmware), 40), ''), firmware_version),
           rate_window_start = window_start,
           rate_window_count = device.rate_window_count + 1,
           offline_notified_at = null
     where id = device.id;

    return jsonb_build_object(
        'ok', true,
        'device_id', device.id,
        'lot_id', device.lot_id,
        'kind', device.kind,
        'name', device.name,
        'server_time', now_time
    );
end;
$$;

revoke all on function public.device_accept_request(integer, bigint, timestamptz, text)
    from public, anon, authenticated;
grant execute on function public.device_accept_request(integer, bigint, timestamptz, text)
    to service_role;

create or replace function public.device_record_auth_failure(p_device_id integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
begin
    select * into device from public.lot_devices d where d.id = p_device_id;
    if not found then
        return;
    end if;
    if exists (
        select 1 from public.device_events e
         where e.device_id = device.id and e.event = 'auth_failed'
           and e.created_at > now() - interval '10 minutes'
    ) then
        return;
    end if;
    perform public.device_event(device.lot_id, device.id, device.name,
        'auth_failed', null);
    insert into public.notifications (
        user_id, type, title, body, data, dedupe_key, lot_id
    )
    select u.id, 'device_auth_failed', 'Fallo de autenticación de dispositivo',
           'Se rechazó una clave del dispositivo ' || device.name || '.',
           jsonb_build_object('device_id', device.id, 'device_name', device.name),
           'device_auth_failed:' || device.id || ':'
               || to_char(now(), 'YYYYMMDDHH24') || ':user:' || u.id,
           device.lot_id
      from public.lot_members lm
      join public.users u on u.id = lm.user_id
     where lm.lot_id = device.lot_id and lm.role = 'admin' and u.is_active
    on conflict (dedupe_key) do nothing;
end;
$$;

revoke all on function public.device_record_auth_failure(integer)
    from public, anon, authenticated;
grant execute on function public.device_record_auth_failure(integer) to service_role;

create or replace function public.device_heartbeat(
    p_device_id integer,
    p_status jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    minutes integer;
begin
    if p_status is null or jsonb_typeof(p_status) <> 'object'
       or pg_column_size(p_status) > 2048 then
        raise exception 'InvalidDataError';
    end if;
    select * into device from public.lot_devices d where d.id = p_device_id;
    if not found then
        raise exception 'DeviceNotFoundError';
    end if;
    update public.lot_devices set last_status = p_status where id = device.id;
    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = device.lot_id;
    return jsonb_build_object(
        'server_time', now(),
        'heartbeat_interval_s', 60,
        'offline_minutes', coalesce(minutes, 5)
    );
end;
$$;

revoke all on function public.device_heartbeat(integer, jsonb)
    from public, anon, authenticated;
grant execute on function public.device_heartbeat(integer, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- Jobs.
-- ---------------------------------------------------------------------------
create or replace function public.notify_offline_devices()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    minutes integer;
    flagged integer := 0;
begin
    for device in
        select d.* from public.lot_devices d
          join public.parking_settings ps on ps.lot_id = d.lot_id
         where d.enabled
           and d.last_seen_at is not null
           and d.offline_notified_at is null
           and d.last_seen_at < now() - make_interval(mins => ps.device_offline_minutes)
    loop
        select ps.device_offline_minutes into minutes
          from public.parking_settings ps where ps.lot_id = device.lot_id;
        insert into public.notifications (
            user_id, type, title, body, data, dedupe_key, lot_id
        )
        select u.id, 'device_offline', 'Dispositivo sin conexión',
               device.name || ' dejó de responder.',
               jsonb_build_object(
                   'device_id', device.id, 'device_name', device.name,
                   'last_seen_at', device.last_seen_at),
               'device_offline:' || device.id || ':user:' || u.id, device.lot_id
          from public.lot_members lm
          join public.users u on u.id = lm.user_id
         where lm.lot_id = device.lot_id and lm.role = 'admin' and u.is_active
        on conflict (dedupe_key) do nothing;
        update public.lot_devices set offline_notified_at = now()
         where id = device.id;
        perform public.device_event(device.lot_id, device.id, device.name,
            'offline', null, jsonb_build_object('last_seen_at', device.last_seen_at));
        flagged := flagged + 1;
    end loop;
    return flagged;
end;
$$;

revoke all on function public.notify_offline_devices()
    from public, anon, authenticated;

create or replace function public.purge_device_events(p_days integer default 180)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    days integer := greatest(coalesce(p_days, 180), 30);
    removed integer;
begin
    delete from public.device_events e
     where e.created_at < now() - make_interval(days => days);
    get diagnostics removed = row_count;
    return removed;
end;
$$;

revoke all on function public.purge_device_events(integer)
    from public, anon, authenticated;
