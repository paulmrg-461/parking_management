-- Barrier control — per-barrier configuration and the shared firmware table.
--
-- A barrier is a `lot_devices` row of kind `barrier` with one config row: its
-- direction, the paired LPR camera, which events may open it and the timings
-- the firmware enforces. Nothing here opens anything: commands, signing and
-- triggers arrive in later migrations, so a lot without a barrier is
-- untouched.
--
-- See openspec/changes/add-barrier-control/design.md (D4, data model).

create table if not exists public.barrier_config (
    device_id              integer primary key references public.lot_devices(id) on delete cascade,
    lot_id                 integer not null references public.parking_lots(id) on delete cascade,
    direction              text    not null default 'entry' check (direction in ('entry', 'exit')),
    camera_device_id       integer references public.lot_devices(id) on delete set null,
    open_on_checkin        text    not null default 'lpr_only' check (open_on_checkin in ('never', 'lpr_only', 'always')),
    open_on_paid_exit      text    not null default 'lpr_only' check (open_on_paid_exit in ('never', 'lpr_only', 'always')),
    open_for_pass_entry    boolean not null default false,
    open_hold_ms           integer not null default 1000  check (open_hold_ms between 200 and 30000),
    max_open_seconds       integer not null default 20    check (max_open_seconds between 5 and 120),
    post_clear_delay_ms    integer not null default 1500  check (post_clear_delay_ms between 500 and 10000),
    max_reversals          integer not null default 3     check (max_reversals between 1 and 10),
    command_ttl_seconds    integer not null default 30    check (command_ttl_seconds between 10 and 120),
    updated_at             timestamptz not null default now()
);

alter table public.barrier_config enable row level security;
revoke all on public.barrier_config from anon, authenticated;

create or replace function public.barrier_config_check()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if not exists (
        select 1 from public.lot_devices d
         where d.id = new.device_id and d.kind = 'barrier' and d.lot_id = new.lot_id
    ) then
        raise exception 'InvalidDeviceKindError';
    end if;
    if new.camera_device_id is not null and not exists (
        select 1 from public.lot_devices c
         where c.id = new.camera_device_id and c.kind = 'camera'
           and c.lot_id = new.lot_id
    ) then
        raise exception 'InvalidDeviceKindError';
    end if;
    return new;
end;
$$;

revoke all on function public.barrier_config_check()
    from public, anon, authenticated;

drop trigger if exists trg_barrier_config_check on public.barrier_config;
create trigger trg_barrier_config_check
    before insert or update on public.barrier_config
    for each row execute function public.barrier_config_check();

drop trigger if exists trg_audit_row on public.barrier_config;
create trigger trg_audit_row after insert or update or delete on public.barrier_config
    for each row execute function public.record_audit();

-- Firmware artifacts: private, service role only (the gateway streams them).
insert into storage.buckets (id, name, public, file_size_limit)
values ('firmware', 'firmware', false, 4194304)
on conflict (id) do nothing;

create table if not exists public.device_firmware (
    id           serial primary key,
    kind         text    not null check (kind in ('camera', 'barrier', 'sensor_hub')),
    version      varchar(20) not null check (version ~ '^[0-9]+\.[0-9]+\.[0-9]+$'),
    sha256       text    not null check (sha256 ~ '^[0-9a-f]{64}$'),
    size_bytes   integer not null check (size_bytes > 0),
    storage_path varchar(200) not null,
    secure_version integer not null default 0,
    released     boolean not null default false,
    created_by   integer references public.users(id) on delete set null,
    created_at   timestamptz not null default now(),
    unique (kind, version)
);

alter table public.device_firmware enable row level security;
revoke all on public.device_firmware from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Read: the lot's barriers with their config. Any member.
-- ---------------------------------------------------------------------------
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
                   'direction', c.direction,
                   'camera_device_id', c.camera_device_id,
                   'camera_name', cam.name,
                   'open_on_checkin', c.open_on_checkin,
                   'open_on_paid_exit', c.open_on_paid_exit,
                   'open_for_pass_entry', c.open_for_pass_entry,
                   'open_hold_ms', c.open_hold_ms,
                   'max_open_seconds', c.max_open_seconds,
                   'post_clear_delay_ms', c.post_clear_delay_ms,
                   'max_reversals', c.max_reversals,
                   'command_ttl_seconds', c.command_ttl_seconds,
                   'updated_at', c.updated_at
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

