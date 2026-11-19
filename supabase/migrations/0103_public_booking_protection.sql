-- Public booking, part 12: bot protection.
--
-- Two controls, both per lot and both in `parking_settings`:
--
--   * `public_booking_hourly_limit` — ceiling on public holds created in the
--     last hour (sliding window, default 20). Needs no credentials, counts
--     every `source = 'public'` row created in the window (cancelled and
--     expired ones too, so book-and-cancel does not reset it) and never looks
--     at staff holds (`source = 'app'`).
--   * `public_booking_captcha` — when on, the anonymous RPC refuses and the
--     only way in is the `public-booking` Edge Function, which verifies a
--     Cloudflare Turnstile token with the secret and then calls the
--     service-role-only twin below. Off by default, so a deployment without
--     Turnstile keys behaves exactly as before.
--
-- The privilege boundary is a GRANT, not a role sniffed from the JWT: the
-- booking body moves to `public_create_reservation_verified` (service_role
-- only) and `public_create_reservation` keeps its name, signature and anon
-- grant as a thin gate in front of it. No parameter was added, so there is no
-- second overload to disambiguate.

alter table public.parking_settings
    add column if not exists public_booking_captcha boolean not null default false;
alter table public.parking_settings
    add column if not exists public_booking_hourly_limit integer not null default 20;

alter table public.parking_settings
    drop constraint if exists parking_settings_public_booking_limit_check;
alter table public.parking_settings
    add constraint parking_settings_public_booking_limit_check
    check (public_booking_hourly_limit between 1 and 1000);

create index if not exists category_reservations_public_created_idx
    on public.category_reservations (lot_id, created_at)
    where source = 'public';

create or replace function public.public_create_reservation_verified(
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
    timezone_name text;
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

    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;

    -- Throttle: serialize public bookings per lot so two concurrent requests
    -- cannot both read "one below the ceiling", then count the window.
    perform pg_advisory_xact_lock(hashtext('public_booking_throttle'), p_lot_id);
    if (
        select count(*)
          from public.category_reservations r
         where r.lot_id = p_lot_id
           and r.source = 'public'
           and r.created_at > now() - interval '1 hour'
    ) >= coalesce(settings.public_booking_hourly_limit, 20) then
        raise exception 'BookingThrottledError';
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

    timezone_name := coalesce(settings.business_timezone, lot.timezone, 'America/Bogota');

    insert into public.notifications (
        user_id, type, title, body, data, dedupe_key, lot_id
    )
    select u.id,
           'public_reservation',
           'Reserva web: ' || reservation.plate,
           customer_name || ' reservó ' || category_name || ' hasta ' ||
               to_char(reservation.reserved_until at time zone timezone_name, 'HH24:MI'),
           jsonb_build_object(
               'reservation_id', reservation.id,
               'plate', reservation.plate,
               'category_id', p_category_id
           ),
           'public_reservation:' || reservation.id || ':user:' || u.id,
           p_lot_id
      from public.users u
      join public.lot_members lm on lm.user_id = u.id
     where lm.lot_id = p_lot_id
       and u.is_active
    on conflict (dedupe_key) do nothing;

    -- The customer gets the code and the time on WhatsApp, the same way a
    -- receipt does. Queued (never sent here) and drained by
    -- `whatsapp-dispatch`, which needs an approved template with the body
    -- params name, plate, until, lot.
    if coalesce(settings.whatsapp_auto, false) then
        insert into public.whatsapp_messages (
            lot_id, to_phone, template, language, params
        )
        values (
            p_lot_id,
            phone_local,
            'reservation_confirmed',
            'es',
            jsonb_build_array(
                customer_name,
                reservation.plate,
                to_char(
                    reservation.reserved_until at time zone timezone_name,
                    'DD/MM HH24:MI'
                ),
                lot.name
            )
        );
    end if;

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

-- Supabase default privileges hand new functions to anon/authenticated, so
-- the revoke names them explicitly; only the Edge Function's key gets in.
revoke all on function public.public_create_reservation_verified(
    integer, text, integer, timestamp with time zone, text, text
) from public, anon, authenticated;
grant execute on function public.public_create_reservation_verified(
    integer, text, integer, timestamp with time zone, text, text
) to service_role;

-- Same name, signature and grant as before: the anonymous entry point. It
-- refuses when the lot demands a captcha (the caller could not have proved
-- one) and otherwise runs the shared body, throttle included.
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
begin
    if exists (
        select 1
          from public.parking_settings ps
         where ps.lot_id = p_lot_id
           and ps.public_booking_captcha
    ) then
        raise exception 'CaptchaRequiredError';
    end if;
    return public.public_create_reservation_verified(
        p_lot_id, p_plate, p_category_id, p_until,
        p_customer_name, p_customer_phone
    );
end;
$$;

grant execute on function public.public_create_reservation(
    integer, text, integer, timestamp with time zone, text, text
) to anon, authenticated;

-- The lot admin turns the captcha requirement on or off and tunes the
-- ceiling. `null` keeps the current value of either setting.
create or replace function public.set_public_booking_protection(
    p_captcha boolean default null,
    p_hourly_limit integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    updated public.parking_settings%rowtype;
begin
    if p_hourly_limit is not null and p_hourly_limit not between 1 and 1000 then
        raise exception 'InvalidDataError';
    end if;

    update public.parking_settings
       set public_booking_captcha = coalesce(p_captcha, public_booking_captcha),
           public_booking_hourly_limit =
               coalesce(p_hourly_limit, public_booking_hourly_limit),
           updated_at = now()
     where lot_id = lot
     returning * into updated;

    if not found then
        raise exception 'NotFoundError';
    end if;
    return jsonb_build_object(
        'captcha', updated.public_booking_captcha,
        'hourly_limit', updated.public_booking_hourly_limit
    );
end;
$$;

revoke all on function public.set_public_booking_protection(boolean, integer)
    from public, anon;
grant execute on function public.set_public_booking_protection(boolean, integer)
    to authenticated;
