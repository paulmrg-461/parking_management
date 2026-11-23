-- Bay sensors — client RPCs.
--
-- The board reads the sensor layer through `bay_occupancy`; admins map the
-- hub channels to bays, tune the thresholds and the debounce/grace settings;
-- any member can dismiss a mismatch. Sensors never change capacity or a
-- session.

create or replace function public.bay_occupancy()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    settings public.bay_sensor_settings%rowtype;
    enabled boolean;
    bays jsonb;
    mismatches jsonb;
begin
    perform public.require_app_user();
    settings := public.bay_sensor_effective_settings(lot);
    select exists (select 1 from public.bay_sensors s where s.lot_id = lot)
      into enabled;
    if not enabled then
        return jsonb_build_object(
            'sensors_enabled', false,
            'bays', '[]'::jsonb,
            'mismatches', '[]'::jsonb
        );
    end if;
    select coalesce(jsonb_agg(jsonb_build_object(
               'spot_id', s.spot_id,
               'code', p.code,
               'group', p.group_name,
               'status', p.status,
               'sensor_id', s.id,
               'channel', s.channel,
               'state', public.bay_effective_state(
                   s, settings.debounce_seconds, settings.stale_minutes),
               'health', public.bay_health(s, settings),
               'threshold', s.threshold,
               'hysteresis', s.hysteresis,
               'last_raw', s.last_raw,
               'last_report_at', s.last_report_at,
               'mismatch', (
                   select m.kind from public.bay_mismatches m
                    where m.spot_id = s.spot_id and m.status = 'open'
                    order by m.opened_at desc limit 1
               )
           ) order by p.code), '[]'::jsonb)
      into bays
      from public.bay_sensors s
      join public.parking_spots p on p.id = s.spot_id
     where s.lot_id = lot and s.spot_id is not null;
    select coalesce(jsonb_agg(jsonb_build_object(
               'id', m.id,
               'spot_id', m.spot_id,
               'code', p.code,
               'kind', m.kind,
               'session_id', m.session_id,
               'opened_at', m.opened_at
           ) order by m.opened_at desc), '[]'::jsonb)
      into mismatches
      from public.bay_mismatches m
      join public.parking_spots p on p.id = m.spot_id
     where m.lot_id = lot and m.status = 'open';
    return jsonb_build_object(
        'sensors_enabled', true,
        'bays', bays,
        'mismatches', mismatches
    );
end;
$$;

revoke all on function public.bay_occupancy() from public;
grant execute on function public.bay_occupancy() to authenticated;

