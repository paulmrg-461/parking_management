-- Offline conflict resolution, part 1: every row the outbox replays gets a
-- version. A client patches with `version=eq.<n>` (the base it edited from):
-- zero rows means someone else changed the row, and the app can merge or ask
-- instead of silently overwriting a price or a capacity.
--
-- The column and the bump trigger are additive and inert: a client that does
-- not send a version keeps working exactly as today. Enforcement (refusing an
-- unaware table write) is opt-in per lot and only after `min_app_version` is
-- set, so an old build cannot be locked out.

alter table public.vehicles
    add column if not exists version integer not null default 1;
alter table public.tariffs
    add column if not exists version integer not null default 1;
alter table public.categories
    add column if not exists version integer not null default 1;
alter table public.parking_settings
    add column if not exists version integer not null default 1;
alter table public.parking_settings
    add column if not exists row_version_required boolean not null default false;

alter table public.vehicles drop constraint if exists vehicles_version_check;
alter table public.vehicles add constraint vehicles_version_check check (version >= 1);
alter table public.tariffs drop constraint if exists tariffs_version_check;
alter table public.tariffs add constraint tariffs_version_check check (version >= 1);
alter table public.categories drop constraint if exists categories_version_check;
alter table public.categories add constraint categories_version_check check (version >= 1);
alter table public.parking_settings drop constraint if exists parking_settings_version_check;
alter table public.parking_settings add constraint parking_settings_version_check check (version >= 1);

-- Bump only when the row really changes (a no-op update must not create a
-- phantom conflict) and never trust a client-supplied version.
create or replace function public.row_version_guard()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'INSERT' then
        new.version := 1;
        return new;
    end if;
    if (to_jsonb(new) - 'version' - 'updated_at')
       = (to_jsonb(old) - 'version' - 'updated_at') then
        new.version := old.version;
    else
        new.version := old.version + 1;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_row_version on public.vehicles;
create trigger trg_row_version before insert or update on public.vehicles
    for each row execute function public.row_version_guard();
drop trigger if exists trg_row_version on public.tariffs;
create trigger trg_row_version before insert or update on public.tariffs
    for each row execute function public.row_version_guard();
drop trigger if exists trg_row_version on public.categories;
create trigger trg_row_version before insert or update on public.categories
    for each row execute function public.row_version_guard();
drop trigger if exists trg_row_version on public.parking_settings;
create trigger trg_row_version before insert or update on public.parking_settings
    for each row execute function public.row_version_guard();

-- Opt-in enforcement: a direct table write that does not declare version
-- awareness is refused. RPC paths and service-role jobs are exempt.
create or replace function public.row_version_enforcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    path text := nullif(current_setting('request.path', true), '');
    headers jsonb := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb;
    lot integer;
    required boolean;
begin
    if path is null or path like '/rpc/%' then
        return new;
    end if;
    if headers ->> 'x-versioned-write' is not null then
        return new;
    end if;
    lot := public.current_lot_id();
    select coalesce(ps.row_version_required, false) into required
      from public.parking_settings ps
     where ps.lot_id = lot;
    if coalesce(required, false) then
        raise exception 'VersionRequiredError';
    end if;
    return new;
end;
$$;

drop trigger if exists trg_row_version_enforcement on public.vehicles;
create trigger trg_row_version_enforcement before update on public.vehicles
    for each row execute function public.row_version_enforcement();
drop trigger if exists trg_row_version_enforcement on public.tariffs;
create trigger trg_row_version_enforcement before update on public.tariffs
    for each row execute function public.row_version_enforcement();
drop trigger if exists trg_row_version_enforcement on public.categories;
create trigger trg_row_version_enforcement before update on public.categories
    for each row execute function public.row_version_enforcement();
drop trigger if exists trg_row_version_enforcement on public.parking_settings;
create trigger trg_row_version_enforcement before update on public.parking_settings
    for each row execute function public.row_version_enforcement();

create or replace function public.set_row_version_policy(p_required boolean)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    min_version text;
begin
    if coalesce(p_required, false) then
        select nullif(btrim(coalesce(min_app_version, '')), '') into min_version
          from public.parking_settings
         where lot_id = lot;
        if min_version is null then
            raise exception 'MinVersionRequiredError';
        end if;
    end if;
    update public.parking_settings
       set row_version_required = coalesce(p_required, false)
     where lot_id = lot;
    return coalesce(p_required, false);
end;
$$;

revoke all on function public.set_row_version_policy(boolean) from public, anon;
grant execute on function public.set_row_version_policy(boolean) to authenticated;
