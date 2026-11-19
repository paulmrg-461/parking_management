-- Online payments (Wompi) — check-out, preview, public summary, shifts and
-- reports.
-- Invariant: amount_charged = online_paid_amount + desk_due (desk_due >= 0).
-- Inside the grace window the charge is exactly what the customer paid; after
-- it the desk collects the difference. `online` is set by the server only.
-- Same signatures as before (no overloads for PostgREST).

-- ---------------------------------------------------------------------------
-- check_out: applies the grace window, the desk due and the online method.
-- ---------------------------------------------------------------------------
create or replace function public.check_out(
    p_session_id integer,
    p_client_exit_time timestamp with time zone default null,
    p_idempotency_key text default null,
    p_payment_method text default 'cash',
    p_discount_amount integer default 0,
    p_discount_reason text default null,
    p_lost_ticket boolean default false,
    p_lost_ticket_reason text default null,
    p_lot_id integer default null,
    p_card_type text default null,
    p_cash_received integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor_id integer := public.require_app_user();
    lot_value integer := public.resolve_lot(p_lot_id);
    session public.parking_sessions%rowtype;
    vehicle public.vehicles%rowtype;
    exit_at timestamptz;
    gross integer;
    discount integer := greatest(coalesce(p_discount_amount, 0), 0);
    amount integer;
    has_pass boolean;
    lost boolean := coalesce(p_lost_ticket, false);
    lost_reason text;
    tz text;
    response jsonb;
    replay jsonb;
    method text := coalesce(nullif(btrim(p_payment_method), ''), 'cash');
    card_kind text := nullif(lower(btrim(coalesce(p_card_type, ''))), '');
    cash_in integer := nullif(p_cash_received, 0);
    cash_back integer;
    shift integer;
    paid integer;
    paid_at timestamptz;
    grace integer;
    desk_due integer;
    settle jsonb;
begin
    if method not in ('cash', 'card', 'transfer', 'monthly_pass', 'exempt') then
        raise exception 'InvalidPaymentMethod';
    end if;
    if method = 'card' then
        if card_kind is null or card_kind not in ('debit', 'credit') then
            raise exception 'InvalidCardTypeError';
        end if;
    else
        card_kind := null;
    end if;
    if coalesce(p_discount_amount, 0) < 0 then
        raise exception 'InvalidDiscountError';
    end if;
    if lost then
        lost_reason := nullif(btrim(coalesce(p_lost_ticket_reason, '')), '');
        if lost_reason is null then
            raise exception 'LostTicketReasonRequired';
        end if;
        -- A lost ticket ignores the pass, so it cannot be settled as one; the
        -- operator picks a real payment method and retries.
        if method = 'monthly_pass' then
            raise exception 'LostTicketPassMethodError';
        end if;
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
    if session.lot_id <> lot_value then
        raise exception 'LotRequiredError';
    end if;

    select * into vehicle from public.vehicles v where v.id = session.vehicle_id;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;

    -- Offline exits replay their confirmation time, but only within 12 h.
    if p_client_exit_time is not null
       and now() - p_client_exit_time > interval '12 hours' then
        raise exception 'StaleExitTimeError';
    end if;
    exit_at := coalesce(p_client_exit_time, now());
    if exit_at <= session.entry_time or exit_at > now() + interval '5 minutes' then
        raise exception 'InvalidExitTimeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota'),
           coalesce(online_payment_grace_minutes, 15)
      into tz, grace
      from public.parking_settings
     where lot_id = session.lot_id;
    tz := coalesce(tz, 'America/Bogota');
    grace := coalesce(grace, 15);

    select exists (
        select 1 from public.monthly_passes mp
         where mp.vehicle_id = vehicle.id
           and mp.lot_id = session.lot_id
           and mp.active
           and mp.start_date <= (exit_at at time zone tz)::date
           and mp.end_date >= (exit_at at time zone tz)::date
    ) into has_pass;

    -- A lost ticket ignores the pass: there is no ticket to prove the stay.
    if lost then
        has_pass := false;
        gross := public.lost_ticket_amount(session.id, exit_at);
    else
        gross := public.calculate_fare(vehicle.category_id, session.entry_time, exit_at, has_pass);
    end if;

    -- Online split: the customer may have paid before walking to the desk.
    paid := session.online_paid_amount;
    paid_at := session.online_paid_at;
    settle := public.online_settlement_amounts(gross, paid, paid_at, exit_at, grace);
    gross := (settle ->> 'charged')::integer;
    desk_due := (settle ->> 'desk_due')::integer;

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
        if paid > 0 then
            if discount > desk_due then
                raise exception 'InvalidDiscountError';
            end if;
        elsif discount > gross then
            raise exception 'InvalidDiscountError';
        end if;
    end if;

    amount := greatest(gross - discount, 0);
    desk_due := greatest(desk_due - discount, 0);

    -- The server owns the online method: the caller can never send it.
    if paid > 0 and desk_due = 0 then
        method := 'online';
        cash_in := null;
        card_kind := null;
        cash_back := null;
    end if;

    if method = 'cash' then
        if cash_in is not null and cash_in < desk_due then
            raise exception 'InvalidCashReceivedError';
        end if;
        cash_back := case when cash_in is null then null else cash_in - desk_due end;
    else
        cash_in := null;
        cash_back := null;
    end if;

    -- Only the actor's open shift takes the sale. FOR SHARE makes a
    -- concurrent close_shift (FOR UPDATE) wait for this commit; a replay that
    -- arrives after its shift closed lands in the current open shift, or in
    -- no shift at all.
    select s.id into shift
      from public.shifts s
     where s.operator_id = actor_id
       and s.lot_id = session.lot_id
       and s.closed_at is null
     order by s.opened_at desc
     limit 1
     for share;

    update public.parking_sessions
       set status = 'closed',
           exit_time = exit_at,
           closed_recorded_at = now(),
           amount_charged = amount,
           payment_method = method,
           card_type = card_kind,
           cash_received = cash_in,
           cash_change = cash_back,
           discount_amount = discount,
           discount_reason = case when discount > 0 then btrim(p_discount_reason) end,
           discount_by = case when discount > 0 then actor_id end,
           discount_at = case when discount > 0 then now() end,
           lost_ticket = lost,
           lost_ticket_reason = lost_reason,
           shift_id = shift,
           ticket_number = 'TCK-' ||
               (select code from public.parking_lots where id = session.lot_id) ||
               '-' || lpad(session.id::text, 6, '0')
     where id = session.id
     returning * into session;

    -- A pass holder paid online: the money is real, so the session is stored
    -- as online and an admin decides the refund.
    if paid > 0 and has_pass then
        insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
        select u.id,
               'online_payment_review',
               'Pago en línea por revisar',
               'La sesión de ' || vehicle.plate || ' tenía mensualidad y un pago en línea.',
               jsonb_build_object(
                   'session_id', session.id,
                   'plate', vehicle.plate,
                   'amount', paid
               ),
               'online_pass:' || session.id || ':user:' || u.id,
               session.lot_id
          from public.lot_members lm
          join public.users u on u.id = lm.user_id
         where lm.lot_id = session.lot_id
           and lm.role = 'admin'
           and u.is_active
        on conflict (dedupe_key) do nothing;
    end if;

    response := jsonb_build_object(
        'id', session.id,
        'plate', vehicle.plate,
        'entry_time', session.entry_time,
        'exit_time', session.exit_time,
        'amount_charged', session.amount_charged,
        'ticket_number', session.ticket_number,
        'payment_method', session.payment_method,
        'card_type', session.card_type,
        'cash_received', session.cash_received,
        'cash_change', session.cash_change,
        'lot_id', session.lot_id,
        'discount_amount', session.discount_amount,
        'discount_reason', session.discount_reason,
        'lost_ticket', session.lost_ticket,
        'lost_ticket_reason', session.lost_ticket_reason,
        'online_paid_amount', session.online_paid_amount
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, actor_id, 'rpc/check_out', 200, response);
    end if;

    return response;
