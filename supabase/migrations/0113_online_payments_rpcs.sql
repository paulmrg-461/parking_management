-- Online payments (Wompi) — service RPCs.
--   * `session_settlement` is the read model the Edge Function uses to price
--     an intent; it composes fare_breakdown with online_settlement_amounts.
--   * `create_session_payment_intent` / `apply_payment_event` /
--     `list_reconcilable_payment_intents` are service_role only (the browser
--     never sees a payment secret and cannot forge an approved event).
--   * `payment_intent_status` is the public poll (reference + plate).
--   * `settle_payment_intent` is the only place that dispatches on
--     payment_intents.kind (`add-pass-auto-renewal` re-declares it to add
--     `pass`; nothing else must know the kinds).
--   * `report_online_payments` is the bank reconciliation for lot admins.

-- ---------------------------------------------------------------------------
-- Notification helper: one row per active lot member (admins only when asked).
-- ---------------------------------------------------------------------------
create or replace function public.notify_payment(
    p_intent_id bigint,
    p_status text,
    p_type text,
    p_title text,
    p_body text,
    p_admin_only boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    intent public.payment_intents%rowtype;
    session public.parking_sessions%rowtype;
    plate_value text;
    currency_code text;
begin
    select * into intent from public.payment_intents i where i.id = p_intent_id;
    if not found then
        return;
    end if;
    select * into session from public.parking_sessions s where s.id = intent.session_id;
    select v.plate into plate_value
      from public.vehicles v where v.id = session.vehicle_id;
    select coalesce(ps.currency, 'COP') into currency_code
      from public.parking_settings ps where ps.lot_id = intent.lot_id;
    currency_code := coalesce(currency_code, 'COP');

    insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
    select u.id,
           p_type,
           p_title,
           replace(p_body, '{amount}', public.format_money(intent.amount, currency_code)),
           jsonb_build_object(
               'intent_id', intent.id,
               'reference', intent.reference,
               'session_id', intent.session_id,
               'plate', plate_value,
               'amount', intent.amount,
               'payment_status', upper(p_status)
           ),
           'online_pay:' || intent.id || ':' || upper(p_status) || ':user:' || u.id,
           intent.lot_id
      from public.lot_members lm
      join public.users u on u.id = lm.user_id
     where lm.lot_id = intent.lot_id
       and u.is_active
       and (not p_admin_only or lm.role = 'admin')
    on conflict (dedupe_key) do nothing;
end;
$$;

revoke all on function public.notify_payment(bigint, text, text, text, text, boolean)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- session_settlement: fare right now plus the grace-window split.
-- ---------------------------------------------------------------------------
create or replace function public.session_settlement(
    p_session_id integer,
    p_at timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    session public.parking_sessions%rowtype;
    vehicle public.vehicles%rowtype;
    settings public.parking_settings%rowtype;
    at_value timestamptz := coalesce(p_at, now());
    tz text;
    has_pass boolean;
    gross integer;
    settle jsonb;
begin
    select * into session from public.parking_sessions s where s.id = p_session_id;
    if not found then
        raise exception 'SessionNotFoundError';
    end if;
    select * into vehicle from public.vehicles v where v.id = session.vehicle_id;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;
    select * into settings from public.parking_settings ps where ps.lot_id = session.lot_id;
    tz := coalesce(settings.business_timezone, 'America/Bogota');

    select exists (
        select 1 from public.monthly_passes mp
         where mp.vehicle_id = vehicle.id
           and mp.lot_id = session.lot_id
           and mp.active
           and mp.start_date <= (at_value at time zone tz)::date
           and mp.end_date >= (at_value at time zone tz)::date
    ) into has_pass;

    gross := (public.fare_breakdown(
        vehicle.category_id, session.entry_time, at_value, has_pass
    ) ->> 'amount')::integer;

    settle := public.online_settlement_amounts(
        gross,
        session.online_paid_amount,
        session.online_paid_at,
        at_value,
        coalesce(settings.online_payment_grace_minutes, 15)
    );

    return jsonb_build_object(
        'session_id', session.id,
        'lot_id', session.lot_id,
        'status', session.status,
        'plate', vehicle.plate,
        'currency', coalesce(settings.currency, 'COP'),
        'gross', gross,
        'has_pass', has_pass,
        'paid', session.online_paid_amount,
        'due', (settle ->> 'desk_due')::integer,
        'grace_active', (settle ->> 'grace_active')::boolean,
        'grace_until', settle -> 'grace_until',
        'enabled', coalesce(settings.online_payments_enabled, false),
        'min_amount', coalesce(settings.online_payment_min_amount, 0),
        'grace_minutes', coalesce(settings.online_payment_grace_minutes, 15)
    );
end;
$$;

revoke all on function public.session_settlement(integer, timestamptz)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- create_session_payment_intent: plate-keyed and throttled public surface.
-- ---------------------------------------------------------------------------
create or replace function public.create_session_payment_intent(
    p_session_id bigint,
    p_plate text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    session public.parking_sessions%rowtype;
    settings public.parking_settings%rowtype;
    settlement jsonb;
    due integer;
    existing public.payment_intents%rowtype;
    intent public.payment_intents%rowtype;
    recent integer;
begin
    perform pg_advisory_xact_lock(hashtext('payment_intent'), coalesce(p_session_id, 0)::integer);

    if p_session_id is null or p_session_id <= 0 or length(normalized) < 3 then
        raise exception 'SessionNotFoundError';
    end if;

    select * into session from public.parking_sessions s where s.id = p_session_id;
    if not found then
        raise exception 'SessionNotFoundError';
    end if;
    -- A wrong plate and an unknown session answer the same: no oracle.
    if not exists (
        select 1 from public.vehicles v
         where v.id = session.vehicle_id
           and upper(regexp_replace(v.plate, '\s', '', 'g')) = normalized
    ) then
        raise exception 'SessionNotFoundError';
    end if;
    if session.status = 'closed' then
        raise exception 'SessionAlreadyClosedError';
    end if;

    select * into settings from public.parking_settings ps where ps.lot_id = session.lot_id;
    if not coalesce(settings.online_payments_enabled, false)
       or coalesce(settings.currency, 'COP') <> 'COP' then
        raise exception 'OnlinePaymentsDisabledError';
    end if;

    settlement := public.session_settlement(session.id, now());
    due := (settlement ->> 'due')::integer;
    if due <= 0 then
        raise exception 'NothingToPayError';
    end if;
    if due < coalesce(settings.online_payment_min_amount, 0) then
        raise exception 'AmountTooLowError';
    end if;

    select count(*) into recent
      from public.payment_intents i
     where i.session_id = session.id
       and i.created_at >= now() - interval '1 hour';
    if recent >= 5 then
        raise exception 'PaymentThrottledError';
    end if;

    select * into existing
      from public.payment_intents i
     where i.session_id = session.id
       and i.status = 'pending'
       and i.expires_at > now()
       and i.amount = due
     order by i.id desc
     limit 1;
    if found then
        return jsonb_build_object(
            'intent_id', existing.id,
            'reference', existing.reference,
            'amount', existing.amount,
            'currency', existing.currency,
            'status', existing.status,
            'expires_at', existing.expires_at,
            'grace_minutes', coalesce(settings.online_payment_grace_minutes, 15)
        );
    end if;

    update public.payment_intents
       set status = 'expired', updated_at = now()
     where session_id = session.id and status = 'pending';

    insert into public.payment_intents (lot_id, kind, session_id, reference, amount, currency, expires_at)
    values (
        session.lot_id,
        'session',
        session.id,
        'PM-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
        due,
        'COP',
        now() + interval '30 minutes'
    )
    returning * into intent;

    return jsonb_build_object(
        'intent_id', intent.id,
        'reference', intent.reference,
        'amount', intent.amount,
        'currency', intent.currency,
        'status', intent.status,
        'expires_at', intent.expires_at,
        'grace_minutes', coalesce(settings.online_payment_grace_minutes, 15)
    );
end;
$$;

revoke all on function public.create_session_payment_intent(bigint, text)
    from public, anon, authenticated;
grant execute on function public.create_session_payment_intent(bigint, text)
    to service_role;

-- ---------------------------------------------------------------------------
-- settle_payment_intent: the single dispatch on payment_intents.kind.
-- ---------------------------------------------------------------------------
create or replace function public.settle_payment_intent(p_intent_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    intent public.payment_intents%rowtype;
    session public.parking_sessions%rowtype;
    plate_value text;
begin
    select * into intent from public.payment_intents i where i.id = p_intent_id;
    if not found then
        raise exception 'PaymentIntentNotFoundError';
    end if;

    if intent.kind <> 'session' or intent.session_id is null then
        return jsonb_build_object('kind', 'ignored', 'applied', false, 'session_id', null);
    end if;

    select * into session from public.parking_sessions s where s.id = intent.session_id;
    select v.plate into plate_value
      from public.vehicles v where v.id = session.vehicle_id;

    if session.status <> 'open' then
        -- The customer paid after the desk closed the session: the money is
        -- real, so record it and let a human decide the refund.
        perform public.notify_payment(
            intent.id,
            'LATE_CLOSED',
            'online_payment_review',
            'Pago en línea por revisar',
            'Pago de {amount} para ' || coalesce(plate_value, 'un vehículo') ||
                ' llegó después de la salida.',
            true
        );
        return jsonb_build_object(
            'kind', 'late_closed',
            'applied', false,
            'session_id', session.id
        );
    end if;

    update public.parking_sessions
       set online_paid_amount = online_paid_amount + intent.amount,
           online_paid_at = now()
     where id = session.id;

    perform public.notify_payment(
        intent.id,
        'APPROVED',
        'online_payment',
        'Pago en línea',
        coalesce(plate_value, 'Un vehículo') || ' pagó {amount} en línea.',
        false
    );

    return jsonb_build_object(
        'kind', 'applied',
        'applied', true,
        'session_id', session.id
    );
end;
$$;

revoke all on function public.settle_payment_intent(bigint)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- apply_payment_event: idempotent webhook application (service role only).
-- ---------------------------------------------------------------------------
create or replace function public.apply_payment_event(
    p_gateway text,
    p_event jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    event_tx text := nullif(btrim(coalesce(p_event ->> 'transaction_id', '')), '');
    event_reference text := nullif(btrim(coalesce(p_event ->> 'reference', '')), '');
    event_status text := upper(coalesce(p_event ->> 'status', ''));
    event_amount integer := nullif(p_event ->> 'amount', '')::integer;
    event_currency text := upper(coalesce(p_event ->> 'currency', ''));
    event_method text := nullif(btrim(coalesce(p_event ->> 'method', '')), '');
    raw jsonb := coalesce(p_event -> 'raw', '{}'::jsonb);
    event_id bigint;
    intent public.payment_intents%rowtype;
    session public.parking_sessions%rowtype;
    settle jsonb;
    event_outcome text := 'ignored';
    applied boolean := false;
    plate_value text;
begin
    if event_tx is null or event_status = '' then
        raise exception 'InvalidPaymentEventError';
    end if;

    -- (1) Idempotency: the unique event key, not a pre-check.
    insert into public.payment_events (
        gateway, gateway_transaction_id, gateway_status, reference, amount, outcome, payload
    )
    values (p_gateway, event_tx, event_status, event_reference, event_amount, 'ignored', raw)
    on conflict (gateway, gateway_transaction_id, gateway_status) do nothing
    returning id into event_id;
    if event_id is null then
        return jsonb_build_object(
            'applied', false, 'duplicate', true, 'outcome', 'ignored',
            'intent_id', null, 'status', null, 'session_id', null
        );
    end if;

    if event_status not in ('APPROVED', 'DECLINED', 'VOIDED', 'ERROR') then
        return jsonb_build_object(
            'applied', false, 'duplicate', false, 'outcome', 'ignored',
            'intent_id', null, 'status', null, 'session_id', null
        );
    end if;

    -- (2) The intent, locked before the session (check_out locks only the
    -- session, so the order never inverts).
    select * into intent
      from public.payment_intents i
     where i.reference = event_reference
     for update;
    if not found then
        update public.payment_events set outcome = 'unknown_reference' where id = event_id;
        return jsonb_build_object(
            'applied', false, 'duplicate', false, 'outcome', 'unknown_reference',
            'intent_id', null, 'status', null, 'session_id', null
        );
    end if;
    update public.payment_events set intent_id = intent.id where id = event_id;

    -- (3) The gateway must confirm exactly the frozen amount and currency.
    if event_amount is distinct from intent.amount
       or event_currency is distinct from upper(intent.currency) then
        update public.payment_events set outcome = 'mismatch' where id = event_id;
        select v.plate into plate_value
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where s.id = intent.session_id;
        perform public.notify_payment(
            intent.id,
            event_status,
            'online_payment_review',
            'Pago en línea por revisar',
            'El pago de ' || coalesce(plate_value, 'un vehículo') ||
                ' no coincide con el valor del recibo.',
            true
        );
        return jsonb_build_object(
            'applied', false, 'duplicate', false, 'outcome', 'mismatch',
            'intent_id', intent.id, 'status', intent.status, 'session_id', intent.session_id
        );
    end if;

    -- (4) Lock the session for session intents before any side effect.
    if intent.kind = 'session' and intent.session_id is not null then
        select * into session
          from public.parking_sessions s
         where s.id = intent.session_id
         for update;
    end if;

    if event_status = 'APPROVED' then
        if intent.status = 'approved' then
            update public.payment_events set outcome = 'ignored' where id = event_id;
            return jsonb_build_object(
                'applied', false, 'duplicate', false, 'outcome', 'ignored',
                'intent_id', intent.id, 'status', intent.status, 'session_id', intent.session_id
            );
        end if;
        update public.payment_intents
           set status = 'approved',
               gateway_transaction_id = event_tx,
               gateway_method = event_method,
               approved_at = now(),
               updated_at = now()
         where id = intent.id
         returning * into intent;
        settle := public.settle_payment_intent(intent.id);
        event_outcome := coalesce(settle ->> 'kind', 'applied');
        applied := coalesce((settle ->> 'applied')::boolean, false);
    elsif event_status = 'VOIDED' then
        update public.payment_intents
           set status = 'voided', updated_at = now()
         where id = intent.id
         returning * into intent;
        if session.id is not null and session.status = 'open' then
            update public.parking_sessions
               set online_paid_amount = greatest(online_paid_amount - intent.amount, 0)
             where id = session.id;
        end if;
        select v.plate into plate_value
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where s.id = intent.session_id;
        perform public.notify_payment(
            intent.id,
            event_status,
            'online_payment_review',
            'Pago en línea por revisar',
            'Se anuló el pago de {amount} de ' || coalesce(plate_value, 'un vehículo') || '.',
            true
        );
        event_outcome := 'applied';
        applied := true;
    else
        -- DECLINED / ERROR never downgrade an approved payment.
        if intent.status in ('pending', 'expired') then
            update public.payment_intents
               set status = case when event_status = 'DECLINED' then 'declined' else 'error' end,
                   updated_at = now()
             where id = intent.id
             returning * into intent;
            event_outcome := 'applied';
            applied := true;
        end if;
    end if;

    update public.payment_events set outcome = event_outcome where id = event_id;

    return jsonb_build_object(
        'applied', applied,
        'duplicate', false,
        'outcome', event_outcome,
        'intent_id', intent.id,
        'status', intent.status,
        'session_id', intent.session_id
    );
end;
$$;

revoke all on function public.apply_payment_event(text, jsonb)
    from public, anon, authenticated;
grant execute on function public.apply_payment_event(text, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- payment_intent_status: public poll, keyed by reference + plate.
-- ---------------------------------------------------------------------------
create or replace function public.payment_intent_status(
    p_reference text,
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
    reference_value text := upper(btrim(coalesce(p_reference, '')));
    intent public.payment_intents%rowtype;
    session public.parking_sessions%rowtype;
    grace integer;
begin
    if length(reference_value) < 6 or length(normalized) < 3 then
        return null;
    end if;

    select * into intent
      from public.payment_intents i
     where i.reference = reference_value;
    if not found or intent.session_id is null then
        return null;
    end if;

    select * into session from public.parking_sessions s where s.id = intent.session_id;
    if not found then
        return null;
    end if;
    if not exists (
        select 1 from public.vehicles v
         where v.id = session.vehicle_id
           and upper(regexp_replace(v.plate, '\s', '', 'g')) = normalized
    ) then
        return null;
    end if;

    select coalesce(ps.online_payment_grace_minutes, 15) into grace
      from public.parking_settings ps where ps.lot_id = intent.lot_id;

    return jsonb_build_object(
        'status', intent.status,
        'amount', intent.amount,
        'session_id', session.id,
        'paid_total', session.online_paid_amount,
        'grace_until', case
            when session.online_paid_at is null then null
            else session.online_paid_at + make_interval(mins => coalesce(grace, 15))
        end
    );
end;
$$;

revoke all on function public.payment_intent_status(text, text) from public;
grant execute on function public.payment_intent_status(text, text)
    to anon, authenticated;

-- ---------------------------------------------------------------------------
-- expire_payment_intents: pending -> expired (an APPROVED later still counts).
-- ---------------------------------------------------------------------------
create or replace function public.expire_payment_intents()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    expired integer;
begin
    update public.payment_intents
       set status = 'expired', updated_at = now()
     where status = 'pending' and expires_at < now();
    get diagnostics expired = row_count;
    return expired;
end;
$$;

revoke all on function public.expire_payment_intents()
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- list_reconcilable_payment_intents: the reconcile job's work list.
-- ---------------------------------------------------------------------------
create or replace function public.list_reconcilable_payment_intents(
    p_older_than_minutes integer default 10
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    items jsonb;
begin
    select coalesce(jsonb_agg(item order by item ->> 'id'), '[]'::jsonb) into items
      from (
        select jsonb_build_object(
                   'id', i.id,
                   'reference', i.reference,
                   'gateway', i.gateway,
                   'amount', i.amount
               ) as item
          from public.payment_intents i
         where i.status = 'pending'
           and i.created_at <= now() - make_interval(mins => greatest(coalesce(p_older_than_minutes, 10), 0))
           and i.created_at >= now() - interval '24 hours'
         order by i.created_at
         limit 50
      ) rows;
    return items;
end;
$$;

revoke all on function public.list_reconcilable_payment_intents(integer)
    from public, anon, authenticated;
grant execute on function public.list_reconcilable_payment_intents(integer)
    to service_role;

-- ---------------------------------------------------------------------------
-- report_online_payments: bank reconciliation for the lot's business dates.
-- ---------------------------------------------------------------------------
create or replace function public.report_online_payments(
    p_start_date date,
    p_end_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    tz text;
    window_start timestamptz;
    window_end timestamptz;
    total bigint;
    approved_count integer;
    items jsonb;
begin
    if p_start_date is null or p_end_date is null or p_start_date > p_end_date then
        raise exception 'InvalidReportRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    select coalesce(sum(i.amount) filter (where i.status = 'approved'), 0),
           count(*) filter (where i.status = 'approved')
      into total, approved_count
      from public.payment_intents i
     where i.lot_id = lot
       and i.status in ('approved', 'voided')
       and i.approved_at >= window_start
       and i.approved_at < window_end;

    select coalesce(jsonb_agg(item order by item ->> 'approved_at' desc), '[]'::jsonb)
      into items
      from (
        select jsonb_build_object(
                   'intent_id', i.id,
                   'reference', i.reference,
                   'gateway_transaction_id', i.gateway_transaction_id,
                   'gateway_method', i.gateway_method,
                   'amount', i.amount,
                   'approved_at', i.approved_at,
                   'session_id', i.session_id,
                   'plate', v.plate,
                   'ticket_number', s.ticket_number,
                   'status', i.status
               ) as item
          from public.payment_intents i
          left join public.parking_sessions s on s.id = i.session_id
          left join public.vehicles v on v.id = s.vehicle_id
         where i.lot_id = lot
           and i.status in ('approved', 'voided')
           and i.approved_at >= window_start
           and i.approved_at < window_end
      ) rows;

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'total', total,
        'count', approved_count,
        'items', items
    );
end;
$$;

revoke all on function public.report_online_payments(date, date) from public;
grant execute on function public.report_online_payments(date, date) to authenticated;
