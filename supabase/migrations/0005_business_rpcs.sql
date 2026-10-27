-- Business logic that used to live in FastAPI:
-- fare calculation, atomic check-in/check-out, reports, branding and the
-- open-sessions read model. All write RPCs are security definer and derive
-- the operator from auth.uid(); the client never supplies operator ids.
--
-- Parameter names are prefixed with p_ so they can never be confused with
-- column references inside PL/pgSQL.

alter table public.parking_settings
    add column if not exists business_timezone text not null default 'America/Bogota';

-- The first draft used unprefixed parameter names; recreate the functions so
-- the p_* names are unambiguous (CREATE OR REPLACE cannot rename inputs).
drop function if exists public.check_out(integer, timestamptz, text);
drop function if exists public.check_in(text, integer, text, text, jsonb, text, timestamptz);
drop function if exists public.calculate_fare(integer, timestamptz, timestamptz, boolean);
drop function if exists public.report_revenue(date, date);
drop function if exists public.report_occupancy();
drop function if exists public.set_branding_logo(text);
drop function if exists public.replay_idempotent(text, integer, text);
drop function if exists public.remember_idempotent(text, integer, text, integer, jsonb);

-- Public branding (login screen) can be read before authentication.
grant usage on schema public to anon;
grant select on public.parking_settings to anon;
drop policy if exists settings_public_read on public.parking_settings;
create policy settings_public_read on public.parking_settings
    for select to anon, authenticated using (true);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.current_app_user_id()
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select id from public.users where auth_user_id = auth.uid() and is_active
$$;

create or replace function public.require_app_user()
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    uid integer := public.current_app_user_id();
begin
    if uid is null then
        raise exception 'InvalidTokenError';
    end if;
    return uid;
end;
$$;

create or replace function public.require_admin()
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
begin
    if public.current_app_role() is distinct from 'admin' then
        raise exception 'AdminRequiredError';
    end if;
    return uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Open sessions read model (RLS applies to the underlying tables)
-- ---------------------------------------------------------------------------
create or replace view public.open_sessions_view
with (security_invoker = true) as
select
    s.id,
    s.vehicle_id,
    v.plate,
    s.entry_time,
    s.status,
    (select count(*) from public.evidence_photos p where p.session_id = s.id) as photo_count
from public.parking_sessions s
join public.vehicles v on v.id = s.vehicle_id
where s.status = 'open';

grant select on public.open_sessions_view to authenticated;

-- ---------------------------------------------------------------------------
-- Fare calculation (parity with backend/app/domain/billing.py)
-- ---------------------------------------------------------------------------
create or replace function public.calculate_fare(
    p_category_id integer,
    p_entry_time timestamptz,
    p_exit_time timestamptz,
    p_has_pass boolean default false
)
returns integer
language plpgsql
stable
set search_path = public
as $$
declare
    tz text;
    entry_local timestamp;
    exit_local timestamp;
    day_cursor date;
    last_day date;
    day_start timestamp;
    day_end timestamp;
    seg_start timestamp;
    seg_end timestamp;
    hourly_amount integer;
    daily_amount integer;
    nightly_amount integer;
    night_start time;
    night_end time;
    win_start timestamp;
    win_end timestamp;
    night_secs numeric;
    day_secs numeric;
    day_charge integer;
    total integer := 0;
begin
    if p_has_pass then
        return 0;
    end if;
    if p_exit_time <= p_entry_time then
        raise exception 'InvalidBillingPeriodError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where id = 1;
    tz := coalesce(tz, 'America/Bogota');

    entry_local := p_entry_time at time zone tz;
    exit_local := p_exit_time at time zone tz;

    select t.amount into hourly_amount
      from public.tariffs t
     where t.category_id = p_category_id and t.type = 'hourly' and t.active
     order by t.id limit 1;
    if hourly_amount is null then
        raise exception 'MissingHourlyTariffError';
    end if;

    select t.amount into daily_amount
      from public.tariffs t
     where t.category_id = p_category_id and t.type = 'daily' and t.active
     order by t.id limit 1;

    select t.amount, t.start_time::time, t.end_time::time
      into nightly_amount, night_start, night_end
      from public.tariffs t
     where t.category_id = p_category_id and t.type = 'nightly' and t.active
     order by t.id limit 1;

    day_cursor := entry_local::date;
    last_day := (exit_local - interval '1 microsecond')::date;

    while day_cursor <= last_day loop
        day_start := day_cursor::timestamp;
        day_end := day_start + interval '1 day';
        seg_start := greatest(entry_local, day_start);
        seg_end := least(exit_local, day_end);

        if seg_end > seg_start then
            night_secs := 0;
            if nightly_amount is not null and night_start is not null and night_end is not null then
                win_start := day_start + night_start;
                win_end := day_start + night_end;
                if night_start < night_end then
                    night_secs := night_secs + greatest(
                        0,
                        extract(epoch from least(seg_end, win_end) - greatest(seg_start, win_start))
                    );
                else
                    night_secs := night_secs + greatest(
                        0,
                        extract(epoch from least(seg_end, win_end) - greatest(seg_start, day_start))
                    );
                    night_secs := night_secs + greatest(
                        0,
                        extract(epoch from least(seg_end, day_end) - greatest(seg_start, win_start))
                    );
                end if;
            end if;

            day_secs := extract(epoch from seg_end - seg_start) - night_secs;
            day_charge :=
                ceil(day_secs / 3600.0)::integer * greatest(hourly_amount, 0)
                + ceil(night_secs / 3600.0)::integer * greatest(coalesce(nightly_amount, 0), 0);
            if daily_amount is not null then
                day_charge := least(day_charge, greatest(daily_amount, 0));
            end if;
            total := total + day_charge;
        end if;

        day_cursor := day_cursor + 1;
    end loop;

    return greatest(total, 0);