end;
$$;

-- ---------------------------------------------------------------------------
-- check_out_preview: the same split, exposed to the dialog.
-- ---------------------------------------------------------------------------
create or replace function public.check_out_preview(p_session_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    session public.parking_sessions%rowtype;
    vehicle public.vehicles%rowtype;
    tz text;
    has_pass boolean;
    preview_at timestamptz := now();
    breakdown jsonb;
    grace integer;
    settle jsonb;
begin
    perform public.require_app_user();

    select * into session
      from public.parking_sessions s
     where s.id = p_session_id;
    if not found then
        raise exception 'SessionNotFoundError';
    end if;
    if session.status = 'closed' then
        raise exception 'SessionAlreadyClosedError';
    end if;
    if session.lot_id <> public.current_lot_id() then
        raise exception 'LotRequiredError';
    end if;

    select * into vehicle from public.vehicles v where v.id = session.vehicle_id;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;

    select coalesce(business_timezone, 'America/Bogota'),
           coalesce(online_payment_grace_minutes, 15)
      into tz, grace
      from public.parking_settings
     where lot_id = session.lot_id;
    tz := coalesce(tz, 'America/Bogota');
    grace := coalesce(grace, 15);

    select exists (
        select 1 from public.monthly_passes mp
         where mp.vehicle_id = vehicle.id
           and mp.lot_id = session.lot_id
           and mp.active
           and mp.start_date <= (preview_at at time zone tz)::date
           and mp.end_date >= (preview_at at time zone tz)::date
    ) into has_pass;

    breakdown := public.fare_breakdown(
        vehicle.category_id, session.entry_time, preview_at, has_pass
    );

    settle := public.online_settlement_amounts(
        (breakdown ->> 'amount')::integer,
        session.online_paid_amount,
        session.online_paid_at,
        preview_at,
        grace
    );

    return breakdown || jsonb_build_object(
        'session_id', session.id,
        'amount', (breakdown ->> 'amount')::integer,
        'has_pass', has_pass,
        'entry_time', session.entry_time,
        'previewed_at', preview_at,
        'lost_ticket_amount', public.lost_ticket_amount(session.id, preview_at),
        'online_paid_amount', session.online_paid_amount,
        'online_paid_at', session.online_paid_at,
        'grace_active', (settle ->> 'grace_active')::boolean,
        'grace_until', settle -> 'grace_until',
        'amount_due', (settle ->> 'desk_due')::integer
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- public_session_summary: the customer page sees the amount still due.
-- ---------------------------------------------------------------------------
create or replace function public.public_session_summary(
    p_session_id bigint,
    p_plate text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    row public.parking_sessions%rowtype;
    category_id integer;
    tz text;
    currency_code text;
    online_enabled boolean;
    online_min integer;
    grace integer;
    has_pass boolean;
    exit_at timestamptz;
    breakdown jsonb;
    amount integer;
    settle jsonb;
    amount_due integer;
begin
    if p_session_id is null or p_session_id <= 0 or length(normalized) < 3 then
        return null;
    end if;

    select s.* into row
      from public.parking_sessions s
     where s.id = p_session_id;
    if not found then
        return null;
    end if;

    select v.category_id into category_id
      from public.vehicles v
     where v.id = row.vehicle_id
       and upper(regexp_replace(v.plate, '\s', '', 'g')) = normalized;
    if not found then
        return null;
    end if;

    select coalesce(ps.business_timezone, 'America/Bogota'),
           coalesce(ps.currency, 'COP'),
           coalesce(ps.online_payments_enabled, false),
           coalesce(ps.online_payment_min_amount, 0),
           coalesce(ps.online_payment_grace_minutes, 15)
      into tz, currency_code, online_enabled, online_min, grace
      from public.parking_settings ps
     where ps.lot_id = row.lot_id;
    tz := coalesce(tz, 'America/Bogota');
    currency_code := coalesce(currency_code, 'COP');
    grace := coalesce(grace, 15);

    exit_at := coalesce(row.exit_time, now());
    has_pass := exists (
        select 1
          from public.monthly_passes mp
         where mp.vehicle_id = row.vehicle_id
           and mp.lot_id = row.lot_id
           and mp.active
           and mp.start_date <= (now() at time zone tz)::date
           and mp.end_date >= (now() at time zone tz)::date
    );

    breakdown := public.fare_breakdown(
        category_id,
        row.entry_time,
        exit_at,
        has_pass
    );

    amount := case
        when row.status = 'closed'
            then coalesce(row.amount_charged, (breakdown ->> 'amount')::int)
        else (breakdown ->> 'amount')::int
    end;

    settle := public.online_settlement_amounts(
        (breakdown ->> 'amount')::integer,
        row.online_paid_amount,
        row.online_paid_at,
        exit_at,
        grace
    );
    amount_due := case
        when row.status = 'closed' then 0
        else (settle ->> 'desk_due')::integer
    end;

    return jsonb_build_object(
        'session_id', row.id,
        'status', row.status,
        'entry_time', row.entry_time,
        'exit_time', row.exit_time,
        'duration_seconds', greatest(
            0,
            extract(epoch from (exit_at - row.entry_time))::int
        ),
        'currency', currency_code,
        'has_pass', has_pass,
        'amount', amount,
        'breakdown', breakdown,
        'online_payments_enabled', online_enabled,
        'online_paid_amount', row.online_paid_amount,
        'amount_due', amount_due,
        'grace_until', settle -> 'grace_until',
        'online_min_amount', online_min
    );
end;
$$;

revoke all on function public.public_session_summary(bigint, text) from public;
grant execute on function public.public_session_summary(bigint, text)
    to anon, authenticated;

-- ---------------------------------------------------------------------------
-- shift_totals: the desk part only; online money never enters expected_cash.
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
    online_sales bigint;
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
    if shift.lot_id <> public.current_lot_id() then
        raise exception 'LotRequiredError';
    end if;
    if shift.operator_id <> public.current_app_user_id()
       and not public.is_lot_admin(shift.lot_id) then
        raise exception 'AdminRequiredError';
    end if;

    select count(*),
           coalesce(sum(amount_charged), 0),
           coalesce(sum(amount_charged - online_paid_amount)
                    filter (where payment_method = 'cash'), 0),
           coalesce(sum(amount_charged - online_paid_amount)
                    filter (where payment_method = 'card'), 0),
           coalesce(sum(amount_charged - online_paid_amount)
                    filter (where payment_method = 'transfer'), 0),
           coalesce(sum(amount_charged) filter (where payment_method = 'monthly_pass'), 0),
           coalesce(sum(amount_charged - online_paid_amount)
                    filter (where payment_method = 'exempt'), 0),
           coalesce(sum(online_paid_amount), 0),
           coalesce(sum(discount_amount), 0)
      into session_count, revenue, cash_sales, card_sales, transfer_sales,
           pass_sales, exempt_sales, online_sales, discounts
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
        'online_sales', online_sales,
        'discounts', discounts,
        'pass_cash_sales', pass_cash_sales,
        'pass_payments', pass_payments,
        'withdrawals', withdrawals,
        'deposits', deposits
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- report_revenue: by_payment splits the online part from the desk part.
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
      from public.parking_settings where lot_id = public.current_lot_id();
    tz := coalesce(tz, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    select coalesce(sum(s.amount_charged), 0),
           coalesce(sum(s.discount_amount), 0),
           count(*) filter (where s.discount_amount > 0)
      into total, discounts, discounted_sessions
      from public.parking_sessions s
     where s.status = 'closed'
       and s.lot_id = public.current_lot_id()
       and s.exit_time >= window_start
       and s.exit_time < window_end;

    select coalesce(sum(p.amount), 0) into pass_revenue
      from public.monthly_pass_payments p
     where p.lot_id = public.current_lot_id()
       and p.status = 'paid'
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
       and s.lot_id = public.current_lot_id()
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
       and s.lot_id = public.current_lot_id()
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by c.id, c.name
      ) categories;

    select coalesce(jsonb_agg(item order by item ->> 'payment_method'), '[]'::jsonb)
      into by_payment
      from (
        select jsonb_build_object(
                   'payment_method', payment_method,
                   'amount', coalesce(sum(amount), 0)
               ) as item
          from (
            select coalesce(s.payment_method, 'unknown') as payment_method,
                   s.amount_charged - s.online_paid_amount as amount
              from public.parking_sessions s
             where s.status = 'closed'
               and s.lot_id = public.current_lot_id()
               and s.exit_time >= window_start
               and s.exit_time < window_end
            union all
            select 'online',
                   s.online_paid_amount
              from public.parking_sessions s
             where s.status = 'closed'
               and s.lot_id = public.current_lot_id()
               and s.exit_time >= window_start
               and s.exit_time < window_end
               and s.online_paid_amount > 0
          ) rows
         group by payment_method
      ) payments;

    select coalesce(jsonb_agg(item order by item ->> 'payment_method'), '[]'::jsonb)
      into pass_by_payment
      from (
        select jsonb_build_object(
                   'payment_method', p.payment_method,
                   'amount', coalesce(sum(p.amount), 0)
               ) as item
          from public.monthly_pass_payments p
         where p.lot_id = public.current_lot_id()
           and p.status = 'paid'
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
       and s.lot_id = public.current_lot_id()
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

-- ---------------------------------------------------------------------------
-- report_revenue_all: same split, cross-lot report (kept as before).
-- ---------------------------------------------------------------------------
create or replace function public.report_revenue_all(p_start_date date, p_end_date date)
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
      from public.parking_settings where lot_id = public.current_lot_id();
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
                   'payment_method', payment_method,
                   'amount', coalesce(sum(amount), 0)
               ) as item
          from (
            select coalesce(s.payment_method, 'unknown') as payment_method,
                   s.amount_charged - s.online_paid_amount as amount
              from public.parking_sessions s
             where s.status = 'closed'
               and s.exit_time >= window_start
               and s.exit_time < window_end
            union all
            select 'online',
                   s.online_paid_amount
              from public.parking_sessions s
             where s.status = 'closed'
               and s.exit_time >= window_start
               and s.exit_time < window_end
               and s.online_paid_amount > 0
          ) rows
         group by payment_method
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
        'by_lot', (
            select coalesce(jsonb_agg(item order by item ->> 'lot'), '[]'::jsonb)
              from (
                select jsonb_build_object(
                           'lot', l.name,
                           'lot_id', l.id,
                           'amount', coalesce(sum(s.amount_charged), 0),
                           'tickets', count(s.id),
                           'avg_ticket', case
                               when count(s.id) = 0 then 0
                               else (coalesce(sum(s.amount_charged), 0) / count(s.id))::integer
                           end
                       ) as item
                  from public.parking_lots l
                  left join public.parking_sessions s
                    on s.lot_id = l.id
                   and s.status = 'closed'
                   and s.exit_time >= window_start
                   and s.exit_time < window_end
                 group by l.id, l.name
              ) lots
        ),
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

grant execute on function public.report_revenue_all(date, date) to authenticated;

-- ---------------------------------------------------------------------------
-- open_sessions_view: the desk sees the paid amount and the deadline.
-- ---------------------------------------------------------------------------
create or replace view public.open_sessions_view
with (security_invoker = true) as
select s.id,
       s.vehicle_id,
       v.plate,
       s.entry_time,
       s.status,
       (select count(*) from public.evidence_photos p where p.session_id = s.id) as photo_count,
       exists (
           select 1 from public.monthly_passes mp
            where mp.vehicle_id = s.vehicle_id
              and mp.lot_id = s.lot_id
              and mp.active
              and mp.start_date <= (now() at time zone coalesce(tz.name, 'America/Bogota'))::date
              and mp.end_date >= (now() at time zone coalesce(tz.name, 'America/Bogota'))::date
       ) as has_pass,
       s.left_keys,
       s.online_paid_amount,
       (s.online_paid_at + make_interval(mins => coalesce(tz.grace, 15))) as online_grace_until
  from public.parking_sessions s
  join public.vehicles v on v.id = s.vehicle_id
  left join lateral (
      select ps.business_timezone as name,
             ps.online_payment_grace_minutes as grace
        from public.parking_settings ps
       where ps.lot_id = s.lot_id
  ) tz on true
 where s.status = 'open';

grant select on public.open_sessions_view to authenticated;