create or replace function public.list_bay_sensors()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    settings public.bay_sensor_settings%rowtype;
begin
    perform public.require_lot_admin();
    settings := public.bay_sensor_effective_settings(lot);
    return coalesce((
        select jsonb_agg(jsonb_build_object(
                   'sensor_id', s.id,
                   'hub_device_id', s.hub_device_id,
                   'hub_name', d.name,
                   'channel', s.channel,
                   'spot_id', s.spot_id,
                   'spot_code', p.code,
                   'sensor_type', s.sensor_type,
                   'threshold', s.threshold,
                   'hysteresis', s.hysteresis,
                   'reported_state', s.reported_state,
                   'state', public.bay_effective_state(
                       s, settings.debounce_seconds, settings.stale_minutes),
                   'health', public.bay_health(s, settings),
                   'last_raw', s.last_raw,
                   'last_report_at', s.last_report_at,
                   'flaps', (
                       select count(*) from public.bay_sensor_events e
                        where e.sensor_id = s.id
                          and e.at >= now() - interval '1 hour'
                   )
               ) order by d.name, s.channel)
          from public.bay_sensors s
          join public.lot_devices d on d.id = s.hub_device_id
          left join public.parking_spots p on p.id = s.spot_id
         where s.lot_id = lot
    ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_bay_sensors() from public;
grant execute on function public.list_bay_sensors() to authenticated;

create or replace function public.map_bay_sensor(
    p_sensor_id integer,
    p_spot_id integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    sensor public.bay_sensors%rowtype;
    spot public.parking_spots%rowtype;
begin
    select * into sensor from public.bay_sensors s
     where s.id = p_sensor_id and s.lot_id = lot;
    if not found then
        raise exception 'SensorNotFoundError';
    end if;
    select * into spot from public.parking_spots p
     where p.id = p_spot_id and p.lot_id = lot;
    if not found then
        raise exception 'SpotNotFoundError';
    end if;
    if sensor.spot_id is not null then
        raise exception 'SensorAlreadyMappedError';
    end if;
    if exists (
        select 1 from public.bay_sensors s
         where s.lot_id = lot and s.spot_id = p_spot_id
    ) then
        raise exception 'SpotHasSensorError';
    end if;
    update public.bay_mismatches m
       set status = 'resolved', resolved_reason = 'sensor_unreliable',
           resolved_at = now()
     where m.sensor_id = sensor.id and m.status = 'open';
    update public.bay_sensors s set spot_id = p_spot_id where s.id = sensor.id;
    return jsonb_build_object(
        'sensor_id', sensor.id,
        'spot_id', p_spot_id,
        'spot_code', spot.code
    );
end;
$$;

revoke all on function public.map_bay_sensor(integer, integer) from public;
grant execute on function public.map_bay_sensor(integer, integer) to authenticated;

create or replace function public.unmap_bay_sensor(p_sensor_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    sensor public.bay_sensors%rowtype;
begin
    select * into sensor from public.bay_sensors s
     where s.id = p_sensor_id and s.lot_id = lot;
    if not found then
        raise exception 'SensorNotFoundError';
    end if;
    update public.bay_mismatches m
       set status = 'resolved', resolved_reason = 'sensor_unreliable',
           resolved_at = now()
     where m.sensor_id = sensor.id and m.status = 'open';
    update public.bay_sensors s set spot_id = null where s.id = sensor.id;
    return jsonb_build_object('sensor_id', sensor.id, 'spot_id', null);
end;
$$;

revoke all on function public.unmap_bay_sensor(integer) from public;
grant execute on function public.unmap_bay_sensor(integer) to authenticated;

create or replace function public.set_bay_sensor_threshold(
    p_sensor_id integer,
    p_threshold numeric,
    p_hysteresis numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    sensor public.bay_sensors%rowtype;
begin
    if p_threshold is null or p_threshold <= 0
       or (p_hysteresis is not null and p_hysteresis < 0) then
        raise exception 'InvalidDataError';
    end if;
    select * into sensor from public.bay_sensors s
     where s.id = p_sensor_id and s.lot_id = lot;
    if not found then
        raise exception 'SensorNotFoundError';
    end if;
    update public.bay_sensors s
       set threshold = p_threshold,
           hysteresis = coalesce(p_hysteresis, s.hysteresis)
     where s.id = sensor.id;
    return jsonb_build_object(
        'sensor_id', sensor.id,
        'threshold', p_threshold,
        'hysteresis', coalesce(p_hysteresis, sensor.hysteresis)
    );
end;
$$;

revoke all on function public.set_bay_sensor_threshold(integer, numeric, numeric) from public;
grant execute on function public.set_bay_sensor_threshold(integer, numeric, numeric) to authenticated;

create or replace function public.dismiss_bay_mismatch(
    p_mismatch_id bigint,
    p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    mismatch public.bay_mismatches%rowtype;
    clean_note text := left(btrim(coalesce(p_note, '')), 200);
begin
    select * into mismatch from public.bay_mismatches m
     where m.id = p_mismatch_id and m.lot_id = lot;
    if not found then
        raise exception 'MismatchNotFoundError';
    end if;
    if mismatch.status <> 'open' then
        raise exception 'MismatchResolvedError';
    end if;
    if char_length(btrim(coalesce(p_note, ''))) > 200 then
        raise exception 'InvalidDataError';
    end if;
    update public.bay_mismatches m
       set status = 'resolved', resolved_reason = 'dismissed',
           resolved_by = actor, resolved_at = now(),
           note = case when clean_note = '' then null else clean_note end
     where m.id = mismatch.id;
    return jsonb_build_object('mismatch_id', mismatch.id, 'status', 'resolved');
end;
$$;

revoke all on function public.dismiss_bay_mismatch(bigint, text) from public;
grant execute on function public.dismiss_bay_mismatch(bigint, text) to authenticated;

create or replace function public.get_bay_sensor_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
begin
    perform public.require_app_user();
    return to_jsonb(public.bay_sensor_effective_settings(lot));
end;
$$;

revoke all on function public.get_bay_sensor_settings() from public;
grant execute on function public.get_bay_sensor_settings() to authenticated;

create or replace function public.set_bay_sensor_settings(
    p_debounce_seconds integer default null,
    p_stale_minutes integer default null,
    p_flap_per_hour integer default null,
    p_mismatch_grace_minutes integer default null,
    p_cooldown_minutes integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    current public.bay_sensor_settings%rowtype := public.bay_sensor_effective_settings(lot);
begin
    if coalesce(p_debounce_seconds, current.debounce_seconds) not between 5 and 300
       or coalesce(p_stale_minutes, current.stale_minutes) not between 2 and 60
       or coalesce(p_flap_per_hour, current.flap_per_hour) not between 3 and 120
       or coalesce(p_mismatch_grace_minutes, current.mismatch_grace_minutes) not between 1 and 60
       or coalesce(p_cooldown_minutes, current.cooldown_minutes) not between 1 and 1440
    then
        raise exception 'InvalidDataError';
    end if;
    insert into public.bay_sensor_settings (
        lot_id, debounce_seconds, stale_minutes, flap_per_hour,
        mismatch_grace_minutes, cooldown_minutes, updated_at
    ) values (
        lot,
        coalesce(p_debounce_seconds, current.debounce_seconds),
        coalesce(p_stale_minutes, current.stale_minutes),
        coalesce(p_flap_per_hour, current.flap_per_hour),
        coalesce(p_mismatch_grace_minutes, current.mismatch_grace_minutes),
        coalesce(p_cooldown_minutes, current.cooldown_minutes),
        now()
    )
    on conflict (lot_id) do update
        set debounce_seconds = excluded.debounce_seconds,
            stale_minutes = excluded.stale_minutes,
            flap_per_hour = excluded.flap_per_hour,
            mismatch_grace_minutes = excluded.mismatch_grace_minutes,
            cooldown_minutes = excluded.cooldown_minutes,
            updated_at = now();
    return to_jsonb(public.bay_sensor_effective_settings(lot));
end;
$$;

revoke all on function public.set_bay_sensor_settings(integer, integer, integer, integer, integer) from public;
grant execute on function public.set_bay_sensor_settings(integer, integer, integer, integer, integer) to authenticated;
