-- Reports: did the public page bring cars in? The owner needs to see how many
-- holds the web produced and how many actually turned into a stay, without
-- exporting the table. Counts are scoped to the selected business window
-- (`reserved_from` inside it), the lot and the admin role.

create or replace function public.report_reservations(
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
    total integer;
    public_count integer;
    app_count integer;
    used_count integer;
    used_public integer;
    cancelled_count integer;
    expired_count integer;
    active_count integer;
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

    select count(*),
           count(*) filter (where r.source = 'public'),
           count(*) filter (where r.source = 'app'),
           count(*) filter (where r.status = 'used'),
           count(*) filter (where r.status = 'used' and r.source = 'public'),
           count(*) filter (where r.status = 'cancelled'),
           count(*) filter (where r.status = 'expired'),
           count(*) filter (where r.status = 'active')
      into total, public_count, app_count, used_count, used_public,
           cancelled_count, expired_count, active_count
      from public.category_reservations r
     where r.lot_id = lot
       and r.reserved_from >= window_start
       and r.reserved_from < window_end;

    return jsonb_build_object(
        'total', total,
        'public', public_count,
        'app', app_count,
        'used', used_count,
        'used_public', used_public,
        'cancelled', cancelled_count,
        'expired', expired_count,
        'active', active_count
    );
end;
$$;

grant execute on function public.report_reservations(date, date) to authenticated;
