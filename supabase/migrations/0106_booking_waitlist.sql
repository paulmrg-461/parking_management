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
