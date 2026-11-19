-- Dynamic pricing — admin RPCs, the operator/public reads, simulation, the
-- impact report and the public-availability price keys.
-- `public_availability` is a wrapper since `0109`; Case A: re-declare it with
-- the pricing decoration before the forecast block.

-- ---------------------------------------------------------------------------
-- Validation helper shared by save_pricing_rule and pricing_simulate.
-- ---------------------------------------------------------------------------
create or replace function public.pricing_check_rule_fields(
    p_name text,
    p_priority integer,
    p_group text,
    p_min_occupancy integer,
    p_max_occupancy integer,
    p_weekdays integer,
    p_from_time time,
    p_to_time time,
    p_multiplier_bps integer,
    p_surcharge_amount integer
)
returns void
language plpgsql
immutable
set search_path = public
as $$
declare
    clean_name text := btrim(coalesce(p_name, ''));
begin
    if length(clean_name) < 1 or length(clean_name) > 80 then
        raise exception 'InvalidPricingRuleError';
    end if;
    if p_priority is null or p_priority not between 0 and 1000 then
        raise exception 'InvalidPricingRuleError';
    end if;
    if p_group is not null and p_group not in ('car', 'moto', 'heavy') then
        raise exception 'InvalidPricingRuleError';
    end if;
    if p_min_occupancy is not null and p_min_occupancy not between 0 and 100 then
        raise exception 'InvalidPricingRuleError';
    end if;
    if p_max_occupancy is not null and p_max_occupancy not between 0 and 100 then
        raise exception 'InvalidPricingRuleError';
    end if;
    if p_min_occupancy is not null and p_max_occupancy is not null
       and p_min_occupancy > p_max_occupancy then
        raise exception 'InvalidPricingRuleError';
    end if;
    if p_weekdays is not null and p_weekdays not between 1 and 127 then
        raise exception 'InvalidPricingRuleError';
    end if;
    if (p_from_time is null) <> (p_to_time is null)
       or (p_from_time is not null and p_from_time = p_to_time) then
        raise exception 'InvalidPricingRuleError';
    end if;
    if p_multiplier_bps is null or p_multiplier_bps not between 1000 and 50000 then
        raise exception 'InvalidPricingRuleError';
    end if;
    if coalesce(p_surcharge_amount, 0) not between 0 and 100000000 then
        raise exception 'InvalidPricingRuleError';
    end if;
    if p_multiplier_bps = 10000 and coalesce(p_surcharge_amount, 0) <= 0 then
        raise exception 'InvalidPricingRuleError';
    end if;
end;
$$;

revoke all on function public.pricing_check_rule_fields(text, integer, text, integer, integer, integer, time, time, integer, integer)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Settings and rules (lot admins).
-- ---------------------------------------------------------------------------
create or replace function public.get_pricing_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    settings public.parking_settings%rowtype;
begin
    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    return jsonb_build_object(
        'enabled', coalesce(settings.pricing_enabled, false),
        'floor_bps', coalesce(settings.pricing_floor_bps, 10000),
        'ceiling_bps', coalesce(settings.pricing_ceiling_bps, 15000),
        'round_to', coalesce(settings.pricing_round_to, 1)
    );
end;
$$;

revoke all on function public.get_pricing_settings() from public;
grant execute on function public.get_pricing_settings() to authenticated;

