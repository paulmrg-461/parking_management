-- Monthly pass auto-renewal — reminders, the public renewal page and the
-- settlement of online renewals.
--   * `queue_pass_renewal_reminders` is the cron entry point: it expires stale
--     offers, deactivates ended parents that already have a child and queues at
--     most one reminder per (pass|offer, cadence window).
--   * `send_pass_renewal_link` is the admin action ("Enviar enlace").
--   * `public_pass_renewal` / `create_pass_renewal_intent` are the token-keyed
--     public surface (masked plate only).
--   * `settle_pass_renewal` creates the child pass **after** the payment is
--     approved; `settle_payment_intent` dispatches `kind = 'pass'` to it.
--   * `report_online_payments` now lists pass renewals too.

-- ---------------------------------------------------------------------------
-- Idempotent WhatsApp queue helper (cron has no actor and no lot header).
-- ---------------------------------------------------------------------------
create or replace function public.queue_whatsapp_message(
    p_lot_id integer,
    p_phone text,
    p_template text,
    p_params jsonb,
    p_button_param text,
    p_dedupe_key text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    inserted_id bigint;
begin
    insert into public.whatsapp_messages (
        lot_id, to_phone, template, language, params, button_param, dedupe_key
    )
    values (
        p_lot_id,
        left(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), 32),
        left(btrim(coalesce(p_template, '')), 60),
        'es',
        coalesce(p_params, '[]'::jsonb),
        nullif(btrim(coalesce(p_button_param, '')), ''),
        nullif(btrim(coalesce(p_dedupe_key, '')), '')
    )
    on conflict (dedupe_key) where dedupe_key is not null do nothing
    returning id into inserted_id;
    return inserted_id is not null;
end;
$$;

revoke all on function public.queue_whatsapp_message(integer, text, text, jsonb, text, text)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Reminder job.
-- ---------------------------------------------------------------------------
create or replace function public.queue_pass_renewal_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    rec record;
    offer public.pass_renewal_offers%rowtype;
    tz text;
    today date;
    days_left integer;
    target integer;
    cadence integer[];
    period_months integer;
    new_start date;
    new_end date;
    digits text;
    phone text;
    queued boolean;
    queued_count integer := 0;
