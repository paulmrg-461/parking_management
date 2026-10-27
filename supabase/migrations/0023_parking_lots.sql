-- Multiple parking lots. Everything that belongs to a site gains a `lot_id`;
-- existing data is attached to a seeded `default` lot so the upgrade is
-- transparent and reversible (the columns are additive for old clients).

create table if not exists public.parking_lots (
    id         serial      primary key,
    code       varchar(10) not null unique,
    name       varchar(80) not null,
    address    varchar(160) not null default '',
    timezone   varchar(64) not null default 'America/Bogota',
    active     boolean     not null default true,
    created_at timestamptz not null default now()
);

insert into public.parking_lots (id, code, name)
values (1, 'DEF', 'Parqueadero')
on conflict (id) do nothing;

select setval(
    pg_get_serial_sequence('public.parking_lots', 'id'),
    greatest((select coalesce(max(id), 1) from public.parking_lots), 1)
);

alter table public.parking_lots enable row level security;
grant select on public.parking_lots to authenticated;

drop policy if exists lots_read on public.parking_lots;
create policy lots_read on public.parking_lots
    for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- Membership: a user can work at several sites with a role per site. The
-- platform role stays in `public.users.role` (who may create lots).
-- ---------------------------------------------------------------------------
create table if not exists public.lot_members (
    user_id    integer     not null references public.users(id) on delete cascade,
    lot_id     integer     not null references public.parking_lots(id) on delete cascade,
    role       varchar(20) not null default 'operator'
               check (role in ('operator', 'admin')),
    created_at timestamptz not null default now(),
    primary key (user_id, lot_id)
);
create index if not exists ix_lot_members_lot on public.lot_members(lot_id);

alter table public.lot_members enable row level security;
grant select on public.lot_members to authenticated;

drop policy if exists lot_members_read_own_or_admin on public.lot_members;
create policy lot_members_read_own_or_admin on public.lot_members
    for select to authenticated
    using (user_id = public.current_app_user_id() or public.is_admin());

-- Every existing user joins the default lot with their current role.
insert into public.lot_members (user_id, lot_id, role)
select u.id, 1, u.role from public.users u
on conflict (user_id, lot_id) do nothing;

-- New profiles (auth trigger) join the default lot automatically.
create or replace function public.add_default_lot_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.lot_members (user_id, lot_id, role)
    values (new.id, 1, new.role)
    on conflict (user_id, lot_id) do nothing;
    return new;
end;
$$;

drop trigger if exists trg_add_default_lot_member on public.users;
create trigger trg_add_default_lot_member
    after insert on public.users
    for each row execute function public.add_default_lot_member();

-- ---------------------------------------------------------------------------
-- Lot dimension on every site-scoped table. `default 1` backfills existing
-- rows in one statement.
-- ---------------------------------------------------------------------------
alter table public.categories
    add column if not exists lot_id integer not null default 1
    references public.parking_lots(id);
alter table public.tariffs
    add column if not exists lot_id integer not null default 1
    references public.parking_lots(id);
alter table public.parking_sessions
    add column if not exists lot_id integer not null default 1
    references public.parking_lots(id);
alter table public.shifts
    add column if not exists lot_id integer not null default 1
    references public.parking_lots(id);
alter table public.monthly_passes
    add column if not exists lot_id integer not null default 1
    references public.parking_lots(id);
alter table public.monthly_pass_payments
    add column if not exists lot_id integer not null default 1
    references public.parking_lots(id);
alter table public.category_reservations
    add column if not exists lot_id integer not null default 1
    references public.parking_lots(id);
alter table public.parking_settings
    add column if not exists lot_id integer not null default 1
    references public.parking_lots(id);
alter table public.notifications
    add column if not exists lot_id integer references public.parking_lots(id);

create index if not exists ix_categories_lot on public.categories(lot_id);
create index if not exists ix_tariffs_lot on public.tariffs(lot_id);
create index if not exists ix_sessions_lot on public.parking_sessions(lot_id, status);
create index if not exists ix_shifts_lot on public.shifts(lot_id, opened_at desc);
create index if not exists ix_passes_lot on public.monthly_passes(lot_id);
create index if not exists ix_pass_payments_lot on public.monthly_pass_payments(lot_id);
create index if not exists ix_reservations_lot on public.category_reservations(lot_id);
create index if not exists ix_notifications_lot on public.notifications(lot_id);

-- Two lots may both have a "car" category, and each operator opens one shift
-- per site.
alter table public.categories drop constraint if exists categories_name_key;
drop index if exists uq_open_shift_per_operator;
create unique index if not exists uq_open_shift_per_operator_lot
    on public.shifts(operator_id, lot_id) where closed_at is null;

-- The settings row used to be the literal singleton id = 1; each lot now owns
-- one row, so the id needs a sequence.
do $$
begin
    if not exists (
        select 1 from pg_attribute
         where attrelid = 'public.parking_settings'::regclass
           and attname = 'id'
           and attidentity <> ''
    ) then
        alter table public.parking_settings
            alter column id add generated by default as identity;
    end if;
end $$;

select setval(
    pg_get_serial_sequence('public.parking_settings', 'id'),
    greatest((select coalesce(max(id), 1) from public.parking_settings), 1)
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
         where conname = 'categories_lot_name_key'
           and conrelid = 'public.categories'::regclass
    ) then
        alter table public.categories
            add constraint categories_lot_name_key unique (lot_id, name);
    end if;
    if not exists (
        select 1 from pg_constraint
         where conname = 'parking_settings_lot_key'
           and conrelid = 'public.parking_settings'::regclass
    ) then
        alter table public.parking_settings
            add constraint parking_settings_lot_key unique (lot_id);
    end if;
end $$;

-- A pass payment inherits the lot of its pass, including rows created by the
-- existing trigger after this migration.
update public.monthly_pass_payments p
   set lot_id = mp.lot_id
  from public.monthly_passes mp
 where mp.id = p.monthly_pass_id
   and p.lot_id <> mp.lot_id;

create or replace function public.create_pass_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.monthly_pass_payments (
        monthly_pass_id, amount, payment_method, due_date, lot_id
    )
    values (
        new.id,
        new.amount,
        coalesce(new.auto_renew_payment_method, 'cash'),
        new.start_date,
        new.lot_id
    )
    on conflict (monthly_pass_id) do nothing;
    return new;
end;
$$;
