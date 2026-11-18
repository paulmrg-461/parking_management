-- Merchant agreements ("convenios") — schema half.
--   1. `merchants`: one benefit rule per merchant, lot-scoped, audited.
--   2. `merchant_credentials`: token + PIN hashes, RLS with no policy and no
--      grant (only the security definer functions read them).
--   3. `merchant_validations`: one row per (merchant, session); the benefit is
--      applied at check-out and the terms are snapshotted.
--   4. `parking_sessions.gross_amount` / `fare_adjustments`: the fare before
--      benefits and the ordered automatic lines.
--   5. `parking_settings.merchant_max_per_session`.
-- pgcrypto lives in `public` on a scratch database and in `extensions` on the
-- hosted image, so the functions that hash set `search_path = public,
-- extensions` (never a prefix in SQL text).

alter table public.parking_sessions
    add column if not exists gross_amount integer,
    add column if not exists fare_adjustments jsonb not null default '[]'::jsonb;
alter table public.parking_sessions drop constraint if exists parking_sessions_gross_amount_check;
alter table public.parking_sessions add constraint parking_sessions_gross_amount_check
    check (gross_amount is null or gross_amount >= 0);
alter table public.parking_sessions drop constraint if exists parking_sessions_fare_adjustments_check;
alter table public.parking_sessions add constraint parking_sessions_fare_adjustments_check
    check (jsonb_typeof(fare_adjustments) = 'array');

alter table public.parking_settings
    add column if not exists merchant_max_per_session integer not null default 1;
alter table public.parking_settings drop constraint if exists parking_settings_merchant_max_check;
alter table public.parking_settings add constraint parking_settings_merchant_max_check
    check (merchant_max_per_session between 0 and 5);

create table if not exists public.merchants (
    id                  serial       primary key,
    lot_id              integer      not null references public.parking_lots(id),
    name                varchar(120) not null check (length(btrim(name)) between 2 and 120),
    benefit_kind        text         not null
                        check (benefit_kind in ('free_minutes', 'percentage', 'fixed_amount')),
    benefit_value       integer      not null,
    max_amount          integer      check (max_amount is null or max_amount > 0),
    billing_mode        text         not null default 'merchant_paid'
                        check (billing_mode in ('merchant_paid', 'courtesy')),
    daily_cap           integer      check (daily_cap is null or daily_cap between 1 and 10000),
    monthly_cap         integer      check (monthly_cap is null or monthly_cap between 1 and 100000),
    active              boolean      not null default true,
    credentials_version integer      not null default 1,
    created_at          timestamptz  not null default now(),
    updated_at          timestamptz  not null default now(),
    constraint merchants_lot_name_key unique (lot_id, name),
    constraint merchants_id_lot_key unique (id, lot_id),
    constraint merchants_benefit_check check (
        (benefit_kind = 'free_minutes' and benefit_value between 1 and 1440)
     or (benefit_kind = 'percentage'   and benefit_value between 1 and 100)
     or (benefit_kind = 'fixed_amount' and benefit_value >= 1))
);

create table if not exists public.merchant_credentials (
    merchant_id      integer     primary key references public.merchants(id) on delete cascade,
    token_hash       text        not null unique,
    pin_hash         text        not null,
    pin_failures     integer     not null default 0 check (pin_failures between 0 and 5),
    locked_until     timestamptz,
    token_rotated_at timestamptz not null default now(),
    pin_set_at       timestamptz not null default now(),
    last_used_at     timestamptz
);

create table if not exists public.merchant_validations (
    id            bigserial   primary key,
    lot_id        integer     not null references public.parking_lots(id),
    merchant_id   integer     not null,
    session_id    integer     not null references public.parking_sessions(id) on delete cascade,
    source        text        not null check (source in ('public', 'desk')),
    created_by    integer     references public.users(id),
    status        text        not null default 'pending'
                  check (status in ('pending', 'applied', 'revoked', 'forfeited')),
    terms         jsonb       not null,
    amount        integer     not null default 0 check (amount >= 0),
    created_at    timestamptz not null default now(),
    applied_at    timestamptz,
    revoked_by    integer     references public.users(id),
    revoked_at    timestamptz,
    revoke_reason varchar(200),
    constraint merchant_validations_merchant_lot_fkey
        foreign key (merchant_id, lot_id) references public.merchants (id, lot_id),
    constraint merchant_validations_state_check check (
        (status = 'pending'  and applied_at is null and revoked_at is null)
     or (status in ('applied', 'forfeited') and applied_at is not null)
     or (status = 'revoked'  and revoked_at is not null and revoke_reason is not null)),
    constraint merchant_validations_actor_check check ((source = 'desk') = (created_by is not null))
);
create unique index if not exists uq_merchant_validation_active
    on public.merchant_validations (merchant_id, session_id) where status <> 'revoked';
create index if not exists ix_merchant_validations_lot_created
    on public.merchant_validations (lot_id, created_at);
create index if not exists ix_merchant_validations_merchant_created
    on public.merchant_validations (merchant_id, created_at);
create index if not exists ix_merchant_validations_pending
    on public.merchant_validations (session_id) where status = 'pending';

alter table public.merchants enable row level security;
alter table public.merchant_credentials enable row level security;  -- no policy, no grant
alter table public.merchant_validations enable row level security;
revoke all on public.merchants, public.merchant_credentials, public.merchant_validations
    from anon, authenticated;
grant select on public.merchants, public.merchant_validations to authenticated;

drop policy if exists merchants_read on public.merchants;
create policy merchants_read on public.merchants
    for select to authenticated using (lot_id = public.current_lot_id());
drop policy if exists merchant_validations_read on public.merchant_validations;
create policy merchant_validations_read on public.merchant_validations
    for select to authenticated using (lot_id = public.current_lot_id());

drop trigger if exists trg_audit_row on public.merchants;
create trigger trg_audit_row after insert or update or delete on public.merchants
    for each row execute function public.record_audit();
drop trigger if exists trg_audit_row on public.merchant_validations;
create trigger trg_audit_row after insert or update or delete on public.merchant_validations
    for each row execute function public.record_audit();
