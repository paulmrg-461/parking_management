-- Monthly-pass charges: every new pass creates a pending payment that an
-- admin marks as paid (cash/card/transfer). Auto-renewed passes go through the
-- same flow, so no renewal is silently treated as collected revenue.

alter table public.monthly_passes
    add column if not exists auto_renew_payment_method text not null default 'cash';
alter table public.monthly_passes
    drop constraint if exists monthly_passes_auto_renew_method_check;
alter table public.monthly_passes
    add constraint monthly_passes_auto_renew_method_check
    check (auto_renew_payment_method in ('cash', 'card', 'transfer'));

create table if not exists public.monthly_pass_payments (
    id               bigserial primary key,
    monthly_pass_id  bigint      not null unique references public.monthly_passes(id) on delete cascade,
    amount           integer     not null check (amount > 0),
    payment_method   text        not null default 'cash'
        check (payment_method in ('cash', 'card', 'transfer')),
    status           text        not null default 'pending'
        check (status in ('pending', 'paid', 'waived')),
    due_date         date        not null,
    paid_at          timestamptz,
    paid_by          integer     references public.users(id),
    shift_id         bigint      references public.shifts(id),
    created_at       timestamptz not null default now()
);
create index if not exists ix_pass_payments_status
    on public.monthly_pass_payments(status, due_date);
create index if not exists ix_pass_payments_shift
    on public.monthly_pass_payments(shift_id) where status = 'paid';

alter table public.monthly_pass_payments enable row level security;
grant select on public.monthly_pass_payments to authenticated;

drop policy if exists pass_payments_admin_read on public.monthly_pass_payments;
create policy pass_payments_admin_read on public.monthly_pass_payments
    for select to authenticated using (public.is_admin());

-- Every pass (manual or renewed) gets exactly one pending charge.
create or replace function public.create_pass_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.monthly_pass_payments (
        monthly_pass_id, amount, payment_method, due_date
    )
    values (
        new.id, new.amount, new.auto_renew_payment_method, new.start_date
    )
    on conflict (monthly_pass_id) do nothing;
    return new;
end;
$$;

drop trigger if exists trg_create_pass_payment on public.monthly_passes;
create trigger trg_create_pass_payment
    after insert on public.monthly_passes
    for each row execute function public.create_pass_payment();

-- ---------------------------------------------------------------------------
-- Pending charges + collection
-- ---------------------------------------------------------------------------
create or replace function public.pending_pass_payments()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    result jsonb;
begin
    perform public.require_admin();
    select coalesce(jsonb_agg(item order by item ->> 'due_date'), '[]'::jsonb)
      into result
      from (
        select jsonb_build_object(
                   'id', p.id,
                   'monthly_pass_id', p.monthly_pass_id,
                   'vehicle_id', mp.vehicle_id,
                   'plate', v.plate,
                   'start_date', mp.start_date,
                   'end_date', mp.end_date,
                   'amount', p.amount,
                   'payment_method', p.payment_method,
                   'status', p.status,
                   'due_date', p.due_date
               ) as item
          from public.monthly_pass_payments p
          join public.monthly_passes mp on mp.id = p.monthly_pass_id
          join public.vehicles v on v.id = mp.vehicle_id
         where p.status = 'pending'
         order by p.due_date
      ) rows;
    return result;
end;
$$;

