-- Home dashboard "today" summary for the active site: revenue, entries/exits
-- and current occupancy in one read (the occupancy card does its own call).

create or replace function public.dashboard_today()
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
    window_start timestamptz;
    window_end timestamptz;
    revenue bigint;
    cash_revenue bigint;
    pass_revenue bigint;
    entries bigint;
    exits bigint;
    open_now bigint;
begin
    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    window_start := date_trunc('day', now() at time zone tz) at time zone tz;
    window_end := window_start + interval '1 day';

    select coalesce(sum(s.amount_charged), 0),
           coalesce(sum(s.amount_charged) filter (where s.payment_method = 'cash'), 0),
           count(*)
      into revenue, cash_revenue, exits
      from public.parking_sessions s
     where s.lot_id = lot
       and s.status = 'closed'
       and s.exit_time >= window_start
       and s.exit_time < window_end;

    select count(*) into entries
      from public.parking_sessions s
     where s.lot_id = lot
       and s.entry_time >= window_start
       and s.entry_time < window_end;

    select count(*) into open_now
      from public.parking_sessions s
     where s.lot_id = lot and s.status = 'open';

    select coalesce(sum(p.amount), 0) into pass_revenue
      from public.monthly_pass_payments p
     where p.lot_id = lot
       and p.status = 'paid'
       and p.paid_at >= window_start
       and p.paid_at < window_end;

    return jsonb_build_object(
        'lot_id', lot,
        'revenue', revenue,
        'cash_revenue', cash_revenue,
        'pass_revenue', pass_revenue,
        'entries', entries,
        'exits', exits,
        'open_now', open_now
    );
end;
$$;

grant execute on function public.dashboard_today() to authenticated;
