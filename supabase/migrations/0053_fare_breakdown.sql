-- One source of truth for the money: fare_breakdown returns the components
-- (billed hours by day/night, rates, daily cap) and calculate_fare becomes a
-- thin wrapper over it. The check-out preview and the payment dialog show the
-- same numbers the server charges.

create or replace function public.fare_breakdown(
    p_category_id integer,
    p_entry_time timestamptz,
    p_exit_time timestamptz,
    p_has_pass boolean default false
)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
    tz text;
    entry_local timestamp;
    exit_local timestamp;
    day_cursor date;
    last_day date;
    day_start timestamp;
    day_end timestamp;
    seg_start timestamp;
    seg_end timestamp;
    hourly_amount integer;
    daily_amount integer;
    nightly_amount integer;
    night_start time;
    night_end time;
    win_start timestamp;
    win_end timestamp;
    night_secs numeric;
    day_secs numeric;
    day_charge integer;
    day_hours integer := 0;
    night_hours integer := 0;
    days_charged integer := 0;
    cap_applied boolean := false;
    total integer := 0;
begin
    if p_exit_time <= p_entry_time then
        raise exception 'InvalidBillingPeriodError';
    end if;

    if p_has_pass then
        return jsonb_build_object(
            'amount', 0,
            'hourly_rate', null,
            'nightly_rate', null,
            'daily_rate', null,
            'day_hours', 0,
            'night_hours', 0,
            'days', 0,
            'daily_cap_applied', false,
            'elapsed_seconds', extract(epoch from p_exit_time - p_entry_time)::integer
        );
    end if;

    select coalesce(ps.business_timezone, 'America/Bogota') into tz
      from public.parking_settings ps
      join public.categories c on c.lot_id = ps.lot_id
     where c.id = p_category_id;
    tz := coalesce(tz, 'America/Bogota');

    entry_local := p_entry_time at time zone tz;
    exit_local := p_exit_time at time zone tz;

    select t.amount into hourly_amount
      from public.tariffs t
     where t.category_id = p_category_id and t.type = 'hourly' and t.active
     order by t.id limit 1;
    if hourly_amount is null then
        raise exception 'MissingHourlyTariffError';
    end if;

    select t.amount into daily_amount
      from public.tariffs t
     where t.category_id = p_category_id and t.type = 'daily' and t.active
     order by t.id limit 1;

    select t.amount, t.start_time::time, t.end_time::time
      into nightly_amount, night_start, night_end
      from public.tariffs t
     where t.category_id = p_category_id and t.type = 'nightly' and t.active
     order by t.id limit 1;

    day_cursor := entry_local::date;
    last_day := (exit_local - interval '1 microsecond')::date;

    while day_cursor <= last_day loop
        day_start := day_cursor::timestamp;
        day_end := day_start + interval '1 day';
        seg_start := greatest(entry_local, day_start);
        seg_end := least(exit_local, day_end);

        if seg_end > seg_start then
            night_secs := 0;
            if nightly_amount is not null and night_start is not null and night_end is not null then
                win_start := day_start + night_start;
                win_end := day_start + night_end;
                if night_start < night_end then
                    night_secs := night_secs + greatest(
                        0,
                        extract(epoch from least(seg_end, win_end) - greatest(seg_start, win_start))
                    );
                else
                    night_secs := night_secs + greatest(
                        0,
                        extract(epoch from least(seg_end, win_end) - greatest(seg_start, day_start))
                    );
                    night_secs := night_secs + greatest(
                        0,
                        extract(epoch from least(seg_end, day_end) - greatest(seg_start, win_start))
                    );
                end if;
            end if;

            day_secs := extract(epoch from seg_end - seg_start) - night_secs;
            day_hours := day_hours + ceil(day_secs / 3600.0)::integer;
            night_hours := night_hours + ceil(night_secs / 3600.0)::integer;
            day_charge :=
                ceil(day_secs / 3600.0)::integer * greatest(hourly_amount, 0)
                + ceil(night_secs / 3600.0)::integer * greatest(coalesce(nightly_amount, 0), 0);
            if daily_amount is not null and day_charge > greatest(daily_amount, 0) then
                day_charge := greatest(daily_amount, 0);
                cap_applied := true;
            end if;
            days_charged := days_charged + 1;
            total := total + day_charge;
        end if;

        day_cursor := day_cursor + 1;
    end loop;

    return jsonb_build_object(
        'amount', greatest(total, 0),
        'hourly_rate', hourly_amount,
        'nightly_rate', nightly_amount,
        'daily_rate', daily_amount,
        'day_hours', day_hours,
        'night_hours', night_hours,
        'days', days_charged,
        'daily_cap_applied', cap_applied,
        'elapsed_seconds', extract(epoch from p_exit_time - p_entry_time)::integer
    );
end;
$$;

grant execute on function public.fare_breakdown(integer, timestamptz, timestamptz, boolean)
    to authenticated;

create or replace function public.calculate_fare(
    p_category_id integer,
    p_entry_time timestamptz,
    p_exit_time timestamptz,
    p_has_pass boolean default false
)
returns integer
language sql
stable
set search_path = public
as $$
    select (public.fare_breakdown($1, $2, $3, $4) ->> 'amount')::integer;
$$;

grant execute on function public.calculate_fare(integer, timestamptz, timestamptz, boolean)
    to authenticated;

-- Preview gains the breakdown so the dialog can explain the charge.
create or replace function public.check_out_preview(p_session_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    session public.parking_sessions%rowtype;
    vehicle public.vehicles%rowtype;
    tz text;
    has_pass boolean;
    preview_at timestamptz := now();
    breakdown jsonb;
begin
    perform public.require_app_user();

    select * into session
      from public.parking_sessions s
     where s.id = p_session_id;
    if not found then
        raise exception 'SessionNotFoundError';
    end if;
    if session.status = 'closed' then
        raise exception 'SessionAlreadyClosedError';
    end if;
    if session.lot_id <> public.current_lot_id() then
        raise exception 'LotRequiredError';
    end if;

    select * into vehicle from public.vehicles v where v.id = session.vehicle_id;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = session.lot_id;
    tz := coalesce(tz, 'America/Bogota');

    select exists (
        select 1 from public.monthly_passes mp
         where mp.vehicle_id = vehicle.id
           and mp.active
           and mp.start_date <= (preview_at at time zone tz)::date
           and mp.end_date >= (preview_at at time zone tz)::date
    ) into has_pass;

    breakdown := public.fare_breakdown(
        vehicle.category_id, session.entry_time, preview_at, has_pass
    );

    return breakdown || jsonb_build_object(
        'session_id', session.id,
        'amount', (breakdown ->> 'amount')::integer,
        'has_pass', has_pass,
        'entry_time', session.entry_time,
        'previewed_at', preview_at
    );
end;
$$;

grant execute on function public.check_out_preview(integer) to authenticated;
