-- Device gateway — registry and event log.
-- Devices are not users: they authenticate with a per-device API key whose
-- SHA-256 hash is stored here and whose plaintext is shown once. No audit
-- trigger touches this table (it would copy the hash into audit_log);
-- `device_events` is the trail.
--
-- This change ships the registry and transport only. Camera/barrier/sensor
-- behaviour lives in the follow-up hardware changes.

create table if not exists public.lot_devices (
    id                  serial      primary key,
    lot_id              integer     not null references public.parking_lots(id) on delete cascade,
    kind                text        not null check (kind in ('camera', 'barrier', 'sensor_hub')),
    name                varchar(60) not null check (char_length(btrim(name)) between 1 and 60),
    key_prefix          varchar(12) not null unique check (key_prefix ~ '^[0-9a-f]{12}$'),
    key_hash            text        not null check (key_hash ~ '^[0-9a-f]{64}$'),
    enabled             boolean     not null default true,
    last_seen_at        timestamptz,
    last_seq            bigint      not null default 0 check (last_seq >= 0),
    firmware_version    varchar(40),
    last_status         jsonb       not null default '{}'::jsonb,
    rate_per_minute     integer     not null default 120 check (rate_per_minute between 6 and 600),
    rate_window_start   timestamptz not null default now(),
    rate_window_count   integer     not null default 0,
    offline_notified_at timestamptz,
    key_rotated_at      timestamptz not null default now(),
    created_by          integer     references public.users(id) on delete set null,
    created_at          timestamptz not null default now(),
    unique (lot_id, name)
);
create index if not exists ix_lot_devices_lot on public.lot_devices(lot_id);

alter table public.lot_devices enable row level security;
revoke all on public.lot_devices from anon, authenticated;

create table if not exists public.device_events (
    id          bigserial   primary key,
    lot_id      integer     not null references public.parking_lots(id) on delete cascade,
    device_id   integer     references public.lot_devices(id) on delete set null,
    device_name varchar(60) not null,
    event       text        not null check (event in (
                    'registered', 'key_rotated', 'renamed', 'enabled', 'disabled',
                    'deleted', 'online', 'offline', 'auth_failed', 'request_rejected')),
    actor_id    integer     references public.users(id) on delete set null,
    detail      jsonb       not null default '{}'::jsonb,
    created_at  timestamptz not null default now()
);
create index if not exists ix_device_events_lot_created
    on public.device_events(lot_id, created_at desc);
create index if not exists ix_device_events_device_created
    on public.device_events(device_id, created_at desc);

alter table public.device_events enable row level security;
grant select on public.device_events to authenticated;

drop policy if exists device_events_admin_read on public.device_events;
create policy device_events_admin_read on public.device_events
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

alter table public.parking_settings
    add column if not exists device_offline_minutes integer not null default 5;
alter table public.parking_settings
    drop constraint if exists parking_settings_device_offline_check;
alter table public.parking_settings
    add constraint parking_settings_device_offline_check
    check (device_offline_minutes between 2 and 1440);

create or replace function public.max_client_clock_skew()
returns interval
language sql
immutable
as $$ select interval '5 minutes' $$;

grant execute on function public.max_client_clock_skew() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Helpers.
-- ---------------------------------------------------------------------------
create or replace function public.device_status(
    p_enabled boolean,
    p_last_seen_at timestamptz,
    p_offline_minutes integer
)
returns text
language sql
immutable
set search_path = public
as $$
    select case
        when not p_enabled then 'disabled'
        when p_last_seen_at is null then 'never_seen'
        when p_last_seen_at < now() - make_interval(mins => p_offline_minutes)
            then 'offline'
        else 'online'
    end;
$$;

revoke all on function public.device_status(boolean, timestamptz, integer)
    from public, anon, authenticated;

create or replace function public.device_json(
    p_device public.lot_devices,
    p_offline_minutes integer
)
returns jsonb
language sql
immutable
set search_path = public
as $$
    select jsonb_build_object(
        'id', p_device.id,
        'lot_id', p_device.lot_id,
        'kind', p_device.kind,
        'name', p_device.name,
        'key_prefix', p_device.key_prefix,
        'enabled', p_device.enabled,
        'status', public.device_status(
            p_device.enabled, p_device.last_seen_at, p_offline_minutes),
        'last_seen_at', p_device.last_seen_at,
        'firmware_version', p_device.firmware_version,
        'last_status', p_device.last_status,
        'rate_per_minute', p_device.rate_per_minute,
        'key_rotated_at', p_device.key_rotated_at,
        'created_at', p_device.created_at
    );
$$;

revoke all on function public.device_json(public.lot_devices, integer)
    from public, anon, authenticated;

create or replace function public.device_event(
    p_lot_id integer,
    p_device_id integer,
    p_name text,
    p_event text,
    p_actor integer,
    p_detail jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.device_events (
        lot_id, device_id, device_name, event, actor_id, detail
    ) values (p_lot_id, p_device_id, left(p_name, 60), p_event, p_actor, p_detail);
end;
$$;

revoke all on function public.device_event(integer, integer, text, text, integer, jsonb)
    from public, anon, authenticated;
