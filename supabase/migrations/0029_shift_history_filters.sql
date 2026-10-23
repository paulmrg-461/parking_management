-- Admins can narrow the shift history by date range; the lot filter is
-- implicit (current_lot_id).

drop function if exists public.list_shifts(integer);

create function public.list_shifts(
    p_limit integer default 20,
    p_start_date date default null,
    p_end_date date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    tz text;
    window_start timestamptz;
    window_end timestamptz;
    result jsonb;
begin
    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    window_start := case
        when p_start_date is null then null
        else p_start_date::timestamp at time zone tz
    end;
    window_end := case
        when p_end_date is null then null
        else (p_end_date + 1)::timestamp at time zone tz
    end;

    select coalesce(jsonb_agg(item order by item ->> 'opened_at' desc), '[]'::jsonb)
      into result
      from (
        select public.shift_totals(s.id) as item
          from (
            select id
              from public.shifts
             where lot_id = lot
               and (window_start is null or opened_at >= window_start)
               and (window_end is null or opened_at < window_end)
             order by opened_at desc
             limit greatest(coalesce(p_limit, 20), 1)
          ) s
      ) rows;
    return result;
end;
$$;

grant execute on function public.list_shifts(integer, date, date) to authenticated;
