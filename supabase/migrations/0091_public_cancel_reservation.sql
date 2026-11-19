-- Public booking, part 5: the customer can give the space back. A hold that
-- will not be used blocks a real car until it expires (up to 24 h), so the
-- confirmation screen offers "Cancelar reserva".
--
-- The call needs the code, the plate AND the phone that made the booking, so
-- guessing a plate (or walking the ids) is not enough to free someone else's
-- space. Only `source = 'public'` holds can be cancelled this way; an
-- operator hold is cancelled from the app.

create or replace function public.public_cancel_reservation(
    p_lot_id integer,
    p_reservation_id bigint,
    p_plate text,
    p_customer_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    phone_digits text := regexp_replace(coalesce(p_customer_phone, ''), '\D', '', 'g');
    phone_local text;
    reservation public.category_reservations%rowtype;
begin
    phone_local := case
        when length(phone_digits) = 12 and phone_digits like '57%'
            then right(phone_digits, 10)
        else phone_digits
    end;

    update public.category_reservations r
       set status = 'cancelled'
     where r.id = p_reservation_id
       and r.lot_id = p_lot_id
       and r.plate = normalized
       and r.customer_phone = phone_local
       and r.source = 'public'
       and r.status = 'active'
    returning * into reservation;

    if not found then
        raise exception 'ReservationNotFoundError';
    end if;

    return jsonb_build_object(
        'id', reservation.id,
        'plate', reservation.plate,
        'status', reservation.status,
        'reserved_until', reservation.reserved_until
    );
end;
$$;

revoke all on function public.public_cancel_reservation(
    integer, bigint, text, text
) from public;
grant execute on function public.public_cancel_reservation(
    integer, bigint, text, text
) to anon, authenticated;
