-- Barrier control — the issuing logic and its triggers.
--
-- Four sources may open a barrier: a decided camera event (check-in, paid
-- exit, recognised pass holder) and a session close. Every path goes through
-- `barrier_issue_command`, which de-duplicates an in-flight command, records
-- an expired one when the barrier is offline (and alerts) and returns the
-- signed payload to the caller (the gateway signs at delivery).
--
-- The triggers never fail the business transaction: a broken barrier must not
-- roll back a check-in or a check-out.

create or replace function public.barrier_issue_command(
    p_lot_id integer,
    p_device_id integer,
    p_source text,
    p_reason text default null,
    p_session_id integer default null,
    p_lpr_event_id bigint default null,
    p_requested_by integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    config public.barrier_config%rowtype;
    command public.barrier_commands%rowtype;
    minutes integer;
    status text;
begin
    if p_source not in ('checkin','paid_exit','pass_recognised','manual','online_payment') then
        return null;
    end if;
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.lot_id = p_lot_id and d.kind = 'barrier';
    if not found then
        return null;
    end if;
    select * into config from public.barrier_config c where c.device_id = device.id;
    if not found then
        return null;
    end if;

    -- One open command per barrier: a second issuer gets the same command.
    select * into command from public.barrier_commands c
     where c.device_id = device.id and c.status in ('queued', 'delivered')
     order by c.issued_at desc
     limit 1;
    if found then
        return public.barrier_command_json(command);
    end if;

    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = p_lot_id;
    status := public.device_status(
        device.enabled, device.last_seen_at, coalesce(minutes, 5));
    if status <> 'online' then
        insert into public.barrier_commands (
            lot_id, device_id, device_name, source, reason, session_id,
            lpr_event_id, requested_by, status, expires_at, result
        ) values (
            p_lot_id, device.id, device.name, p_source, p_reason, p_session_id,
            p_lpr_event_id, p_requested_by, 'expired',
            now() + make_interval(secs => config.command_ttl_seconds),
            jsonb_build_object('error', 'offline')
        ) returning * into command;
        perform public.barrier_notify_failed(command.id);
        return public.barrier_command_json(command);
    end if;

    insert into public.barrier_commands (
        lot_id, device_id, device_name, source, reason, session_id,
        lpr_event_id, requested_by, status, expires_at
    ) values (
        p_lot_id, device.id, device.name, p_source, p_reason, p_session_id,
        p_lpr_event_id, p_requested_by, 'queued',
        now() + make_interval(secs => config.command_ttl_seconds)
    ) returning * into command;
    return public.barrier_command_json(command);
end;
$$;

revoke all on function public.barrier_issue_command(integer, integer, text, text, integer, bigint, integer)
    from public, anon, authenticated;
grant execute on function public.barrier_issue_command(integer, integer, text, text, integer, bigint, integer)
    to service_role;

-- The single enabled barrier of a direction when its rule is 'always'.
create or replace function public.barrier_single_device(
    p_lot_id integer,
    p_direction text,
    p_rule_column text
)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    device_id integer;
    total integer;
begin
    select count(*), min(c.device_id) into total, device_id
      from public.barrier_config c
      join public.lot_devices d on d.id = c.device_id and d.enabled
     where c.lot_id = p_lot_id
       and c.direction = p_direction
       and ((p_rule_column = 'open_on_checkin' and c.open_on_checkin = 'always')
         or (p_rule_column = 'open_on_paid_exit' and c.open_on_paid_exit = 'always'));
    return case when total = 1 then device_id else null end;
end;
$$;

revoke all on function public.barrier_single_device(integer, text, text)
    from public, anon, authenticated;

-- Online payments hook: same pairing rules as a paid exit.
create or replace function public.barrier_request_exit_open(
    p_session_id integer,
    p_source text default 'online_payment'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    session public.parking_sessions%rowtype;
    event public.lpr_events%rowtype;
    config public.barrier_config%rowtype;
    single integer;
begin
    if p_source not in ('online_payment', 'paid_exit') then
        return null;
    end if;
    select * into session from public.parking_sessions s where s.id = p_session_id;
    if not found then
        return null;
    end if;
    select * into event from public.lpr_events e
     where e.session_id = session.id
       and e.lot_id = session.lot_id
       and e.reason = 'exit_unpaid'
       and e.created_at >= now() - interval '15 minutes'
     order by e.created_at desc
     limit 1;
    if found then
        select * into config from public.barrier_config c
         where c.lot_id = session.lot_id
           and c.camera_device_id = event.device_id
           and c.direction = 'exit'
           and c.open_on_paid_exit <> 'never';
        if found then
            return public.barrier_issue_command(
                session.lot_id, config.device_id, p_source, null,
                session.id, event.id, null);
        end if;
    end if;
    single := public.barrier_single_device(
        session.lot_id, 'exit', 'open_on_paid_exit');
    if single is not null then
        return public.barrier_issue_command(
            session.lot_id, single, p_source, null, session.id, null, null);
    end if;
    return null;
end;
$$;

revoke all on function public.barrier_request_exit_open(integer, text)
    from public, anon, authenticated;
grant execute on function public.barrier_request_exit_open(integer, text)
    to service_role;

-- ---------------------------------------------------------------------------
-- Triggers.
-- ---------------------------------------------------------------------------
create or replace function public.barrier_on_lpr_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    config public.barrier_config%rowtype;
    source text;
begin
    begin
        if new.direction = 'entry' then
            if new.status in ('done', 'confirmed') and new.session_id is not null then
                source := 'checkin';
            elsif new.has_pass
                  and new.status in ('pending', 'done')
                  and new.direction = 'entry'
                  and coalesce(new.reason, '')::text
                      not in ('duplicate_session', 'blacklisted')
                  and new.created_at >= now() - interval '20 seconds' then
                source := 'pass_recognised';
            else
                return new;
            end if;
            select * into config from public.barrier_config c
             where c.lot_id = new.lot_id
               and c.camera_device_id = new.device_id
               and c.direction = 'entry';
            if not found or config.open_on_checkin = 'never' then
                return new;
            end if;
            if source = 'pass_recognised' then
                if not config.open_for_pass_entry or new.confidence < 0.95 then
                    return new;
                end if;
            end if;
            perform public.barrier_issue_command(
                new.lot_id, config.device_id, source, null,
                new.session_id, new.id, null);
        elsif new.direction = 'exit' and new.reason = 'exit_paid' then
            select * into config from public.barrier_config c
             where c.lot_id = new.lot_id
               and c.camera_device_id = new.device_id
               and c.direction = 'exit';
            if found and config.open_on_paid_exit <> 'never' then
                perform public.barrier_issue_command(
                    new.lot_id, config.device_id, 'paid_exit', null,
                    new.session_id, new.id, null);
            end if;
        end if;
    exception when others then
        raise warning 'barrier_on_lpr_event: %', sqlerrm;
    end;
    return new;
end;
$$;

revoke all on function public.barrier_on_lpr_event()
    from public, anon, authenticated;

drop trigger if exists trg_barrier_lpr_event on public.lpr_events;
create trigger trg_barrier_lpr_event
    after insert or update of status on public.lpr_events
    for each row execute function public.barrier_on_lpr_event();

create or replace function public.barrier_on_session_closed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    event public.lpr_events%rowtype;
    config public.barrier_config%rowtype;
    single integer;
begin
    begin
        select * into event from public.lpr_events e
         where e.session_id = new.id
           and e.lot_id = new.lot_id
           and e.reason = 'exit_unpaid'
           and e.created_at >= now() - interval '15 minutes'
         order by e.created_at desc
         limit 1;
        if found then
            select * into config from public.barrier_config c
             where c.lot_id = new.lot_id
               and c.camera_device_id = event.device_id
               and c.direction = 'exit'
               and c.open_on_paid_exit <> 'never';
            if found then
                perform public.barrier_issue_command(
                    new.lot_id, config.device_id, 'paid_exit', null,
                    new.id, event.id, null);
                return new;
            end if;
        end if;
        single := public.barrier_single_device(
            new.lot_id, 'exit', 'open_on_paid_exit');
        if single is not null then
            perform public.barrier_issue_command(
                new.lot_id, single, 'paid_exit', null, new.id, null, null);
        end if;
    exception when others then
        raise warning 'barrier_on_session_closed: %', sqlerrm;
    end;
    return new;
end;
$$;

revoke all on function public.barrier_on_session_closed()
    from public, anon, authenticated;

drop trigger if exists trg_barrier_session_closed on public.parking_sessions;
create trigger trg_barrier_session_closed
    after update of status on public.parking_sessions
    for each row
    when (old.status = 'open' and new.status = 'closed')
    execute function public.barrier_on_session_closed();

create or replace function public.barrier_on_session_opened()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    single integer;
begin
    begin
        single := public.barrier_single_device(
            new.lot_id, 'entry', 'open_on_checkin');
        if single is not null then
            perform public.barrier_issue_command(
                new.lot_id, single, 'checkin', null, new.id, null, null);
        end if;
    exception when others then
        raise warning 'barrier_on_session_opened: %', sqlerrm;
    end;
    return new;
end;
$$;

revoke all on function public.barrier_on_session_opened()
    from public, anon, authenticated;

drop trigger if exists trg_barrier_session_opened on public.parking_sessions;
create trigger trg_barrier_session_opened
    after insert on public.parking_sessions
    for each row
    when (new.status = 'open')
    execute function public.barrier_on_session_opened();
