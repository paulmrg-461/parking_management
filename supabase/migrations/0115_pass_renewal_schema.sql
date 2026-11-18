-- Monthly pass auto-renewal — schema half.
--   1. Per-lot switches: reminders (`pass_renewal_enabled`), payment links
--      (`pass_renewal_payment_links`, COP + online payments only) and the
--      reminder cadence as a validated text ('7,3,1').
--   2. `pass_renewal_offers` holds the planned next period and amount; the pass
--      is created only when the payment is approved (an early pass would let
--      the customer park free).
--   3. `whatsapp_messages` gains a dedupe key and the URL-button parameter.
--   4. Online money can be a pass payment (`online` is a stored method).
--   5. `payment_intents` can target a pass offer (`kind = 'pass'`).
-- All flags default off: existing lots behave exactly as today.

alter table public.parking_settings
    add column if not exists pass_renewal_enabled boolean not null default false,
    add column if not exists pass_renewal_payment_links boolean not null default false,
    add column if not exists pass_renewal_cadence text not null default '7,3,1';

alter table public.parking_settings
    drop constraint if exists parking_settings_pass_renewal_check;
alter table public.parking_settings
    add constraint parking_settings_pass_renewal_check check (
        pass_renewal_cadence ~ '^([0-9]|[12][0-9]|30)(,([0-9]|[12][0-9]|30)){0,4}$'
        and (not pass_renewal_payment_links
             or (online_payments_enabled and currency = 'COP'))
    );

alter table public.whatsapp_messages
    add column if not exists button_param text,
    add column if not exists dedupe_key text;
create unique index if not exists uq_whatsapp_dedupe
    on public.whatsapp_messages(dedupe_key) where dedupe_key is not null;

alter table public.monthly_pass_payments
    drop constraint if exists monthly_pass_payments_payment_method_check;
alter table public.monthly_pass_payments
    add constraint monthly_pass_payments_payment_method_check
    check (payment_method in ('cash','card','transfer','online'));

create table if not exists public.pass_renewal_offers (
    id                 bigserial primary key,
    lot_id             integer     not null references public.parking_lots(id),
    monthly_pass_id    bigint      not null references public.monthly_passes(id) on delete cascade,
    token              text        not null unique,
    period_start       date        not null,
    period_end         date        not null,
    amount             integer     not null check (amount > 0),
    status             text        not null default 'open'
        check (status in ('open','paid','expired','cancelled')),
    expires_at         timestamptz not null,
    reminders_sent     integer     not null default 0,
    last_reminder_at   timestamptz,
    paid_at            timestamptz,
    renewal_pass_id    bigint      references public.monthly_passes(id),
    created_at         timestamptz not null default now(),
    check (period_end > period_start)
);
create unique index if not exists uq_pass_renewal_open
    on public.pass_renewal_offers(monthly_pass_id) where status = 'open';
create index if not exists ix_pass_renewal_lot
    on public.pass_renewal_offers(lot_id, created_at desc);

alter table public.pass_renewal_offers enable row level security;
grant select on public.pass_renewal_offers to authenticated;
drop policy if exists pass_renewal_offers_admin_read on public.pass_renewal_offers;
create policy pass_renewal_offers_admin_read on public.pass_renewal_offers
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

-- Widen the intents table created by add-online-payments.
alter table public.payment_intents
    add column if not exists pass_renewal_offer_id bigint
        references public.pass_renewal_offers(id);
alter table public.payment_intents drop constraint if exists payment_intents_kind_check;
alter table public.payment_intents add constraint payment_intents_kind_check
    check (kind in ('session','pass'));
alter table public.payment_intents drop constraint if exists payment_intents_target_check;
alter table public.payment_intents add constraint payment_intents_target_check check (
    (kind = 'session' and session_id is not null and pass_renewal_offer_id is null)
    or (kind = 'pass' and pass_renewal_offer_id is not null and session_id is null)
);
