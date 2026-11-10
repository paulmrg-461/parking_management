-- Public booking, part 13: when the lot cancels a web hold, the customer has
-- to know. The operator cancels from the board, the hold disappears from the
-- board and the customer would otherwise travel for nothing. If the lot has
-- automated WhatsApp on, queue a `reservation_cancelled` message with the
-- name, plate and lot (same queue and template pattern as the confirmation).
--
-- Operator holds (`source = 'app'`) are untouched: no phone was collected.

create or replace function public.cancel_reservation(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    reservation public.category_reservations%rowtype;
    lot_name text;
    whatsapp_on boolean;
begin
    perform public.require_app_user();
    select * into reservation
      from public.category_reservations r
     where r.id = p_id
     for update;
    if not found then
        raise exception 'ReservationNotFoundError';
    end if;
    if reservation.lot_id <> public.current_lot_id() then
        raise exception 'LotRequiredError';
    end if;
    if reservation.status <> 'active' then
        raise exception 'ReservationNotActiveError';
    end if;

    update public.category_reservations
       set status = 'cancelled'
     where id = reservation.id
     returning * into reservation;

    select coalesce(ps.whatsapp_auto, false), coalesce(l.name, '')
      into whatsapp_on, lot_name
      from public.parking_lots l
      left join public.parking_settings ps on ps.lot_id = l.id
     where l.id = reservation.lot_id;

    if whatsapp_on
       and reservation.source = 'public'
       and reservation.customer_phone is not null then
        insert into public.whatsapp_messages (
            lot_id, to_phone, template, language, params
        )
        values (
            reservation.lot_id,
            reservation.customer_phone,
            'reservation_cancelled',
            'es',
            jsonb_build_array(
                coalesce(reservation.customer_name, ''),
                reservation.plate,
                lot_name
            )
        );
    end if;

    return jsonb_build_object('id', reservation.id, 'status', reservation.status);
end;
$$;

grant execute on function public.cancel_reservation(bigint) to authenticated;
