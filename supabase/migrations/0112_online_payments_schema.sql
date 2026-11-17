-- Online payments (Wompi) — schema half.
--   1. Per-lot opt-in (COP only) with the grace window and the minimum amount.
--   2. `online` becomes a stored payment method; the server sets it, the
--      caller can never send it (check_out keeps its allow-list).
--   3. `payment_intents` freezes the amount the gateway will charge and
--      `payment_events` is the idempotent webhook log (service role only).
--   4. `online_settlement_amounts` is the pure grace-window rule shared by
--      `check_out`, the preview and the public summary.
-- Existing lots stay inert: `online_payments_enabled` defaults to false.

alter table public.parking_settings
    add column if not exists online_payments_enabled boolean not null default false,
    add column if not exists online_payment_grace_minutes integer not null default 15,
    add column if not exists online_payment_min_amount integer not null default 1500;

alter table public.parking_settings
    drop constraint if exists parking_settings_online_payment_check;
alter table public.parking_settings
    add constraint parking_settings_online_payment_check check (
        online_payment_grace_minutes between 5 and 120
        and online_payment_min_amount between 0 and 100000000
        and (not online_payments_enabled or currency = 'COP')
    );

alter table public.parking_sessions
    add column if not exists online_paid_amount integer not null default 0
        check (online_paid_amount >= 0),
    add column if not exists online_paid_at timestamptz;

alter table public.parking_sessions
    drop constraint if exists parking_sessions_payment_method_check;
alter table public.parking_sessions
    add constraint parking_sessions_payment_method_check check (
        payment_method is null
        or payment_method in ('cash','card','transfer','monthly_pass','exempt','online')
    );

create table if not exists public.payment_intents (
    id                     bigserial primary key,
    lot_id                 integer     not null references public.parking_lots(id),
    kind                   text        not null default 'session' check (kind in ('session')),
    session_id             integer     references public.parking_sessions(id),
    reference              text        not null unique,
    amount                 integer     not null check (amount > 0),
    currency               text        not null default 'COP' check (currency = 'COP'),
    gateway                text        not null default 'wompi',
    status                 text        not null default 'pending'
        check (status in ('pending','approved','declined','voided','error','expired')),
    gateway_transaction_id text,
    gateway_method         text,
    expires_at             timestamptz not null,
    approved_at            timestamptz,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now(),
    constraint payment_intents_target_check check (kind <> 'session' or session_id is not null)
);
create index if not exists ix_payment_intents_lot on public.payment_intents(lot_id, created_at desc);
create index if not exists ix_payment_intents_session on public.payment_intents(session_id, created_at desc);
create index if not exists ix_payment_intents_pending on public.payment_intents(created_at) where status = 'pending';
create unique index if not exists uq_payment_intents_transaction
    on public.payment_intents(gateway, gateway_transaction_id) where gateway_transaction_id is not null;

create table if not exists public.payment_events (
    id                     bigserial primary key,
    gateway                text        not null,
    gateway_transaction_id text        not null,
    gateway_status         text        not null,
    intent_id              bigint      references public.payment_intents(id) on delete set null,
    reference              text,
    amount                 integer,
    outcome                text        not null
        check (outcome in ('applied','ignored','unknown_reference','mismatch','late_closed')),
    payload                jsonb       not null default '{}'::jsonb,
    created_at             timestamptz not null default now(),
    unique (gateway, gateway_transaction_id, gateway_status)
);
create index if not exists ix_payment_events_intent on public.payment_events(intent_id);

alter table public.payment_intents enable row level security;
alter table public.payment_events enable row level security;
grant select on public.payment_intents to authenticated;
drop policy if exists payment_intents_admin_read on public.payment_intents;
create policy payment_intents_admin_read on public.payment_intents
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));
-- payment_events: RLS on, no policy, no grant: only the service role and
-- security definer functions read or write it.

-- Grace window rule (pure). Inside the window the charge is exactly what the
-- customer paid; outside it the charge is the greater of the fare and the
-- payment, and the desk collects the difference.
create or replace function public.online_settlement_amounts(
    p_gross integer, p_paid integer, p_paid_at timestamptz,
    p_exit timestamptz, p_grace_minutes integer
) returns jsonb language sql immutable set search_path = public as $$
    select jsonb_build_object(
        'grace_until', case when p_paid > 0 and p_paid_at is not null
                            then p_paid_at + make_interval(mins => p_grace_minutes) end,
        'grace_active', p_paid > 0 and p_paid_at is not null
                        and p_exit <= p_paid_at + make_interval(mins => p_grace_minutes),
        'charged', case
            when p_paid > 0 and p_paid_at is not null
                 and p_exit <= p_paid_at + make_interval(mins => p_grace_minutes) then p_paid
            else greatest(p_gross, p_paid) end,
        'desk_due', case
            when p_paid > 0 and p_paid_at is not null
                 and p_exit <= p_paid_at + make_interval(mins => p_grace_minutes) then 0
            else greatest(p_gross, p_paid) - p_paid end
    );
$$;
revoke all on function public.online_settlement_amounts(integer, integer, timestamptz, timestamptz, integer)
    from public, anon, authenticated;
