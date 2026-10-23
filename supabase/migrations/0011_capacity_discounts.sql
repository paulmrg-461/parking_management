-- Capacity per category (with a full-lot guard) and audited admin discounts.

alter table public.categories
    add column if not exists capacity integer not null default 0;
alter table public.categories
    drop constraint if exists categories_capacity_check;
alter table public.categories
    add constraint categories_capacity_check check (capacity >= 0);

alter table public.parking_sessions
    add column if not exists discount_amount integer not null default 0;
alter table public.parking_sessions
    add column if not exists discount_reason text;
alter table public.parking_sessions
    add column if not exists discount_by integer references public.users(id);
alter table public.parking_sessions
    add column if not exists discount_at timestamptz;

alter table public.parking_sessions
    drop constraint if exists parking_sessions_discount_check;
alter table public.parking_sessions
    add constraint parking_sessions_discount_check
    check (discount_amount >= 0);

-- Shift/cash tables are created here because check-out references them; the
-- shift RPCs live in 0012.
create table if not exists public.shifts (
    id            bigserial primary key,
    operator_id   integer     not null references public.users(id),
    opened_at     timestamptz not null default now(),
    closed_at     timestamptz,
    opening_float integer     not null default 0,
    counted_cash  integer,
    expected_cash integer,
    difference    integer,
    notes         text,
    created_at    timestamptz not null default now()
);
create unique index if not exists uq_open_shift_per_operator
    on public.shifts(operator_id) where closed_at is null;
create index if not exists ix_shifts_opened on public.shifts(opened_at desc);

create table if not exists public.cash_movements (
    id         bigserial primary key,
    shift_id   bigint      not null references public.shifts(id) on delete cascade,
    type       text        not null check (type in ('withdrawal', 'deposit', 'adjustment')),
    amount     integer     not null check (amount > 0),
    reason     text        not null,
    created_by integer     references public.users(id),
    created_at timestamptz not null default now()
);
create index if not exists ix_cash_movements_shift on public.cash_movements(shift_id);

alter table public.parking_sessions
    add column if not exists shift_id bigint references public.shifts(id);
create index if not exists ix_parking_sessions_shift on public.parking_sessions(shift_id);

-- ---------------------------------------------------------------------------
-- Capacity guard: serialized per category so two concurrent check-ins cannot
-- exceed the configured capacity.
-- ---------------------------------------------------------------------------
create or replace function public.enforce_category_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    category integer;
    capacity integer;
    open_count integer;
begin
    select v.category_id into category from public.vehicles v where v.id = new.vehicle_id;
    if category is null then
        return new;
    end if;
    perform pg_advisory_xact_lock(hashtext('category:' || category));
    select c.capacity into capacity from public.categories c where c.id = category;
    if coalesce(capacity, 0) > 0 then
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where v.category_id = category
           and s.status = 'open';
        if open_count >= capacity then
            raise exception 'CategoryFullError';
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_enforce_category_capacity on public.parking_sessions;
create trigger trg_enforce_category_capacity
    before insert on public.parking_sessions
    for each row execute function public.enforce_category_capacity();

-- ---------------------------------------------------------------------------
-- Occupancy snapshot (any signed-in user) includes capacity/full flags.
-- ---------------------------------------------------------------------------
create or replace function public.occupancy_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    total bigint;
    total_capacity bigint;
    by_category jsonb;
begin
    perform public.require_app_user();

    select count(*) into total
      from public.parking_sessions s where s.status = 'open';

    select coalesce(sum(c.capacity), 0) into total_capacity
      from public.categories c where c.capacity > 0;

    select coalesce(jsonb_agg(item order by item ->> 'category_name'), '[]'::jsonb)
      into by_category
      from (
        select jsonb_build_object(
                   'category_id', c.id,
                   'category_name', c.name,
                   'count', count(s.id),
                   'capacity', c.capacity,
                   'is_full', (c.capacity > 0 and count(s.id) >= c.capacity)
               ) as item
          from public.categories c
          left join public.vehicles v on v.category_id = c.id
          left join public.parking_sessions s
            on s.vehicle_id = v.id and s.status = 'open'
         group by c.id, c.name, c.capacity
      ) categories;

    return jsonb_build_object(
        'total_open', total,
        'total_capacity', total_capacity,
        'by_category', by_category
    );
end;
$$;

grant execute on function public.occupancy_snapshot() to authenticated;

create or replace function public.report_occupancy()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    perform public.require_admin();
    return public.occupancy_snapshot();
end;
$$;

grant execute on function public.report_occupancy() to authenticated;

-- ---------------------------------------------------------------------------
-- Check-out with an audited discount (admin-only).
-- ---------------------------------------------------------------------------
drop function if exists public.check_out(integer, timestamptz, text, text);
drop function if exists public.check_out(integer, timestamptz, text, text, integer, text);

