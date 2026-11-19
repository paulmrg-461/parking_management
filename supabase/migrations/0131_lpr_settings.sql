-- LPR gate — per-lot settings and camera directions.
--
-- The camera (Jetson + gateway) decides nothing: every threshold lives here
-- and is read by the service-role ingest function. Only lot admins change it;
-- members read it through get_lpr_settings(). A lot without a row behaves
-- exactly like the defaults (assist mode), so existing lots are untouched.
--
-- See openspec/changes/add-lpr-camera-gate/design.md (D3, D6, data model).

create table if not exists public.lpr_settings (
    lot_id                   integer primary key references public.parking_lots(id) on delete cascade,
    mode                     text    not null default 'assist' check (mode in ('assist', 'auto')),
    min_confidence           numeric(4,3) not null default 0.800 check (min_confidence between 0.5 and 0.99),
    auto_confidence          numeric(4,3) not null default 0.920 check (auto_confidence between 0.5 and 0.999),
    min_votes                integer not null default 3   check (min_votes between 1 and 10),
    vote_window_seconds      integer not null default 8   check (vote_window_seconds between 2 and 60),
    cooldown_seconds         integer not null default 120 check (cooldown_seconds between 10 and 3600),
    pending_expire_minutes   integer not null default 60  check (pending_expire_minutes between 5 and 1440),
    exit_paid_window_minutes integer not null default 15  check (exit_paid_window_minutes between 1 and 120),
    default_category_id      integer references public.categories(id) on delete set null,
    acting_user_id           integer references public.users(id) on delete set null,
    updated_at               timestamptz not null default now(),
    check (auto_confidence >= min_confidence)
);

alter table public.lpr_settings enable row level security;
grant select on public.lpr_settings to authenticated;

drop policy if exists lpr_settings_member_read on public.lpr_settings;
create policy lpr_settings_member_read on public.lpr_settings
    for select to authenticated
    using (lot_id = public.current_lot_id());

-- Writes only through set_lpr_settings (security definer, no write grant).
drop trigger if exists trg_audit_row on public.lpr_settings;
create trigger trg_audit_row after insert or update or delete on public.lpr_settings
    for each row execute function public.record_audit();

create table if not exists public.lpr_camera_config (
    device_id  integer primary key references public.lot_devices(id) on delete cascade,
    lot_id     integer not null references public.parking_lots(id) on delete cascade,
    direction  text    not null check (direction in ('entry', 'exit'))
);

alter table public.lpr_camera_config enable row level security;
-- No grants: read through get_lpr_settings(), written by
-- set_lpr_camera_direction().

-- ---------------------------------------------------------------------------
-- Effective settings: the row or the documented defaults. The literal must
-- list every column in table order; a SQL test fails when a column is added
-- without updating it.
-- ---------------------------------------------------------------------------
create or replace function public.lpr_effective_settings(p_lot_id integer)
returns public.lpr_settings
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        (select s from public.lpr_settings s where s.lot_id = p_lot_id),
        row(p_lot_id, 'assist', 0.800, 0.920, 3, 8, 120, 60, 15,
            null, null, now())::public.lpr_settings
    );
$$;

revoke all on function public.lpr_effective_settings(integer)
    from public, anon, authenticated;
grant execute on function public.lpr_effective_settings(integer) to service_role;

-- ---------------------------------------------------------------------------
-- Read: settings plus the lot's cameras. Any member of the lot.
-- ---------------------------------------------------------------------------
create or replace function public.get_lpr_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    settings public.lpr_settings%rowtype := public.lpr_effective_settings(lot);
    minutes integer;
    cameras jsonb;
begin
    perform public.require_app_user();
    select coalesce(device_offline_minutes, 5) into minutes
      from public.parking_settings where lot_id = lot;
    select coalesce(jsonb_agg(jsonb_build_object(
                   'device_id', d.id,
                   'name', d.name,
                   'direction', c.direction,
                   'status', public.device_status(
                       d.enabled, d.last_seen_at, coalesce(minutes, 5))
               ) order by d.name, d.id), '[]'::jsonb)
      into cameras
      from public.lot_devices d
      left join public.lpr_camera_config c on c.device_id = d.id
     where d.lot_id = lot and d.kind = 'camera';
    return to_jsonb(settings) || jsonb_build_object('cameras', cameras);
end;
$$;

revoke all on function public.get_lpr_settings() from public;
grant execute on function public.get_lpr_settings() to authenticated;

