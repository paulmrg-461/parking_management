-- Shift, capacity, pass renewal and evidence integrity fixes (audit 2026-11):
--   4. create_reservation takes the same advisory locks as check_in, in the
--      same order (group via category_group(name) first, then category).
--   5. renew_monthly_passes uses each lot's business date, renews only passes
--      that already ended (end_date < local today) and keeps calendar-month
--      periods (no 30/31-day drift).
--   6. add_cash_movement / register_pass_payment lock the open shift
--      FOR SHARE, so close_shift (FOR UPDATE) waits and counts them.
--   9. shift_totals authorizes lot admins (is_lot_admin), not only platform
--      admins, so list_shifts works for them.
--  10. check_in evidence paths must be objects the caller uploaded to the
--      `evidence` bucket and not referenced by another evidence row.
--  11. unique index on evidence_photos(file_path).
--  12. close_shift / notify_session_event format amounts in the lot currency.

-- ---------------------------------------------------------------------------
-- 12. Money formatting (mirrors the Flutter `Money.format`).
-- ---------------------------------------------------------------------------
-- COP: `$5.000` (no decimals, `.` grouping). USD: `US$1,234.50` (cents).
create or replace function public.format_money(p_amount bigint, p_currency text)
returns text
language sql
immutable
set search_path = public
as $$
    select case when p_amount < 0 then '-' else '' end ||
           case
               when upper(coalesce(p_currency, 'COP')) = 'USD' then
                   'US$' || to_char(abs(p_amount) / 100, 'FM999,999,999,999,990') ||
                   '.' || lpad((abs(p_amount) % 100)::text, 2, '0')
               else
                   '$' || replace(to_char(abs(p_amount), 'FM999,999,999,999,990'), ',', '.')
           end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Cash movements only in the open shift, locked against a close.
-- ---------------------------------------------------------------------------
create or replace function public.add_cash_movement(p_type text, p_amount integer, p_reason text)
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
     where s.operator_id = uid
       and s.lot_id = public.current_lot_id()
       and s.closed_at is null
     order by s.opened_at desc
     limit 1
     for share;
    if shift_id is null then
        raise exception 'NoOpenShiftError';
    end if;

    insert into public.cash_movements (shift_id, type, amount, reason, created_by)
    values (shift_id, p_type, p_amount, btrim(p_reason), uid);

    return public.shift_totals(shift_id);
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
    if payment.lot_id <> public.current_lot_id() then
        raise exception 'LotRequiredError';
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
         where s.operator_id = actor
           and s.lot_id = public.current_lot_id()
           and s.closed_at is null
         order by s.opened_at desc
         limit 1
         for share;
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

-- ---------------------------------------------------------------------------
-- 9. shift_totals: own shift, or an admin of the shift's lot.
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
    if shift.lot_id <> public.current_lot_id() then
        raise exception 'LotRequiredError';
    end if;
    if shift.operator_id <> public.current_app_user_id()
       and not public.is_lot_admin(shift.lot_id) then
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
-- 6, 12. close_shift: totals after the FOR UPDATE lock; currency-aware text.
-- ---------------------------------------------------------------------------
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
    currency_code text;
