-- Booking waitlist, part 2: the reservations report learns about the queue.
--
-- `report_reservations` answered "did the public page bring cars in?". With a
-- waitlist a hold can also arrive as an unclaimed offer (`source =
-- 'waitlist'`), which is not a booking yet: it must not inflate `public`,
-- `app` or `total`. Every existing count therefore excludes it, and a
-- `waitlist` object counts the turns of the same business window.
--
-- Only the three `source = 'waitlist'` rows are excluded, so nothing else
-- changes for a lot that never enables the waitlist.

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
    waitlist_joined integer;
    waitlist_offered integer;
    waitlist_claimed integer;
    waitlist_expired integer;
    waitlist_left integer;
    waitlist_cancelled integer;
    waitlist_waiting integer;
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

    -- Unclaimed offers are holds, not bookings: they are not counted here.
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
       and r.source <> 'waitlist'
       and r.reserved_from >= window_start
       and r.reserved_from < window_end;

    select count(*),
           count(*) filter (where w.offered_at is not null),
           count(*) filter (where w.status = 'claimed'),
           count(*) filter (where w.status = 'expired'),
           count(*) filter (where w.status = 'left'),
           count(*) filter (where w.status = 'cancelled'),
           count(*) filter (where w.status = 'waiting')
      into waitlist_joined, waitlist_offered, waitlist_claimed,
           waitlist_expired, waitlist_left, waitlist_cancelled,
           waitlist_waiting
      from public.reservation_waitlist w
     where w.lot_id = lot
       and w.created_at >= window_start
       and w.created_at < window_end;

    return jsonb_build_object(
        'total', total,
        'public', public_count,
        'app', app_count,
        'used', used_count,
        'used_public', used_public,
        'cancelled', cancelled_count,
        'expired', expired_count,
        'active', active_count,
        'waitlist', jsonb_build_object(
            'joined', waitlist_joined,
            'offered', waitlist_offered,
            'claimed', waitlist_claimed,
            'expired', waitlist_expired,
            'left', waitlist_left,
            'cancelled', waitlist_cancelled,
            'waiting', waitlist_waiting
        )
    );
end;
$$;

grant execute on function public.report_reservations(date, date) to authenticated;