end;
$$;

-- ---------------------------------------------------------------------------
-- Idempotency helpers
-- ---------------------------------------------------------------------------
create or replace function public.replay_idempotent(
    p_key text,
    p_user_id integer,
    p_endpoint text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    stored public.idempotency_keys%rowtype;
begin
    select * into stored from public.idempotency_keys ik where ik.key = p_key;
    if not found then
        return null;
    end if;
    if stored.user_id <> p_user_id or stored.endpoint <> p_endpoint then
        raise exception 'IdempotencyKeyInUseError';
    end if;
    return stored.response_body::jsonb;
end;
$$;

create or replace function public.remember_idempotent(
    p_key text,
    p_user_id integer,
    p_endpoint text,
    p_status_code integer,
    p_response jsonb
)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.idempotency_keys (key, user_id, endpoint, status_code, response_body, created_at)
    values (p_key, p_user_id, p_endpoint, p_status_code, p_response::text, now())
    on conflict (key) do nothing;
$$;

-- ---------------------------------------------------------------------------
-- Check-in
-- ---------------------------------------------------------------------------
create or replace function public.check_in(
    p_plate text,
    p_category_id integer default null,
    p_color text default null,
    p_brand text default null,
    p_photos jsonb default '[]'::jsonb,
    p_idempotency_key text default null,
    p_client_entry_time timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    operator_id integer := public.require_app_user();
    normalized_plate text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    vehicle public.vehicles%rowtype;
    session public.parking_sessions%rowtype;
    entry_at timestamptz;
    response jsonb;
    replay jsonb;
    photo jsonb;
    photo_count integer := 0;
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
        if not exists (select 1 from public.categories c where c.id = p_category_id) then
            raise exception 'CategoryNotFoundError';
        end if;
        insert into public.vehicles (plate, category_id, color, brand, created_by)
        values (normalized_plate, p_category_id, p_color, p_brand, operator_id)
        on conflict (plate) do update set plate = excluded.plate
        returning * into vehicle;
    end if;

    if exists (
        select 1 from public.parking_sessions s
         where s.vehicle_id = vehicle.id and s.status = 'open'
    ) then
        raise exception 'DuplicateOpenSessionError';
    end if;

    begin
        insert into public.parking_sessions (vehicle_id, operator_id, entry_time, status)
        values (vehicle.id, operator_id, entry_at, 'open')
        returning * into session;
    exception when unique_violation then
        raise exception 'DuplicateOpenSessionError';
    end;

    for photo in select * from jsonb_array_elements(coalesce(p_photos, '[]'::jsonb)) loop
        insert into public.evidence_photos (session_id, file_path, taken_at)
        values (
            session.id,
            photo ->> 'path',
            coalesce((photo ->> 'taken_at')::timestamptz, now())
        );
        photo_count := photo_count + 1;
    end loop;

    response := jsonb_build_object(
        'id', session.id,
        'vehicle_id', vehicle.id,
        'plate', vehicle.plate,
        'status', session.status,
        'entry_time', session.entry_time,
        'photo_count', photo_count
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, operator_id, 'rpc/check_in', 201, response);
    end if;

    return response;
end;
$$;

-- ---------------------------------------------------------------------------
-- Check-out
-- ---------------------------------------------------------------------------
create or replace function public.check_out(
    p_session_id integer,
    p_client_exit_time timestamptz default null,
    p_idempotency_key text default null
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
begin
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

    update public.parking_sessions
       set status = 'closed',
           exit_time = exit_at,
           amount_charged = amount,
           ticket_number = 'TCK-' || lpad(session.id::text, 6, '0')
     where id = session.id
     returning * into session;

    response := jsonb_build_object(
        'id', session.id,
        'plate', vehicle.plate,
        'entry_time', session.entry_time,
        'exit_time', session.exit_time,
        'amount_charged', session.amount_charged,
        'ticket_number', session.ticket_number
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, operator_id, 'rpc/check_out', 200, response);
    end if;

    return response;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reports
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

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'total', total,
        'by_day', by_day,
        'by_category', by_category
    );
end;
$$;

create or replace function public.report_occupancy()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    total bigint;
    by_category jsonb;
begin
    perform public.require_admin();

    select count(*) into total
      from public.parking_sessions s where s.status = 'open';

    select coalesce(jsonb_agg(item order by item ->> 'category_name'), '[]'::jsonb)
      into by_category
      from (
        select jsonb_build_object(
                   'category_id', c.id,
                   'category_name', c.name,
                   'count', count(s.id)
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
         where s.status = 'open'
         group by c.id, c.name
      ) categories;

    return jsonb_build_object('total_open', total, 'by_category', by_category);
end;
$$;

-- ---------------------------------------------------------------------------
-- Branding logo
-- ---------------------------------------------------------------------------
create or replace function public.set_branding_logo(p_path text)
returns public.parking_settings
language plpgsql
security definer
set search_path = public
as $$
declare
    updated public.parking_settings%rowtype;
begin
    perform public.require_admin();
    update public.parking_settings
       set logo_path = p_path,
           logo_version = logo_version + 1,
           updated_at = now()
     where id = 1
     returning * into updated;
    return updated;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
grant execute on function public.calculate_fare(integer, timestamptz, timestamptz, boolean) to authenticated;
grant execute on function public.check_in(text, integer, text, text, jsonb, text, timestamptz) to authenticated;
grant execute on function public.check_out(integer, timestamptz, text) to authenticated;
grant execute on function public.report_revenue(date, date) to authenticated;
grant execute on function public.report_occupancy() to authenticated;
grant execute on function public.set_branding_logo(text) to authenticated;
