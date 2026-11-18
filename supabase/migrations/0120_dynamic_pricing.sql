-- Dynamic pricing — schema, pure functions, triggers and the pricing hook.
--   1. Per-lot switches and guard rails (floor / ceiling / rounding).
--   2. `pricing_rules`: one winning rule per entry (priority, then id).
--   3. The effective rate is LOCKED on the session at insert (a BEFORE INSERT
--      trigger, so `check_in` keeps its 11 arguments) and is immutable.
--   4. A public hold locks the price the customer was shown; a session that
--      consumes the hold keeps the cheaper of the two.
--   5. `fare_pricing_step` (owned by add-merchant-validations) is replaced with
--      the real implementation; `fare_quote` is untouched.
-- Inert by default: `pricing_enabled = false` means no lock, normal tariff.

alter table public.parking_settings
    add column if not exists pricing_enabled boolean not null default false,
    add column if not exists pricing_floor_bps integer not null default 10000,
    add column if not exists pricing_ceiling_bps integer not null default 15000,
    add column if not exists pricing_round_to integer not null default 1;
alter table public.parking_settings drop constraint if exists parking_settings_pricing_check;
alter table public.parking_settings add constraint parking_settings_pricing_check check (
    pricing_floor_bps between 1000 and 10000
    and pricing_ceiling_bps between 10000 and 50000
    and pricing_round_to between 1 and 1000);

create table if not exists public.pricing_rules (
    id                 serial      primary key,
    lot_id             integer     not null references public.parking_lots(id),
    name               varchar(80) not null,
    active             boolean     not null default true,
    priority           integer     not null default 100 check (priority between 0 and 1000),
    group_name         text        check (group_name in ('car', 'moto', 'heavy')),
    min_occupancy_pct  integer     check (min_occupancy_pct between 0 and 100),
    max_occupancy_pct  integer     check (max_occupancy_pct between 0 and 100),
    weekdays           integer     check (weekdays between 1 and 127),
    from_time          time,
    to_time            time,
    multiplier_bps     integer     not null default 10000 check (multiplier_bps between 1000 and 50000),
    surcharge_amount   integer     not null default 0 check (surcharge_amount between 0 and 100000000),
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now(),
    constraint pricing_rules_name_check check (length(btrim(name)) between 1 and 80),
    constraint pricing_rules_band_check check (
        min_occupancy_pct is null or max_occupancy_pct is null
        or min_occupancy_pct <= max_occupancy_pct),
    constraint pricing_rules_window_check check (
        (from_time is null) = (to_time is null)
        and (from_time is null or from_time <> to_time)),
    constraint pricing_rules_effect_check check (
        multiplier_bps <> 10000 or surcharge_amount > 0),
    constraint pricing_rules_name_key unique (lot_id, name)
);
create index if not exists ix_pricing_rules_lot_active
    on public.pricing_rules (lot_id, priority desc, id) where active;

alter table public.parking_sessions
    add column if not exists pricing_lock jsonb;
alter table public.category_reservations
    add column if not exists pricing_lock jsonb;

alter table public.pricing_rules enable row level security;
revoke all on public.pricing_rules from anon, authenticated;
grant select on public.pricing_rules to authenticated;
drop policy if exists pricing_rules_read on public.pricing_rules;
create policy pricing_rules_read on public.pricing_rules
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop trigger if exists trg_audit_row on public.pricing_rules;
create trigger trg_audit_row after insert or update or delete on public.pricing_rules
    for each row execute function public.record_audit();

-- ---------------------------------------------------------------------------
-- Pure functions.
-- ---------------------------------------------------------------------------
create or replace function public.pricing_apply_detail(p_lock jsonb, p_base integer)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
    raw integer;
    lo integer;
    hi integer;
    value integer;
    step integer;
    amount integer;
    clamped text;
begin
    if p_lock is null or p_base <= 0 then
        return jsonb_build_object('amount', greatest(coalesce(p_base, 0), 0), 'clamped', null);
    end if;

    raw := (p_base * (p_lock ->> 'multiplier_bps')::integer + 5000) / 10000
        + coalesce((p_lock ->> 'surcharge_amount')::integer, 0);
    lo := (p_base * (p_lock ->> 'floor_bps')::integer + 5000) / 10000;
    hi := (p_base * (p_lock ->> 'ceiling_bps')::integer + 5000) / 10000;

    if raw < lo then
        clamped := 'floor';
    elsif raw > hi then
        clamped := 'ceiling';
    end if;
    value := least(greatest(raw, lo), hi);

    step := greatest(coalesce((p_lock ->> 'round_to')::integer, 1), 1);
    amount := ((value + step / 2) / step) * step;

    return jsonb_build_object('amount', amount, 'clamped', clamped);
