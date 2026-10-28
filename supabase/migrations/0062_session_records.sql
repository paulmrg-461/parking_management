-- Site-wide activity log for the "Records" page: the latest sessions (entries
-- and exits) with an optional plate filter, paginated server-side.

create or replace function public.session_records(
    p_plate text default null,
    p_limit integer default 50,
    p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    filter_plate text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    take integer := least(greatest(coalesce(p_limit, 50), 1), 200);
    skip integer := greatest(coalesce(p_offset, 0), 0);
    total bigint;
    records jsonb;
begin
    perform public.require_app_user();

    select count(*) into total
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
     where s.lot_id = lot
       and (filter_plate = '' or v.plate ilike '%' || filter_plate || '%');

    select coalesce(
               jsonb_agg(item order by (item ->> 'entry_time')::timestamptz desc),
               '[]'::jsonb
           )
      into records
      from (
        select jsonb_build_object(
                   'id', s.id,
                   'plate', v.plate,
                   'category', c.name,
                   'entry_time', s.entry_time,
                   'exit_time', s.exit_time,
                   'status', s.status,
                   'amount_charged', coalesce(s.amount_charged, 0),
                   'ticket_number', s.ticket_number,
                   'payment_method', s.payment_method,
                   'duration_seconds', extract(epoch from (
                       coalesce(s.exit_time, now()) - s.entry_time
                   ))::integer
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.lot_id = lot
           and (filter_plate = '' or v.plate ilike '%' || filter_plate || '%')
         order by s.entry_time desc
         limit take offset skip
      ) rows;

    return jsonb_build_object('total', total, 'records', records);
end;
$$;

grant execute on function public.session_records(text, integer, integer) to authenticated;
