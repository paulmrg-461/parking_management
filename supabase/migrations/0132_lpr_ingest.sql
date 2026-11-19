-- LPR gate — reads, server-side voting, decisions and snapshots.
--
-- The camera posts reads through the service-role gateway; this function is
-- the only writer of lpr_reads/lpr_events. Debounce and voting are
-- deterministic (design D3) and the decision table (D4) never closes a
-- session: an unpaid exit is only a pending alert for the desk.
--
-- Auto entry impersonates the lot's system operator inside its own
-- transaction: `check_in` is called with named arguments and every claim is
-- restored afterwards, including on failure.

create table if not exists public.lpr_events (
    id            bigserial primary key,
    lot_id        integer not null references public.parking_lots(id) on delete cascade,
    device_id     integer references public.lot_devices(id) on delete set null,
    direction     text    not null check (direction in ('entry', 'exit')),
    plate         varchar(20) not null,
    confidence    numeric(4,3) not null,
    votes         integer not null check (votes >= 1),
    status        text    not null check (status in ('pending','done','blocked','confirmed','dismissed','expired')),
    reason        text    check (reason in ('assist_mode','low_confidence','unknown_plate','no_system_operator',
                                            'duplicate_session','lot_full','error','blacklisted',
                                            'exit_unpaid','exit_paid','no_open_session')),
    session_id    integer references public.parking_sessions(id) on delete set null,
    vehicle_id    integer references public.vehicles(id) on delete set null,
    has_pass      boolean not null default false,
    snapshot_path varchar(255),
    detail        jsonb   not null default '{}'::jsonb,
    resolved_by   integer references public.users(id) on delete set null,
    resolved_at   timestamptz,
    created_at    timestamptz not null default now()
);
create index if not exists ix_lpr_events_lot_status
    on public.lpr_events(lot_id, status, created_at desc);
create index if not exists ix_lpr_events_plate
    on public.lpr_events(lot_id, plate, direction, created_at desc);
alter table public.lpr_events enable row level security;
revoke all on public.lpr_events from anon, authenticated;

create table if not exists public.lpr_reads (
    id          bigserial primary key,
    lot_id      integer not null references public.parking_lots(id) on delete cascade,
    device_id   integer not null references public.lot_devices(id) on delete cascade,
    client_ref  uuid    not null,
    direction   text    not null check (direction in ('entry', 'exit')),
    plate       varchar(20) not null,
    confidence  numeric(4,3) not null check (confidence > 0 and confidence <= 1),
    captured_at timestamptz not null,
    track_id    varchar(40),
    outcome     text    not null,
    event_id    bigint  references public.lpr_events(id) on delete set null,
    created_at  timestamptz not null default now(),
    unique (device_id, client_ref)
);
create index if not exists ix_lpr_reads_vote
    on public.lpr_reads(device_id, plate, captured_at) where event_id is null;
alter table public.lpr_reads enable row level security;
revoke all on public.lpr_reads from anon, authenticated;

-- Storage: an event snapshot is readable by the members of its lot even before
-- a session/evidence row exists. The policy cannot use current_lot_id() (the
-- header is stripped), so it goes through a security-definer helper.
create or replace function public.can_read_lpr_snapshot(p_path text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.lpr_events e
         where e.snapshot_path = p_path
           and public.can_read_lot(e.lot_id)
    );
$$;
grant execute on function public.can_read_lpr_snapshot(text) to authenticated;

drop policy if exists lpr_snapshots_read on storage.objects;
create policy lpr_snapshots_read on storage.objects
    for select to authenticated
    using (bucket_id = 'evidence' and name like 'lpr/%'
           and public.can_read_lpr_snapshot(name));