end;
$$;

revoke all on function public.pricing_apply_detail(jsonb, integer)
    from public, anon, authenticated;

create or replace function public.pricing_apply(p_lock jsonb, p_base integer)
returns integer
language sql
immutable
set search_path = public
as $$
    select (public.pricing_apply_detail(p_lock, p_base) ->> 'amount')::integer;
$$;

revoke all on function public.pricing_apply(jsonb, integer)
    from public, anon, authenticated;

create or replace function public.pricing_group_capacity(p_lot integer, p_group text)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    total integer;
    active integer;
    configured integer;
    out_of_service integer;
begin
    if p_group is null or p_group not in ('car', 'moto') then
        return 0;
    end if;

    select count(*), count(*) filter (where status = 'active')
      into total, active
      from public.parking_spots
     where lot_id = p_lot and group_name = p_group;
    if total > 0 then
        return coalesce(active, 0);
    end if;

    select case when p_group = 'car' then car_capacity else moto_capacity end,
           case when p_group = 'car' then car_out_of_service else moto_out_of_service end
      into configured, out_of_service
      from public.parking_settings
     where lot_id = p_lot;
    return public.usable_capacity(configured, out_of_service);
end;
$$;

revoke all on function public.pricing_group_capacity(integer, text)
    from public, anon, authenticated;

create or replace function public.pricing_group_occupancy(p_lot integer, p_group text)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    capacity integer := public.pricing_group_capacity(p_lot, p_group);
    open_count integer;
    held_count integer;
begin
    if capacity <= 0 then
        return null;
    end if;

    select count(*) into open_count
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.categories c on c.id = v.category_id
     where s.lot_id = p_lot
       and s.status = 'open'
       and public.category_group(c.name) = p_group;

    select count(*) into held_count
      from public.category_reservations r
      join public.categories c on c.id = r.category_id
     where r.lot_id = p_lot
       and r.status = 'active'
       and r.reserved_until > now()
       and public.category_group(c.name) = p_group;

    return least(floor(100 * (open_count + held_count)::numeric / capacity)::integer, 999);
end;
$$;

revoke all on function public.pricing_group_occupancy(integer, text)
    from public, anon, authenticated;

create or replace function public.pricing_rule_matches(
    p_rule public.pricing_rules,
    p_group text,
    p_local timestamp,
    p_occupancy integer
)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
    today_bit integer := 1 << (extract(isodow from p_local)::integer - 1);
    yesterday_bit integer := 1 << (extract(isodow from p_local - interval '1 day')::integer - 1);
    today_ok boolean := p_rule.weekdays is null
        or (p_rule.weekdays & (1 << (extract(isodow from p_local)::integer - 1))) <> 0;
    yesterday_ok boolean := p_rule.weekdays is null
        or (p_rule.weekdays & (1 << (extract(isodow from p_local - interval '1 day')::integer - 1))) <> 0;
begin
    if not p_rule.active then
        return false;
    end if;
    if p_rule.group_name is not null and p_rule.group_name is distinct from p_group then
        return false;
    end if;
    if not (p_rule.min_occupancy_pct is null and p_rule.max_occupancy_pct is null) then
        if p_occupancy is null
           or p_occupancy < coalesce(p_rule.min_occupancy_pct, 0)
           or p_occupancy > coalesce(p_rule.max_occupancy_pct, 100) then
            return false;
        end if;
    end if;

    if p_rule.from_time is null then
        return today_ok;
    elsif p_rule.from_time < p_rule.to_time then
        return p_local::time >= p_rule.from_time
            and p_local::time < p_rule.to_time
            and today_ok;
    else
        return (p_local::time >= p_rule.from_time and today_ok)
            or (p_local::time < p_rule.to_time and yesterday_ok);
    end if;
end;
$$;

revoke all on function public.pricing_rule_matches(public.pricing_rules, text, timestamp, integer)
    from public, anon, authenticated;

