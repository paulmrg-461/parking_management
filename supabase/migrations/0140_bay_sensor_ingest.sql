-- Bay sensors — ingest, mismatch evaluation and retention.
--
-- The hub posts channel readings; the server applies them in order, computes
-- the effective state at read time and never touches capacity or sessions.
-- `evaluate_bay_mismatches` compares the physical state with the sessions and
-- the bay status, opens one mismatch per (bay, kind) after the grace window,
-- resolves it automatically and alerts the lot. Sensors are advisory.

create or replace function public.bay_notify(
    p_lot_id integer,
    p_type text,
    p_title text,
    p_body text,
    p_data jsonb,
    p_dedupe text,
    p_admins_only boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.notifications (
        user_id, type, title, body, data, dedupe_key, lot_id
    )
    select u.id, p_type, p_title, p_body, p_data,
           p_dedupe || ':user:' || u.id, p_lot_id
      from public.lot_members lm
      join public.users u on u.id = lm.user_id
     where lm.lot_id = p_lot_id
       and u.is_active
       and (not p_admins_only or lm.role = 'admin')
    on conflict (dedupe_key) do nothing;
end;
$$;

revoke all on function public.bay_notify(integer, text, text, text, jsonb, text, boolean)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Device RPCs (service role only).
-- ---------------------------------------------------------------------------
create or replace function public.device_bay_config(p_device_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    channels jsonb;
begin
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.enabled;
    if not found or device.kind <> 'sensor_hub' then
        raise exception 'InvalidDeviceKindError';
    end if;
    select coalesce(jsonb_agg(jsonb_build_object(
               'ch', s.channel,
               'type', s.sensor_type,
               'threshold', s.threshold,
               'hysteresis', s.hysteresis,
               'mapped', s.spot_id is not null
           ) order by s.channel), '[]'::jsonb)
      into channels
      from public.bay_sensors s where s.hub_device_id = device.id;
    return jsonb_build_object(
        'report_interval_s', 60,
        'stable_ms', 5000,
        'channels', channels
    );
end;
$$;

revoke all on function public.device_bay_config(integer)
    from public, anon, authenticated;
grant execute on function public.device_bay_config(integer) to service_role;

create or replace function public.device_bay_report(
    p_device_id integer,
    p_channels jsonb,
    p_full boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    settings public.bay_sensor_settings%rowtype;
    element jsonb;
    sensor public.bay_sensors%rowtype;
    ch integer;
    state text;
    raw_value numeric;
    at_time timestamptz;
    accepted integer := 0;
    ignored integer := 0;
    created jsonb := '[]'::jsonb;
    previous text;
    confirmed text;
    total_channels integer;
    new_channels integer := 0;
    existing integer;
begin
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.enabled;
    if not found or device.kind <> 'sensor_hub' then
        raise exception 'InvalidDeviceKindError';
    end if;
    if p_channels is null or jsonb_typeof(p_channels) <> 'array'
       or jsonb_array_length(p_channels) < 1
       or jsonb_array_length(p_channels) > 64 then
        raise exception 'InvalidDataError';
    end if;

    settings := public.bay_sensor_effective_settings(device.lot_id);

    -- Validate the whole batch first: nothing is written on a bad element.
    for element in select value from jsonb_array_elements(p_channels) loop
        if jsonb_typeof(element) <> 'object' then
            raise exception 'InvalidDataError';
        end if;
        ch := (element ->> 'ch')::integer;
        state := element ->> 'state';
        at_time := (element ->> 'at')::timestamptz;
        if ch is null or ch < 1 or ch > 64
           or state is null or state not in ('free', 'occupied', 'error')
           or at_time is null then
            raise exception 'InvalidDataError';
        end if;
        if at_time > now() + public.max_client_clock_skew() then
            raise exception 'InvalidReadTimeError';
        end if;
    end loop;

    -- Serialize reports of one hub in channel order.
    perform 1 from public.bay_sensors s
     where s.hub_device_id = device.id order by s.channel for update;

    select count(*) into existing from public.bay_sensors s
     where s.hub_device_id = device.id;
    for element in select value from jsonb_array_elements(p_channels) loop
        ch := (element ->> 'ch')::integer;
        if not exists (
            select 1 from public.bay_sensors s
             where s.hub_device_id = device.id and s.channel = ch
        ) then
            new_channels := new_channels + 1;
        end if;
    end loop;
    total_channels := existing + new_channels;
    if total_channels > 64 then
        raise exception 'ChannelLimitError';
    end if;

    for element in select value from jsonb_array_elements(p_channels) loop
        ch := (element ->> 'ch')::integer;
        state := element ->> 'state';
        at_time := (element ->> 'at')::timestamptz;
        raw_value := case when element ->> 'raw' is null then null
                          else (element ->> 'raw')::numeric end;

        select * into sensor from public.bay_sensors s
         where s.hub_device_id = device.id and s.channel = ch for update;
        if not found then
            insert into public.bay_sensors (
                lot_id, hub_device_id, channel, reported_state,
                reported_since, last_report_at, last_raw
            ) values (
                device.lot_id, device.id, ch, state, at_time, at_time, raw_value
            ) returning * into sensor;
            created := created || to_jsonb(ch);
            accepted := accepted + 1;
            continue;
        end if;
        if sensor.last_report_at is not null and at_time <= sensor.last_report_at then
            ignored := ignored + 1;
            continue;
        end if;
        if state <> coalesce(sensor.reported_state, '') then
            previous := public.bay_effective_state(
                sensor, settings.debounce_seconds, settings.stale_minutes);
            confirmed := case when previous in ('free', 'occupied')
                              then previous else null end;
            insert into public.bay_sensor_events (lot_id, sensor_id, state, at)
            values (device.lot_id, sensor.id, state, at_time);
            update public.bay_sensors s
               set reported_state = state,
                   reported_since = at_time,
                   confirmed_state = confirmed,
                   last_report_at = at_time,
                   last_raw = coalesce(raw_value, s.last_raw)
             where s.id = sensor.id;
        else
            update public.bay_sensors s
               set last_report_at = at_time,
                   last_raw = coalesce(raw_value, s.last_raw)
             where s.id = sensor.id;
        end if;
        accepted := accepted + 1;
    end loop;

    return jsonb_build_object(
        'accepted', accepted,
        'ignored', ignored,
        'created_channels', created
    );
end;
$$;

revoke all on function public.device_bay_report(integer, jsonb, boolean)
    from public, anon, authenticated;
grant execute on function public.device_bay_report(integer, jsonb, boolean)
    to service_role;

-- ---------------------------------------------------------------------------
-- Mismatch synchronisation and evaluation.
-- ---------------------------------------------------------------------------
create or replace function public.bay_sync_mismatch(
    p_lot_id integer,
    p_spot_id integer,
    p_sensor_id integer,
    p_session_id integer,
    p_kind text,
    p_active boolean,
    p_cooldown_minutes integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    mismatch public.bay_mismatches%rowtype;
    sensor_name text;
begin
    if not p_active then
        update public.bay_mismatches m
           set status = 'resolved', resolved_reason = 'auto', resolved_at = now()
         where m.spot_id = p_spot_id and m.kind = p_kind and m.status = 'open';
        return false;
    end if;
    if exists (
        select 1 from public.bay_mismatches m
         where m.spot_id = p_spot_id and m.kind = p_kind and m.status = 'open'
    ) then
        return false;
    end if;
    if exists (
        select 1 from public.bay_mismatches m
         where m.spot_id = p_spot_id and m.kind = p_kind
           and m.status = 'resolved'
           and m.resolved_at > now() - make_interval(mins => p_cooldown_minutes)
    ) then
        return false;
    end if;

    insert into public.bay_mismatches (
        lot_id, spot_id, sensor_id, kind, session_id
    ) values (
        p_lot_id, p_spot_id, p_sensor_id, p_kind, p_session_id
    ) returning * into mismatch;

    select code into sensor_name from public.parking_spots s where s.id = p_spot_id;
    perform public.bay_notify(
        p_lot_id,
        'bay_mismatch',
        'Cupo con diferencia',
        'El cupo ' || coalesce(sensor_name, p_spot_id::text)
            || ' no coincide con el sistema.',
        jsonb_build_object(
            'mismatch_id', mismatch.id,
            'spot_id', p_spot_id,
            'kind', p_kind
        ),
        'bay_mismatch:' || mismatch.id,
        false
    );
    return true;
end;
$$;

revoke all on function public.bay_sync_mismatch(integer, integer, integer, integer, text, boolean, integer)
    from public, anon, authenticated;

create or replace function public.evaluate_bay_mismatches()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer;
    settings public.bay_sensor_settings%rowtype;
    sensor public.bay_sensors%rowtype;
    spot public.parking_spots%rowtype;
    open_session public.parking_sessions%rowtype;
    hub public.lot_devices%rowtype;
    minutes integer;
    hub_status text;
    eff text;
    health text;
    stable_for interval;
    grace interval;
    opened integer := 0;
begin
    for lot in
        select distinct s.lot_id from public.bay_sensors s order by 1
    loop
        perform pg_advisory_xact_lock(hashtext('bay_eval'), lot);
        settings := public.bay_sensor_effective_settings(lot);
        grace := make_interval(mins => settings.mismatch_grace_minutes);

        -- A sensor that stopped being reliable cannot keep raising alerts.
        update public.bay_mismatches m
           set status = 'resolved',
               resolved_reason = 'sensor_unreliable',
               resolved_at = now()
          from public.bay_sensors s
         where m.status = 'open'
           and m.sensor_id = s.id
           and s.lot_id = lot
           and public.bay_health(s, settings) <> 'ok';

        for sensor in
            select * from public.bay_sensors s
             where s.lot_id = lot and s.spot_id is not null
             order by s.id
        loop
            health := public.bay_health(sensor, settings);
            continue when health <> 'ok';

            select * into hub from public.lot_devices d
             where d.id = sensor.hub_device_id;
            select coalesce(device_offline_minutes, 5) into minutes
              from public.parking_settings where lot_id = lot;
            hub_status := public.device_status(
                hub.enabled, hub.last_seen_at, coalesce(minutes, 5));
            if health in ('stale', 'fault', 'flapping') and hub_status <> 'offline' then
                perform public.bay_notify(
                    lot,
                    'bay_sensor_unhealthy',
                    'Sensor de cupo con problemas',
                    coalesce(hub.name, 'Hub') || ' canal ' || sensor.channel
                        || ': ' || health,
                    jsonb_build_object(
                        'sensor_id', sensor.id,
                        'health', health
                    ),
                    'bay_sensor_unhealthy:' || sensor.id || ':'
                        || to_char(now(), 'YYYYMMDD'),
                    true
                );
            end if;

            eff := public.bay_effective_state(
                sensor, settings.debounce_seconds, settings.stale_minutes);
            stable_for := case
                when eff = coalesce(sensor.reported_state, '')
                    then now() - coalesce(sensor.reported_since, now())
                else interval '0'
            end;
            select * into spot from public.parking_spots p where p.id = sensor.spot_id;
            select * into open_session from public.parking_sessions s
             where s.lot_id = lot and s.spot_id = spot.id and s.status = 'open'
             order by s.entry_time limit 1;

            if public.bay_sync_mismatch(
                lot, spot.id, sensor.id, null,
                'occupied_unassigned',
                eff = 'occupied' and spot.status = 'active'
                    and open_session.id is null and stable_for >= grace,
                settings.cooldown_minutes) then
                opened := opened + 1;
            end if;
            if public.bay_sync_mismatch(
                lot, spot.id, sensor.id, open_session.id,
                'assigned_empty',
                eff = 'free' and open_session.id is not null
                    and open_session.entry_time <= now() - grace
                    and stable_for >= grace,
                settings.cooldown_minutes) then
                opened := opened + 1;
            end if;
            if public.bay_sync_mismatch(
                lot, spot.id, sensor.id, null,
                'occupied_out_of_service',
                eff = 'occupied' and spot.status = 'out_of_service'
                    and stable_for >= grace,
                settings.cooldown_minutes) then
                opened := opened + 1;
            end if;
        end loop;
    end loop;
    return opened;
end;
$$;

revoke all on function public.evaluate_bay_mismatches()
    from public, anon, authenticated;
grant execute on function public.evaluate_bay_mismatches() to service_role;

create or replace function public.purge_bay_sensor_events(p_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    cutoff timestamptz := now() - make_interval(
        days => greatest(coalesce(p_days, 90), 1));
    removed integer;
begin
    delete from public.bay_sensor_events e where e.at < cutoff;
    get diagnostics removed = row_count;
    return removed;
end;
$$;

revoke all on function public.purge_bay_sensor_events(integer)
    from public, anon, authenticated;
grant execute on function public.purge_bay_sensor_events(integer) to service_role;