begin
    -- (1) An offer only lives until the end of the renewal window.
    update public.pass_renewal_offers
       set status = 'expired'
     where status = 'open' and expires_at < now();

    -- (2) renew_monthly_passes never revisits a parent that already has a
    -- child, so the ended ones are deactivated here. A pass whose dates still
    -- cover today is never touched.
    update public.monthly_passes mp
       set active = false
     where mp.active
       and exists (
           select 1 from public.monthly_passes child
            where child.renewed_from_id = mp.id
       )
       and exists (
           select 1 from public.parking_settings ps
            where ps.lot_id = mp.lot_id
              and mp.end_date < (now() at time zone
                  coalesce(ps.business_timezone, 'America/Bogota'))::date
       );

    -- (3) One reminder per pass and cadence window.
    for rec in
        select mp.id,
               mp.vehicle_id,
               mp.lot_id,
               mp.start_date,
               mp.end_date,
               mp.amount,
               v.plate,
               v.owner_name,
               v.owner_phone,
               ps.business_timezone,
               ps.currency,
               ps.pass_renewal_cadence,
               ps.pass_renewal_payment_links
          from public.monthly_passes mp
          join public.vehicles v on v.id = mp.vehicle_id
          join public.parking_settings ps on ps.lot_id = mp.lot_id
         where mp.active
           and coalesce(ps.pass_renewal_enabled, false)
           and coalesce(ps.whatsapp_auto, false)
           and ps.pass_renewal_cadence is not null
           and v.owner_phone is not null
           and not exists (
               select 1 from public.monthly_passes child
                where child.renewed_from_id = mp.id
           )
           and not exists (
               select 1 from public.pass_renewal_offers o
                where o.monthly_pass_id = mp.id and o.status = 'paid'
           )
    loop
        tz := coalesce(rec.business_timezone, 'America/Bogota');
        today := (now() at time zone tz)::date;
        days_left := rec.end_date - today;
        -- From -3 (ended three days ago) to +30: nothing older is nudged.
        if days_left < -3 or days_left > 30 then
            continue;
        end if;

        cadence := string_to_array(rec.pass_renewal_cadence, ',')::integer[];
        select min(d) into target from unnest(cadence) as d where d >= days_left;
        if target is null then
            continue;
        end if;

        digits := regexp_replace(coalesce(rec.owner_phone, ''), '\D', '', 'g');
        if length(digits) not between 7 and 15 then
            continue;
        end if;
        -- ASSUMPTION: a 10-digit number starting with 3 is a Colombian
        -- mobile, so the country code is required by the Cloud API.
        phone := case
            when length(digits) = 10 and left(digits, 1) = '3'
                then '57' || digits
            else digits
        end;

        period_months := public.pass_period_months(rec.start_date, rec.end_date);
        new_start := rec.end_date + 1;
        new_end := case
            when period_months is not null then
                (new_start + make_interval(months => period_months))::date - 1
            else rec.end_date + (rec.end_date - rec.start_date + 1)
        end;

        if coalesce(rec.pass_renewal_payment_links, false) then
            select * into offer
              from public.pass_renewal_offers o
             where o.monthly_pass_id = rec.id and o.status = 'open';
            if found then
                update public.pass_renewal_offers
                   set period_start = new_start,
                       period_end = new_end,
                       amount = rec.amount,
                       expires_at = (rec.end_date + 8)::timestamp at time zone tz
                 where id = offer.id
                 returning * into offer;
            else
                insert into public.pass_renewal_offers (
                    lot_id, monthly_pass_id, token, period_start, period_end,
                    amount, expires_at
                )
                values (
                    rec.lot_id,
                    rec.id,
                    -- 192 random bits over two UUIDs (pgcrypto may live in a
                    -- different schema on hosted deployments).
                    left(
                        replace(gen_random_uuid()::text, '-', '') ||
                        replace(gen_random_uuid()::text, '-', ''),
                        48
                    ),
                    new_start,
                    new_end,
                    rec.amount,
                    (rec.end_date + 8)::timestamp at time zone tz
                )
                returning * into offer;
            end if;

            queued := public.queue_whatsapp_message(
                rec.lot_id,
                phone,
                'pass_renewal_link',
                jsonb_build_array(
                    coalesce(nullif(btrim(rec.owner_name), ''), 'cliente'),
                    rec.plate,
                    to_char(rec.end_date, 'DD/MM/YYYY'),
                    public.format_money(rec.amount, coalesce(rec.currency, 'COP'))
                ),
                offer.token,
                'pass_renewal:' || offer.id || ':' || target
            );
            if queued then
                update public.pass_renewal_offers
                   set reminders_sent = reminders_sent + 1,
                       last_reminder_at = now()
                 where id = offer.id;
                queued_count := queued_count + 1;
            end if;
        else
            queued := public.queue_whatsapp_message(
                rec.lot_id,
                phone,
                'pass_expiry',
                jsonb_build_array(rec.plate, to_char(rec.end_date, 'DD/MM/YYYY')),
                null,
                'pass_reminder:' || rec.id || ':' || rec.end_date || ':' || target
            );
            if queued then
                queued_count := queued_count + 1;
            end if;
        end if;
    end loop;

    return queued_count;
end;
$$;

