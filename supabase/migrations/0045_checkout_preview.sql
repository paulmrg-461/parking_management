-- Shows the fare before charging, without closing the session. The client
-- never computes money; this is the same calculate_fare used by check_out.

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
    gross integer;
    preview_at timestamptz := now();
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

    gross := public.calculate_fare(
        vehicle.category_id, session.entry_time, preview_at, has_pass
    );

    return jsonb_build_object(
        'session_id', session.id,
        'amount', gross,
        'has_pass', has_pass,
        'entry_time', session.entry_time,
        'previewed_at', preview_at
    );
end;
$$;

grant execute on function public.check_out_preview(integer) to authenticated;