-- ---------------------------------------------------------------------------
-- Helpers (internal).
-- ---------------------------------------------------------------------------
create or replace function public.lpr_event_json(p_event public.lpr_events)
returns jsonb
language sql
immutable
set search_path = public
as $$
    select jsonb_build_object(
        'id', p_event.id,
        'kind', p_event.direction,
        'status', p_event.status,
        'reason', p_event.reason,
        'plate', p_event.plate,
        'confidence', p_event.confidence,
        'votes', p_event.votes,
        'session_id', p_event.session_id,
        'vehicle_id', p_event.vehicle_id,
        'has_pass', p_event.has_pass,
        'snapshot_path', p_event.snapshot_path,
        'created_at', p_event.created_at
    );
$$;

revoke all on function public.lpr_event_json(public.lpr_events)
    from public, anon, authenticated;

-- One notification per event and member. Called only when an event needs the
-- desk (pending or blocked); a paid exit notifies nobody.
create or replace function public.lpr_notify(p_event_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    event public.lpr_events%rowtype;
    kind text;
    title text;
    body text;
begin
    select * into event from public.lpr_events where id = p_event_id;
    if not found then
        return;
    end if;
    if event.reason = 'exit_unpaid' then
        kind := 'lpr_exit';
        title := 'Vehículo saliendo';
        body := event.plate || ' tiene una sesión abierta.';
    elsif event.reason = 'blacklisted' then
        kind := 'lpr_blacklisted';
        title := 'Vehículo en lista negra';
        body := event.plate || ' está en la lista negra.';
    else
        kind := 'lpr_pending';
        title := 'Lectura de placa pendiente';
        body := event.plate || ' espera confirmación en la puerta.';
    end if;
    insert into public.notifications (
        user_id, type, title, body, data, dedupe_key, lot_id
    )
    select u.id, kind, title, body,
           jsonb_build_object(
               'event_id', event.id,
               'plate', event.plate,
               'reason', event.reason
           ),
           'lpr:' || event.id || ':user:' || u.id,
           event.lot_id
      from public.lot_members lm
      join public.users u on u.id = lm.user_id
     where lm.lot_id = event.lot_id and u.is_active
    on conflict (dedupe_key) do nothing;
end;
$$;

revoke all on function public.lpr_notify(bigint) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Device RPCs.
-- ---------------------------------------------------------------------------
create or replace function public.device_lpr_config(p_device_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    config public.lpr_camera_config%rowtype;
    settings public.lpr_settings%rowtype;
begin
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.enabled;
    if not found or device.kind <> 'camera' then
        raise exception 'InvalidDeviceKindError';
    end if;
    select * into config from public.lpr_camera_config c
     where c.device_id = device.id;
    if not found then
        raise exception 'LprDirectionNotSetError';
    end if;
    settings := public.lpr_effective_settings(device.lot_id);
    return jsonb_build_object(
        'direction', config.direction,
        'min_confidence', settings.min_confidence,
        'vote_window_seconds', settings.vote_window_seconds,
        'heartbeat_interval_s', 60
    );
end;
$$;

revoke all on function public.device_lpr_config(integer)
    from public, anon, authenticated;
grant execute on function public.device_lpr_config(integer) to service_role;

create or replace function public.device_ingest_lpr_read(
    p_device_id integer,
    p_client_ref uuid,
    p_plate text,
    p_confidence numeric,
    p_captured_at timestamptz,
    p_track_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    config public.lpr_camera_config%rowtype;
    settings public.lpr_settings%rowtype;
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    read_row public.lpr_reads%rowtype;
    existing public.lpr_reads%rowtype;
    event public.lpr_events%rowtype;
    vehicle public.vehicles%rowtype;
    open_session public.parking_sessions%rowtype;
    paid_session public.parking_sessions%rowtype;
    has_vehicle boolean := false;
    event_status text;
    event_reason text;
    event_session integer;
    event_vehicle integer;
    has_pass boolean := false;
    detail jsonb := '{}'::jsonb;
    votes integer := 0;
    mean_conf numeric := 0;
    acting public.users%rowtype;
    acting_ok boolean := false;
    checkin jsonb;
    previous_sub text;
    previous_claims text;
    previous_headers text;
begin
    perform pg_advisory_xact_lock(hashtext('lpr'), p_device_id);

    select * into device from public.lot_devices d where d.id = p_device_id;
    if not found or not device.enabled or device.kind <> 'camera' then
        raise exception 'InvalidDeviceKindError';
    end if;
    select * into config from public.lpr_camera_config c
     where c.device_id = device.id;
    if not found then
        raise exception 'LprDirectionNotSetError';
    end if;
    if normalized !~ '^[A-Z0-9]{4,10}$' then
        raise exception 'InvalidPlateError';
    end if;
    if p_confidence is null or p_confidence <= 0 or p_confidence > 1 then
        raise exception 'InvalidConfidenceError';
    end if;
    if p_captured_at is null
       or p_captured_at > now() + public.max_client_clock_skew() then
        raise exception 'InvalidReadTimeError';
    end if;

    -- Idempotent retry: the same client_ref returns the stored outcome.
    select * into existing from public.lpr_reads r
     where r.device_id = device.id and r.client_ref = p_client_ref;
    if found then
        if existing.event_id is not null then
            select * into event from public.lpr_events e
             where e.id = existing.event_id;
            return jsonb_build_object(
                'read_id', existing.id,
                'outcome', 'replayed',
                'event', public.lpr_event_json(event),
                'snapshot_wanted', event.snapshot_path is null
            );
        end if;
        return jsonb_build_object(
            'read_id', existing.id,
            'outcome', 'replayed',
            'event', null,
            'snapshot_wanted', false
        );
    end if;

    settings := public.lpr_effective_settings(device.lot_id);

    insert into public.lpr_reads (
        lot_id, device_id, client_ref, direction, plate, confidence,
        captured_at, track_id, outcome
    ) values (
        device.lot_id, device.id, p_client_ref, config.direction, normalized,
        p_confidence, p_captured_at, left(btrim(coalesce(p_track_id, '')), 40),
        'recorded'
    ) returning * into read_row;

    -- A read that arrives late is stored as a fact but never votes.
    if p_captured_at < now() - interval '15 minutes' then
        update public.lpr_reads set outcome = 'stale' where id = read_row.id;
        return jsonb_build_object('read_id', read_row.id, 'outcome', 'stale',
                                  'event', null, 'snapshot_wanted', false);
    end if;

    if p_confidence < settings.min_confidence then
        update public.lpr_reads
           set outcome = 'ignored_low_confidence'
         where id = read_row.id;
        return jsonb_build_object('read_id', read_row.id,
                                  'outcome', 'ignored_low_confidence',
                                  'event', null, 'snapshot_wanted', false);
    end if;

    -- Debounce: a car sitting in front of the camera produces one event.
    select * into event from public.lpr_events e
     where e.lot_id = device.lot_id
       and e.direction = config.direction
       and e.plate = normalized
       and e.created_at >= now() - make_interval(secs => settings.cooldown_seconds)
     order by e.created_at desc, e.id desc
     limit 1;
    if found then
        update public.lpr_reads
           set outcome = 'debounced', event_id = event.id
         where id = read_row.id;
        return jsonb_build_object(
            'read_id', read_row.id,
            'outcome', 'debounced',
            'event', public.lpr_event_json(event),
            'snapshot_wanted', event.snapshot_path is null
        );
    end if;

    -- Votes: unattached, confident reads of this camera inside the window.
    select count(*), coalesce(avg(confidence), 0)
      into votes, mean_conf
      from public.lpr_reads r
     where r.device_id = device.id
       and r.plate = normalized
       and r.event_id is null
       and r.confidence >= settings.min_confidence
       and r.captured_at between
           p_captured_at - make_interval(secs => settings.vote_window_seconds)
           and p_captured_at;
    if votes < settings.min_votes then
        return jsonb_build_object('read_id', read_row.id, 'outcome', 'recorded',
                                  'event', null, 'snapshot_wanted', false);
    end if;

    select * into vehicle from public.vehicles v where v.plate = normalized;
    has_vehicle := found;
    if has_vehicle then
        has_pass := exists (
            select 1 from public.monthly_passes mp
             where mp.vehicle_id = vehicle.id
               and mp.lot_id = device.lot_id
               and mp.active
               and mp.start_date <= (now() at time zone 'America/Bogota')::date
               and mp.end_date >= (now() at time zone 'America/Bogota')::date
        );
    end if;

    if config.direction = 'entry' then
        if has_vehicle and vehicle.is_blacklisted then
            event_status := 'blocked';
            event_reason := 'blacklisted';
        elsif has_vehicle and exists (
            select 1 from public.parking_sessions s
             where s.vehicle_id = vehicle.id and s.status = 'open'
        ) then
            event_status := 'pending';
            event_reason := 'duplicate_session';
        elsif settings.mode = 'assist' then
            event_status := 'pending';
            event_reason := 'assist_mode';
        elsif mean_conf < settings.auto_confidence then
            event_status := 'pending';
            event_reason := 'low_confidence';
        elsif not has_vehicle and settings.default_category_id is null then
            event_status := 'pending';
            event_reason := 'unknown_plate';
        else
            if settings.acting_user_id is not null then
                select * into acting from public.users u
                 where u.id = settings.acting_user_id and u.is_active
                   and exists (
                       select 1 from public.lot_members lm
                        where lm.lot_id = device.lot_id
                          and lm.user_id = u.id
                          and lm.role in ('operator', 'admin')
                   );
                acting_ok := found and acting.auth_user_id is not null;
            end if;
            if not acting_ok then
                event_status := 'pending';
                event_reason := 'no_system_operator';
            else
                previous_sub := current_setting('request.jwt.claim.sub', true);
                previous_claims := current_setting('request.jwt.claims', true);
                previous_headers := current_setting('request.headers', true);
                begin
                    perform set_config('request.jwt.claim.sub',
                        acting.auth_user_id::text, true);
                    perform set_config('request.jwt.claims',
                        json_build_object('sub', acting.auth_user_id,
                                          'role', 'authenticated')::text, true);
                    perform set_config('request.headers',
                        json_build_object('x-lot-id', device.lot_id)::text, true);
                    checkin := public.check_in(
                        p_plate => normalized,
                        p_category_id => case when has_vehicle then null
                                              else settings.default_category_id end,
                        p_client_entry_time => p_captured_at,
                        p_lot_id => device.lot_id,
                        p_idempotency_key => 'lpr-read:' || p_client_ref::text
                    );
                    event_status := 'done';
                    event_reason := null;
                    event_session := (checkin ->> 'id')::integer;
                    event_vehicle := (checkin ->> 'vehicle_id')::integer;
                exception when others then
                    if sqlerrm like '%ParkingFullError%'
                       or sqlerrm like '%CategoryFullError%' then
                        event_status := 'pending';
                        event_reason := 'lot_full';
                    else
                        event_status := 'pending';
                        event_reason := 'error';
                        detail := jsonb_build_object('error', sqlerrm);
                    end if;
                end;
                perform set_config('request.jwt.claim.sub',
                    coalesce(previous_sub, ''), true);
                perform set_config('request.jwt.claims',
                    coalesce(previous_claims, ''), true);
                perform set_config('request.headers',
                    coalesce(previous_headers, ''), true);
            end if;
        end if;
    else
        if has_vehicle and vehicle.is_blacklisted then
            event_status := 'blocked';
            event_reason := 'blacklisted';
        else
            if has_vehicle then
                select * into open_session from public.parking_sessions s
                 where s.vehicle_id = vehicle.id
                   and s.lot_id = device.lot_id
                   and s.status = 'open'
                 order by s.entry_time desc
                 limit 1;
            end if;
            if open_session.id is not null then
                event_status := 'pending';
                event_reason := 'exit_unpaid';
                event_session := open_session.id;
            else
                if has_vehicle then
                    select * into paid_session from public.parking_sessions s
                     where s.vehicle_id = vehicle.id
                       and s.lot_id = device.lot_id
                       and s.status = 'closed'
                       and s.exit_time >= now() - make_interval(
                           mins => settings.exit_paid_window_minutes)
                     order by s.exit_time desc
                     limit 1;
                end if;
                if paid_session.id is not null then
                    event_status := 'done';
                    event_reason := 'exit_paid';
                    event_session := paid_session.id;
                else
                    event_status := 'pending';
                    event_reason := 'no_open_session';
                end if;
            end if;
        end if;
    end if;

    insert into public.lpr_events (
        lot_id, device_id, direction, plate, confidence, votes, status,
        reason, session_id, vehicle_id, has_pass, detail
    ) values (
        device.lot_id, device.id, config.direction, normalized, mean_conf,
        votes, event_status, event_reason, event_session, event_vehicle,
        has_pass, detail
    ) returning * into event;

    update public.lpr_reads
       set event_id = event.id, outcome = 'decided'
     where device_id = device.id
       and plate = normalized
       and event_id is null
       and confidence >= settings.min_confidence
       and captured_at between
           p_captured_at - make_interval(secs => settings.vote_window_seconds)
           and p_captured_at;

    if event.status in ('pending', 'blocked') then
        perform public.lpr_notify(event.id);
    end if;

    return jsonb_build_object(
        'read_id', read_row.id,
        'outcome', 'decided',
        'event', public.lpr_event_json(event),
        'snapshot_wanted', true
    );
end;
$$;

revoke all on function public.device_ingest_lpr_read(integer, uuid, text, numeric, timestamptz, text)
    from public, anon, authenticated;
grant execute on function public.device_ingest_lpr_read(integer, uuid, text, numeric, timestamptz, text)
    to service_role;

create or replace function public.device_lpr_attach_snapshot(
    p_device_id integer,
    p_event_id bigint,
    p_path text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    device public.lot_devices%rowtype;
    event public.lpr_events%rowtype;
    expected text;
begin
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.enabled;
    if not found or device.kind <> 'camera' then
        raise exception 'LprEventNotFoundError';
    end if;
    select * into event from public.lpr_events e
     where e.id = p_event_id
       and e.device_id = device.id
       and e.lot_id = device.lot_id;
    if not found then
        raise exception 'LprEventNotFoundError';
    end if;
    expected := 'lpr/' || device.lot_id || '/' || device.id || '/' || event.id || '.jpg';
    if p_path is null or p_path <> expected then
        raise exception 'InvalidSnapshotPathError';
    end if;
    if event.snapshot_path is not null then
        raise exception 'SnapshotAlreadyAttachedError';
    end if;
    if exists (
        select 1 from public.evidence_photos p
         where p.file_path = p_path
           and (event.session_id is null or p.session_id <> event.session_id)
    ) then
        raise exception 'InvalidSnapshotPathError';
    end if;

    update public.lpr_events set snapshot_path = p_path where id = event.id;
    if event.session_id is not null
       and not exists (
           select 1 from public.evidence_photos p
            where p.file_path = p_path and p.session_id = event.session_id
       ) then
        insert into public.evidence_photos (session_id, file_path, taken_at)
        values (event.session_id, p_path, now());
    end if;
    return jsonb_build_object(
        'event_id', event.id,
        'session_id', event.session_id
    );
end;
$$;

revoke all on function public.device_lpr_attach_snapshot(integer, bigint, text)
    from public, anon, authenticated;
grant execute on function public.device_lpr_attach_snapshot(integer, bigint, text)
    to service_role;
