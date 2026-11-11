-- Booking waitlist, part 1: settings, tables, constraints.
--
-- When every category is full the public page used to render "call us" and the
-- customer left. The waitlist remembers the turn and hands out the space when
-- one frees, as a **real hold** in `category_reservations` (`source =
-- 'waitlist'`), so every capacity counter already counts it and an offer
-- cannot overbook by construction.
--
-- This file holds the schema first; the customer RPCs, the dispatch/claim/
-- expiry functions, the triggers and the desk RPCs follow in the same
-- migration (see the sections below).
--
-- `waitlist_enabled` defaults to false: with it off every new RPC refuses or
-- reports `enabled = false` and the triggers return at once, so the page looks
-- exactly as it does today.

alter table public.parking_settings
    add column if not exists waitlist_enabled boolean not null default false;
alter table public.parking_settings
    add column if not exists waitlist_claim_minutes integer not null default 15;
alter table public.parking_settings
    add column if not exists waitlist_max_entries integer not null default 30;

alter table public.parking_settings
    drop constraint if exists parking_settings_waitlist_check;
alter table public.parking_settings
    add constraint parking_settings_waitlist_check check (
        waitlist_claim_minutes between 5 and 120
        and waitlist_max_entries between 1 and 500
    );

-- A waitlist offer is a hold, so the source catalogue and the "a public hold
-- carries contact data" rule both widen by one value.
alter table public.category_reservations
    drop constraint if exists category_reservations_source_check;
alter table public.category_reservations
    add constraint category_reservations_source_check
    check (source in ('app', 'public', 'waitlist'));

alter table public.category_reservations
    drop constraint if exists category_reservations_public_contact_check;
alter table public.category_reservations
    add constraint category_reservations_public_contact_check
    check (
        source not in ('public', 'waitlist')
        or (
            customer_name is not null
            and length(btrim(customer_name)) between 1 and 120
            -- `null ~ pattern` is null, which would let a hold through: the
            -- explicit null test is what makes the rule hold.
            and customer_phone is not null
            and customer_phone ~ '^3[0-9]{9}$'
        )
    );

create table if not exists public.reservation_waitlist (
    id             bigserial   primary key,
    lot_id         integer     not null references public.parking_lots(id),
    category_id    integer     not null,
    group_name     text        not null check (group_name in ('car', 'moto', 'heavy')),
    plate          varchar(20) not null,
    customer_name  varchar(120) not null,
    customer_phone varchar(20) not null,
    status         text        not null default 'waiting'
                   check (status in ('waiting', 'offered', 'claimed', 'expired', 'left', 'cancelled')),
    wait_until     timestamptz not null,
    hold_minutes   integer     not null default 60 check (hold_minutes between 10 and 1440),
    offered_at     timestamptz,
    offer_until    timestamptz,
    reservation_id bigint      references public.category_reservations(id) on delete set null,
    claimed_at     timestamptz,
    created_at     timestamptz not null default now(),
    constraint reservation_waitlist_category_lot_fkey
        foreign key (category_id, lot_id) references public.categories (id, lot_id),
    constraint reservation_waitlist_contact_check check (
        customer_phone ~ '^3[0-9]{9}$'
        and length(btrim(customer_name)) between 1 and 120
    ),
    -- An offer always carries its deadline and its hold; nothing else does.
    constraint reservation_waitlist_offer_check check (
        (status = 'offered') = (offer_until is not null and reservation_id is not null)
        or status <> 'offered'
    )
);

-- One active turn per plate and lot (waiting or offered).
create unique index if not exists uq_waitlist_active_plate
    on public.reservation_waitlist (lot_id, plate)
    where status in ('waiting', 'offered');
create index if not exists ix_waitlist_fifo
    on public.reservation_waitlist (lot_id, group_name, created_at, id)
    where status = 'waiting';
create index if not exists ix_waitlist_phone_active
    on public.reservation_waitlist (lot_id, customer_phone)
    where status in ('waiting', 'offered');
