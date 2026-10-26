-- Payment methods on check-out, payment breakdown in reports, and daily
-- overstay alerts.

alter table public.parking_sessions
    add column if not exists payment_method varchar(20);

alter table public.parking_sessions
    drop constraint if exists parking_sessions_payment_method_check;
alter table public.parking_sessions
    add constraint parking_sessions_payment_method_check
    check (
        payment_method is null
        or payment_method in ('cash', 'card', 'transfer', 'monthly_pass', 'exempt')
    );

alter table public.parking_settings
    add column if not exists overstay_hours integer not null default 24;

alter table public.parking_settings
    drop constraint if exists parking_settings_overstay_check;
alter table public.parking_settings
    add constraint parking_settings_overstay_check
    check (overstay_hours between 1 and 168);

-- ---------------------------------------------------------------------------
-- Check-out now records how the customer paid.
-- ---------------------------------------------------------------------------
drop function if exists public.check_out(integer, timestamptz, text);

create function public.check_out(
    p_session_id integer,
    p_client_exit_time timestamptz default null,
    p_idempotency_key text default null,
    p_payment_method text default 'cash'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    operator_id integer := public.require_app_user();
    session public.parking_sessions%rowtype;
    vehicle public.vehicles%rowtype;
    exit_at timestamptz;
    amount integer;
    has_pass boolean;
    tz text;
    response jsonb;
    replay jsonb;
    method text := coalesce(nullif(btrim(p_payment_method), ''), 'cash');
begin
    if method not in ('cash', 'card', 'transfer', 'monthly_pass', 'exempt') then
        raise exception 'InvalidPaymentMethod';
    end if;

    if p_idempotency_key is not null then
        replay := public.replay_idempotent(p_idempotency_key, operator_id, 'rpc/check_out');
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

    amount := public.calculate_fare(vehicle.category_id, session.entry_time, exit_at, has_pass);
    if has_pass then
        method := 'monthly_pass';
    end if;

    update public.parking_sessions
       set status = 'closed',
           exit_time = exit_at,
           amount_charged = amount,
           payment_method = method,
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
        'payment_method', session.payment_method
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, operator_id, 'rpc/check_out', 200, response);
    end if;

    return response;
end;
$$;

grant execute on function public.check_out(integer, timestamptz, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Check-out notifications carry the payment method.
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
    amount_value integer;
begin
    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where id = 1;
    tz := coalesce(tz, 'America/Bogota');

    if tg_op = 'INSERT' and new.status = 'open' then
        select v.plate into plate_value from public.vehicles v where v.id = new.vehicle_id;
        insert into public.notifications (user_id, type, title, body, data, dedupe_key)
        select u.id,
               'check_in',
               'Vehículo ' || plate_value || ' ingresó',
               'Entrada registrada a las ' ||
                   to_char(new.entry_time at time zone tz, 'HH24:MI'),
               jsonb_build_object('session_id', new.id, 'plate', plate_value),
               'check_in:' || new.id || ':user:' || u.id
          from public.users u
         where u.role = 'admin' and u.is_active
        on conflict (dedupe_key) do nothing;
    elsif tg_op = 'UPDATE' and new.status = 'closed' and old.status = 'open' then
        select v.plate into plate_value from public.vehicles v where v.id = new.vehicle_id;
        amount_value := coalesce(new.amount_charged, 0);
        insert into public.notifications (user_id, type, title, body, data, dedupe_key)
        select u.id,
               'check_out',
               'Vehículo ' || plate_value || ' salió',
               'Salida registrada. Cobro: $' || amount_value,
               jsonb_build_object(
                   'session_id', new.id,
                   'plate', plate_value,
                   'amount_charged', amount_value,
                   'ticket_number', new.ticket_number,
                   'payment_method', new.payment_method
               ),
               'check_out:' || new.id || ':user:' || u.id
          from public.users u
         where u.role = 'admin' and u.is_active
        on conflict (dedupe_key) do nothing;
    end if;
    return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Revenue by payment method
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

    select coalesce(sum(s.amount_charged), 0) into total
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
        'by_day', by_day,
        'by_category', by_category,
        'by_payment', by_payment
    );
end;
$$;

grant execute on function public.report_revenue(date, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Overstay alerts (call daily; one alert per vehicle per day)
-- ---------------------------------------------------------------------------
create or replace function public.notify_overstays()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
    hours integer;
begin
    select overstay_hours into hours from public.parking_settings where id = 1;
    hours := coalesce(hours, 24);

    insert into public.notifications (user_id, type, title, body, data, dedupe_key)
    select u.id,
           'overstay',
           'Vehículo ' || v.plate || ' lleva más de ' || hours || ' h',
           'Ingresó el ' || to_char(s.entry_time at time zone tz, 'DD/MM/YYYY HH24:MI'),
           jsonb_build_object(
               'session_id', s.id,
               'plate', v.plate,
               'entry_time', s.entry_time,
               'hours', hours
           ),
           'overstay:' || s.id || ':' || current_date || ':user:' || u.id
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.users u on u.role = 'admin' and u.is_active
      cross join lateral (
          select coalesce(business_timezone, 'America/Bogota') as tz
            from public.parking_settings where id = 1
      ) zone
     where s.status = 'open'
       and s.entry_time < now() - make_interval(hours => hours)
    on conflict (dedupe_key) do nothing;

    get diagnostics changed = row_count;
    return changed;
end;
$$;

grant execute on function public.notify_overstays() to authenticated;
