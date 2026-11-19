-- Hourly traffic for the reports screen: how many vehicles entered and left
-- each hour of the business day in the selected range. Staffing decisions
-- ("when is the gate busiest?") do not need a second aggregation in Dart.

create or replace function public.report_hourly_traffic(
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
    hours jsonb;
begin
    perform public.require_admin();
    if p_start_date is null
       or p_end_date is null
       or p_start_date > p_end_date then
        raise exception 'InvalidReportRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    with entries as (
        select extract(hour from s.entry_time at time zone tz)::integer as hour,
               count(*) as total
          from public.parking_sessions s
         where s.lot_id = lot
           and s.entry_time >= window_start
           and s.entry_time < window_end
         group by 1
    ), exits as (
        select extract(hour from s.exit_time at time zone tz)::integer as hour,
               count(*) as total
          from public.parking_sessions s
         where s.lot_id = lot
           and s.status = 'closed'
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by 1
    )
    select coalesce(jsonb_agg(jsonb_build_object(
               'hour', h.hour,
               'entries', coalesce(e.total, 0),
               'exits', coalesce(x.total, 0)
           ) order by h.hour), '[]'::jsonb)
      into hours
      from generate_series(0, 23) as h(hour)
      left join entries e on e.hour = h.hour
      left join exits x on x.hour = h.hour;

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'timezone', tz,
        'hours', hours
    );
end;
$$;

grant execute on function public.report_hourly_traffic(date, date)
    to authenticated;