-- ---------------------------------------------------------------------------
-- Write: upsert the config. Admin only; every field coalesces with the
-- current value (or the documented default for a new row).
-- ---------------------------------------------------------------------------
create or replace function public.set_barrier_config(
    p_device_id integer,
    p_direction text default null,
    p_camera_device_id integer default null,
    p_open_on_checkin text default null,
    p_open_on_paid_exit text default null,
    p_open_for_pass_entry boolean default null,
    p_open_hold_ms integer default null,
    p_max_open_seconds integer default null,
    p_post_clear_delay_ms integer default null,
    p_max_reversals integer default null,
    p_command_ttl_seconds integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    device public.lot_devices%rowtype;
    current public.barrier_config%rowtype;
    direction text;
    camera integer;
begin
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.lot_id = lot;
    if not found then
        raise exception 'DeviceNotFoundError';
    end if;
    if device.kind <> 'barrier' then
        raise exception 'InvalidDeviceKindError';
    end if;
    select * into current from public.barrier_config c
     where c.device_id = device.id;
    if not found then
        current.device_id := device.id;
        current.lot_id := lot;
        current.direction := 'entry';
        current.open_on_checkin := 'lpr_only';
        current.open_on_paid_exit := 'lpr_only';
        current.open_for_pass_entry := false;
        current.open_hold_ms := 1000;
        current.max_open_seconds := 20;
        current.post_clear_delay_ms := 1500;
        current.max_reversals := 3;
        current.command_ttl_seconds := 30;
        current.camera_device_id := null;
    end if;

    direction := coalesce(p_direction, current.direction);
    if direction not in ('entry', 'exit') then
        raise exception 'InvalidDataError';
    end if;
    -- A zero camera id clears the pairing.
    if p_camera_device_id = 0 then
        camera := null;
    else
        camera := coalesce(p_camera_device_id, current.camera_device_id);
    end if;
    if camera is not null and not exists (
        select 1 from public.lot_devices c
         where c.id = camera and c.kind = 'camera' and c.lot_id = lot
    ) then
        raise exception 'InvalidDeviceKindError';
    end if;
    if coalesce(p_open_on_checkin, current.open_on_checkin)
           not in ('never', 'lpr_only', 'always')
       or coalesce(p_open_on_paid_exit, current.open_on_paid_exit)
           not in ('never', 'lpr_only', 'always') then
        raise exception 'InvalidDataError';
    end if;
    if coalesce(p_open_hold_ms, current.open_hold_ms) not between 200 and 30000
       or coalesce(p_max_open_seconds, current.max_open_seconds) not between 5 and 120
       or coalesce(p_post_clear_delay_ms, current.post_clear_delay_ms) not between 500 and 10000
       or coalesce(p_max_reversals, current.max_reversals) not between 1 and 10
       or coalesce(p_command_ttl_seconds, current.command_ttl_seconds) not between 10 and 120
    then
        raise exception 'InvalidDataError';
    end if;

    insert into public.barrier_config (
        device_id, lot_id, direction, camera_device_id, open_on_checkin,
        open_on_paid_exit, open_for_pass_entry, open_hold_ms,
        max_open_seconds, post_clear_delay_ms, max_reversals,
        command_ttl_seconds, updated_at
    ) values (
        device.id, lot, direction, camera,
        coalesce(p_open_on_checkin, current.open_on_checkin),
        coalesce(p_open_on_paid_exit, current.open_on_paid_exit),
        coalesce(p_open_for_pass_entry, current.open_for_pass_entry),
        coalesce(p_open_hold_ms, current.open_hold_ms),
        coalesce(p_max_open_seconds, current.max_open_seconds),
        coalesce(p_post_clear_delay_ms, current.post_clear_delay_ms),
        coalesce(p_max_reversals, current.max_reversals),
        coalesce(p_command_ttl_seconds, current.command_ttl_seconds),
        now()
    )
    on conflict (device_id) do update
        set direction = excluded.direction,
            camera_device_id = excluded.camera_device_id,
            open_on_checkin = excluded.open_on_checkin,
            open_on_paid_exit = excluded.open_on_paid_exit,
            open_for_pass_entry = excluded.open_for_pass_entry,
            open_hold_ms = excluded.open_hold_ms,
            max_open_seconds = excluded.max_open_seconds,
            post_clear_delay_ms = excluded.post_clear_delay_ms,
            max_reversals = excluded.max_reversals,
            command_ttl_seconds = excluded.command_ttl_seconds,
            updated_at = now();
    return (
        select to_jsonb(c) from public.barrier_config c where c.device_id = device.id
    );
end;
$$;

revoke all on function public.set_barrier_config(integer, text, integer, text, text, boolean, integer, integer, integer, integer, integer) from public;
grant execute on function public.set_barrier_config(integer, text, integer, text, text, boolean, integer, integer, integer, integer, integer) to authenticated;