create or replace function public.pricing_identity_lock(p_lot integer)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'v', 1,
        'rule_id', null,
        'rule_name', '',
        'kind', 'multiplier',
        'multiplier_bps', 10000,
        'surcharge_amount', 0,
        'floor_bps', coalesce(ps.pricing_floor_bps, 10000),
        'ceiling_bps', coalesce(ps.pricing_ceiling_bps, 15000),
        'round_to', coalesce(ps.pricing_round_to, 1),
        'occupancy_pct', null,
        'locked_at', now(),
        'source', 'checkin'
    )
      from public.parking_settings ps
     where ps.lot_id = p_lot;
$$;

revoke all on function public.pricing_identity_lock(integer)
    from public, anon, authenticated;

create or replace function public.pricing_lock_for(
    p_lot integer,
    p_category_id integer,
    p_at timestamp with time zone,
    p_allow_surcharge boolean default true
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    settings public.parking_settings%rowtype;
    category_name text;
    spot_group text;
    tz text;
    local_at timestamp;
    occupancy integer;
    rule public.pricing_rules%rowtype;
    lock jsonb;
    reference integer;
begin
    select * into settings from public.parking_settings ps where ps.lot_id = p_lot;
    if not found or not coalesce(settings.pricing_enabled, false) then
        return null;
    end if;

    select c.name into category_name
      from public.categories c
     where c.id = p_category_id and c.lot_id = p_lot;
    if not found then
        return null;
    end if;
    spot_group := public.category_group(category_name);

    tz := coalesce(settings.business_timezone, 'America/Bogota');
    local_at := p_at at time zone tz;
    occupancy := public.pricing_group_occupancy(p_lot, spot_group);

    select * into rule
      from public.pricing_rules r
     where r.lot_id = p_lot
       and public.pricing_rule_matches(r, spot_group, local_at, occupancy)
     order by r.priority desc, r.id asc
     limit 1;
    if not found then
        return null;
    end if;

    lock := jsonb_build_object(
        'v', 1,
        'rule_id', rule.id,
        'rule_name', rule.name,
        'kind', case
            when rule.surcharge_amount = 0 then 'multiplier'
            when rule.multiplier_bps = 10000 then 'surcharge'
            else 'both'
        end,
        'multiplier_bps', rule.multiplier_bps,
        'surcharge_amount', rule.surcharge_amount,
        'floor_bps', coalesce(settings.pricing_floor_bps, 10000),
        'ceiling_bps', coalesce(settings.pricing_ceiling_bps, 15000),
        'round_to', coalesce(settings.pricing_round_to, 1),
        'occupancy_pct', occupancy,
        'locked_at', now(),
        'source', 'checkin'
    );

    if not coalesce(p_allow_surcharge, true) then
        select t.amount into reference
          from public.tariffs t
         where t.category_id = p_category_id
           and t.lot_id = p_lot
           and t.type = 'hourly'
           and t.active
         order by t.id
         limit 1;
        reference := coalesce(reference, 0);
        if public.pricing_apply(lock, reference) > reference then
            return null;
        end if;
    end if;

    return lock;
end;
$$;

revoke all on function public.pricing_lock_for(integer, integer, timestamptz, boolean)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Triggers.
-- ---------------------------------------------------------------------------
create or replace function public.lock_session_price()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    settings public.parking_settings%rowtype;
    vehicle_category integer;
    offline boolean;
    current_lock jsonb;
    held_lock jsonb;
    reference integer;
    held_price integer;
    current_price integer;
begin
    if new.pricing_lock is not null then
        return new;
    end if;

    begin
        select * into settings
          from public.parking_settings ps
         where ps.lot_id = new.lot_id;
        if not found or not coalesce(settings.pricing_enabled, false) then
            return new;
        end if;

        select v.category_id into vehicle_category
          from public.vehicles v
         where v.id = new.vehicle_id;
        if vehicle_category is null then
            return new;
        end if;

        offline := new.entry_time < now() - interval '5 minutes';
        current_lock := public.pricing_lock_for(
            new.lot_id, vehicle_category, new.entry_time, not offline
        );
        if current_lock is not null and offline then
            current_lock := jsonb_set(current_lock, '{source}', '"offline"');
        end if;

        select r.pricing_lock into held_lock
          from public.category_reservations r
          join public.vehicles v on v.plate = r.plate
         where v.id = new.vehicle_id
           and r.lot_id = new.lot_id
           and r.status = 'used'
           and r.pricing_lock is not null
           and r.reserved_from <= new.entry_time
           and r.reserved_until + public.reservation_grace(new.lot_id) > new.entry_time
         order by r.id desc
         limit 1;
        if held_lock is not null then
            held_lock := jsonb_set(held_lock, '{source}', '"reservation"');
        end if;

        select t.amount into reference
          from public.tariffs t
         where t.category_id = vehicle_category
           and t.lot_id = new.lot_id
           and t.type = 'hourly'
           and t.active
         order by t.id
         limit 1;
        reference := coalesce(reference, 0);

        held_price := public.pricing_apply(held_lock, reference);
        current_price := public.pricing_apply(current_lock, reference);

        if held_lock is null then
            new.pricing_lock := current_lock;
        elsif current_lock is null then
            new.pricing_lock := case when held_price <= reference then held_lock end;
        else
            new.pricing_lock := case
                when held_price <= current_price then held_lock
                else current_lock
            end;
        end if;

        -- A winner whose effect is the plain tariff is no lock at all.
        if new.pricing_lock is not null
           and public.pricing_apply(new.pricing_lock, reference) = reference then
            new.pricing_lock := null;
        end if;
    exception when others then
        -- A pricing failure must never stop a vehicle from entering.
        new.pricing_lock := null;
    end;

    return new;
end;
$$;

revoke all on function public.lock_session_price()
    from public, anon, authenticated;

create or replace function public.guard_pricing_lock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.pricing_lock is distinct from old.pricing_lock then
        raise exception 'PricingLockImmutableError';
    end if;
    return new;
end;
$$;

revoke all on function public.guard_pricing_lock()
    from public, anon, authenticated;

create or replace function public.lock_reservation_price()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    enabled boolean;
begin
    if new.source <> 'public' or new.pricing_lock is not null then
        return new;
    end if;
    select coalesce(pricing_enabled, false) into enabled
      from public.parking_settings where lot_id = new.lot_id;
    if not coalesce(enabled, false) then
        return new;
    end if;
    begin
        new.pricing_lock := coalesce(
            public.pricing_lock_for(new.lot_id, new.category_id, now(), true),
            public.pricing_identity_lock(new.lot_id)
        );
    exception when others then
        new.pricing_lock := null;
    end;
    return new;
end;
$$;

revoke all on function public.lock_reservation_price()
    from public, anon, authenticated;

drop trigger if exists trg_parking_sessions_pricing_lock on public.parking_sessions;
create trigger trg_parking_sessions_pricing_lock
    before insert on public.parking_sessions
    for each row execute function public.lock_session_price();

drop trigger if exists trg_parking_sessions_pricing_lock_guard on public.parking_sessions;
create trigger trg_parking_sessions_pricing_lock_guard
    before update of pricing_lock on public.parking_sessions
    for each row execute function public.guard_pricing_lock();

drop trigger if exists trg_category_reservations_pricing_lock on public.category_reservations;
create trigger trg_category_reservations_pricing_lock
    before insert on public.category_reservations
    for each row execute function public.lock_reservation_price();

drop trigger if exists trg_category_reservations_pricing_lock_claim on public.category_reservations;
create trigger trg_category_reservations_pricing_lock_claim
    before update of source on public.category_reservations
    for each row execute function public.lock_reservation_price();

-- ---------------------------------------------------------------------------
-- The hook: deterministic given the stored lock (never reads rules/settings).
-- ---------------------------------------------------------------------------
create or replace function public.fare_pricing_step(
    p_session_id integer,
    p_base integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lock jsonb;
    detail jsonb;
begin
    select s.pricing_lock into lock
      from public.parking_sessions s
     where s.id = p_session_id;

    if lock is null or p_base <= 0 then
        return jsonb_build_object('amount', p_base, 'pricing', null);
    end if;

    detail := public.pricing_apply_detail(lock, p_base);
    return jsonb_build_object(
        'amount', (detail ->> 'amount')::integer,
        'pricing', jsonb_build_object(
            'rule_id', lock -> 'rule_id',
            'rule_name', lock ->> 'rule_name',
            'kind', lock ->> 'kind',
            'multiplier_bps', (lock ->> 'multiplier_bps')::integer,
            'surcharge_amount', (lock ->> 'surcharge_amount')::integer,
            'delta', (detail ->> 'amount')::integer - p_base,
            'clamped', detail -> 'clamped',
            'locked_at', lock -> 'locked_at',
            'source', lock ->> 'source'
        )
    );
end;
$$;

revoke all on function public.fare_pricing_step(integer, integer)
    from public, anon, authenticated;
