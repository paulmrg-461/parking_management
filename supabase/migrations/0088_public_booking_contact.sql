-- Public booking: the customer's name and a mobile phone are now required, so
-- the lot can actually reach whoever is holding the space. The phone has to be
-- a Colombian mobile (10 digits starting with 3, optional +57) and is stored in
-- the 10-digit local form so the per-phone guard keeps working.
--
-- The rule is enforced twice: in the RPC and in a table constraint that only
-- applies to `source = 'public'`, so a direct insert cannot bring back an
-- anonymous hold without contact data.

alter table public.category_reservations
    drop constraint if exists category_reservations_public_contact_check;
alter table public.category_reservations
    add constraint category_reservations_public_contact_check
    check (
        source <> 'public'
        or (
            customer_name is not null
            and length(btrim(customer_name)) between 1 and 120
            and customer_phone ~ '^3[0-9]{9}$'
        )
    );

create or replace function public.public_create_reservation(
    p_lot_id integer,
    p_plate text,
    p_category_id integer,
    p_until timestamp with time zone,
    p_customer_name text default null,
    p_customer_phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot public.parking_lots%rowtype;
    settings public.parking_settings%rowtype;
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    customer_name text := btrim(coalesce(p_customer_name, ''));
    phone_digits text := regexp_replace(coalesce(p_customer_phone, ''), '\D', '', 'g');
    phone_local text;
    category_name text;
    reservation public.category_reservations%rowtype;
begin
    select * into lot
      from public.parking_lots l
     where l.id = p_lot_id and l.active;
    if not found then
        raise exception 'LotNotFoundError';
    end if;
    if normalized !~ '^[A-Z0-9-]{3,20}$' then
        raise exception 'InvalidPlateError';
    end if;
    if customer_name = '' or length(customer_name) > 120 then
        raise exception 'InvalidNameError';
    end if;
    phone_local := case
        when length(phone_digits) = 12 and phone_digits like '57%'
            then right(phone_digits, 10)
        else phone_digits
    end;
    if phone_local !~ '^3[0-9]{9}$' then
        raise exception 'InvalidPhoneError';
    end if;
    if p_until is null
       or p_until <= now() + interval '10 minutes'
       or p_until > now() + interval '24 hours' then
        raise exception 'InvalidReservationWindowError';
    end if;

    select lower(c.name) into category_name
      from public.categories c
     where c.id = p_category_id
       and c.lot_id = p_lot_id;
    if not found then
        raise exception 'CategoryNotFoundError';
    end if;

    perform public.reservation_capacity_check(p_lot_id, p_category_id, normalized);

    if exists (
        select 1
          from public.category_reservations r
         where r.lot_id = p_lot_id
           and r.plate = normalized
           and r.status = 'active'
           and r.reserved_until > now()
    ) then
        raise exception 'ReservationExistsError';
    end if;

    if (
        select count(*)
          from public.category_reservations r
         where r.lot_id = p_lot_id
           and r.customer_phone = phone_local
           and r.status = 'active'
           and r.reserved_until > now()
    ) >= 2 then
        raise exception 'ReservationLimitError';
    end if;

    insert into public.category_reservations (
        plate, category_id, reserved_until, notes, created_by, lot_id,
        customer_name, customer_phone, source
    )
    values (
        normalized, p_category_id, p_until, null, null, p_lot_id,
        customer_name, phone_local, 'public'
    )
    returning * into reservation;

    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;

    return jsonb_build_object(
        'id', reservation.id,
        'plate', reservation.plate,
        'category_id', reservation.category_id,
        'category_name', category_name,
        'reserved_until', reservation.reserved_until,
        'status', reservation.status,
        'lot', jsonb_build_object(
            'id', lot.id,
            'name', lot.name,
            'address', coalesce(settings.address, ''),
            'phone', coalesce(settings.phone, ''),
            'whatsapp', coalesce(settings.whatsapp, '')
        )
    );
end;
$$;

grant execute on function public.public_create_reservation(
    integer, text, integer, timestamp with time zone, text, text
) to anon, authenticated;