create index if not exists ix_waitlist_offer_due
    on public.reservation_waitlist (offer_until)
    where status = 'offered';
create index if not exists ix_waitlist_created
    on public.reservation_waitlist (lot_id, created_at);

-- A trigger that could not take the group lock records the group here; the
-- job drains it. Internal: no policy and no grant.
create table if not exists public.waitlist_kicks (
    lot_id     integer     not null references public.parking_lots(id) on delete cascade,
    group_name text        not null,
    created_at timestamptz not null default now(),
    primary key (lot_id, group_name)
);

alter table public.reservation_waitlist enable row level security;
alter table public.waitlist_kicks enable row level security;
revoke all on public.reservation_waitlist, public.waitlist_kicks from anon, authenticated;
grant select on public.reservation_waitlist to authenticated;

drop policy if exists waitlist_read on public.reservation_waitlist;
create policy waitlist_read on public.reservation_waitlist
    for select to authenticated using (lot_id = public.current_lot_id());

-- ---------------------------------------------------------------------------
-- Customer RPCs
-- ---------------------------------------------------------------------------

-- What the public card needs before the customer types anything: whether the
-- waitlist exists for this lot, how long an offer lasts, and how many people
-- are waiting per category (sorted by id). `notify_channel` tells the page
-- whether to promise WhatsApp or "keep this page open".
create or replace function public.public_waitlist_info(p_lot_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot public.parking_lots%rowtype;
    settings public.parking_settings%rowtype;
    waiting jsonb;
begin
    select * into lot
      from public.parking_lots l
     where l.id = p_lot_id and l.active;
    if not found then
        return null;
    end if;
    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;

    select coalesce(jsonb_agg(entry order by entry ->> 'category_id'), '[]'::jsonb)
      into waiting
      from (
          select jsonb_build_object(
                     'category_id', w.category_id,
                     'count', count(*)
                 ) as entry
            from public.reservation_waitlist w
           where w.lot_id = p_lot_id
             and w.status = 'waiting'
           group by w.category_id
      ) grouped;

    return jsonb_build_object(
        'enabled', coalesce(settings.waitlist_enabled, false),
        'claim_minutes', coalesce(settings.waitlist_claim_minutes, 15),
        'max_hold_minutes', 1440,
        'notify_channel',
            case when coalesce(settings.whatsapp_auto, false)
                 then 'whatsapp' else 'screen' end,
        'waiting', waiting
    );
end;
$$;

revoke all on function public.public_waitlist_info(integer) from public;
grant execute on function public.public_waitlist_info(integer) to anon, authenticated;

-- The body of a public join. Service-role only: the anonymous twin below is a
-- captcha gate in front of it, exactly like `public_create_reservation`.
create or replace function public.public_join_waitlist_verified(
    p_lot_id integer,
    p_plate text,
    p_category_id integer,
    p_wait_until timestamptz,
    p_hold_minutes integer,
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
    category public.categories%rowtype;
    entry_group text;
    timezone_name text;
    entry public.reservation_waitlist%rowtype;
    active_count integer;
    position integer;
    capacity_free boolean := false;
    notify_channel text;
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
    -- Waiting at least 10 minutes and at most a day; a hold between 10 and
    -- 1440 minutes, the same bounds as the table check.
    if p_wait_until is null
       or p_wait_until <= now() + interval '10 minutes'
       or p_wait_until > now() + interval '24 hours'
       or p_hold_minutes is null
       or p_hold_minutes not between 10 and 1440 then
        raise exception 'InvalidWaitWindowError';
    end if;

    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;
    if not coalesce(settings.waitlist_enabled, false) then
        raise exception 'WaitlistDisabledError';
    end if;

    select * into category
      from public.categories c
     where c.id = p_category_id
       and c.lot_id = p_lot_id;
    if not found then
        raise exception 'CategoryNotFoundError';
    end if;
    entry_group := public.category_group(lower(category.name));

    -- Same lock, key and window as public bookings, but counting waitlist
    -- entries: a waitlist flood never eats the booking quota and vice versa.
    perform pg_advisory_xact_lock(hashtext('public_booking_throttle'), p_lot_id);
    if (
        select count(*)
          from public.reservation_waitlist w
         where w.lot_id = p_lot_id
           and w.created_at > now() - interval '1 hour'
    ) >= coalesce(settings.public_booking_hourly_limit, 20) then
        raise exception 'BookingThrottledError';
    end if;

    -- The space is still there: the customer should book, not wait. The probe
    -- sets a flag instead of raising inside the block so the "not needed"
    -- answer cannot be swallowed by the handler.
    begin
        perform public.reservation_capacity_check(
            p_lot_id, p_category_id, normalized
        );
        capacity_free := true;
    exception when others then
        if sqlerrm not like '%CategoryFullError%'
           and sqlerrm not like '%ParkingFullError%' then
            raise;
        end if;
    end;
    if capacity_free then
        raise exception 'WaitlistNotNeededError';
    end if;

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

    if exists (
        select 1
          from public.reservation_waitlist w
         where w.lot_id = p_lot_id
           and w.plate = normalized
           and w.status in ('waiting', 'offered')
    ) then
        raise exception 'WaitlistExistsError';
    end if;

    select count(*) into active_count
      from public.reservation_waitlist w
     where w.lot_id = p_lot_id
       and w.customer_phone = phone_local
       and w.status in ('waiting', 'offered');
    if active_count >= 2 then
        raise exception 'WaitlistLimitError';
    end if;

    select count(*) into active_count
      from public.reservation_waitlist w
     where w.lot_id = p_lot_id
       and w.status in ('waiting', 'offered');
    if active_count >= coalesce(settings.waitlist_max_entries, 30) then
        raise exception 'WaitlistFullError';
    end if;

    insert into public.reservation_waitlist (
        lot_id, category_id, group_name, plate, customer_name, customer_phone,
        wait_until, hold_minutes
    )
    values (
        p_lot_id, p_category_id, entry_group, normalized, customer_name,
        phone_local, p_wait_until, p_hold_minutes
    )
    returning * into entry;

    select count(*) + 1 into position
      from public.reservation_waitlist w
     where w.lot_id = p_lot_id
       and w.group_name = entry_group
       and w.status = 'waiting'
       and (w.created_at, w.id) < (entry.created_at, entry.id);

    timezone_name := coalesce(settings.business_timezone, lot.timezone, 'America/Bogota');
    notify_channel := case when coalesce(settings.whatsapp_auto, false)
                           then 'whatsapp' else 'screen' end;

    insert into public.notifications (
        user_id, type, title, body, data, dedupe_key, lot_id
    )
    select u.id,
           'waitlist_joined',
           'Lista de espera: ' || entry.plate,
           customer_name || ' espera ' || lower(category.name),
           jsonb_build_object(
               'entry_id', entry.id,
               'plate', entry.plate,
               'category_id', p_category_id
           ),
           'waitlist_joined:' || entry.id || ':user:' || u.id,
           p_lot_id
      from public.users u
      join public.lot_members lm on lm.user_id = u.id
     where lm.lot_id = p_lot_id
       and u.is_active
    on conflict (dedupe_key) do nothing;

    return jsonb_build_object(
        'id', entry.id,
        'plate', entry.plate,
        'category_id', entry.category_id,
        'category_name', lower(category.name),
        'status', entry.status,
        'position', position,
        'wait_until', entry.wait_until,
        'hold_minutes', entry.hold_minutes,
        'claim_minutes', coalesce(settings.waitlist_claim_minutes, 15),
        'notify_channel', notify_channel,
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

revoke all on function public.public_join_waitlist_verified(
    integer, text, integer, timestamp with time zone, integer, text, text
) from public, anon, authenticated;
grant execute on function public.public_join_waitlist_verified(
    integer, text, integer, timestamp with time zone, integer, text, text
) to service_role;

-- The anonymous entry point: refuses when the lot demands a captcha (the
-- caller could not have proved one), otherwise runs the shared body.
create or replace function public.public_join_waitlist(
    p_lot_id integer,
    p_plate text,
    p_category_id integer,
    p_wait_until timestamptz,
    p_hold_minutes integer,
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
    return public.public_join_waitlist_verified(
        p_lot_id, p_plate, p_category_id, p_wait_until, p_hold_minutes,
        p_customer_name, p_customer_phone
    );
end;
$$;

revoke all on function public.public_join_waitlist(
    integer, text, integer, timestamp with time zone, integer, text, text
) from public;
grant execute on function public.public_join_waitlist(
    integer, text, integer, timestamp with time zone, integer, text, text
) to anon, authenticated;

-- The customer's own turn, fetched with the code and the mobile. Entries from
-- the last 48 hours so an expired turn still explains itself.
create or replace function public.public_waitlist_lookup(
    p_lot_id integer,
    p_entry_id bigint,
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
    entry public.reservation_waitlist%rowtype;
    category_name text;
    position integer;
begin
    phone_local := case
        when length(phone_digits) = 12 and phone_digits like '57%'
            then right(phone_digits, 10)
        else phone_digits
    end;

    select * into entry
      from public.reservation_waitlist w
     where w.id = p_entry_id
       and w.lot_id = p_lot_id
       and w.customer_phone = phone_local
       and w.created_at > now() - interval '48 hours';
    if not found then
        return null;
    end if;

    select * into lot
      from public.parking_lots l
     where l.id = p_lot_id and l.active;
    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;
    select lower(c.name) into category_name
      from public.categories c
     where c.id = entry.category_id;

    select count(*) + 1 into position
      from public.reservation_waitlist w
     where w.lot_id = p_lot_id
       and w.group_name = entry.group_name
       and w.status = 'waiting'
       and (w.created_at, w.id) < (entry.created_at, entry.id);

    return jsonb_build_object(
        'id', entry.id,
        'plate', entry.plate,
        'category_id', entry.category_id,
        'category_name', coalesce(category_name, ''),
        'status', entry.status,
        'position', position,
        'wait_until', entry.wait_until,
        'hold_minutes', entry.hold_minutes,
        'claim_minutes', coalesce(settings.waitlist_claim_minutes, 15),
        'offer_until', entry.offer_until,
        'reservation_id', entry.reservation_id,
        'notify_channel',
            case when coalesce(settings.whatsapp_auto, false)
                 then 'whatsapp' else 'screen' end,
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

revoke all on function public.public_waitlist_lookup(integer, bigint, text)
    from public;
grant execute on function public.public_waitlist_lookup(integer, bigint, text)
    to anon, authenticated;

-- Leaving a turn. Waiting entries become `left`; an offered entry is completed
-- by the dispatch section (it also releases the hold).
create or replace function public.public_leave_waitlist(
    p_lot_id integer,
    p_entry_id bigint,
    p_customer_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    phone_digits text := regexp_replace(coalesce(p_customer_phone, ''), '\D', '', 'g');
    phone_local text;
    entry public.reservation_waitlist%rowtype;
begin
    phone_local := case
        when length(phone_digits) = 12 and phone_digits like '57%'
            then right(phone_digits, 10)
        else phone_digits
    end;

    select * into entry
      from public.reservation_waitlist w
     where w.id = p_entry_id
       and w.lot_id = p_lot_id
       and w.customer_phone = phone_local
       for update;
    if not found or entry.status in ('claimed', 'expired', 'left', 'cancelled') then
        raise exception 'WaitlistEntryNotFoundError';
    end if;

    update public.reservation_waitlist
       set status = 'left'
     where id = entry.id;

    return jsonb_build_object('id', entry.id, 'status', 'left');
end;
$$;

revoke all on function public.public_leave_waitlist(integer, bigint, text)
    from public;
grant execute on function public.public_leave_waitlist(integer, bigint, text)
    to anon, authenticated;
