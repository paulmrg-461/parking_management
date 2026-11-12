-- Occupancy forecast: "will it be full at 6 pm?".
--
-- The history is already in `parking_sessions`. This migration derives, per lot,
-- vehicle group, weekday and hour, the **median** occupancy of the last K
-- same-weekday days (`occupancy_profile`), refreshes it from the job runner and
-- blends it with today's live deviation to forecast the next hours
-- (`occupancy_forecast` for staff, `public_availability.forecast` for the
-- public page as aggregates only).
--
-- `public_availability` becomes a thin wrapper (`|| {'forecast': ...}`) around
-- `public_availability_base`: later changes must edit the **base** function, so
-- a whatever wave edits it is never overwritten by a copy of its body here.

-- ---------------------------------------------------------------------------
-- Settings and profile
-- ---------------------------------------------------------------------------

create table if not exists public.forecast_settings (
    id                 serial primary key,
    lot_id             integer not null unique
                       references public.parking_lots(id) on delete cascade,
    enabled            boolean not null default true,
    history_weeks      integer not null default 8  check (history_weeks between 4 and 26),
    min_samples        integer not null default 4  check (min_samples between 3 and 26),
    blend_decay_pct    integer not null default 85 check (blend_decay_pct between 50 and 99),
    full_threshold_pct integer not null default 100 check (full_threshold_pct between 50 and 100),
    public_enabled     boolean not null default true,
    updated_at         timestamptz not null default now(),
    constraint forecast_settings_samples_check check (min_samples <= history_weeks)
);

create table if not exists public.occupancy_profile (
    lot_id           integer  not null references public.parking_lots(id) on delete cascade,
    group_name       text     not null check (group_name in ('car', 'moto', 'heavy')),
    dow              smallint not null check (dow between 0 and 6),
    hour             smallint not null check (hour between 0 and 23),
    median_occupancy numeric(8, 2) not null check (median_occupancy >= 0),
    samples          smallint not null check (samples >= 0),
    computed_at      timestamptz not null default now(),
    primary key (lot_id, group_name, dow, hour)
);

alter table public.forecast_settings enable row level security;
alter table public.occupancy_profile enable row level security;
revoke all on public.forecast_settings, public.occupancy_profile from anon, authenticated;
grant select on public.forecast_settings, public.occupancy_profile to authenticated;

drop policy if exists forecast_settings_admin_read on public.forecast_settings;
create policy forecast_settings_admin_read on public.forecast_settings
    for select to authenticated
    using (public.is_lot_admin(lot_id) and lot_id = public.current_lot_id());

drop policy if exists occupancy_profile_member_read on public.occupancy_profile;
create policy occupancy_profile_member_read on public.occupancy_profile
    for select to authenticated
    using (lot_id = public.current_lot_id());

drop trigger if exists trg_audit_row on public.forecast_settings;
create trigger trg_audit_row after insert or update on public.forecast_settings
    for each row execute function public.record_audit();

insert into public.forecast_settings (lot_id)
select l.id from public.parking_lots l
on conflict (lot_id) do nothing;

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