create or replace function public.register_pass_payment(
    p_payment_id bigint,
    p_payment_method text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_admin();
    payment public.monthly_pass_payments%rowtype;
    method text;
    shift integer;
    vehicle_plate text;
begin
    select * into payment
      from public.monthly_pass_payments p
     where p.id = p_payment_id
     for update;
    if not found then
        raise exception 'PaymentNotFoundError';
    end if;
    if payment.status <> 'pending' then
        raise exception 'PaymentAlreadyProcessedError';
    end if;

    method := coalesce(nullif(btrim(p_payment_method), ''), payment.payment_method);
    if method not in ('cash', 'card', 'transfer') then
        raise exception 'InvalidPaymentMethod';
    end if;

    if method = 'cash' then
        select s.id into shift
          from public.shifts s
         where s.operator_id = actor and s.closed_at is null
         order by s.opened_at desc
         limit 1;
        if shift is null then
            raise exception 'NoOpenShiftError';
        end if;
    end if;

    update public.monthly_pass_payments
       set status = 'paid',
           payment_method = method,
           paid_at = now(),
           paid_by = actor,
           shift_id = shift
     where id = payment.id
     returning * into payment;

    select v.plate into vehicle_plate
      from public.monthly_passes mp
      join public.vehicles v on v.id = mp.vehicle_id
     where mp.id = payment.monthly_pass_id;

    return jsonb_build_object(
        'id', payment.id,
        'monthly_pass_id', payment.monthly_pass_id,
        'plate', vehicle_plate,
        'amount', payment.amount,
        'payment_method', payment.payment_method,
        'status', payment.status,
        'paid_at', payment.paid_at
    );
end;
$$;

grant execute on function public.pending_pass_payments() to authenticated;
grant execute on function public.register_pass_payment(bigint, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Shift totals include collected pass charges (cash feeds the drawer).
-- ---------------------------------------------------------------------------
create or replace function public.shift_totals(p_shift_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    shift public.shifts%rowtype;
    session_count bigint;
    revenue bigint;
    cash_sales bigint;
    card_sales bigint;
    transfer_sales bigint;
    pass_sales bigint;
    exempt_sales bigint;
    discounts bigint;
    pass_cash_sales bigint;
    pass_payments bigint;
    withdrawals bigint;
    deposits bigint;
    expected integer;
begin
    select * into shift from public.shifts s where s.id = p_shift_id;
    if not found then
        raise exception 'ShiftNotFoundError';
    end if;
    if shift.operator_id <> public.current_app_user_id()
       and public.current_app_role() is distinct from 'admin' then
        raise exception 'AdminRequiredError';
    end if;

    select count(*),
           coalesce(sum(amount_charged), 0),
           coalesce(sum(amount_charged) filter (where payment_method = 'cash'), 0),
           coalesce(sum(amount_charged) filter (where payment_method = 'card'), 0),
           coalesce(sum(amount_charged) filter (where payment_method = 'transfer'), 0),
           coalesce(sum(amount_charged) filter (where payment_method = 'monthly_pass'), 0),
           coalesce(sum(amount_charged) filter (where payment_method = 'exempt'), 0),
           coalesce(sum(discount_amount), 0)
      into session_count, revenue, cash_sales, card_sales, transfer_sales,
           pass_sales, exempt_sales, discounts
      from public.parking_sessions s
     where s.shift_id = p_shift_id and s.status = 'closed';

    select coalesce(sum(amount) filter (where payment_method = 'cash'), 0),
           coalesce(sum(amount), 0)
      into pass_cash_sales, pass_payments
      from public.monthly_pass_payments p
     where p.shift_id = p_shift_id and p.status = 'paid';

    select coalesce(sum(amount) filter (where type = 'withdrawal'), 0),
           coalesce(sum(amount) filter (where type = 'deposit'), 0)
      into withdrawals, deposits
      from public.cash_movements m
     where m.shift_id = p_shift_id;

    expected := shift.opening_float + cash_sales + pass_cash_sales + deposits - withdrawals;

    return jsonb_build_object(
        'id', shift.id,
        'operator_id', shift.operator_id,
        'opened_at', shift.opened_at,
        'closed_at', shift.closed_at,
        'opening_float', shift.opening_float,
        'counted_cash', shift.counted_cash,
        'expected_cash', expected,
        'difference', shift.difference,
        'notes', shift.notes,
        'session_count', session_count,
        'revenue', revenue,
        'cash_sales', cash_sales,
        'card_sales', card_sales,
        'transfer_sales', transfer_sales,
        'pass_sales', pass_sales,
        'exempt_sales', exempt_sales,
        'discounts', discounts,
        'pass_cash_sales', pass_cash_sales,
        'pass_payments', pass_payments,
        'withdrawals', withdrawals,
        'deposits', deposits
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- Reports: pass collections are reported separately from parking stays.
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
    pass_revenue bigint;
    by_day jsonb;
    by_category jsonb;
    by_payment jsonb;
    pass_by_payment jsonb;
    audit jsonb;
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

    select coalesce(sum(p.amount), 0) into pass_revenue
      from public.monthly_pass_payments p
     where p.status = 'paid'
       and p.paid_at >= window_start
       and p.paid_at < window_end;

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

    select coalesce(jsonb_agg(item order by item ->> 'payment_method'), '[]'::jsonb)
      into pass_by_payment
      from (
        select jsonb_build_object(
                   'payment_method', p.payment_method,
                   'amount', coalesce(sum(p.amount), 0)
               ) as item
          from public.monthly_pass_payments p
         where p.status = 'paid'
           and p.paid_at >= window_start
           and p.paid_at < window_end
         group by p.payment_method
      ) pass_payments;

    select coalesce(jsonb_agg(item order by item ->> 'discount_at' desc), '[]'::jsonb)
      into audit
      from (
        select jsonb_build_object(
                   'session_id', s.id,
                   'plate', v.plate,
                   'ticket_number', s.ticket_number,
                   'amount_charged', s.amount_charged,
                   'discount_amount', s.discount_amount,
                   'discount_reason', s.discount_reason,
                   'discount_at', s.discount_at,
                   'admin', u.username
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.users u on u.id = s.discount_by
         where s.status = 'closed'
           and s.discount_amount > 0
           and s.exit_time >= window_start
           and s.exit_time < window_end
         order by s.discount_at desc
         limit 50
      ) discounts_log;

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'total', total,
        'pass_revenue', pass_revenue,
        'total_discounts', discounts,
        'discounted_sessions', discounted_sessions,
        'by_day', by_day,
        'by_category', by_category,
        'by_payment', by_payment,
        'pass_by_payment', pass_by_payment,
        'discount_audit', audit
    );
end;
$$;

grant execute on function public.report_revenue(date, date) to authenticated;
