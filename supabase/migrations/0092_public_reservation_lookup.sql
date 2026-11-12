-- Public booking, part 6: the customer can come back later. A hold is only
-- cancellable while the confirmation screen is open, which is not how people
-- use a web page; this lookup lets them retrieve an active hold with the code
-- printed on the confirmation plus the mobile they booked with.
--
-- Returns null instead of raising when nothing matches: "no encontramos esa
-- reserva" is an expected answer, not an error. Only `source = 'public'`,
-- active and still-valid holds are visible, so the lookup never exposes other
-- customers' history (or an operator's hold).

create or replace function public.public_reservation_lookup(
    p_lot_id integer,
    p_reservation_id bigint,
    p_customer_phone text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    phone_digits text := regexp_replace(coalesce(p_customer_phone, ''), '\D', '', 'g');
    phone_local text;
    lot public.parking_lots%rowtype;
    settings public.parking_settings%rowtype;
    reservation public.category_reservations%rowtype;
    category public.categories%rowtype;
begin
    phone_local := case
        when length(phone_digits) = 12 and phone_digits like '57%'
            then right(phone_digits, 10)
        else phone_digits
    end;

    select * into reservation
      from public.category_reservations r
     where r.id = p_reservation_id
       and r.lot_id = p_lot_id
       and r.customer_phone = phone_local
       and r.source = 'public'
       and r.status = 'active'
       and r.reserved_until > now();
    if not found then
        return null;
    end if;

    select * into lot
      from public.parking_lots l
     where l.id = p_lot_id and l.active;
    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;
    select * into category
      from public.categories c
     where c.id = reservation.category_id;

    return jsonb_build_object(
        'id', reservation.id,
        'plate', reservation.plate,
        'category_id', reservation.category_id,
        'category_name', coalesce(category.name, ''),
        'reserved_until', reservation.reserved_until,
        'status', reservation.status,
        'lot', jsonb_build_object(
            'id', p_lot_id,
            'name', coalesce(lot.name, ''),
            'address', coalesce(settings.address, ''),
            'phone', coalesce(settings.phone, ''),
            'whatsapp', coalesce(settings.whatsapp, '')
        )
    );
end;
$$;

revoke all on function public.public_reservation_lookup(
    integer, bigint, text
) from public;
grant execute on function public.public_reservation_lookup(
    integer, bigint, text
) to anon, authenticated;