-- ---------------------------------------------------------------------------
-- Write: upsert with coalesced values, admin only.
-- ---------------------------------------------------------------------------
create or replace function public.set_lpr_settings(
    p_mode text default null,
    p_min_confidence numeric default null,
    p_auto_confidence numeric default null,
    p_min_votes integer default null,
    p_vote_window_seconds integer default null,
    p_cooldown_seconds integer default null,
    p_default_category_id integer default null,
    p_acting_user_id integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    current public.lpr_settings%rowtype := public.lpr_effective_settings(lot);
    mode text := coalesce(p_mode, current.mode);
    min_confidence numeric := coalesce(p_min_confidence, current.min_confidence);
    auto_confidence numeric := coalesce(p_auto_confidence, current.auto_confidence);
    min_votes integer := coalesce(p_min_votes, current.min_votes);
    window_seconds integer := coalesce(p_vote_window_seconds, current.vote_window_seconds);
    cooldown integer := coalesce(p_cooldown_seconds, current.cooldown_seconds);
    category integer := coalesce(p_default_category_id, current.default_category_id);
    acting integer := coalesce(p_acting_user_id, current.acting_user_id);
    actor_member boolean;
begin
    if mode not in ('assist', 'auto') then
        raise exception 'InvalidDataError';
    end if;
    if min_confidence < 0.5 or min_confidence > 0.99
       or auto_confidence < 0.5 or auto_confidence > 0.999 then
        raise exception 'InvalidDataError';
    end if;
    if min_votes < 1 or min_votes > 10
       or window_seconds < 2 or window_seconds > 60
       or cooldown < 10 or cooldown > 3600 then
        raise exception 'InvalidDataError';
    end if;
    if auto_confidence < min_confidence then
        raise exception 'InvalidDataError';
    end if;
    if p_default_category_id is not null then
        if not exists (
            select 1 from public.categories c
             where c.id = p_default_category_id and c.lot_id = lot
        ) then
            raise exception 'CategoryNotFoundError';
        end if;
    end if;
    if p_acting_user_id is not null then
        select exists (
            select 1
              from public.lot_members lm
              join public.users u on u.id = lm.user_id
             where lm.lot_id = lot
               and lm.user_id = p_acting_user_id
               and lm.role in ('operator', 'admin')
               and u.is_active
        ) into actor_member;
        if not actor_member then
            raise exception 'UserNotFoundError';
        end if;
    end if;
    if mode = 'auto' then
        if acting is null then
            raise exception 'LprSystemOperatorRequiredError';
        end if;
        select exists (
            select 1
              from public.lot_members lm
              join public.users u on u.id = lm.user_id
             where lm.lot_id = lot
               and lm.user_id = acting
               and lm.role in ('operator', 'admin')
               and u.is_active
        ) into actor_member;
        if not actor_member then
            raise exception 'LprSystemOperatorRequiredError';
        end if;
    end if;

    insert into public.lpr_settings (
        lot_id, mode, min_confidence, auto_confidence, min_votes,
        vote_window_seconds, cooldown_seconds, default_category_id,
        acting_user_id, updated_at
    ) values (
        lot, mode, min_confidence, auto_confidence, min_votes,
        window_seconds, cooldown, category, acting, now()
    )
    on conflict (lot_id) do update
        set mode = excluded.mode,
            min_confidence = excluded.min_confidence,
            auto_confidence = excluded.auto_confidence,
            min_votes = excluded.min_votes,
            vote_window_seconds = excluded.vote_window_seconds,
            cooldown_seconds = excluded.cooldown_seconds,
            default_category_id = excluded.default_category_id,
            acting_user_id = excluded.acting_user_id,
            updated_at = now();
    return public.get_lpr_settings();
end;
$$;

revoke all on function public.set_lpr_settings(text, numeric, numeric, integer, integer, integer, integer, integer) from public;
grant execute on function public.set_lpr_settings(text, numeric, numeric, integer, integer, integer, integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Camera direction: one row per camera device, admin only.
-- ---------------------------------------------------------------------------
create or replace function public.set_lpr_camera_direction(
    p_device_id integer,
    p_direction text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    device public.lot_devices%rowtype;
begin
    if p_direction is null or p_direction not in ('entry', 'exit') then
        raise exception 'InvalidDataError';
    end if;
    select * into device from public.lot_devices d
     where d.id = p_device_id and d.lot_id = lot;
    if not found then
        raise exception 'DeviceNotFoundError';
    end if;
    if device.kind <> 'camera' then
        raise exception 'InvalidDeviceKindError';
    end if;
    insert into public.lpr_camera_config (device_id, lot_id, direction)
    values (device.id, lot, p_direction)
    on conflict (device_id) do update
        set direction = excluded.direction, lot_id = excluded.lot_id;
    return jsonb_build_object('device_id', device.id, 'direction', p_direction);
end;
$$;

revoke all on function public.set_lpr_camera_direction(integer, text) from public;
grant execute on function public.set_lpr_camera_direction(integer, text) to authenticated;