create function public.check_out(
    p_session_id integer,
    p_client_exit_time timestamptz default null,
    p_idempotency_key text default null,
    p_payment_method text default 'cash',
    p_discount_amount integer default 0,
    p_discount_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor_id integer := public.require_app_user();
    session public.parking_sessions%rowtype;
    vehicle public.vehicles%rowtype;
    exit_at timestamptz;
    gross integer;
    discount integer := greatest(coalesce(p_discount_amount, 0), 0);
    amount integer;
    has_pass boolean;
    tz text;
    response jsonb;
    replay jsonb;
    method text := coalesce(nullif(btrim(p_payment_method), ''), 'cash');
    shift integer;
begin
    if method not in ('cash', 'card', 'transfer', 'monthly_pass', 'exempt') then
        raise exception 'InvalidPaymentMethod';
    end if;
    if coalesce(p_discount_amount, 0) < 0 then
        raise exception 'InvalidDiscountError';
    end if;

    if p_idempotency_key is not null then
        replay := public.replay_idempotent(p_idempotency_key, actor_id, 'rpc/check_out');
        if replay is not null then
            return replay;
        end if;
    end if;

    select * into session
      from public.parking_sessions s
     where s.id = p_session_id
     for update;
    if not found then
        raise exception 'SessionNotFoundError';
    end if;
    if session.status = 'closed' then
        raise exception 'SessionAlreadyClosedError';
    end if;

    select * into vehicle from public.vehicles v where v.id = session.vehicle_id;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;

    exit_at := coalesce(p_client_exit_time, now());
    if exit_at <= session.entry_time or exit_at > now() + interval '5 minutes' then
        raise exception 'InvalidExitTimeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where id = 1;
    tz := coalesce(tz, 'America/Bogota');

    select exists (
        select 1 from public.monthly_passes mp
         where mp.vehicle_id = vehicle.id
           and mp.active
           and mp.start_date <= (exit_at at time zone tz)::date
           and mp.end_date >= (exit_at at time zone tz)::date
    ) into has_pass;

    gross := public.calculate_fare(vehicle.category_id, session.entry_time, exit_at, has_pass);
    if has_pass then
        method := 'monthly_pass';
        discount := 0;
    end if;

    if discount > 0 then
        if public.current_app_role() is distinct from 'admin' then
            raise exception 'AdminRequiredError';
        end if;
        if p_discount_reason is null or length(btrim(p_discount_reason)) = 0 then
            raise exception 'DiscountReasonRequiredError';
        end if;
        if discount > gross then
            raise exception 'InvalidDiscountError';
        end if;
    end if;

    amount := greatest(gross - discount, 0);

    select s.id into shift
      from public.shifts s
     where s.operator_id = actor_id
       and s.opened_at <= exit_at
       and (s.closed_at is null or s.closed_at >= exit_at)
     order by s.opened_at desc
     limit 1;

    update public.parking_sessions
       set status = 'closed',
           exit_time = exit_at,
           amount_charged = amount,
           payment_method = method,
           discount_amount = discount,
           discount_reason = case when discount > 0 then btrim(p_discount_reason) end,
           discount_by = case when discount > 0 then actor_id end,
           discount_at = case when discount > 0 then now() end,
           shift_id = shift,
           ticket_number = 'TCK-' || lpad(session.id::text, 6, '0')
     where id = session.id
     returning * into session;

    response := jsonb_build_object(
        'id', session.id,
        'plate', vehicle.plate,
        'entry_time', session.entry_time,
        'exit_time', session.exit_time,
        'amount_charged', session.amount_charged,
        'ticket_number', session.ticket_number,
        'payment_method', session.payment_method,
        'discount_amount', session.discount_amount,
        'discount_reason', session.discount_reason
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, actor_id, 'rpc/check_out', 200, response);
    end if;

    return response;
end;
$$;

grant execute on function public.check_out(integer, timestamptz, text, text, integer, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Revenue report: discounts are visible to admins.
-- ---------------------------------------------------------------------------
create or replace function public.report_revenue(p_start_date date, p_end_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    tz text;
    window_start timestamptz;
    window_end timestamptz;
    total bigint;
    discounts bigint;
    discounted_sessions bigint;
    by_day jsonb;
    by_category jsonb;
    by_payment jsonb;
begin
    perform public.require_admin();
    if p_start_date > p_end_date then
        raise exception 'InvalidReportRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where id = 1;
    tz := coalesce(tz, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    select coalesce(sum(s.amount_charged), 0),
           coalesce(sum(s.discount_amount), 0),
           count(*) filter (where s.discount_amount > 0)
      into total, discounts, discounted_sessions
      from public.parking_sessions s
     where s.status = 'closed'
       and s.exit_time >= window_start
       and s.exit_time < window_end;

    select coalesce(jsonb_agg(item order by item ->> 'date'), '[]'::jsonb) into by_day
      from (
        select jsonb_build_object(
                   'date', to_char(exit_time at time zone tz, 'YYYY-MM-DD'),
                   'amount', coalesce(sum(amount_charged), 0)
               ) as item
          from public.parking_sessions s
         where s.status = 'closed'
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by to_char(exit_time at time zone tz, 'YYYY-MM-DD')
      ) days;

    select coalesce(jsonb_agg(item order by item ->> 'category_name'), '[]'::jsonb)
      into by_category
      from (
        select jsonb_build_object(
                   'category_id', c.id,
                   'category_name', c.name,
                   'amount', coalesce(sum(s.amount_charged), 0)
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.status = 'closed'
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by c.id, c.name
      ) categories;

    select coalesce(jsonb_agg(item order by item ->> 'payment_method'), '[]'::jsonb)
      into by_payment
      from (
        select jsonb_build_object(
                   'payment_method', coalesce(payment_method, 'unknown'),
                   'amount', coalesce(sum(amount_charged), 0)
               ) as item
          from public.parking_sessions s
         where s.status = 'closed'
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by coalesce(payment_method, 'unknown')
      ) payments;

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'total', total,
        'total_discounts', discounts,
        'discounted_sessions', discounted_sessions,
        'by_day', by_day,
        'by_category', by_category,
        'by_payment', by_payment
    );
end;
$$;

grant execute on function public.report_revenue(date, date) to authenticated;