-- Capacity of one group, by the same rule the live counters use: bays when the
-- lot drew any of that group, otherwise the usable settings capacity.
create or replace function public.group_capacity(p_lot integer, p_group text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select case
        when exists (
            select 1 from public.parking_spots sp
             where sp.lot_id = p_lot and sp.group_name = p_group)
            then (select count(*)::integer from public.parking_spots sp
                   where sp.lot_id = p_lot and sp.group_name = p_group
                     and sp.status = 'active')
        when p_group = 'car' then public.usable_capacity(
            (select ps.car_capacity from public.parking_settings ps where ps.lot_id = p_lot),
            (select ps.car_out_of_service from public.parking_settings ps where ps.lot_id = p_lot))
        when p_group = 'moto' then public.usable_capacity(
            (select ps.moto_capacity from public.parking_settings ps where ps.lot_id = p_lot),
            (select ps.moto_out_of_service from public.parking_settings ps where ps.lot_id = p_lot))
        else 0
    end;
$$;

revoke all on function public.group_capacity(integer, text)
    from public, anon, authenticated;

-- Net occupancy at every full hour of [p_from, p_to], per group, in the lot's
-- business timezone. Quiet slots come back as 0; a stuck-open session stops
-- counting after 72 hours so one forgotten gate cannot poison the profile.
create or replace function public.occupancy_grid(
    p_lot integer,
    p_from date,
    p_to date
)
returns table (group_name text, day date, hour integer, occupancy integer)
language sql
stable
security definer
set search_path = public
as $$
    with tz as (
        select coalesce(
            (select ps.business_timezone from public.parking_settings ps
              where ps.lot_id = p_lot),
            'America/Bogota'
        ) as name
    ), grp as (
        select distinct public.category_group(c.name) as g
          from public.categories c
         where c.lot_id = p_lot
    ), slots as (
        select g.g, d::date as day, h
          from grp g,
               generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') d,
               generate_series(0, 23) h
    ), marks as (
        select public.category_group(c.name) as g, m as mark
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
          cross join tz
          cross join lateral (
              select s.entry_time at time zone tz.name as e,
                     least(
                         coalesce(s.exit_time, now()),
                         s.entry_time + interval '72 hours'
                     ) at time zone tz.name as x
          ) t
          cross join lateral generate_series(
              date_trunc('hour', t.e)
                  + case
                        when t.e = date_trunc('hour', t.e) then interval '0'
                        else interval '1 hour'
                    end,
              t.x - interval '1 microsecond',
              interval '1 hour'
          ) m
         where s.lot_id = p_lot
           and s.entry_time >= p_from::timestamp at time zone tz.name - interval '72 hours'
           and s.entry_time < (p_to + 1)::timestamp at time zone tz.name
           and m >= p_from::timestamp
           and m < (p_to + 1)::timestamp
    ), counted as (
        select g, mark::date as day, extract(hour from mark)::integer as hour,
               count(*) as n
          from marks
         group by 1, 2, 3
    )
    select s.g, s.day, s.h, coalesce(c.n, 0)::integer
      from slots s
      left join counted c on c.g = s.g and c.day = s.day and c.hour = s.h;
$$;

revoke all on function public.occupancy_grid(integer, date, date)
    from public, anon, authenticated;

-- Rebuilds the profile of every active lot when it is older than six hours
-- (or when forced). The job calls it with no arguments.
create or replace function public.refresh_occupancy_profile(
    p_force boolean default false
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    lot record;
    tz text;
    today date;
    first_day date;
    written integer := 0;
    n integer;
begin
    if not pg_try_advisory_xact_lock(hashtext('refresh_occupancy_profile')) then
        return 0;
    end if;
    for lot in
        select l.id, coalesce(fs.history_weeks, 8) as weeks
          from public.parking_lots l
          left join public.forecast_settings fs on fs.lot_id = l.id
         where l.active and coalesce(fs.enabled, true)
    loop
        continue when not p_force and exists (
            select 1 from public.occupancy_profile p
             where p.lot_id = lot.id
               and p.computed_at > now() - interval '6 hours');
        select coalesce(ps.business_timezone, 'America/Bogota') into tz
          from public.parking_settings ps where ps.lot_id = lot.id;
        tz := coalesce(tz, 'America/Bogota');
        today := (now() at time zone tz)::date;
        select (min(s.entry_time) at time zone tz)::date into first_day
          from public.parking_sessions s where s.lot_id = lot.id;
        continue when first_day is null;
        insert into public.occupancy_profile
               (lot_id, group_name, dow, hour, median_occupancy, samples, computed_at)
        select lot.id,
               g.group_name,
               extract(dow from g.day)::integer,
               g.hour,
               round((percentile_cont(0.5) within group (order by g.occupancy))::numeric, 2),
               count(*),
               now()
          from public.occupancy_grid(lot.id, today - 7 * lot.weeks, today - 1) g
         where g.day >= first_day
         group by g.group_name, extract(dow from g.day), g.hour
        on conflict (lot_id, group_name, dow, hour) do update
           set median_occupancy = excluded.median_occupancy,
               samples = excluded.samples,
               computed_at = excluded.computed_at;
        get diagnostics n = row_count;
        delete from public.occupancy_profile p
         where p.lot_id = lot.id and p.computed_at < now();
        written := written + n;
    end loop;
    return written;
end;
$$;

revoke all on function public.refresh_occupancy_profile(boolean)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The algorithm
-- ---------------------------------------------------------------------------

-- Profile + live deviation, clamped to capacity. `p_now` is explicit so the
-- tests can replay a fixed moment (now() is constant inside a transaction).
create or replace function public.forecast_compute(
    p_lot integer,
    p_horizon integer,
    p_now timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    enabled boolean := true;
    weeks integer := 8;
    min_samples integer := 4;
    decay_pct integer := 85;
    full_pct integer := 100;
    tz text;
    now_local timestamp;
    hour0 timestamp;
    fraction double precision;
    grp text;
    cap integer;
    cur integer;
    p0 numeric;
    p1 numeric;
    s0 integer;
    s1 integer;
    dev numeric;
    k integer;
    mark timestamp;
    ahead double precision;
    raw numeric;
    prev_value numeric;
    prev_ahead double precision;
    hours jsonb;
    level text;
    threshold numeric;
    groups jsonb := '[]'::jsonb;
    any_capacity boolean := false;
    confidence text;
    min_used integer;
    full_at text;
    cross_hours double precision;
    cross_at timestamp;
    oldest_computed timestamptz;
    cell_computed timestamptz;
begin
    select fs.enabled, fs.history_weeks, fs.min_samples,
           fs.blend_decay_pct, fs.full_threshold_pct
      into enabled, weeks, min_samples, decay_pct, full_pct
      from public.forecast_settings fs
     where fs.lot_id = p_lot;
    if not found then
        enabled := true;
        weeks := 8;
        min_samples := 4;
        decay_pct := 85;
        full_pct := 100;
    end if;
    if not enabled then
        return jsonb_build_object(
            'lot_id', p_lot, 'status', 'disabled', 'horizon_hours', p_horizon,
            'groups', '[]'::jsonb, 'profile_computed_at', null
        );
    end if;

    select coalesce(ps.business_timezone, l.timezone, 'America/Bogota') into tz
      from public.parking_lots l
      left join public.parking_settings ps on ps.lot_id = l.id
     where l.id = p_lot;
    tz := coalesce(tz, 'America/Bogota');
    now_local := p_now at time zone tz;
    hour0 := date_trunc('hour', now_local);
    fraction := extract(minute from now_local) / 60.0;

    for grp in select unnest(array['car', 'moto']) loop
        cap := public.group_capacity(p_lot, grp);
        continue when cap is null or cap <= 0;
        any_capacity := true;

        select pr.median_occupancy, pr.samples, pr.computed_at
          into p0, s0, oldest_computed
          from public.occupancy_profile pr
         where pr.lot_id = p_lot and pr.group_name = grp
           and pr.dow = extract(dow from hour0)
           and pr.hour = extract(hour from hour0);
        if not found or s0 < min_samples then
            continue;
        end if;
        select pr.median_occupancy, pr.samples, pr.computed_at
          into p1, s1, cell_computed
          from public.occupancy_profile pr
         where pr.lot_id = p_lot and pr.group_name = grp
           and pr.dow = extract(dow from hour0 + interval '1 hour')
           and pr.hour = extract(hour from hour0 + interval '1 hour');
        if not found or s1 < min_samples then
            continue;
        end if;
        oldest_computed := least(oldest_computed, cell_computed);

        select count(*) into cur
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.lot_id = p_lot
           and s.status = 'open'
           and public.category_group(c.name) = grp;

        dev := cur - (p0 + fraction * (p1 - p0));
        threshold := cap * full_pct / 100.0;
        hours := '[]'::jsonb;
        prev_value := cur;
        prev_ahead := 0;
        full_at := null;
        min_used := least(s0, s1);

        for k in 1 .. p_horizon loop
            mark := hour0 + k * interval '1 hour';
            select pr.median_occupancy, pr.samples, pr.computed_at
              into p0, s0, cell_computed
              from public.occupancy_profile pr
             where pr.lot_id = p_lot and pr.group_name = grp
               and pr.dow = extract(dow from mark)
               and pr.hour = extract(hour from mark);
            if not found or s0 < min_samples then
                hours := null;
                exit;
            end if;
            min_used := least(min_used, s0);
            oldest_computed := least(oldest_computed, cell_computed);

            ahead := extract(epoch from (mark - now_local)) / 3600.0;
            raw := p0 + dev * power(decay_pct / 100.0, ahead);

            level := case
                when raw >= threshold then 'full'
                when raw >= cap * 0.8 then 'busy'
                else 'free'
            end;
            hours := hours || jsonb_build_array(jsonb_build_object(
                'hour_start', to_char(mark, 'YYYY-MM-DD"T"HH24:00'),
                'hour', extract(hour from mark)::integer,
                'expected', round(least(greatest(raw, 0), cap))::integer,
                'level', level
            ));

            if full_at is null
               and prev_value < threshold
               and raw >= threshold then
                cross_hours := prev_ahead
                    + (threshold - prev_value) / (raw - prev_value)
                      * (ahead - prev_ahead);
                cross_at := now_local + cross_hours * interval '1 hour';
                full_at := to_char(
                    date_trunc('hour', cross_at)
                        + round(extract(minute from cross_at) / 15)
                          * interval '15 minutes',
                    'HH24:MI'
                );
            end if;
            prev_value := raw;
            prev_ahead := ahead;
        end loop;

        if hours is null then
            continue;
        end if;
        confidence := case
            when min_used >= 7 then 'high'
            when min_used >= 5 then 'medium'
            else 'low'
        end;
        groups := groups || jsonb_build_array(jsonb_build_object(
            'group', grp,
            'capacity', cap,
            'current', cur,
            'confidence', confidence,
            'samples', min_used,
            'full_now', cur >= threshold,
            'full_at', case when cur >= threshold then null else full_at end,
            'hours', hours
        ));
    end loop;

    return jsonb_build_object(
        'lot_id', p_lot,
        'timezone', tz,
        'generated_at', p_now,
        'status', case
            when jsonb_array_length(groups) > 0 then 'ok'
            when not any_capacity then 'no_capacity'
            else 'insufficient_history'
        end,
        'horizon_hours', p_horizon,
        'profile_computed_at', oldest_computed,
        'groups', groups
    );
end;
$$;

revoke all on function public.forecast_compute(integer, integer, timestamptz)
    from public, anon, authenticated;

-- Staff RPC: any member of the active lot.
create or replace function public.occupancy_forecast(
    p_horizon_hours integer default 12
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer;
begin
    perform public.require_app_user();
    lot := public.current_lot_id();
    if p_horizon_hours is null or p_horizon_hours not between 1 and 24 then
        raise exception 'InvalidForecastHorizonError';
    end if;
    return public.forecast_compute(lot, p_horizon_hours, now());
end;
$$;

revoke all on function public.occupancy_forecast(integer) from public, anon;
grant execute on function public.occupancy_forecast(integer) to authenticated;

-- Public block: aggregates only (levels, deadline, confidence). Any failure is
-- `unavailable` so it can never break the booking page.
create or replace function public.public_forecast_block(p_lot_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    cfg_public boolean;
    staff jsonb;
begin
    select coalesce(fs.public_enabled, true) into cfg_public
      from public.parking_lots l
      left join public.forecast_settings fs on fs.lot_id = l.id
     where l.id = p_lot_id;
    if not coalesce(cfg_public, false) then
        return jsonb_build_object('status', 'hidden', 'groups', '[]'::jsonb);
    end if;
    staff := public.forecast_compute(p_lot_id, 12, now());
    return jsonb_build_object(
        'status', staff ->> 'status',
        'timezone', staff ->> 'timezone',
        'groups', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'group', g ->> 'group',
                       'confidence', g ->> 'confidence',
                       'full_now', (g ->> 'full_now')::boolean,
                       'full_at', g -> 'full_at',
                       'hours', (
                           select jsonb_agg(jsonb_build_object(
                                      'hour', (h ->> 'hour')::integer,
                                      'level', h ->> 'level'
                                  ) order by h ->> 'hour_start')
                             from jsonb_array_elements(g -> 'hours') h
                       )
                   ))
              from jsonb_array_elements(staff -> 'groups') g
        ), '[]'::jsonb)
    );
exception when others then
    return jsonb_build_object('status', 'unavailable', 'groups', '[]'::jsonb);
end;
$$;

revoke all on function public.public_forecast_block(integer)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Backtest
-- ---------------------------------------------------------------------------

create or replace function public.occupancy_forecast_backtest(
    p_weeks integer default 4
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    cfg record;
    tz text;
    today date;
    first_day date;
    from_day date;
    grp text;
    cap integer;
    issue integer;
    lead integer;
    eval_day date;
    prior_now numeric;
    prior_target numeric;
    prior_count integer;
    actual_now integer;
    actual_target integer;
    forecast numeric;
    err numeric;
    err_prior numeric;
    points integer;
    sum_err numeric;
    sum_prior numeric;
    sum_bias numeric;
    lead_points integer;
    lead_sum numeric;
    lead_prior numeric;
    by_lead jsonb;
    groups jsonb := '[]'::jsonb;
    w double precision;
begin
    if p_weeks is null or p_weeks not between 1 and 12 then
        raise exception 'InvalidReportRangeError';
    end if;

    select fs.history_weeks, fs.min_samples, fs.blend_decay_pct into cfg
      from public.forecast_settings fs where fs.lot_id = lot;
    if not found then
        cfg := row(8, 4, 85)::record;
    end if;
    w := cfg.blend_decay_pct / 100.0;

    select coalesce(ps.business_timezone, l.timezone, 'America/Bogota') into tz
      from public.parking_lots l
      left join public.parking_settings ps on ps.lot_id = l.id
     where l.id = lot;
    tz := coalesce(tz, 'America/Bogota');
    today := (now() at time zone tz)::date;
    select (min(s.entry_time) at time zone tz)::date into first_day
      from public.parking_sessions s where s.lot_id = lot;
    if first_day is null then
        return jsonb_build_object(
            'weeks', p_weeks, 'history_weeks', cfg.history_weeks,
            'decay_pct', cfg.blend_decay_pct,
            'issue_hours', jsonb_build_array(8, 12, 16),
            'groups', '[]'::jsonb
        );
    end if;
    from_day := today - 7 * (p_weeks + cfg.history_weeks);

    -- The grid is read once into a temp table: every prior is a 7-day step
    -- inside it, so the loop below never touches parking_sessions again.
    create temporary table if not exists forecast_grid_tmp (
        gname text, day date, hour integer, occupancy integer,
        primary key (gname, day, hour)
    ) on commit drop;
    delete from forecast_grid_tmp;
    insert into forecast_grid_tmp (gname, day, hour, occupancy)
    select g.group_name, g.day, g.hour, g.occupancy
      from public.occupancy_grid(lot, from_day, today - 1) g;

    for grp in select unnest(array['car', 'moto']) loop
        cap := public.group_capacity(lot, grp);
        continue when cap is null or cap <= 0;
        points := 0;
        sum_err := 0;
        sum_prior := 0;
        sum_bias := 0;
        by_lead := '[]'::jsonb;
        for issue in select unnest(array[8, 12, 16]) loop
            for lead in 1 .. 12 loop
                continue when issue + lead > 23;
                lead_points := 0;
                lead_sum := 0;
                lead_prior := 0;
                for eval_day in
                    select distinct g.day from forecast_grid_tmp g
                     where g.gname = grp
                       and g.day > today - 7 * p_weeks
                       and g.day <= today - 1
                     order by 1
                loop
                    continue when eval_day < first_day + (cfg.history_weeks * 7);
                    -- Prior as of that morning: the median of the same
                    -- weekday over the K previous weeks.
                    select percentile_cont(0.5) within group (order by g.occupancy)
                      into prior_now
                      from forecast_grid_tmp g
                     where g.gname = grp and g.day >= eval_day - 7 * cfg.history_weeks
                       and g.day <= eval_day - 7 and g.hour = issue;
                    select count(*) into prior_count
                      from forecast_grid_tmp g
                     where g.gname = grp and g.day >= eval_day - 7 * cfg.history_weeks
                       and g.day <= eval_day - 7 and g.hour = issue
                       and g.occupancy is not null;
                    if prior_now is null or prior_count < cfg.min_samples then
                        continue;
                    end if;
                    select percentile_cont(0.5) within group (order by g.occupancy)
                      into prior_target
                      from forecast_grid_tmp g
                     where g.gname = grp
                       and g.day >= eval_day - 7 * cfg.history_weeks
                       and g.day <= eval_day - 7 and g.hour = issue + lead;
                    if prior_target is null then
                        continue;
                    end if;
                    select g.occupancy into actual_now
                      from forecast_grid_tmp g
                     where g.gname = grp and g.day = eval_day and g.hour = issue;
                    select g.occupancy into actual_target
                      from forecast_grid_tmp g
                     where g.gname = grp and g.day = eval_day and g.hour = issue + lead;
                    if actual_now is null or actual_target is null then
                        continue;
                    end if;
                    forecast := least(greatest(
                        prior_target + (actual_now - prior_now) * power(w, lead),
                        0), cap);
                    err := abs(forecast - actual_target);
                    err_prior := abs(prior_target - actual_target);
                    points := points + 1;
                    sum_err := sum_err + err;
                    sum_prior := sum_prior + err_prior;
                    sum_bias := sum_bias + (forecast - actual_target);
                    lead_points := lead_points + 1;
                    lead_sum := lead_sum + err;
                    lead_prior := lead_prior + err_prior;
                end loop;
                if lead in (1, 3, 6) and lead_points > 0 then
                    by_lead := by_lead || jsonb_build_array(jsonb_build_object(
                        'lead_hours', lead,
                        'points', lead_points,
                        'mae', round((lead_sum / lead_points)::numeric, 2),
                        'mae_prior_only', round((lead_prior / lead_points)::numeric, 2)
                    ));
                end if;
            end loop;
        end loop;
        groups := groups || jsonb_build_array(jsonb_build_object(
            'group', grp,
            'points', points,
            'mae', case when points > 0
                        then round((sum_err / points)::numeric, 2) end,
            'mae_prior_only', case when points > 0
                                   then round((sum_prior / points)::numeric, 2) end,
            'bias', case when points > 0
                         then round((sum_bias / points)::numeric, 2) end,
            'by_lead', by_lead
        ));
    end loop;

    return jsonb_build_object(
        'weeks', p_weeks,
        'history_weeks', cfg.history_weeks,
        'decay_pct', cfg.blend_decay_pct,
        'issue_hours', jsonb_build_array(8, 12, 16),
        'groups', groups
    );
end;
$$;

revoke all on function public.occupancy_forecast_backtest(integer)
    from public, anon;
grant execute on function public.occupancy_forecast_backtest(integer)
    to authenticated;

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

create or replace function public.get_forecast_settings()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    cfg public.forecast_settings%rowtype;
begin
    insert into public.forecast_settings (lot_id)
    values (lot)
    on conflict (lot_id) do nothing;
    select * into cfg from public.forecast_settings fs where fs.lot_id = lot;
    return jsonb_build_object(
        'enabled', cfg.enabled,
        'history_weeks', cfg.history_weeks,
        'min_samples', cfg.min_samples,
        'blend_decay_pct', cfg.blend_decay_pct,
        'full_threshold_pct', cfg.full_threshold_pct,
        'public_enabled', cfg.public_enabled
    );
end;
$$;

revoke all on function public.get_forecast_settings() from public, anon;
grant execute on function public.get_forecast_settings() to authenticated;

create or replace function public.set_forecast_settings(p_settings jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    cfg public.forecast_settings%rowtype;
    key text;
    value jsonb;
    next_enabled boolean;
    next_weeks integer;
    next_samples integer;
    next_decay integer;
    next_full integer;
    next_public boolean;
begin
    if p_settings is null or jsonb_typeof(p_settings) <> 'object' then
        raise exception 'InvalidForecastSettingError';
    end if;
    for key, value in select * from jsonb_each(p_settings) loop
        if key not in ('enabled', 'history_weeks', 'min_samples',
                       'blend_decay_pct', 'full_threshold_pct',
                       'public_enabled') then
            raise exception 'InvalidForecastSettingError';
        end if;
        if key in ('enabled', 'public_enabled') then
            if jsonb_typeof(value) <> 'boolean' then
                raise exception 'InvalidForecastSettingError';
            end if;
        elsif jsonb_typeof(value) <> 'number' then
            raise exception 'InvalidForecastSettingError';
        end if;
    end loop;

    insert into public.forecast_settings (lot_id)
    values (lot)
    on conflict (lot_id) do nothing;
    select * into cfg from public.forecast_settings fs where fs.lot_id = lot;

    -- Validate the resulting row before touching it, so a bad combination is a
    -- typed error and not a check-constraint violation.
    next_enabled := coalesce((p_settings ->> 'enabled')::boolean, cfg.enabled);
    next_weeks := coalesce((p_settings ->> 'history_weeks')::integer, cfg.history_weeks);
    next_samples := coalesce((p_settings ->> 'min_samples')::integer, cfg.min_samples);
    next_decay := coalesce((p_settings ->> 'blend_decay_pct')::integer, cfg.blend_decay_pct);
    next_full := coalesce((p_settings ->> 'full_threshold_pct')::integer, cfg.full_threshold_pct);
    next_public := coalesce((p_settings ->> 'public_enabled')::boolean, cfg.public_enabled);
    if next_weeks not between 4 and 26
       or next_samples not between 3 and 26
       or next_samples > next_weeks
       or next_decay not between 50 and 99
       or next_full not between 50 and 100 then
        raise exception 'InvalidForecastSettingError';
    end if;

    update public.forecast_settings
       set enabled = next_enabled,
           history_weeks = next_weeks,
           min_samples = next_samples,
           blend_decay_pct = next_decay,
           full_threshold_pct = next_full,
           public_enabled = next_public,
           updated_at = now()
     where lot_id = lot
    returning * into cfg;

    -- Any accepted change invalidates this lot's profile; the next job run
    -- (or a forced refresh) rebuilds it.
    delete from public.occupancy_profile p where p.lot_id = lot;

    return jsonb_build_object(
        'enabled', cfg.enabled,
        'history_weeks', cfg.history_weeks,
        'min_samples', cfg.min_samples,
        'blend_decay_pct', cfg.blend_decay_pct,
        'full_threshold_pct', cfg.full_threshold_pct,
        'public_enabled', cfg.public_enabled
    );
end;
$$;

revoke all on function public.set_forecast_settings(jsonb) from public, anon;
grant execute on function public.set_forecast_settings(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- public_availability becomes a wrapper around its own body
-- ---------------------------------------------------------------------------

do $$
begin
    if exists (
        select 1 from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'public_availability'
    ) then
        execute 'alter function public.public_availability(integer) '
             || 'rename to public_availability_base';
    end if;
end $$;

revoke all on function public.public_availability_base(integer)
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
    return base || jsonb_build_object(
        'forecast', public.public_forecast_block(p_lot_id)
    );
end;
$$;

revoke all on function public.public_availability(integer) from public;
grant execute on function public.public_availability(integer) to anon, authenticated;
