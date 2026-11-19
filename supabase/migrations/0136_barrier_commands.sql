-- Barrier control — the command queue, the device RPCs and the device events.
--
-- Commands are issued by the triggers of the next migration; this one gives
-- the gateway everything it needs to deliver and acknowledge them, reports
-- device events, expires stale commands and purges old history. Commands are
-- signed in the Edge Function (next slice); here they are plain rows with a
-- nonce and a short TTL.

create table if not exists public.barrier_commands (
    id            uuid primary key default gen_random_uuid(),
    lot_id        integer not null references public.parking_lots(id) on delete cascade,
    device_id     integer references public.lot_devices(id) on delete set null,
    device_name   varchar(60) not null,
    action        text not null default 'open' check (action = 'open'),
    source        text not null check (source in ('checkin','paid_exit','pass_recognised','manual','online_payment')),
    reason        text check (reason is null or char_length(btrim(reason)) between 3 and 200),
    session_id    integer references public.parking_sessions(id) on delete set null,
    lpr_event_id  bigint  references public.lpr_events(id) on delete set null,
    requested_by  integer references public.users(id) on delete set null,
    nonce         text not null default replace(gen_random_uuid()::text, '-', ''),
    status        text not null default 'queued' check (status in ('queued','delivered','executed','rejected','expired','cancelled')),
    deliveries    integer not null default 0,
    issued_at     timestamptz not null default now(),
    expires_at    timestamptz not null,
    delivered_at  timestamptz,
    acked_at      timestamptz,
    result        jsonb not null default '{}'::jsonb,
    check (source <> 'manual' or (requested_by is not null and reason is not null))
);
create index if not exists ix_barrier_commands_lot_issued
    on public.barrier_commands(lot_id, issued_at desc);
create index if not exists ix_barrier_commands_device_open
    on public.barrier_commands(device_id, issued_at)
    where status in ('queued', 'delivered');
alter table public.barrier_commands enable row level security;
revoke all on public.barrier_commands from anon, authenticated;

create table if not exists public.barrier_events (
    id         bigserial primary key,
    lot_id     integer not null references public.parking_lots(id) on delete cascade,
    device_id  integer not null references public.lot_devices(id) on delete cascade,
    client_ref uuid not null,
    event      text not null check (event in ('opened','closed','loop_retrigger','obstruction','tamper','power_restored','fault','fault_cleared')),
    detail     jsonb not null default '{}'::jsonb,
    happened_at timestamptz not null,
    created_at timestamptz not null default now(),
    unique (device_id, client_ref)
);
create index if not exists ix_barrier_events_lot
    on public.barrier_events(lot_id, happened_at desc);
alter table public.barrier_events enable row level security;
revoke all on public.barrier_events from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Helpers (internal).
-- ---------------------------------------------------------------------------
create or replace function public.barrier_command_json(p_command public.barrier_commands)
returns jsonb
language sql
immutable
set search_path = public
as $$
    select jsonb_build_object(
        'id', p_command.id,
        'device_id', p_command.device_id,
        'device_name', p_command.device_name,
        'action', p_command.action,
        'source', p_command.source,
        'reason', p_command.reason,
        'session_id', p_command.session_id,
        'lpr_event_id', p_command.lpr_event_id,
        'requested_by', p_command.requested_by,
        'nonce', p_command.nonce,
        'status', p_command.status,
        'deliveries', p_command.deliveries,
        'issued_at', p_command.issued_at,
        'expires_at', p_command.expires_at,
        'delivered_at', p_command.delivered_at,
        'acked_at', p_command.acked_at,
        'result', p_command.result
    );
$$;

revoke all on function public.barrier_command_json(public.barrier_commands)
    from public, anon, authenticated;

