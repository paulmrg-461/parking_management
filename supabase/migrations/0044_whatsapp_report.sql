-- Delivery metrics for customer WhatsApp messages (active site, date range).

create or replace function public.report_whatsapp(
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
    sent bigint;
    failed bigint;
    pending bigint;
    by_day jsonb;
begin
    perform public.require_admin();
    if p_start_date > p_end_date then
        raise exception 'InvalidReportRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    select count(*) filter (where m.status = 'sent'),
           count(*) filter (where m.status = 'failed'),
           count(*) filter (where m.status = 'pending')
      into sent, failed, pending
      from public.whatsapp_messages m
     where m.lot_id = lot
       and m.created_at >= window_start
       and m.created_at < window_end;

    select coalesce(jsonb_agg(item order by item ->> 'date'), '[]'::jsonb)
      into by_day
      from (
        select jsonb_build_object(
                   'date', to_char(m.created_at at time zone tz, 'YYYY-MM-DD'),
                   'sent', count(*) filter (where m.status = 'sent'),
                   'failed', count(*) filter (where m.status = 'failed')
               ) as item
          from public.whatsapp_messages m
         where m.lot_id = lot
           and m.created_at >= window_start
           and m.created_at < window_end
         group by to_char(m.created_at at time zone tz, 'YYYY-MM-DD')
      ) days;

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'sent', sent,
        'failed', failed,
        'pending', pending,
        'by_day', by_day
    );
end;
$$;

grant execute on function public.report_whatsapp(date, date) to authenticated;
