-- Expose recent discounted sessions to admins so a discount can be traced to
-- its reason, actor and timestamp from the reports screen.

create or replace function public.report_revenue(p_start_date date, p_end_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    tz text;
    window_start timestamptz;
    window_end timestamptz;
    total bigint;
    discounts bigint;
    discounted_sessions bigint;
    by_day jsonb;
    by_category jsonb;
    by_payment jsonb;
    audit jsonb;
begin
    perform public.require_admin();
    if p_start_date > p_end_date then
        raise exception 'InvalidReportRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where id = 1;
    tz := coalesce(tz, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    select coalesce(sum(s.amount_charged), 0),
           coalesce(sum(s.discount_amount), 0),
           count(*) filter (where s.discount_amount > 0)
      into total, discounts, discounted_sessions
      from public.parking_sessions s
     where s.status = 'closed'
       and s.exit_time >= window_start
       and s.exit_time < window_end;

    select coalesce(jsonb_agg(item order by item ->> 'date'), '[]'::jsonb) into by_day
      from (
        select jsonb_build_object(
                   'date', to_char(exit_time at time zone tz, 'YYYY-MM-DD'),
                   'amount', coalesce(sum(amount_charged), 0)
               ) as item
          from public.parking_sessions s
         where s.status = 'closed'
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by to_char(exit_time at time zone tz, 'YYYY-MM-DD')
      ) days;

    select coalesce(jsonb_agg(item order by item ->> 'category_name'), '[]'::jsonb)
      into by_category
      from (
        select jsonb_build_object(
                   'category_id', c.id,
                   'category_name', c.name,
                   'amount', coalesce(sum(s.amount_charged), 0)
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.status = 'closed'
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by c.id, c.name
      ) categories;

    select coalesce(jsonb_agg(item order by item ->> 'payment_method'), '[]'::jsonb)
      into by_payment
      from (
        select jsonb_build_object(
                   'payment_method', coalesce(payment_method, 'unknown'),
                   'amount', coalesce(sum(amount_charged), 0)
               ) as item
          from public.parking_sessions s
         where s.status = 'closed'
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by coalesce(payment_method, 'unknown')
      ) payments;

    select coalesce(jsonb_agg(item order by item ->> 'discount_at' desc), '[]'::jsonb)
      into audit
      from (
        select jsonb_build_object(
                   'session_id', s.id,
                   'plate', v.plate,
                   'ticket_number', s.ticket_number,
                   'amount_charged', s.amount_charged,
                   'discount_amount', s.discount_amount,
                   'discount_reason', s.discount_reason,
                   'discount_at', s.discount_at,
                   'admin', u.username
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.users u on u.id = s.discount_by
         where s.status = 'closed'
           and s.discount_amount > 0
           and s.exit_time >= window_start
           and s.exit_time < window_end
         order by s.discount_at desc
         limit 50
      ) discounts_log;

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'total', total,
        'total_discounts', discounts,
        'discounted_sessions', discounted_sessions,
        'by_day', by_day,
        'by_category', by_category,
        'by_payment', by_payment,
        'discount_audit', audit
    );
end;
$$;

grant execute on function public.report_revenue(date, date) to authenticated;