-- One row per member (or admin) and notification; dedupe_key is unique.
create or replace function public.barrier_notify(
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
           p_dedupe || ':user:' || u.id,
           p_lot_id
      from public.lot_members lm
      join public.users u on u.id = lm.user_id
     where lm.lot_id = p_lot_id
       and u.is_active
       and (not p_admins_only or lm.role = 'admin')
    on conflict (dedupe_key) do nothing;
end;
$$;

revoke all on function public.barrier_notify(integer, text, text, text, jsonb, text, boolean)
    from public, anon, authenticated;

create or replace function public.barrier_notify_failed(p_command_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    command public.barrier_commands%rowtype;
    source_text text;
begin
    select * into command from public.barrier_commands c where c.id = p_command_id;
    if not found then
        return;
    end if;
    source_text := case command.source
        when 'checkin' then 'entrada'
        when 'paid_exit' then 'salida pagada'
        when 'pass_recognised' then 'pase mensual'
        when 'manual' then 'apertura manual'
        else 'pago en línea'
    end;
    perform public.barrier_notify(
        command.lot_id,
        'barrier_command_failed',
        'La barrera no abrió',
        command.device_name || ' no ejecutó la orden (' || source_text || ')',
        jsonb_build_object(
            'command_id', command.id,
            'device_id', command.device_id,
            'session_id', command.session_id
        ),
        'barrier_command_failed:' || command.id,
        false
    );
end;
$$;

revoke all on function public.barrier_notify_failed(uuid)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Device RPCs (service role only).
-- ---------------------------------------------------------------------------
create or replace function public.device_barrier_config(p_device_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    config public.barrier_config%rowtype;
begin
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.enabled;
    if not found or device.kind <> 'barrier' then
        raise exception 'InvalidDeviceKindError';
    end if;
    select * into config from public.barrier_config c
     where c.device_id = device.id;
    if not found then
        raise exception 'BarrierConfigMissingError';
    end if;
    return jsonb_build_object(
        'direction', config.direction,
        'open_hold_ms', config.open_hold_ms,
        'max_open_seconds', config.max_open_seconds,
        'post_clear_delay_ms', config.post_clear_delay_ms,
        'max_reversals', config.max_reversals,
        'command_ttl_seconds', config.command_ttl_seconds,
        'heartbeat_interval_s', 60
    );
end;
$$;

revoke all on function public.device_barrier_config(integer)
    from public, anon, authenticated;
grant execute on function public.device_barrier_config(integer) to service_role;

create or replace function public.device_barrier_next(p_device_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    command public.barrier_commands%rowtype;
begin
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.enabled;
    if not found or device.kind <> 'barrier' then
        raise exception 'InvalidDeviceKindError';
    end if;
    select * into command from public.barrier_commands c
     where c.device_id = device.id
       and c.status in ('queued', 'delivered')
       and c.expires_at > now()
       and (c.delivered_at is null
            or (c.deliveries < 3
                and c.delivered_at <= now() - interval '5 seconds'))
     order by c.issued_at, c.id
     limit 1
     for update;
    if not found then
        return null;
    end if;
    update public.barrier_commands c
       set status = 'delivered',
           deliveries = c.deliveries + 1,
           delivered_at = now()
     where c.id = command.id;
    select * into command from public.barrier_commands c where c.id = command.id;
    return public.barrier_command_json(command);
end;
$$;

revoke all on function public.device_barrier_next(integer)
    from public, anon, authenticated;
grant execute on function public.device_barrier_next(integer) to service_role;

create or replace function public.device_barrier_ack(
    p_device_id integer,
    p_command_id uuid,
    p_result text,
    p_detail jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    command public.barrier_commands%rowtype;
begin
    if p_result not in ('opened', 'refused') then
        raise exception 'InvalidDataError';
    end if;
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.kind = 'barrier';
    if not found then
        raise exception 'BarrierCommandNotFoundError';
    end if;
    select * into command from public.barrier_commands c
     where c.id = p_command_id and c.device_id = device.id
     for update;
    if not found then
        raise exception 'BarrierCommandNotFoundError';
    end if;
    if command.status in ('executed', 'rejected') then
        return public.barrier_command_json(command);
    end if;
    update public.barrier_commands c
       set status = case when p_result = 'opened' then 'executed' else 'rejected' end,
           acked_at = now(),
           result = coalesce(p_detail, '{}'::jsonb) || jsonb_build_object('result', p_result)
     where c.id = command.id;
    if p_result = 'refused' then
        perform public.barrier_notify_failed(command.id);
    end if;
    select * into command from public.barrier_commands c where c.id = command.id;
    return public.barrier_command_json(command);
end;
$$;

revoke all on function public.device_barrier_ack(integer, uuid, text, jsonb)
    from public, anon, authenticated;
grant execute on function public.device_barrier_ack(integer, uuid, text, jsonb)
    to service_role;

create or replace function public.device_barrier_event(
    p_device_id integer,
    p_client_ref uuid,
    p_event text,
    p_at timestamptz,
    p_detail jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    labels text;
    created boolean;
    inserted public.barrier_events%rowtype;
begin
    if p_event not in ('opened','closed','loop_retrigger','obstruction','tamper',
                       'power_restored','fault','fault_cleared') then
        raise exception 'InvalidDataError';
    end if;
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.kind = 'barrier';
    if not found then
        raise exception 'InvalidDeviceKindError';
    end if;
    insert into public.barrier_events (
        lot_id, device_id, client_ref, event, detail, happened_at
    ) values (
        device.lot_id, device.id, p_client_ref, p_event,
        coalesce(p_detail, '{}'::jsonb), coalesce(p_at, now())
    )
    on conflict (device_id, client_ref) do nothing
    returning * into inserted;
    created := inserted.id is not null;
    if created and p_event in ('obstruction','tamper','power_restored','fault') then
        labels := case p_event
            when 'obstruction' then 'obstrucción'
            when 'tamper' then 'manipulación'
            when 'power_restored' then 'reinicio por falla de energía'
            else 'falla'
        end;
        perform public.barrier_notify(
            device.lot_id,
            'barrier_fault',
            'Alerta en la barrera',
            device.name || ': ' || labels,
            jsonb_build_object('device_id', device.id, 'event', p_event),
            'barrier_fault:' || device.id || ':' || p_event || ':'
                || to_char(now(), 'YYYYMMDDHH24MI'),
            true
        );
    end if;
    if not created then
        select * into inserted from public.barrier_events e
         where e.device_id = device.id and e.client_ref = p_client_ref;
    end if;
    return jsonb_build_object(
        'id', inserted.id,
        'event', inserted.event,
        'replayed', not created
    );
end;
$$;

revoke all on function public.device_barrier_event(integer, uuid, text, timestamptz, jsonb)
    from public, anon, authenticated;
grant execute on function public.device_barrier_event(integer, uuid, text, timestamptz, jsonb)
    to service_role;

create or replace function public.device_firmware_manifest(
    p_device_id integer,
    p_current text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    firmware public.device_firmware%rowtype;
begin
    select * into device from public.lot_devices d where d.id = p_device_id;
    if not found then
        raise exception 'InvalidDeviceKindError';
    end if;
    select * into firmware from public.device_firmware f
     where f.kind = device.kind and f.released
       and (p_current is null or f.version <> p_current)
     order by f.secure_version desc, f.created_at desc
     limit 1;
    if not found then
        return null;
    end if;
    return jsonb_build_object(
        'version', firmware.version,
        'sha256', firmware.sha256,
        'size_bytes', firmware.size_bytes,
        'secure_version', firmware.secure_version,
        'storage_path', firmware.storage_path
    );
end;
$$;

revoke all on function public.device_firmware_manifest(integer, text)
    from public, anon, authenticated;
grant execute on function public.device_firmware_manifest(integer, text)
    to service_role;

-- ---------------------------------------------------------------------------
-- Jobs (service role only).
-- ---------------------------------------------------------------------------
create or replace function public.expire_barrier_commands()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    command public.barrier_commands%rowtype;
    changed integer := 0;
begin
    for command in
        select * from public.barrier_commands c
         where c.status in ('queued', 'delivered')
           and c.expires_at < now()
         for update
    loop
        update public.barrier_commands c
           set status = 'expired',
               result = coalesce(c.result, '{}'::jsonb)
                   || jsonb_build_object('error', 'expired')
         where c.id = command.id;
        perform public.barrier_notify_failed(command.id);
        changed := changed + 1;
    end loop;
    return changed;
end;
$$;

revoke all on function public.expire_barrier_commands()
    from public, anon, authenticated;
grant execute on function public.expire_barrier_commands() to service_role;

create or replace function public.purge_barrier_events(p_days integer default 365)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    cutoff timestamptz := now() - make_interval(days => greatest(coalesce(p_days, 365), 1));
    events integer;
    commands integer;
begin
    delete from public.barrier_events e where e.happened_at < cutoff;
    get diagnostics events = row_count;
    delete from public.barrier_commands c where c.issued_at < cutoff;
    get diagnostics commands = row_count;
    return events + commands;
end;
$$;

revoke all on function public.purge_barrier_events(integer)
    from public, anon, authenticated;
grant execute on function public.purge_barrier_events(integer) to service_role;
