-- Barrier control — the operator and admin RPCs.
--
-- Operators see the barriers, open one manually with a mandatory reason
-- (audited and rate-limited, admins notified) and follow the command history.
-- Admins configure (via set_barrier_config) and release firmware. Every read
-- is scoped to the active lot.

create or replace function public.list_barriers()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    minutes integer;
begin
    perform public.require_app_user();
    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = lot;
    return coalesce((
        select jsonb_agg(jsonb_build_object(
                   'device_id', d.id,
                   'name', d.name,
                   'enabled', d.enabled,
                   'status', public.device_status(
                       d.enabled, d.last_seen_at, coalesce(minutes, 5)),
                   'last_seen_at', d.last_seen_at,
                   'firmware_version', d.firmware_version,
                   'direction', c.direction,
                   'camera_device_id', c.camera_device_id,
                   'camera_name', cam.name,
                   'config', case when c.device_id is null then null
                       else jsonb_build_object(
                           'direction', c.direction,
                           'camera_device_id', c.camera_device_id,
                           'open_on_checkin', c.open_on_checkin,
                           'open_on_paid_exit', c.open_on_paid_exit,
                           'open_for_pass_entry', c.open_for_pass_entry,
                           'open_hold_ms', c.open_hold_ms,
                           'max_open_seconds', c.max_open_seconds,
                           'post_clear_delay_ms', c.post_clear_delay_ms,
                           'max_reversals', c.max_reversals,
                           'command_ttl_seconds', c.command_ttl_seconds,
                           'updated_at', c.updated_at
                       ) end,
                   'in_flight', (
                       select public.barrier_command_json(cmd)
                         from public.barrier_commands cmd
                        where cmd.device_id = d.id
                          and cmd.status in ('queued', 'delivered')
                        order by cmd.issued_at desc
                        limit 1
                   ),
                   'last_command', (
                       select public.barrier_command_json(cmd)
                         from public.barrier_commands cmd
                        where cmd.device_id = d.id
                        order by cmd.issued_at desc
                        limit 1
                   )
               ) order by d.name, d.id)
          from public.lot_devices d
          left join public.barrier_config c on c.device_id = d.id
          left join public.lot_devices cam on cam.id = c.camera_device_id
         where d.lot_id = lot and d.kind = 'barrier'
    ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_barriers() from public;
grant execute on function public.list_barriers() to authenticated;

create or replace function public.request_manual_barrier_open(
    p_device_id integer,
    p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    device public.lot_devices%rowtype;
    minutes integer;
    status text;
    reason text := btrim(coalesce(p_reason, ''));
    recent integer;
    command jsonb;
    command_id uuid;
    user_name text;
begin
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.lot_id = lot and d.kind = 'barrier';
    if not found then
        raise exception 'DeviceNotFoundError';
    end if;
    if char_length(reason) < 3 or char_length(reason) > 200 then
        raise exception 'BarrierReasonRequiredError';
    end if;
    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = lot;
    status := public.device_status(
        device.enabled, device.last_seen_at, coalesce(minutes, 5));
    if status <> 'online' then
        raise exception 'BarrierOfflineError';
    end if;
    if exists (
        select 1 from public.barrier_commands c
         where c.device_id = device.id and c.status in ('queued', 'delivered')
    ) then
        raise exception 'BarrierBusyError';
    end if;
    select count(*) into recent from public.barrier_commands c
     where c.lot_id = lot
       and c.source = 'manual'
       and c.requested_by = actor
       and c.issued_at > now() - interval '1 hour';
    if recent >= 10 then
        raise exception 'BarrierRateLimitedError';
    end if;

    command := public.barrier_issue_command(
        lot, device.id, 'manual', reason, null, null, actor);
    command_id := (command ->> 'id')::uuid;
    select display_name into user_name from public.users u where u.id = actor;
    perform public.barrier_notify(
        lot,
        'barrier_manual_open',
        'Barrera abierta manualmente',
        device.name || ': ' || coalesce(user_name, 'Operador')
            || ' la abrió. Motivo: ' || reason,
        jsonb_build_object(
            'command_id', command_id,
            'device_id', device.id
        ),
        'barrier_manual_open:' || command_id,
        true
    );
    return jsonb_build_object(
        'command_id', command_id,
        'expires_at', command ->> 'expires_at'
    );
end;
$$;

revoke all on function public.request_manual_barrier_open(integer, text) from public;
grant execute on function public.request_manual_barrier_open(integer, text) to authenticated;

create or replace function public.get_barrier_command(p_command_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    command public.barrier_commands%rowtype;
    user_name text;
begin
    select * into command from public.barrier_commands c
     where c.id = p_command_id and c.lot_id = lot;
    if not found then
        raise exception 'BarrierCommandNotFoundError';
    end if;
    select display_name into user_name from public.users u
     where u.id = command.requested_by;
    return public.barrier_command_json(command)
        || jsonb_build_object('requested_by_name', user_name);
end;
$$;

revoke all on function public.get_barrier_command(uuid) from public;
grant execute on function public.get_barrier_command(uuid) to authenticated;

create or replace function public.list_barrier_commands(
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
    lot integer := public.current_lot_id();
    max_rows integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
    if p_device_id is not null and not exists (
        select 1 from public.lot_devices d
         where d.id = p_device_id and d.lot_id = lot and d.kind = 'barrier'
    ) then
        raise exception 'DeviceNotFoundError';
    end if;
    return coalesce((
        select jsonb_agg(public.barrier_command_json(c)
                   || jsonb_build_object('requested_by_name', u.display_name)
                   order by c.issued_at desc, c.id desc)
          from (
              select * from public.barrier_commands cmd
               where cmd.lot_id = lot
                 and (p_device_id is null or cmd.device_id = p_device_id)
               order by cmd.issued_at desc, cmd.id desc
               limit max_rows
          ) c
          left join public.users u on u.id = c.requested_by
    ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_barrier_commands(integer, integer) from public;
grant execute on function public.list_barrier_commands(integer, integer) to authenticated;

create or replace function public.release_device_firmware(
    p_kind text,
    p_version text,
    p_sha256 text,
    p_size_bytes integer,
    p_storage_path text,
    p_secure_version integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_admin();
    firmware public.device_firmware%rowtype;
begin
    if p_kind not in ('camera', 'barrier', 'sensor_hub') then
        raise exception 'InvalidDataError';
    end if;
    if p_version is null or p_version !~ '^[0-9]+\.[0-9]+\.[0-9]+$' then
        raise exception 'InvalidDataError';
    end if;
    if p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' then
        raise exception 'InvalidDataError';
    end if;
    if p_size_bytes is null or p_size_bytes <= 0
       or p_storage_path is null
       or char_length(p_storage_path) not between 1 and 200 then
        raise exception 'InvalidDataError';
    end if;
    begin
        insert into public.device_firmware (
            kind, version, sha256, size_bytes, storage_path,
            secure_version, released, created_by
        ) values (
            p_kind, p_version, p_sha256, p_size_bytes, p_storage_path,
            greatest(coalesce(p_secure_version, 0), 0), true, actor
        ) returning * into firmware;
    exception when unique_violation then
        raise exception 'ConflictError';
    end;
    return to_jsonb(firmware);
end;
$$;

revoke all on function public.release_device_firmware(text, text, text, integer, text, integer) from public;
grant execute on function public.release_device_firmware(text, text, text, integer, text, integer) to authenticated;