create or replace function public.set_pricing_settings(
    p_enabled boolean default null,
    p_floor_bps integer default null,
    p_ceiling_bps integer default null,
    p_round_to integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    settings public.parking_settings%rowtype;
    floor_value integer;
    ceiling_value integer;
    round_value integer;
begin
    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    floor_value := coalesce(p_floor_bps, settings.pricing_floor_bps);
    ceiling_value := coalesce(p_ceiling_bps, settings.pricing_ceiling_bps);
    round_value := coalesce(p_round_to, settings.pricing_round_to);

    if floor_value not between 1000 and 10000
       or ceiling_value not between 10000 and 50000
       or round_value not between 1 and 1000 then
        raise exception 'InvalidPricingSettingsError';
    end if;

    update public.parking_settings
       set pricing_enabled = coalesce(p_enabled, pricing_enabled),
           pricing_floor_bps = floor_value,
           pricing_ceiling_bps = ceiling_value,
           pricing_round_to = round_value
     where lot_id = lot;

    return jsonb_build_object(
        'enabled', coalesce(p_enabled, settings.pricing_enabled),
        'floor_bps', floor_value,
        'ceiling_bps', ceiling_value,
        'round_to', round_value
    );
end;
$$;

revoke all on function public.set_pricing_settings(boolean, integer, integer, integer) from public;
grant execute on function public.set_pricing_settings(boolean, integer, integer, integer)
    to authenticated;

create or replace function public.pricing_rule_json(p_rule public.pricing_rules)
returns jsonb
language sql
immutable
set search_path = public
as $$
    select jsonb_build_object(
        'id', p_rule.id,
        'name', p_rule.name,
        'active', p_rule.active,
        'priority', p_rule.priority,
        'group', p_rule.group_name,
        'min_occupancy_pct', p_rule.min_occupancy_pct,
        'max_occupancy_pct', p_rule.max_occupancy_pct,
        'weekdays', p_rule.weekdays,
        'from_time', case when p_rule.from_time is null then null
            else to_char(p_rule.from_time, 'HH24:MI') end,
        'to_time', case when p_rule.to_time is null then null
            else to_char(p_rule.to_time, 'HH24:MI') end,
        'multiplier_bps', p_rule.multiplier_bps,
        'surcharge_amount', p_rule.surcharge_amount,
        'updated_at', p_rule.updated_at
    );
$$;

revoke all on function public.pricing_rule_json(public.pricing_rules)
    from public, anon, authenticated;

create or replace function public.list_pricing_rules()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
begin
    return coalesce((
        select jsonb_agg(public.pricing_rule_json(r) order by r.priority desc, r.id)
          from public.pricing_rules r
         where r.lot_id = lot
    ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_pricing_rules() from public;
grant execute on function public.list_pricing_rules() to authenticated;

create or replace function public.save_pricing_rule(
    p_name text,
    p_priority integer,
    p_group text,
    p_min_occupancy integer,
    p_max_occupancy integer,
    p_weekdays integer,
    p_from_time time,
    p_to_time time,
    p_multiplier_bps integer,
    p_surcharge_amount integer,
    p_active boolean default true,
    p_id integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    rule public.pricing_rules%rowtype;
begin
    perform public.pricing_check_rule_fields(
        p_name, p_priority, p_group, p_min_occupancy, p_max_occupancy,
        p_weekdays, p_from_time, p_to_time, p_multiplier_bps, p_surcharge_amount
    );

    if p_id is null then
        begin
            insert into public.pricing_rules (
                lot_id, name, active, priority, group_name, min_occupancy_pct,
                max_occupancy_pct, weekdays, from_time, to_time,
                multiplier_bps, surcharge_amount
            )
            values (
                lot, btrim(p_name), coalesce(p_active, true), p_priority,
                p_group, p_min_occupancy, p_max_occupancy, p_weekdays,
                p_from_time, p_to_time, p_multiplier_bps,
                coalesce(p_surcharge_amount, 0)
            )
            returning * into rule;
        exception when unique_violation then
            raise exception 'DuplicatePricingRuleError';
        end;
    else
        begin
            update public.pricing_rules
               set name = btrim(p_name),
                   active = coalesce(p_active, true),
                   priority = p_priority,
                   group_name = p_group,
                   min_occupancy_pct = p_min_occupancy,
                   max_occupancy_pct = p_max_occupancy,
                   weekdays = p_weekdays,
                   from_time = p_from_time,
                   to_time = p_to_time,
                   multiplier_bps = p_multiplier_bps,
                   surcharge_amount = coalesce(p_surcharge_amount, 0),
                   updated_at = now()
             where id = p_id and lot_id = lot
             returning * into rule;
        exception when unique_violation then
            raise exception 'DuplicatePricingRuleError';
        end;
        if rule.id is null then
            raise exception 'PricingRuleNotFoundError';
        end if;
    end if;

    return public.pricing_rule_json(rule);
end;
$$;

revoke all on function public.save_pricing_rule(text, integer, text, integer, integer, integer, time, time, integer, integer, boolean, integer)
    from public;
grant execute on function public.save_pricing_rule(text, integer, text, integer, integer, integer, time, time, integer, integer, boolean, integer)
    to authenticated;

create or replace function public.delete_pricing_rule(p_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
begin
    delete from public.pricing_rules r
     where r.id = p_id and r.lot_id = lot;
    if not found then
        raise exception 'PricingRuleNotFoundError';
    end if;
    return jsonb_build_object('id', p_id, 'deleted', true);
end;
$$;

revoke all on function public.delete_pricing_rule(integer) from public;
grant execute on function public.delete_pricing_rule(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Read models for the operator and the public pages.
-- ---------------------------------------------------------------------------
create or replace function public.pricing_quote(p_category_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    category_name text;
    spot_group text;
    settings public.parking_settings%rowtype;
    lock jsonb;
    base integer := 0;
    current integer := 0;
    tier text := 'base';
    occupancy integer;
begin
    perform public.require_app_user();

    select c.name into category_name
      from public.categories c
     where c.id = p_category_id and c.lot_id = lot;
    if not found then
        raise exception 'CategoryNotFoundError';
    end if;
    spot_group := public.category_group(category_name);

    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    select t.amount into base
      from public.tariffs t
     where t.category_id = p_category_id and t.lot_id = lot
       and t.type = 'hourly' and t.active
     order by t.id limit 1;
    base := coalesce(base, 0);

    lock := public.pricing_lock_for(lot, p_category_id, now(), true);
    current := public.pricing_apply(lock, base);
    tier := case
        when current > base then 'higher'
        when current < base then 'lower'
        else 'base'
    end;
    occupancy := public.pricing_group_occupancy(lot, spot_group);

    return jsonb_build_object(
        'enabled', coalesce(settings.pricing_enabled, false),
        'category_id', p_category_id,
        'group', spot_group,
        'at', now(),
        'occupancy_pct', occupancy,
        'rule', case when lock is null then null else jsonb_build_object(
            'id', (lock ->> 'rule_id')::integer,
            'name', lock ->> 'rule_name'
        ) end,
        'multiplier_bps', coalesce((lock ->> 'multiplier_bps')::integer, 10000),
        'surcharge_amount', coalesce((lock ->> 'surcharge_amount')::integer, 0),
        'hourly_base', base,
        'hourly_current', current,
        'tier', tier
    );
end;
$$;

revoke all on function public.pricing_quote(integer) from public;
grant execute on function public.pricing_quote(integer) to authenticated;

create or replace function public.pricing_session_lock(p_session_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    session public.parking_sessions%rowtype;
    vehicle_category integer;
    lock jsonb;
    hourly_base integer := 0;
begin
    perform public.require_app_user();

    select * into session
      from public.parking_sessions s
     where s.id = p_session_id;
    if not found or session.lot_id <> lot then
        raise exception 'SessionNotFoundError';
    end if;
    lock := session.pricing_lock;
    if lock is null then
        return null;
    end if;

    select v.category_id into vehicle_category from public.vehicles v where v.id = session.vehicle_id;
    select t.amount into hourly_base
      from public.tariffs t
     where t.category_id = vehicle_category and t.lot_id = session.lot_id
       and t.type = 'hourly' and t.active
     order by t.id limit 1;
    hourly_base := coalesce(hourly_base, 0);

    return jsonb_build_object(
        'session_id', session.id,
        'rule_id', (lock ->> 'rule_id')::integer,
        'rule_name', lock ->> 'rule_name',
        'kind', lock ->> 'kind',
        'multiplier_bps', (lock ->> 'multiplier_bps')::integer,
        'surcharge_amount', (lock ->> 'surcharge_amount')::integer,
        'hourly_base', hourly_base,
        'hourly_locked', public.pricing_apply(lock, hourly_base),
        'occupancy_pct', (lock ->> 'occupancy_pct')::integer,
        'locked_at', lock -> 'locked_at',
        'source', lock ->> 'source'
    );
end;
$$;

revoke all on function public.pricing_session_lock(integer) from public;
grant execute on function public.pricing_session_lock(integer) to authenticated;

create or replace function public.public_reservation_pricing(
    p_lot_id integer,
    p_reservation_id bigint,
    p_customer_phone text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    phone_digits text := regexp_replace(coalesce(p_customer_phone, ''), '\D', '', 'g');
    phone_local text;
    reservation public.category_reservations%rowtype;
    lock jsonb;
    hourly_base integer := 0;
begin
    phone_local := case
        when length(phone_digits) = 12 and phone_digits like '57%'
            then right(phone_digits, 10)
        else phone_digits
    end;

    select * into reservation
      from public.category_reservations r
     where r.id = p_reservation_id
       and r.lot_id = p_lot_id
       and r.customer_phone = phone_local
       and r.source = 'public'
       and r.status = 'active'
       and r.reserved_until > now();
    if not found then
        return null;
    end if;
    lock := reservation.pricing_lock;
    if lock is null then
        return null;
    end if;

    select t.amount into hourly_base
      from public.tariffs t
     where t.category_id = reservation.category_id and t.lot_id = p_lot_id
       and t.type = 'hourly' and t.active
     order by t.id limit 1;
    hourly_base := coalesce(hourly_base, 0);

    return jsonb_build_object(
        'rule_id', (lock ->> 'rule_id')::integer,
        'rule_name', lock ->> 'rule_name',
        'kind', lock ->> 'kind',
        'multiplier_bps', (lock ->> 'multiplier_bps')::integer,
        'surcharge_amount', (lock ->> 'surcharge_amount')::integer,
        'hourly_base', hourly_base,
        'hourly_locked', public.pricing_apply(lock, hourly_base),
        'occupancy_pct', (lock ->> 'occupancy_pct')::integer,
        'locked_at', lock -> 'locked_at',
        'source', lock ->> 'source'
    );
end;
$$;

revoke all on function public.public_reservation_pricing(integer, bigint, text) from public;
grant execute on function public.public_reservation_pricing(integer, bigint, text)
    to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Simulation (read-only) and the impact report.
-- ---------------------------------------------------------------------------
create or replace function public.pricing_simulate(
    p_days integer default 30,
    p_rules jsonb default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    settings public.parking_settings%rowtype;
    tz text;
    total_sessions integer;
    considered integer := 0;
    affected integer := 0;
    base_total bigint := 0;
    simulated_total bigint := 0;
    at_floor integer := 0;
    at_ceiling integer := 0;
    session record;
    category_id integer;
    category_name text;
    spot_group text;
    base integer;
    others integer;
    occupancy integer;
    capacity integer;
    local_at timestamp;
    lock jsonb;
    detail jsonb;
    rule public.pricing_rules%rowtype;
    candidate public.pricing_rules%rowtype;
    idx integer := 0;
    simulated integer;
    rows jsonb := '[]'::jsonb;
    by_rule jsonb;
    by_hour jsonb;
begin
    if p_days is null or p_days < 1 or p_days > 90 then
        raise exception 'InvalidReportRangeError';
    end if;

    select count(*) into total_sessions
      from public.parking_sessions s
     where s.lot_id = lot
       and s.status = 'closed'
       and not coalesce(s.lost_ticket, false)
       and s.payment_method is distinct from 'monthly_pass'
       and s.entry_time >= now() - make_interval(days => p_days);
    if total_sessions > 20000 then
        raise exception 'PricingSimulationTooLargeError';
    end if;

    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    tz := coalesce(settings.business_timezone, 'America/Bogota');

    for session in
        select s.*
          from public.parking_sessions s
         where s.lot_id = lot
           and s.status = 'closed'
           and not coalesce(s.lost_ticket, false)
           and s.payment_method is distinct from 'monthly_pass'
           and s.entry_time >= now() - make_interval(days => p_days)
    loop
        select v.category_id, c.name into category_id, category_name
          from public.vehicles v
          join public.categories c on c.id = v.category_id
         where v.id = session.vehicle_id;
        if category_id is null then
            continue;
        end if;
        spot_group := public.category_group(category_name);

        begin
            base := (public.fare_breakdown(
                category_id, session.entry_time, session.exit_time, false
            ) ->> 'amount')::integer;
        exception when others then
            if sqlerrm not like '%MissingHourlyTariffError%' then raise; end if;
            continue;
        end;
        if base is null or base <= 0 then
            continue;
        end if;

        capacity := public.pricing_group_capacity(lot, spot_group);
        if capacity > 0 then
            select count(*) into others
              from public.parking_sessions o
              join public.vehicles ov on ov.id = o.vehicle_id
              join public.categories oc on oc.id = ov.category_id
             where o.lot_id = lot
               and o.id <> session.id
               and public.category_group(oc.name) = spot_group
               and o.entry_time <= session.entry_time
               and (o.exit_time is null or o.exit_time > session.entry_time);
            occupancy := least(floor(100 * others::numeric / capacity)::integer, 999);
        else
            occupancy := null;
        end if;

        local_at := session.entry_time at time zone tz;
        lock := null;
        idx := 0;

        if p_rules is null then
            for rule in
                select r.* from public.pricing_rules r
                 where r.lot_id = lot and r.active
                 order by r.priority desc, r.id
            loop
                if public.pricing_rule_matches(rule, spot_group, local_at, occupancy) then
                    lock := jsonb_build_object(
                        'v', 1, 'rule_id', rule.id, 'rule_name', rule.name,
                        'kind', case when rule.surcharge_amount = 0 then 'multiplier'
                                     when rule.multiplier_bps = 10000 then 'surcharge'
                                     else 'both' end,
                        'multiplier_bps', rule.multiplier_bps,
                        'surcharge_amount', rule.surcharge_amount,
                        'floor_bps', coalesce(settings.pricing_floor_bps, 10000),
                        'ceiling_bps', coalesce(settings.pricing_ceiling_bps, 15000),
                        'round_to', coalesce(settings.pricing_round_to, 1),
                        'occupancy_pct', occupancy, 'locked_at', now(),
                        'source', 'checkin'
                    );
                    exit;
                end if;
            end loop;
        else
            for candidate in
                select * from jsonb_to_recordset(p_rules) as x(
                    name text, priority integer, "group" text,
                    min_occupancy integer, max_occupancy integer,
                    weekdays integer, from_time time, to_time time,
                    multiplier_bps integer, surcharge_amount integer
                )
            loop
                idx := idx + 1;
                perform public.pricing_check_rule_fields(
                    candidate.name, candidate.priority, candidate.group_name,
                    candidate.min_occupancy_pct, candidate.max_occupancy_pct,
                    candidate.weekdays, candidate.from_time, candidate.to_time,
                    candidate.multiplier_bps, candidate.surcharge_amount
                );
                candidate.id := -idx;
                candidate.lot_id := lot;
                candidate.active := true;
                if public.pricing_rule_matches(candidate, spot_group, local_at, occupancy) then
                    lock := jsonb_build_object(
                        'v', 1, 'rule_id', -idx, 'rule_name', candidate.name,
                        'kind', case when candidate.surcharge_amount = 0 then 'multiplier'
                                     when candidate.multiplier_bps = 10000 then 'surcharge'
                                     else 'both' end,
                        'multiplier_bps', candidate.multiplier_bps,
                        'surcharge_amount', candidate.surcharge_amount,
                        'floor_bps', coalesce(settings.pricing_floor_bps, 10000),
                        'ceiling_bps', coalesce(settings.pricing_ceiling_bps, 15000),
                        'round_to', coalesce(settings.pricing_round_to, 1),
                        'occupancy_pct', occupancy, 'locked_at', now(),
                        'source', 'checkin'
                    );
                    exit;
                end if;
            end loop;
        end if;

        considered := considered + 1;
        base_total := base_total + base;
        detail := public.pricing_apply_detail(lock, base);
        simulated := coalesce((detail ->> 'amount')::integer, base);
        simulated_total := simulated_total + simulated;
        if (detail ->> 'clamped') = 'floor' then
            at_floor := at_floor + 1;
        elsif (detail ->> 'clamped') = 'ceiling' then
            at_ceiling := at_ceiling + 1;
        end if;
        if lock is not null and simulated <> base then
            affected := affected + 1;
        end if;

        rows := rows || jsonb_build_object(
            'rule_id', case when lock is null then null else (lock ->> 'rule_id')::integer end,
            'rule_name', lock ->> 'rule_name',
            'delta', simulated - base,
            'hour', extract(hour from local_at)::integer
        );
    end loop;

    select coalesce(jsonb_agg(jsonb_build_object(
               'rule_id', coalesce(r.rule_id, -1),
               'name', r.rule_name,
               'sessions', r.sessions,
               'delta', r.delta
           ) order by r.sessions desc), '[]'::jsonb)
      into by_rule
      from (
        select x.rule_id, x.rule_name, count(*) as sessions, sum(x.delta) as delta
          from jsonb_to_recordset(rows) as x(
              rule_id integer, rule_name text, delta integer, hour integer)
         where x.rule_name is not null
         group by x.rule_id, x.rule_name
      ) r;

    select coalesce(jsonb_agg(jsonb_build_object(
               'hour', h.hour,
               'sessions', h.sessions,
               'delta', h.delta
           ) order by h.hour), '[]'::jsonb)
      into by_hour
      from (
        select x.hour, count(*) as sessions, sum(x.delta) as delta
          from jsonb_to_recordset(rows) as x(
              rule_id integer, rule_name text, delta integer, hour integer)
         group by x.hour
      ) h;

    return jsonb_build_object(
        'days', p_days,
        'from', now() - make_interval(days => p_days),
        'to', now(),
        'sessions_considered', considered,
        'sessions_affected', affected,
        'base_total', base_total,
        'simulated_total', simulated_total,
        'delta', simulated_total - base_total,
        'delta_pct_bps', case
            when base_total = 0 then null
            else round((simulated_total - base_total) * 10000.0 / base_total)::integer
        end,
        'at_floor', at_floor,
        'at_ceiling', at_ceiling,
        'by_rule', by_rule,
        'by_hour', by_hour,
        'assumptions', jsonb_build_object(
            'holds_excluded', true, 'tariffs', 'current', 'capacity', 'current')
    );
end;
$$;

revoke all on function public.pricing_simulate(integer, jsonb) from public;
grant execute on function public.pricing_simulate(integer, jsonb) to authenticated;

create or replace function public.report_pricing_impact(
    p_start_date date,
    p_end_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    tz text;
    window_start timestamptz;
    window_end timestamptz;
    locked integer;
    surcharged integer;
    discounted integer;
    extra bigint;
    given_discount bigint;
    by_rule jsonb;
begin
    perform public.require_admin();
    if p_start_date is null or p_end_date is null or p_start_date > p_end_date then
        raise exception 'InvalidReportRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    with rows as (
        select s.id,
               s.pricing_lock,
               s.gross_amount - (public.fare_breakdown(
                   v.category_id, s.entry_time, s.exit_time, false
               ) ->> 'amount')::integer as delta
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where s.lot_id = lot
           and s.status = 'closed'
           and s.pricing_lock is not null
           and not coalesce(s.lost_ticket, false)
           and s.payment_method is distinct from 'monthly_pass'
           and s.gross_amount is not null
           and s.exit_time >= window_start
           and s.exit_time < window_end
    )
    select count(*),
           count(*) filter (where delta > 0),
           count(*) filter (where delta < 0),
           coalesce(sum(delta) filter (where delta > 0), 0),
           coalesce(-sum(delta) filter (where delta < 0), 0)
      into locked, surcharged, discounted, extra, given_discount
      from rows;

    select coalesce(jsonb_agg(jsonb_build_object(
               'rule_id', coalesce(r.rule_id, -1),
               'name', r.rule_name,
               'sessions', r.sessions,
               'delta', r.delta
           ) order by r.sessions desc), '[]'::jsonb)
      into by_rule
      from (
        select (s.pricing_lock ->> 'rule_id')::integer as rule_id,
               s.pricing_lock ->> 'rule_name' as rule_name,
               count(*) as sessions,
               coalesce(sum(s.gross_amount - (public.fare_breakdown(
                   v.category_id, s.entry_time, s.exit_time, false
               ) ->> 'amount')::integer), 0) as delta
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where s.lot_id = lot
           and s.status = 'closed'
           and s.pricing_lock is not null
           and not coalesce(s.lost_ticket, false)
           and s.payment_method is distinct from 'monthly_pass'
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by 1, 2
      ) r;

    return jsonb_build_object(
        'from', p_start_date,
        'to', p_end_date,
        'locked_sessions', locked,
        'surcharged_sessions', surcharged,
        'discounted_sessions', discounted,
        'extra_revenue', extra,
        'discount_given', given_discount,
        'net_delta', extra - given_discount,
        'by_rule', by_rule
    );
end;
$$;

revoke all on function public.report_pricing_impact(date, date) from public;
grant execute on function public.report_pricing_impact(date, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Public availability decoration (Case A: the wrapper already exists since
-- `0109`, so only the one-line call is added).
-- ---------------------------------------------------------------------------
create or replace function public.pricing_decorate_availability(
    p_lot_id integer,
    p_payload jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    enabled boolean;
    categories jsonb := '[]'::jsonb;
    item jsonb;
    category_id integer;
    hourly integer;
    lock jsonb;
    current integer;
    tier text;
begin
    select coalesce(pricing_enabled, false) into enabled
      from public.parking_settings where lot_id = p_lot_id;
    if not coalesce(enabled, false) then
        return coalesce(p_payload, '{}'::jsonb)
            || jsonb_build_object('pricing', jsonb_build_object('enabled', false));
    end if;

    for item in
        select * from jsonb_array_elements(coalesce(p_payload -> 'categories', '[]'::jsonb))
    loop
        category_id := (item ->> 'id')::integer;
        hourly := coalesce((item ->> 'hourly_amount')::integer, 0);
        lock := public.pricing_lock_for(p_lot_id, category_id, now(), true);
        current := public.pricing_apply(lock, hourly);
        tier := case
            when current > hourly then 'higher'
            when current < hourly then 'lower'
            else 'base'
        end;
        categories := categories || (item || jsonb_build_object(
            'current_hourly_amount', current,
            'price_rule', case when lock is null then null else lock ->> 'rule_name' end,
            'price_multiplier_bps', coalesce((lock ->> 'multiplier_bps')::integer, 10000),
            'price_tier', tier
        ));
    end loop;

    return coalesce(p_payload, '{}'::jsonb) || jsonb_build_object(
        'categories', categories,
        'pricing', jsonb_build_object('enabled', true)
    );
end;
$$;

revoke all on function public.pricing_decorate_availability(integer, jsonb)
    from public, anon, authenticated;

create or replace function public.public_availability(p_lot_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    base jsonb := public.public_availability_base(p_lot_id);
begin
    if base is null then
        return null;
    end if;
    base := public.pricing_decorate_availability(p_lot_id, base);
    return base || jsonb_build_object(
        'forecast', public.public_forecast_block(p_lot_id)
    );
end;
$$;

revoke all on function public.public_availability(integer) from public;
grant execute on function public.public_availability(integer) to anon, authenticated;
