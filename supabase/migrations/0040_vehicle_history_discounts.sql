-- The vehicle timeline carries the discount so a ticket can be reprinted
-- from history with the same numbers as the original receipt.

create or replace function public.vehicle_history(p_plate text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    vehicle public.vehicles%rowtype;
    category_name text;
    result jsonb;
begin
    perform public.require_app_user();
    if normalized = '' then
        raise exception 'VehicleNotFoundError';
    end if;

    select * into vehicle from public.vehicles v where v.plate = normalized;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;
    select c.name into category_name
      from public.categories c where c.id = vehicle.category_id;

    select jsonb_build_object(
        'plate', vehicle.plate,
        'vehicle_id', vehicle.id,
        'category_id', vehicle.category_id,
        'category_name', category_name,
        'color', vehicle.color,
        'brand', vehicle.brand,
        'is_blacklisted', vehicle.is_blacklisted,
        'notes', vehicle.notes,
        'visits', count(*),
        'current_lot_visits', count(*) filter (where s.lot_id = public.current_lot_id()),
        'total_spent', coalesce(sum(s.amount_charged) filter (where s.status = 'closed'), 0),
        'open_sessions', count(*) filter (where s.status = 'open'),
        'sessions', coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'id', s.id,
                    'entry_time', s.entry_time,
                    'exit_time', s.exit_time,
                    'status', s.status,
                    'amount_charged', s.amount_charged,
                    'ticket_number', s.ticket_number,
                    'payment_method', s.payment_method,
                    'lost_ticket', s.lost_ticket,
                    'discount_amount', s.discount_amount,
                    'discount_reason', s.discount_reason,
                    'lot_id', s.lot_id,
                    'lot_name', (select l.name from public.parking_lots l where l.id = s.lot_id),
                    'duration_seconds', case
                        when s.exit_time is not null
                            then extract(epoch from s.exit_time - s.entry_time)::bigint
                        else extract(epoch from now() - s.entry_time)::bigint
                    end
                )
                order by s.entry_time desc
            ),
            '[]'::jsonb
        )
    ) into result
      from public.parking_sessions s
     where s.vehicle_id = vehicle.id;

    return result;
end;
$$;

grant execute on function public.vehicle_history(text) to authenticated;
