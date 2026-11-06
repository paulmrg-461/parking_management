-- Home dashboard trend: daily revenue, entries and exits for the active site.
-- `dashboard_today` answers "how are we doing today"; this RPC answers "how
-- did the last few days go" without exposing the admin-only reports. Days
-- without movement are returned as zeroes, so the client can paint a
-- contiguous series without filling gaps itself.

create or replace function public.dashboard_trend(p_days integer default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    tz text;
    today_start timestamp;
    days jsonb;
begin
    if p_days is null or p_days < 1 or p_days > 31 then
        raise exception 'InvalidTrendRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    today_start := date_trunc('day', now() at time zone tz);

    select coalesce(jsonb_agg(jsonb_build_object(
                   'date', to_char(day, 'YYYY-MM-DD'),
                   'revenue', revenue,
                   'entries', entries,
                   'exits', exits
               ) order by day), '[]'::jsonb)
      into days
      from (
        select day,
               (select coalesce(sum(s.amount_charged), 0)
                  from public.parking_sessions s
                 where s.lot_id = lot
                   and s.status = 'closed'
                   and s.exit_time >= day at time zone tz
                   and s.exit_time < (day + interval '1 day') at time zone tz
               ) as revenue,
               (select count(*)
                  from public.parking_sessions s
                 where s.lot_id = lot
                   and s.entry_time >= day at time zone tz
                   and s.entry_time < (day + interval '1 day') at time zone tz
               ) as entries,
               (select count(*)
                  from public.parking_sessions s
                 where s.lot_id = lot
                   and s.status = 'closed'
                   and s.exit_time >= day at time zone tz
                   and s.exit_time < (day + interval '1 day') at time zone tz
               ) as exits
          from generate_series(
                 today_start - make_interval(days => p_days - 1),
                 today_start,
                 interval '1 day'
               ) as day
      ) rows;

    return jsonb_build_object(
        'lot_id', lot,
        'start_date', to_char(
            today_start - make_interval(days => p_days - 1), 'YYYY-MM-DD'
        ),
        'end_date', to_char(today_start, 'YYYY-MM-DD'),
        'days', days
    );
end;
$$;

grant execute on function public.dashboard_trend(integer) to authenticated;
