-- Operator shifts and cash reconciliation ("arqueo").
--
-- A shift belongs to one operator and stays open until they count the cash.
-- Check-outs attach to the shift open at the exit time (see check_out), so an
-- offline replay lands in the shift where the operator actually acted.

alter table public.shifts enable row level security;
alter table public.cash_movements enable row level security;

grant select on public.shifts, public.cash_movements to authenticated;

drop policy if exists shifts_read_own_or_admin on public.shifts;
create policy shifts_read_own_or_admin on public.shifts
    for select to authenticated
    using (operator_id = public.current_app_user_id() or public.is_admin());

drop policy if exists cash_movements_read_own_or_admin on public.cash_movements;
create policy cash_movements_read_own_or_admin on public.cash_movements
    for select to authenticated
    using (
        exists (
            select 1 from public.shifts s
             where s.id = shift_id
               and (s.operator_id = public.current_app_user_id() or public.is_admin())
        )
    );

-- ---------------------------------------------------------------------------
-- Shift summary
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

    select coalesce(sum(amount) filter (where type = 'withdrawal'), 0),
           coalesce(sum(amount) filter (where type = 'deposit'), 0)
      into withdrawals, deposits
      from public.cash_movements m
     where m.shift_id = p_shift_id;

    expected := shift.opening_float + cash_sales + deposits - withdrawals;

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
        'withdrawals', withdrawals,
        'deposits', deposits
    );
end;
$$;

grant execute on function public.shift_totals(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
create or replace function public.open_shift(p_opening_float integer default 0)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
    shift_id bigint;
begin
    if coalesce(p_opening_float, 0) < 0 then
        raise exception 'InvalidOpeningFloatError';
    end if;
    begin
        insert into public.shifts (operator_id, opening_float)
        values (uid, coalesce(p_opening_float, 0))
        returning id into shift_id;
    exception when unique_violation then
        raise exception 'ShiftAlreadyOpenError';
    end;
    return public.shift_totals(shift_id);
end;
$$;

create or replace function public.current_shift()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    shift_id bigint;
begin
    select s.id into shift_id
      from public.shifts s
     where s.operator_id = public.current_app_user_id()
       and s.closed_at is null
     order by s.opened_at desc
     limit 1;
    if shift_id is null then
        return null;
    end if;
    return public.shift_totals(shift_id);
end;
$$;

create or replace function public.close_shift(
    p_counted_cash integer default 0,
    p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
    shift public.shifts%rowtype;
    totals jsonb;
    expected integer;
    counted integer := coalesce(p_counted_cash, 0);
begin
    if counted < 0 then
        raise exception 'InvalidCountedCashError';
    end if;

    select * into shift
      from public.shifts s
     where s.operator_id = uid and s.closed_at is null
     order by s.opened_at desc
     limit 1
     for update;
    if not found then
        raise exception 'NoOpenShiftError';
    end if;

    totals := public.shift_totals(shift.id);
    expected := (totals ->> 'expected_cash')::integer;

    update public.shifts
       set closed_at = now(),
           counted_cash = counted,
           expected_cash = expected,
           difference = counted - expected,
           notes = nullif(btrim(coalesce(p_notes, '')), '')
     where id = shift.id;

    insert into public.notifications (user_id, type, title, body, data, dedupe_key)
    select u.id,
           'shift_closed',
           'Turno cerrado',
           'Diferencia de caja: $' || (counted - expected),
           jsonb_build_object(
               'shift_id', shift.id,
               'counted_cash', counted,
               'expected_cash', expected,
               'difference', counted - expected
           ),
           'shift_close:' || shift.id || ':user:' || u.id
      from public.users u
     where u.role = 'admin' and u.is_active
    on conflict (dedupe_key) do nothing;

    return public.shift_totals(shift.id);
end;
$$;

create or replace function public.add_cash_movement(
    p_type text,
    p_amount integer,
    p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
    shift_id bigint;
begin
    if p_type not in ('withdrawal', 'deposit', 'adjustment') then
        raise exception 'InvalidCashMovementType';
    end if;
    if coalesce(p_amount, 0) <= 0 then
        raise exception 'InvalidCashMovementAmount';
    end if;
    if p_reason is null or length(btrim(p_reason)) = 0 then
        raise exception 'CashMovementReasonRequired';
    end if;

    select s.id into shift_id
      from public.shifts s
     where s.operator_id = uid and s.closed_at is null
     order by s.opened_at desc
     limit 1;
    if shift_id is null then
        raise exception 'NoOpenShiftError';
    end if;

    insert into public.cash_movements (shift_id, type, amount, reason, created_by)
    values (shift_id, p_type, p_amount, btrim(p_reason), uid);

    return public.shift_totals(shift_id);
end;
$$;

create or replace function public.list_shifts(p_limit integer default 20)
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
    select coalesce(jsonb_agg(item order by item ->> 'opened_at' desc), '[]'::jsonb)
      into result
      from (
        select public.shift_totals(s.id) as item
          from (
            select id from public.shifts order by opened_at desc limit greatest(p_limit, 1)
          ) s
      ) rows;
    return result;
end;
$$;

grant execute on function public.open_shift(integer) to authenticated;
grant execute on function public.current_shift() to authenticated;
grant execute on function public.close_shift(integer, text) to authenticated;
grant execute on function public.add_cash_movement(text, integer, text) to authenticated;
grant execute on function public.list_shifts(integer) to authenticated;