revoke all on function public.queue_pass_renewal_reminders()
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Admin action: send the renewal link now.
-- ---------------------------------------------------------------------------
create or replace function public.send_pass_renewal_link(p_pass_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    pass public.monthly_passes%rowtype;
    settings public.parking_settings%rowtype;
    plate_value text;
    owner_name text;
    owner_phone text;
    tz text;
    today date;
    period_months integer;
    new_start date;
    new_end date;
    offer public.pass_renewal_offers%rowtype;
    digits text;
    phone text;
    queued boolean;
begin
    select * into pass
      from public.monthly_passes mp
     where mp.id = p_pass_id and mp.lot_id = lot;
    if not found then
        raise exception 'PassNotFoundError';
    end if;

    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    if not coalesce(settings.pass_renewal_enabled, false)
       or not coalesce(settings.pass_renewal_payment_links, false) then
        raise exception 'PassRenewalDisabledError';
    end if;
    if not coalesce(settings.whatsapp_auto, false) then
        raise exception 'WhatsappDisabledError';
    end if;

    select v.plate, v.owner_name, v.owner_phone
      into plate_value, owner_name, owner_phone
      from public.vehicles v
     where v.id = pass.vehicle_id;
    digits := regexp_replace(coalesce(owner_phone, ''), '\D', '', 'g');
    if length(digits) not between 7 and 15 then
        raise exception 'MissingOwnerPhoneError';
    end if;
    if exists (
        select 1 from public.monthly_passes child
         where child.renewed_from_id = pass.id
    ) then
        raise exception 'PassAlreadyRenewedError';
    end if;

    tz := coalesce(settings.business_timezone, 'America/Bogota');
    today := (now() at time zone tz)::date;
    period_months := public.pass_period_months(pass.start_date, pass.end_date);
    new_start := pass.end_date + 1;
    new_end := case
        when period_months is not null then
            (new_start + make_interval(months => period_months))::date - 1
        else pass.end_date + (pass.end_date - pass.start_date + 1)
    end;

    select * into offer
      from public.pass_renewal_offers o
     where o.monthly_pass_id = pass.id and o.status = 'open';
    if found then
        update public.pass_renewal_offers
           set period_start = new_start,
               period_end = new_end,
               amount = pass.amount,
               expires_at = (pass.end_date + 8)::timestamp at time zone tz
         where id = offer.id
         returning * into offer;
    else
        insert into public.pass_renewal_offers (
            lot_id, monthly_pass_id, token, period_start, period_end, amount,
            expires_at
        )
        values (
            lot,
            pass.id,
            left(
                replace(gen_random_uuid()::text, '-', '') ||
                replace(gen_random_uuid()::text, '-', ''),
                48
            ),
            new_start,
            new_end,
            pass.amount,
            (pass.end_date + 8)::timestamp at time zone tz
        )
        returning * into offer;
    end if;

    phone := case
        when length(digits) = 10 and left(digits, 1) = '3' then '57' || digits
        else digits
    end;

    queued := public.queue_whatsapp_message(
        lot,
        phone,
        'pass_renewal_link',
        jsonb_build_array(
            coalesce(nullif(btrim(owner_name), ''), 'cliente'),
            plate_value,
            to_char(pass.end_date, 'DD/MM/YYYY'),
            public.format_money(pass.amount, coalesce(settings.currency, 'COP'))
        ),
        offer.token,
        'pass_renewal_manual:' || offer.id || ':' || today
    );
    if queued then
        update public.pass_renewal_offers
           set reminders_sent = reminders_sent + 1,
               last_reminder_at = now()
         where id = offer.id;
    end if;

    return jsonb_build_object(
        'offer_id', offer.id,
        'status', offer.status,
        'queued', queued
    );
end;
$$;

revoke all on function public.send_pass_renewal_link(bigint) from public;
grant execute on function public.send_pass_renewal_link(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- Public page: token-keyed, masked plate only.
-- ---------------------------------------------------------------------------
create or replace function public.public_pass_renewal(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    token_value text := lower(btrim(coalesce(p_token, '')));
    offer public.pass_renewal_offers%rowtype;
    plate_value text;
    lot_name text;
    currency_code text;
    links_enabled boolean;
    child public.monthly_passes%rowtype;
begin
    if length(token_value) <> 48 then
        return null;
    end if;

    select * into offer
      from public.pass_renewal_offers o
     where o.token = token_value;
    if not found then
        return null;
    end if;

    select v.plate, l.name, coalesce(ps.currency, 'COP'),
           coalesce(ps.pass_renewal_payment_links, false)
             and coalesce(ps.online_payments_enabled, false)
      into plate_value, lot_name, currency_code, links_enabled
      from public.monthly_passes mp
      join public.vehicles v on v.id = mp.vehicle_id
      join public.parking_lots l on l.id = mp.lot_id
      join public.parking_settings ps on ps.lot_id = mp.lot_id
     where mp.id = offer.monthly_pass_id;

    if offer.renewal_pass_id is not null then
        select * into child
          from public.monthly_passes mp
         where mp.id = offer.renewal_pass_id;
    end if;

    return jsonb_build_object(
        'status', offer.status,
        'lot_name', lot_name,
        'plate_masked', left(coalesce(plate_value, ''), 3) ||
            repeat('*', greatest(length(coalesce(plate_value, '')) - 3, 0)),
        'period_start', offer.period_start,
        'period_end', offer.period_end,
        'amount', offer.amount,
        'currency', currency_code,
        'expires_at', offer.expires_at,
        'payment_links_enabled', links_enabled,
        'renewal_period_start', child.start_date,
        'renewal_period_end', child.end_date
    );
end;
$$;

revoke all on function public.public_pass_renewal(text) from public;
grant execute on function public.public_pass_renewal(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Intent creation for a renewal offer (service role only).
-- ---------------------------------------------------------------------------
create or replace function public.create_pass_renewal_intent(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    token_value text := lower(btrim(coalesce(p_token, '')));
    offer public.pass_renewal_offers%rowtype;
    settings public.parking_settings%rowtype;
    existing public.payment_intents%rowtype;
    intent public.payment_intents%rowtype;
    recent integer;
begin
    if length(token_value) <> 48 then
        raise exception 'PassRenewalNotFoundError';
    end if;

    select * into offer
      from public.pass_renewal_offers o
     where o.token = token_value
     for update;
    if not found then
        raise exception 'PassRenewalNotFoundError';
    end if;
    perform pg_advisory_xact_lock(hashtext('pass_intent'), offer.id::integer);

    if offer.status = 'paid' then
        raise exception 'PassRenewalPaidError';
    end if;
    if offer.status in ('expired', 'cancelled') or offer.expires_at < now() then
        raise exception 'PassRenewalExpiredError';
    end if;

    select * into settings from public.parking_settings ps where ps.lot_id = offer.lot_id;
    if not coalesce(settings.pass_renewal_enabled, false)
       or not coalesce(settings.pass_renewal_payment_links, false)
       or not coalesce(settings.online_payments_enabled, false)
       or coalesce(settings.currency, 'COP') <> 'COP' then
        raise exception 'OnlinePaymentsDisabledError';
    end if;
    if offer.amount < coalesce(settings.online_payment_min_amount, 0) then
        raise exception 'AmountTooLowError';
    end if;

    select count(*) into recent
      from public.payment_intents i
     where i.pass_renewal_offer_id = offer.id
       and i.created_at >= now() - interval '1 hour';
    if recent >= 5 then
        raise exception 'PaymentThrottledError';
    end if;

    select * into existing
      from public.payment_intents i
     where i.pass_renewal_offer_id = offer.id
       and i.status = 'pending'
       and i.expires_at > now()
       and i.amount = offer.amount
     order by i.id desc
     limit 1;
    if found then
        return jsonb_build_object(
            'intent_id', existing.id,
            'reference', existing.reference,
            'amount', existing.amount,
            'currency', existing.currency,
            'status', existing.status,
            'expires_at', existing.expires_at
        );
    end if;

    update public.payment_intents
       set status = 'expired', updated_at = now()
     where pass_renewal_offer_id = offer.id and status = 'pending';

    insert into public.payment_intents (
        lot_id, kind, pass_renewal_offer_id, reference, amount, currency,
        expires_at
    )
    values (
        offer.lot_id,
        'pass',
        offer.id,
        'PM-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
        offer.amount,
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
        'expires_at', intent.expires_at
    );
end;
$$;

revoke all on function public.create_pass_renewal_intent(text)
    from public, anon, authenticated;
grant execute on function public.create_pass_renewal_intent(text) to service_role;

-- ---------------------------------------------------------------------------
-- Settlement: the child pass is created only after the payment is approved.
-- ---------------------------------------------------------------------------
create or replace function public.settle_pass_renewal(p_intent_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    intent public.payment_intents%rowtype;
    offer public.pass_renewal_offers%rowtype;
    pass public.monthly_passes%rowtype;
    child public.monthly_passes%rowtype;
    settings public.parking_settings%rowtype;
    plate_value text;
    tz text;
    today date;
    period_months integer;
    new_start date;
    new_end date;
    child_paid boolean;
begin
    select * into intent from public.payment_intents i where i.id = p_intent_id;
    if not found then
        raise exception 'PaymentIntentNotFoundError';
    end if;
    if intent.kind <> 'pass' or intent.pass_renewal_offer_id is null then
        return jsonb_build_object(
            'kind', 'pass', 'applied', false,
            'renewal_pass_id', null, 'outcome', 'ignored'
        );
    end if;

    select * into offer
      from public.pass_renewal_offers o
     where o.id = intent.pass_renewal_offer_id
     for update;
    if not found then
        return jsonb_build_object(
            'kind', 'pass', 'applied', false,
            'renewal_pass_id', null, 'outcome', 'ignored'
        );
    end if;

    select * into pass
      from public.monthly_passes mp
     where mp.id = offer.monthly_pass_id
     for update;
    select v.plate into plate_value
      from public.vehicles v where v.id = pass.vehicle_id;

    -- (c) The offer was already settled: record it for a human review.
    if offer.status = 'paid' then
        insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
        select u.id,
               'online_payment_review',
               'Pago en línea por revisar',
               'Se recibió otro pago para la mensualidad de ' || coalesce(plate_value, 'un vehículo') || '.',
               jsonb_build_object(
                   'intent_id', intent.id,
                   'pass_renewal_offer_id', offer.id,
                   'monthly_pass_id', offer.monthly_pass_id,
                   'plate', plate_value
               ),
               'pass_review:' || offer.id || ':user:' || u.id,
               offer.lot_id
          from public.lot_members lm
          join public.users u on u.id = lm.user_id
         where lm.lot_id = offer.lot_id
           and lm.role = 'admin'
           and u.is_active
        on conflict (dedupe_key) do nothing;
        return jsonb_build_object(
            'kind', 'pass', 'applied', false,
            'renewal_pass_id', offer.renewal_pass_id, 'outcome', 'late_closed'
        );
    end if;

    select * into settings from public.parking_settings ps where ps.lot_id = offer.lot_id;
    tz := coalesce(settings.business_timezone, 'America/Bogota');
    today := (now() at time zone tz)::date;

    -- (b) The expiry job renewed the pass first: pay that charge.
    select * into child
      from public.monthly_passes mp
     where mp.renewed_from_id = pass.id;

    if not found then
        period_months := public.pass_period_months(pass.start_date, pass.end_date);
        new_start := greatest(offer.period_start, today);
        new_end := case
            when period_months is not null then
                (new_start + make_interval(months => period_months))::date - 1
            else new_start + (pass.end_date - pass.start_date)
        end;
        begin
            insert into public.monthly_passes (
                vehicle_id, start_date, end_date, amount, active, auto_renew,
                auto_renew_payment_method, renewed_from_id, lot_id
            )
            values (
                pass.vehicle_id, new_start, new_end, pass.amount, true,
                pass.auto_renew, pass.auto_renew_payment_method, pass.id,
                pass.lot_id
            )
            returning * into child;
        exception when unique_violation then
            -- Lost a race with renew_monthly_passes: adopt its child.
            select * into child
              from public.monthly_passes mp
             where mp.renewed_from_id = pass.id;
        end;
    end if;

    child_paid := false;
    update public.monthly_pass_payments p
       set status = 'paid',
           payment_method = 'online',
           paid_at = now(),
           paid_by = null,
           shift_id = null
     where p.monthly_pass_id = child.id
       and p.status = 'pending'
     returning true into child_paid;

    if not coalesce(child_paid, false) then
        -- A pass created by the cash renewal already has a paid charge.
        insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
        select u.id,
               'online_payment_review',
               'Pago en línea por revisar',
               'Se recibió un pago para la mensualidad de ' || coalesce(plate_value, 'un vehículo') ||
                   ', que ya estaba pagada.',
               jsonb_build_object(
                   'intent_id', intent.id,
                   'pass_renewal_offer_id', offer.id,
                   'monthly_pass_id', child.id,
                   'plate', plate_value
               ),
               'pass_review:' || offer.id || ':user:' || u.id,
               offer.lot_id
          from public.lot_members lm
          join public.users u on u.id = lm.user_id
         where lm.lot_id = offer.lot_id
           and lm.role = 'admin'
           and u.is_active
        on conflict (dedupe_key) do nothing;
    end if;

    update public.pass_renewal_offers
       set status = 'paid',
           paid_at = now(),
           renewal_pass_id = child.id
     where id = offer.id;

    insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
    select u.id,
           'pass_renewal_paid',
           'Mensualidad renovada en línea',
           'Vehículo ' || coalesce(plate_value, '') || ': ' ||
               to_char(child.start_date, 'DD/MM/YYYY') || ' - ' ||
               to_char(child.end_date, 'DD/MM/YYYY'),
           jsonb_build_object(
               'monthly_pass_id', child.id,
               'vehicle_id', pass.vehicle_id,
               'plate', plate_value,
               'start_date', child.start_date,
               'end_date', child.end_date
           ),
           'pass_renewal_paid:' || offer.id || ':user:' || u.id,
           offer.lot_id
      from public.lot_members lm
      join public.users u on u.id = lm.user_id
     where lm.lot_id = offer.lot_id
       and u.is_active
    on conflict (dedupe_key) do nothing;

    return jsonb_build_object(
        'kind', 'pass',
        'applied', true,
        'renewal_pass_id', child.id,
        'outcome', case when coalesce(child_paid, false) then 'applied' else 'late_closed' end
    );
end;
$$;

revoke all on function public.settle_pass_renewal(bigint)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- settle_payment_intent: session behaviour unchanged, pass delegated.
-- For a pass intent `kind` carries the settle outcome so `apply_payment_event`
-- (unchanged) records a valid `payment_events.outcome`.
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
    settled jsonb;
begin
    select * into intent from public.payment_intents i where i.id = p_intent_id;
    if not found then
        raise exception 'PaymentIntentNotFoundError';
    end if;

    if intent.kind = 'pass' then
        settled := public.settle_pass_renewal(intent.id);
        return jsonb_build_object(
            'kind', settled ->> 'outcome',
            'applied', coalesce((settled ->> 'applied')::boolean, false),
            'session_id', null,
            'renewal_pass_id', (settled ->> 'renewal_pass_id')::bigint
        );
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
-- report_online_payments: pass renewals appear with their kind and pass id.
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
                   'kind', i.kind,
                   'reference', i.reference,
                   'gateway_transaction_id', i.gateway_transaction_id,
                   'gateway_method', i.gateway_method,
                   'amount', i.amount,
                   'approved_at', i.approved_at,
                   'session_id', i.session_id,
                   'pass_id', o.monthly_pass_id,
                   'plate', coalesce(sv.plate, pv.plate),
                   'ticket_number', s.ticket_number,
                   'status', i.status
               ) as item
          from public.payment_intents i
          left join public.parking_sessions s on s.id = i.session_id
          left join public.vehicles sv on sv.id = s.vehicle_id
          left join public.pass_renewal_offers o on o.id = i.pass_renewal_offer_id
          left join public.monthly_passes mp on mp.id = o.monthly_pass_id
          left join public.vehicles pv on pv.id = mp.vehicle_id
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
