-- Bay sensors — schema, effective state and health.
--
-- Sensors are advisory: `slot_board()`, capacity, check-in and reservations
-- do not read them. A hub reports channel states; the server debounces at
-- read time, judges health and (in the ingest migration) detects mismatches.
-- A lot without sensors is untouched.

create table if not exists public.bay_sensor_settings (
    lot_id                 integer primary key references public.parking_lots(id) on delete cascade,
    debounce_seconds       integer not null default 20 check (debounce_seconds between 5 and 300),
    stale_minutes          integer not null default 5  check (stale_minutes between 2 and 60),
    flap_per_hour          integer not null default 12 check (flap_per_hour between 3 and 120),
    mismatch_grace_minutes integer not null default 3  check (mismatch_grace_minutes between 1 and 60),
    cooldown_minutes       integer not null default 30 check (cooldown_minutes between 1 and 1440),
    updated_at             timestamptz not null default now()
);
alter table public.bay_sensor_settings enable row level security;
revoke all on public.bay_sensor_settings from anon, authenticated;

create or replace function public.bay_sensor_effective_settings(p_lot_id integer)
returns public.bay_sensor_settings
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        (select s from public.bay_sensor_settings s where s.lot_id = p_lot_id),
        row(p_lot_id, 20, 5, 12, 3, 30, now())::public.bay_sensor_settings
    );
$$;

revoke all on function public.bay_sensor_effective_settings(integer)
    from public, anon, authenticated;
grant execute on function public.bay_sensor_effective_settings(integer)
    to service_role;

create table if not exists public.bay_sensors (
    id              serial primary key,
    lot_id          integer  not null references public.parking_lots(id) on delete cascade,
    hub_device_id   integer  not null references public.lot_devices(id) on delete cascade,
    channel         smallint not null check (channel between 1 and 64),
    spot_id         integer  references public.parking_spots(id) on delete set null,
    sensor_type     text     not null default 'ultrasonic'
        check (sensor_type in ('ultrasonic', 'magnetic', 'contact')),
    threshold       numeric(8,1) not null default 1800 check (threshold > 0),
    hysteresis      numeric(8,1) not null default 150 check (hysteresis >= 0),
    reported_state  text     check (reported_state in ('free', 'occupied', 'error')),
    reported_since  timestamptz,
    confirmed_state text     check (confirmed_state in ('free', 'occupied')),
    last_report_at  timestamptz,
    last_raw        numeric(10,2),
    created_at      timestamptz not null default now(),
    unique (hub_device_id, channel)
);
create unique index if not exists uq_bay_sensor_spot
    on public.bay_sensors(spot_id) where spot_id is not null;
create index if not exists ix_bay_sensors_lot on public.bay_sensors(lot_id);
alter table public.bay_sensors enable row level security;
revoke all on public.bay_sensors from anon, authenticated;

create or replace function public.bay_sensors_check()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if not exists (
        select 1 from public.lot_devices d
         where d.id = new.hub_device_id and d.kind = 'sensor_hub'
           and d.lot_id = new.lot_id
    ) then
        raise exception 'InvalidDeviceKindError';
    end if;
    if new.spot_id is not null and not exists (
        select 1 from public.parking_spots p
         where p.id = new.spot_id and p.lot_id = new.lot_id
    ) then
        raise exception 'SpotNotFoundError';
    end if;
    return new;
end;
$$;

revoke all on function public.bay_sensors_check()
    from public, anon, authenticated;

drop trigger if exists trg_bay_sensors_check on public.bay_sensors;
create trigger trg_bay_sensors_check
    before insert or update of hub_device_id, spot_id, lot_id on public.bay_sensors
    for each row execute function public.bay_sensors_check();

drop trigger if exists trg_audit_row on public.bay_sensors;
create trigger trg_audit_row after insert or update or delete on public.bay_sensors
    for each row execute function public.record_audit();

create table if not exists public.bay_sensor_events (
    id        bigserial primary key,
    lot_id    integer not null references public.parking_lots(id) on delete cascade,
    sensor_id integer not null references public.bay_sensors(id) on delete cascade,
    state     text    not null check (state in ('free', 'occupied', 'error')),
    at        timestamptz not null
);
create index if not exists ix_bay_sensor_events_sensor
    on public.bay_sensor_events(sensor_id, at desc);
alter table public.bay_sensor_events enable row level security;
revoke all on public.bay_sensor_events from anon, authenticated;

create table if not exists public.bay_mismatches (
    id              bigserial primary key,
    lot_id          integer not null references public.parking_lots(id) on delete cascade,
    spot_id         integer not null references public.parking_spots(id) on delete cascade,
    sensor_id       integer references public.bay_sensors(id) on delete set null,
    kind            text    not null
        check (kind in ('occupied_unassigned', 'assigned_empty', 'occupied_out_of_service')),
    session_id      integer references public.parking_sessions(id) on delete set null,
    status          text    not null default 'open' check (status in ('open', 'resolved')),
    resolved_reason text    check (resolved_reason in ('auto', 'dismissed', 'sensor_unreliable')),
    note            text    check (note is null or char_length(note) <= 200),
    resolved_by     integer references public.users(id) on delete set null,
    opened_at       timestamptz not null default now(),
    resolved_at     timestamptz
);
create unique index if not exists uq_bay_mismatch_open
    on public.bay_mismatches(spot_id, kind) where status = 'open';
create index if not exists ix_bay_mismatches_lot
    on public.bay_mismatches(lot_id, status, opened_at desc);
alter table public.bay_mismatches enable row level security;
revoke all on public.bay_mismatches from anon, authenticated;

-- Effective state: a change must hold for the debounce window before it
-- replaces the previous state; silence makes it unknown instead of stale.
create or replace function public.bay_effective_state(
    s public.bay_sensors,
    p_debounce_seconds integer,
    p_stale_minutes integer
)
returns text
language sql
stable
set search_path = public
as $$
    select case
        when s.last_report_at is null then 'unknown'
        when s.last_report_at < now() - make_interval(mins => p_stale_minutes)
            then 'unknown'
        when s.reported_state = 'error' then 'unknown'
        when s.reported_since <= now() - make_interval(secs => p_debounce_seconds)
            then s.reported_state
        else coalesce(s.confirmed_state, 'unknown')
    end;
$$;

revoke all on function public.bay_effective_state(public.bay_sensors, integer, integer)
    from public, anon, authenticated;

-- Health priority: unmapped, never_seen, stale, fault, flapping, ok.
create or replace function public.bay_health(
    s public.bay_sensors,
    p_settings public.bay_sensor_settings
)
returns text
language sql
stable
security definer
set search_path = public
as $$
    select case
        when s.spot_id is null then 'unmapped'
        when s.last_report_at is null then 'never_seen'
        when s.last_report_at < now() - make_interval(mins => p_settings.stale_minutes)
            then 'stale'
        when s.reported_state = 'error' then 'fault'
        when (
            select count(*) from public.bay_sensor_events e
             where e.sensor_id = s.id
               and e.at >= now() - interval '1 hour'
        ) >= p_settings.flap_per_hour then 'flapping'
        else 'ok'
    end;
$$;

revoke all on function public.bay_health(public.bay_sensors, public.bay_sensor_settings)
    from public, anon, authenticated;
