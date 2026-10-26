-- Application schema, kept in sync with backend/app/infrastructure/models.py.
-- Supabase owns the schema now; FastAPI still reads/writes it during the
-- migration and Alembic is skipped when SCHEMA_MANAGED_EXTERNALLY=1.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Users (profile mirror of auth.users; see 0002 for the auth link)
-- ---------------------------------------------------------------------------
create table if not exists public.users (
    id          serial primary key,
    username    varchar(50)  not null unique,
    display_name varchar(100) not null,
    role        varchar(20)  not null,
    pin_hash    varchar(255),
    is_active   boolean      not null default true,
    created_at  timestamptz  not null default now(),
    updated_at  timestamptz  not null default now()
);

-- ---------------------------------------------------------------------------
-- Reference data
-- ---------------------------------------------------------------------------
create table if not exists public.categories (
    id         serial primary key,
    name       varchar(50) not null unique,
    created_at timestamptz not null default now()
);

create table if not exists public.tariffs (
    id          serial primary key,
    category_id integer     not null references public.categories(id),
    type        varchar(20) not null,
    amount      integer     not null,
    start_time  varchar(5),
    end_time    varchar(5),
    active      boolean     not null default true,
    created_at  timestamptz not null default now()
);
create index if not exists ix_tariffs_category_id on public.tariffs(category_id);

create table if not exists public.vehicles (
    id          serial primary key,
    plate       varchar(20) not null unique,
    category_id integer     not null references public.categories(id),
    color       varchar(30),
    brand       varchar(50),
    created_by  integer     references public.users(id) on delete set null,
    created_at  timestamptz not null default now()
);
create index if not exists ix_vehicles_category_id on public.vehicles(category_id);

-- ---------------------------------------------------------------------------
-- Parking sessions + evidence
-- ---------------------------------------------------------------------------
create table if not exists public.parking_sessions (
    id             serial primary key,
    vehicle_id     integer     not null references public.vehicles(id),
    operator_id    integer     not null references public.users(id),
    entry_time     timestamptz not null default now(),
    status         varchar(10) not null default 'open',
    exit_time      timestamptz,
    amount_charged integer,
    ticket_number  varchar(20),
    created_at     timestamptz not null default now()
);
create index if not exists ix_parking_sessions_vehicle_id on public.parking_sessions(vehicle_id);
create index if not exists ix_parking_sessions_operator_id on public.parking_sessions(operator_id);
create unique index if not exists uq_open_session_per_vehicle
    on public.parking_sessions(vehicle_id)
    where status = 'open';
create index if not exists ix_sessions_open_entry
    on public.parking_sessions(entry_time)
    where status = 'open';
create index if not exists ix_sessions_status_exit
    on public.parking_sessions(status, exit_time);
create unique index if not exists uq_sessions_ticket
    on public.parking_sessions(ticket_number)
    where ticket_number is not null;

create table if not exists public.evidence_photos (
    id         serial primary key,
    session_id integer      not null references public.parking_sessions(id),
    file_path  varchar(255) not null,
    taken_at   timestamptz  not null default now()
);
create index if not exists ix_evidence_photos_session_id on public.evidence_photos(session_id);

-- ---------------------------------------------------------------------------
-- Monthly passes
-- ---------------------------------------------------------------------------
create table if not exists public.monthly_passes (
    id         serial primary key,
    vehicle_id integer     not null references public.vehicles(id),
    start_date date        not null,
    end_date   date        not null,
    amount     integer     not null,
    active     boolean     not null default true,
    created_at timestamptz not null default now()
);
create index if not exists ix_monthly_passes_vehicle_id on public.monthly_passes(vehicle_id);

-- ---------------------------------------------------------------------------
-- Settings singleton
-- ---------------------------------------------------------------------------
create table if not exists public.parking_settings (
    id           integer      primary key,
    name         varchar(80)  not null default 'Parqueadero',
    address      varchar(160) not null default '',
    schedule     varchar(120) not null default '',
    phone        varchar(32)  not null default '',
    website      varchar(200) not null default '',
    whatsapp     varchar(32)  not null default '',
    logo_version integer      not null default 0,
    logo_path    varchar(255),
    updated_at   timestamptz  not null default now()
);

insert into public.parking_settings (id) values (1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Idempotency store (FastAPI writes it for offline replays)
-- ---------------------------------------------------------------------------
create table if not exists public.idempotency_keys (
    key           varchar(100) primary key,
    user_id       integer      not null references public.users(id) on delete cascade,
    endpoint      varchar(200) not null,
    status_code   integer      not null,
    response_body text         not null,
    created_at    timestamptz  not null
);
create index if not exists ix_idempotency_keys_created_at
    on public.idempotency_keys(created_at);