begin
    if counted < 0 then
        raise exception 'InvalidCountedCashError';
    end if;

    -- FOR UPDATE waits for in-flight check-outs / movements / pass payments
    -- (they hold FOR SHARE); the totals below run in a later statement and
    -- therefore see their committed rows.
    select * into shift
      from public.shifts s
     where s.operator_id = uid
       and s.lot_id = public.current_lot_id()
       and s.closed_at is null
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

    select ps.currency into currency_code
      from public.parking_settings ps
     where ps.lot_id = shift.lot_id;

    insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
    select u.id,
           'shift_closed',
           'Turno cerrado',
           'Diferencia de caja: ' || public.format_money(counted - expected, currency_code),
           jsonb_build_object(
               'shift_id', shift.id,
               'counted_cash', counted,
               'expected_cash', expected,
               'difference', counted - expected
           ),
           'shift_close:' || shift.id || ':user:' || u.id,
           shift.lot_id
      from public.users u
     where u.role = 'admin' and u.is_active
       and exists (
           select 1 from public.lot_members lm
            where lm.user_id = u.id and lm.lot_id = shift.lot_id
       )
    on conflict (dedupe_key) do nothing;

    return public.shift_totals(shift.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 12. Activity notifications: currency-aware amount.
-- ---------------------------------------------------------------------------
create or replace function public.notify_session_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    plate_value text;
    tz text;
    currency_code text;
    amount_value integer;
    actor_id integer;
    actor_name text;
    actor_role text;
    event_type text;
    event_title text;
    event_body text;
    event_data jsonb;
begin
    select coalesce(ps.business_timezone, 'America/Bogota'), ps.currency
      into tz, currency_code
      from public.parking_settings ps
     where ps.lot_id = new.lot_id;
    tz := coalesce(tz, 'America/Bogota');

    select v.plate into plate_value
      from public.vehicles v
     where v.id = new.vehicle_id;

    if tg_op = 'INSERT' and new.status = 'open' then
        actor_id := new.operator_id;
        event_type := 'check_in';
        event_title := 'Entrada registrada';
        event_data := jsonb_build_object(
            'action', 'check_in',
            'session_id', new.id,
            'plate', plate_value,
            'entry_time', new.entry_time
        );
    elsif tg_op = 'UPDATE' and new.status = 'closed' and old.status = 'open' then
        -- The trigger runs inside the check-out transaction, so the actor is
        -- still the signed-in user (the row only stores the entry operator).
        actor_id := public.current_app_user_id();
        amount_value := coalesce(new.amount_charged, 0);
        event_type := 'check_out';
        event_title := 'Salida registrada';
        event_data := jsonb_build_object(
            'action', 'check_out',
            'session_id', new.id,
            'plate', plate_value,
            'amount_charged', amount_value,
            'ticket_number', new.ticket_number,
            'payment_method', new.payment_method,
            'exit_time', new.exit_time
        );
    else
        return new;
    end if;

    select u.display_name,
           case when u.role = 'admin' then 'Administrador' else 'Operador' end
      into actor_name, actor_role
      from public.users u
     where u.id = actor_id;

    event_data := event_data || jsonb_build_object(
        'actor_id', actor_id,
        'actor_name', actor_name,
        'actor_role', actor_role
    );

    if event_type = 'check_in' then
        event_body := coalesce(actor_name, 'Un usuario') || ' (' ||
            coalesce(actor_role, 'Operador') || ') registró el ingreso de ' ||
            coalesce(plate_value, 'un vehículo') || ' · ' ||
            to_char(new.entry_time at time zone tz, 'HH24:MI');
    else
        event_body := coalesce(actor_name, 'Un usuario') || ' (' ||
            coalesce(actor_role, 'Operador') || ') registró la salida de ' ||
            coalesce(plate_value, 'un vehículo') || ' · Cobro: ' ||
            public.format_money(amount_value, currency_code);
    end if;

    insert into public.notifications (
        user_id, type, title, body, data, dedupe_key, lot_id
    )
    select u.id,
           event_type,
           event_title,
           event_body,
           event_data,
           event_type || ':' || new.id || ':user:' || u.id,
           new.lot_id
      from public.lot_members lm
      join public.users u on u.id = lm.user_id
     where lm.lot_id = new.lot_id
       and u.is_active
    on conflict (dedupe_key) do nothing;

    return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. create_reservation: check_in's lock keys and order.
-- ---------------------------------------------------------------------------
create or replace function public.create_reservation(
    p_plate text,
    p_category_id integer,
    p_until timestamp with time zone,
    p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    capacity integer;
    open_count integer;
    reserved_count integer;
    category_name text;
    car_capacity integer := 0;
    moto_capacity integer := 0;
    car_out integer := 0;
    moto_out integer := 0;
    spots_total integer := 0;
    spots_active integer := 0;
    spot_group text;
    group_configured boolean := false;
    group_capacity integer := 0;
    is_car boolean;
    is_moto boolean;
    reservation public.category_reservations%rowtype;
begin
    if normalized = '' then
        raise exception 'InvalidPlateError';
    end if;
    if p_category_id is null then
        raise exception 'CategoryNotFoundError';
    end if;
    if p_until is null or p_until <= now() then
        raise exception 'InvalidReservationWindowError';
    end if;

    select lower(c.name) into category_name
      from public.categories c
     where c.id = p_category_id
       and c.lot_id = lot;
    if not found then
        raise exception 'CategoryNotFoundError';
    end if;
    spot_group := public.category_group(category_name);

    -- Same keys and order as check_in → enforce_category_capacity:
    -- group first, then category (no ABBA deadlock, no oversell).
    perform pg_advisory_xact_lock(hashtext('group:' || lot || ':' || spot_group));
    perform pg_advisory_xact_lock(hashtext('category:' || p_category_id));

    select c.capacity into capacity
      from public.categories c
     where c.id = p_category_id;

    if exists (
        select 1 from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where v.plate = normalized and s.status = 'open'
    ) then
        raise exception 'VehicleAlreadyInsideError';
    end if;

    if coalesce(capacity, 0) > 0 then
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where v.category_id = p_category_id
           and s.status = 'open'
           and s.lot_id = lot;
        select count(*) into reserved_count
          from public.category_reservations r
         where r.category_id = p_category_id
           and r.lot_id = lot
           and r.status = 'active'
           and r.reserved_until > now();
        if open_count + reserved_count >= capacity then
            raise exception 'CategoryFullError';
        end if;
    end if;

    is_car := category_name in ('car', 'carro', 'auto', 'camioneta', 'suv');
    is_moto := category_name in ('moto', 'motos', 'motorcycle');
    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.car_out_of_service, 0),
           coalesce(ps.moto_out_of_service, 0)
      into car_capacity, moto_capacity, car_out, moto_out
      from public.parking_settings ps
     where ps.lot_id = lot;

    select count(*), count(*) filter (where status = 'active')
      into spots_total, spots_active
      from public.parking_spots sp
     where sp.lot_id = lot
       and sp.group_name = spot_group;

    if spots_total > 0 then
        group_configured := true;
        group_capacity := spots_active;
    else
        group_configured := case
            when is_car then car_capacity > 0
            when is_moto then moto_capacity > 0
            else false
        end;
        group_capacity := case
            when is_car then public.usable_capacity(car_capacity, car_out)
            when is_moto then public.usable_capacity(moto_capacity, moto_out)
            else 0
        end;
    end if;

    if group_configured then
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.status = 'open'
           and s.lot_id = lot
           and public.category_group(c.name) = spot_group;
        select count(*) into reserved_count
          from public.category_reservations r
          join public.categories c on c.id = r.category_id
         where r.lot_id = lot
           and r.status = 'active'
           and r.reserved_until > now()
           and public.category_group(c.name) = spot_group;
        if open_count + reserved_count >= group_capacity then
            raise exception 'ParkingFullError';
        end if;
    end if;

    insert into public.category_reservations (
        plate, category_id, reserved_until, notes, created_by, lot_id
    )
    values (
        normalized, p_category_id, p_until,
        nullif(btrim(coalesce(p_notes, '')), ''), actor, lot
    )
    returning * into reservation;

    return jsonb_build_object(
        'id', reservation.id,
        'plate', reservation.plate,
        'category_id', reservation.category_id,
        'reserved_from', reservation.reserved_from,
        'reserved_until', reservation.reserved_until,
        'status', reservation.status,
        'lot_id', reservation.lot_id,
        'notes', reservation.notes
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Pass renewal: lot business date, calendar months.
-- ---------------------------------------------------------------------------
-- Whole calendar months a pass covers (start + n months - 1 day = end), or
-- null when the period is not month-shaped (then the day count is kept).
create or replace function public.pass_period_months(p_start date, p_end date)
returns integer
language sql
immutable
set search_path = public
as $$
    select n
      from generate_series(1, 24) as n
     where (p_start + make_interval(months => n))::date - 1 = p_end
     order by n
     limit 1;
$$;

create or replace function public.renew_monthly_passes()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    create temp table if not exists renewed_passes (
        id bigint,
        vehicle_id integer,
        start_date date,
        end_date date,
        amount integer,
        renewed_from_id bigint,
        lot_id integer
    ) on commit drop;

    truncate renewed_passes;

    -- A pass renews the day after its last valid day in the lot's timezone,
    -- so it stays active (and free at check-out) through its end date.
    with candidates as (
        select mp.*,
               (mp.end_date - mp.start_date + 1) as duration_days,
               public.pass_period_months(mp.start_date, mp.end_date) as period_months
          from public.monthly_passes mp
          left join public.parking_settings ps on ps.lot_id = mp.lot_id
         where mp.active
           and mp.auto_renew
           and mp.end_date < (now() at time zone coalesce(ps.business_timezone, 'America/Bogota'))::date
           and not exists (
               select 1 from public.monthly_passes child
                where child.renewed_from_id = mp.id
           )
    ),
    inserted as (
        insert into public.monthly_passes (
            vehicle_id, start_date, end_date, amount, active, auto_renew,
            renewed_from_id, lot_id
        )
        select c.vehicle_id,
               c.end_date + 1,
               case
                   when c.period_months is not null then
                       (c.end_date + 1 + make_interval(months => c.period_months))::date - 1
                   else c.end_date + c.duration_days
               end,
               c.amount,
               true,
               c.auto_renew,
               c.id,
               c.lot_id
          from candidates c
        on conflict (renewed_from_id) do nothing
        returning id, vehicle_id, start_date, end_date, amount, renewed_from_id, lot_id
    )
    insert into renewed_passes (
        id, vehicle_id, start_date, end_date, amount, renewed_from_id, lot_id
    )
    select id, vehicle_id, start_date, end_date, amount, renewed_from_id, lot_id
      from inserted;

    select count(*) into changed from renewed_passes;

    -- Only the passes renewed above (all already past their end date).
    update public.monthly_passes mp
       set active = false
     where mp.id in (select renewed_from_id from renewed_passes);

    insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
    select u.id,
           'monthly_pass_renewed',
           'Mensualidad renovada',
           'Vehículo ' || v.plate || ': ' ||
               to_char(rp.start_date, 'DD/MM/YYYY') || ' - ' ||
               to_char(rp.end_date, 'DD/MM/YYYY'),
           jsonb_build_object(
               'monthly_pass_id', rp.id,
               'vehicle_id', rp.vehicle_id,
               'plate', v.plate,
               'start_date', rp.start_date,
               'end_date', rp.end_date,
               'amount', rp.amount
           ),
           'pass_renew:' || rp.renewed_from_id || ':' || rp.id || ':user:' || u.id,
           rp.lot_id
      from renewed_passes rp
      join public.vehicles v on v.id = rp.vehicle_id
      join public.users u on u.role = 'admin' and u.is_active
     where exists (
         select 1 from public.lot_members lm
          where lm.user_id = u.id and lm.lot_id = rp.lot_id
     )
    on conflict (dedupe_key) do nothing;

    return changed;
end;
$$;

-- ---------------------------------------------------------------------------
-- 10, 11. Evidence paths.
-- ---------------------------------------------------------------------------
-- One evidence row per stored object (live data had no duplicates).
create unique index if not exists uq_evidence_photos_file_path
    on public.evidence_photos (file_path);

-- The path must be an object the caller uploaded to the evidence bucket and
-- must not already back another evidence row.
create or replace function public.require_evidence_object(p_path text)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    if p_path is null or not exists (
        select 1 from storage.objects o
         where o.bucket_id = 'evidence'
           and o.name = p_path
           and o.owner = auth.uid()
    ) then
        raise exception 'EvidenceNotFoundError';
    end if;
    if exists (select 1 from public.evidence_photos p where p.file_path = p_path) then
        raise exception 'EvidenceAlreadyUsedError';
    end if;
end;
$$;

revoke all on function public.require_evidence_object(text) from public;
revoke all on function public.require_evidence_object(text) from anon, authenticated;

-- check_in: every evidence path must pass require_evidence_object (10).
create or replace function public.check_in(p_plate text, p_category_id integer DEFAULT NULL::integer, p_color text DEFAULT NULL::text, p_brand text DEFAULT NULL::text, p_photos jsonb DEFAULT '[]'::jsonb, p_idempotency_key text DEFAULT NULL::text, p_client_entry_time timestamp with time zone DEFAULT NULL::timestamp with time zone, p_lot_id integer DEFAULT NULL::integer, p_left_keys boolean DEFAULT false, p_spot_id integer DEFAULT NULL::integer, p_videos jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
declare
    operator_id integer := public.require_app_user();
    lot_value integer := public.resolve_lot(p_lot_id);
    normalized_plate text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    vehicle public.vehicles%rowtype;
    session public.parking_sessions%rowtype;
    entry_at timestamptz;
    response jsonb;
    replay jsonb;
    photo jsonb;
    photo_count integer := 0;
    video jsonb;
    video_count integer := 0;
    category_name text;
    spot_group text;
    spot public.parking_spots%rowtype;
    chosen_spot integer;
    spots_total integer := 0;
begin
    if normalized_plate = '' then
        raise exception 'VehicleNotFoundError';
    end if;

    if p_idempotency_key is not null then
        replay := public.replay_idempotent(p_idempotency_key, operator_id, 'rpc/check_in');
        if replay is not null then
            return replay;
        end if;
    end if;

    if p_client_entry_time is not null and p_client_entry_time > now() + interval '5 minutes' then
        raise exception 'InvalidEntryTimeError';
    end if;
    entry_at := coalesce(p_client_entry_time, now());

    select * into vehicle from public.vehicles v where v.plate = normalized_plate;
    if not found then
        if p_category_id is null then
            raise exception 'VehicleNotRegisteredError';
        end if;
        if not exists (
            select 1 from public.categories c
             where c.id = p_category_id
               and c.lot_id = lot_value
        ) then
            raise exception 'CategoryNotFoundError';
        end if;
        insert into public.vehicles (plate, category_id, color, brand, created_by)
        values (normalized_plate, p_category_id, p_color, p_brand, operator_id)
        on conflict (plate) do update set plate = excluded.plate
        returning * into vehicle;
    end if;

    if not exists (
        select 1 from public.categories c
         where c.id = vehicle.category_id
           and c.lot_id = lot_value
    ) then
        if p_category_id is not null and exists (
            select 1 from public.categories c
             where c.id = p_category_id
               and c.lot_id = lot_value
        ) then
            vehicle.category_id := p_category_id;
        else
            select c2.id into vehicle.category_id
              from public.categories c2
              join public.categories c1 on c1.name = c2.name
             where c1.id = vehicle.category_id
               and c2.lot_id = lot_value
             limit 1;
            if vehicle.category_id is null then
                raise exception 'CategoryNotFoundError';
            end if;
        end if;
        update public.vehicles
           set category_id = vehicle.category_id
         where id = vehicle.id;
    end if;

    if vehicle.is_blacklisted then
        raise exception 'VehicleBlacklistedError';
    end if;

    if exists (
        select 1 from public.parking_sessions s
         where s.vehicle_id = vehicle.id and s.status = 'open'
    ) then
        raise exception 'DuplicateOpenSessionError';
    end if;

    select c.name into category_name
      from public.categories c
     where c.id = vehicle.category_id;
    spot_group := public.category_group(category_name);

    -- Serialize spot selection for the group (the capacity guard locks the
    -- same key later, so ordering is stable).
    perform pg_advisory_xact_lock(
        hashtext('group:' || lot_value || ':' || spot_group)
    );

    if p_spot_id is not null then
        select * into spot
          from public.parking_spots sp
         where sp.id = p_spot_id
           and sp.lot_id = lot_value
         for update;
        if not found then
            raise exception 'SpotNotFoundError';
        end if;
        if spot.group_name <> spot_group then
            raise exception 'SpotGroupMismatchError';
        end if;
        if spot.status <> 'active' then
            raise exception 'SpotOutOfServiceError';
        end if;
        if exists (
            select 1 from public.parking_sessions s
             where s.status = 'open' and s.spot_id = spot.id
        ) then
            raise exception 'SpotTakenError';
        end if;
        chosen_spot := spot.id;
    else
        select count(*) into spots_total
          from public.parking_spots sp
         where sp.lot_id = lot_value
           and sp.group_name = spot_group;

        if spots_total > 0 then
            select sp.* into spot
              from public.parking_spots sp
             where sp.lot_id = lot_value
               and sp.group_name = spot_group
               and sp.status = 'active'
               and not exists (
                   select 1 from public.parking_sessions s
                    where s.status = 'open' and s.spot_id = sp.id
               )
             order by sp.grid_row, sp.grid_col
             limit 1
             for update;
            if not found then
                raise exception 'ParkingFullError';
            end if;
            chosen_spot := spot.id;
        end if;
    end if;

    -- A reservation for this plate holds a slot: close it before the capacity
    -- trigger counts active reservations, so the car converts its hold into
    -- an occupied slot instead of being rejected.
    update public.category_reservations
       set status = 'used'
     where plate = vehicle.plate
       and lot_id = lot_value
       and status = 'active'
       and reserved_until > now();

    begin
        insert into public.parking_sessions (
            vehicle_id, operator_id, entry_time, status, lot_id, left_keys, spot_id
        )
        values (
            vehicle.id, operator_id, entry_at, 'open', lot_value,
            coalesce(p_left_keys, false), chosen_spot
        )
        returning * into session;
    exception when unique_violation then
        raise exception 'DuplicateOpenSessionError';
    end;

    for photo in select * from jsonb_array_elements(coalesce(p_photos, '[]'::jsonb)) loop
        perform public.require_evidence_object(photo ->> 'path');
        insert into public.evidence_photos (session_id, file_path, taken_at)
        values (
            session.id,
            photo ->> 'path',
            coalesce((photo ->> 'taken_at')::timestamptz, now())
        );
        photo_count := photo_count + 1;
    end loop;

    for video in select * from jsonb_array_elements(coalesce(p_videos, '[]'::jsonb)) loop
        perform public.require_evidence_object(video ->> 'path');
        insert into public.evidence_photos (
            session_id, file_path, taken_at, kind, duration_seconds
        )
        values (
            session.id,
            video ->> 'path',
            coalesce((video ->> 'taken_at')::timestamptz, now()),
            'video',
            nullif(video ->> 'duration_seconds', '')::integer
        );
        video_count := video_count + 1;
    end loop;

    response := jsonb_build_object(
        'id', session.id,
        'vehicle_id', vehicle.id,
        'plate', vehicle.plate,
        'status', session.status,
        'entry_time', session.entry_time,
        'lot_id', session.lot_id,
        'left_keys', session.left_keys,
        'photo_count', photo_count,
        'video_count', video_count,
        'spot_id', session.spot_id,
        'spot_code', (
            select ps.code from public.parking_spots ps where ps.id = session.spot_id
        )
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, operator_id, 'rpc/check_in', 201, response);
    end if;

    return response;
end;
$$;
