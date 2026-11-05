-- Billing integrity fixes (audit 2026-11):
--   1. fare_breakdown bills ceil(stay / 1 h) once for the whole stay and
--      distributes those hours over the day/night buckets of each calendar
--      day by largest remainder; the daily cap still applies per day.
--   2. has_pass (check_out, check_out_preview, slot_board) only counts passes
--      of the session's lot.
--   3. tariffs must belong to their category's lot (composite FK) and
--      fare_breakdown only reads tariffs of the category's lot.
--   6. check_out attaches the sale only to the actor's OPEN shift, locking it
--      FOR SHARE so close_shift (FOR UPDATE) waits and then sees the row.
--   7. lost ticket: fee read from the session's lot, gross is
--      greatest(fare, fee | daily tariff | 0), a monthly_pass method is
--      rejected (LostTicketPassMethodError); check_out_preview returns
--      lost_ticket_amount.
--   8. an offline exit time older than 12 h is rejected (StaleExitTimeError);
--      the server close time is stored in parking_sessions.closed_recorded_at.

-- ---------------------------------------------------------------------------
-- 3. Tariffs belong to their category's lot.
-- ---------------------------------------------------------------------------
alter table public.categories
    add constraint categories_id_lot_key unique (id, lot_id);

alter table public.tariffs
    add constraint tariffs_category_lot_fkey
    foreign key (category_id, lot_id) references public.categories (id, lot_id);

-- ---------------------------------------------------------------------------
-- 8. Server-side close time (audit of offline exit times).
-- ---------------------------------------------------------------------------
alter table public.parking_sessions
    add column if not exists closed_recorded_at timestamptz;

comment on column public.parking_sessions.closed_recorded_at is
    'Server time when check_out ran; exit_time may be an earlier offline client time.';

-- ---------------------------------------------------------------------------
-- 1. Billable hours: largest-remainder allocation.
-- ---------------------------------------------------------------------------
-- Splits p_total_hours over the buckets proportionally to p_secs (Hamilton
-- method). Ties go to the earliest bucket, so the result is deterministic.
create or replace function public.allocate_billable_hours(
    p_secs numeric[],
    p_total_hours integer
)
returns integer[]
language sql
immutable
set search_path = public
as $$
    with buckets as (
        select b.ord, b.secs, sum(b.secs) over () as total
          from unnest(p_secs) with ordinality as b(secs, ord)
    ),
    floors as (
        select ord, secs,
               case when total > 0 then div(p_total_hours * secs, total) else 0 end as base,
               case when total > 0
                    then p_total_hours * secs - div(p_total_hours * secs, total) * total
                    else 0
               end as remainder
          from buckets
    ),
    ranked as (
        select ord, secs, base,
               row_number() over (order by remainder desc, ord) as rank,
               p_total_hours - sum(base) over () as leftover
          from floors
    )
    select coalesce(
               array_agg(
                   (base + case when secs > 0 and rank <= leftover then 1 else 0 end)::integer
                   order by ord
               ),
               '{}'::integer[]
           )
      from ranked;
$$;

create or replace function public.fare_breakdown(
    p_category_id integer,
    p_entry_time timestamp with time zone,
    p_exit_time timestamp with time zone,
    p_has_pass boolean default false
)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
    tz text;
    lot integer;
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
    bucket_secs numeric[] := '{}';
    allocated integer[];
    billable_hours integer;
    idx integer;
    day_charge integer;
    day_hours integer := 0;
    night_hours integer := 0;
    days_charged integer := 0;
    cap_applied boolean := false;
    total integer := 0;
begin
    if p_exit_time <= p_entry_time then
        raise exception 'InvalidBillingPeriodError';
    end if;

    if p_has_pass then
        return jsonb_build_object(
            'amount', 0,
            'hourly_rate', null,
            'nightly_rate', null,
            'daily_rate', null,
            'day_hours', 0,
            'night_hours', 0,
            'days', 0,
            'daily_cap_applied', false,
            'elapsed_seconds', extract(epoch from p_exit_time - p_entry_time)::integer
        );
    end if;

    select c.lot_id, coalesce(ps.business_timezone, 'America/Bogota')
      into lot, tz
      from public.categories c
      left join public.parking_settings ps on ps.lot_id = c.lot_id
     where c.id = p_category_id;
    tz := coalesce(tz, 'America/Bogota');

    entry_local := p_entry_time at time zone tz;
    exit_local := p_exit_time at time zone tz;

    select t.amount into hourly_amount
      from public.tariffs t
     where t.category_id = p_category_id and t.lot_id = lot
       and t.type = 'hourly' and t.active
     order by t.id limit 1;
    if hourly_amount is null then
        raise exception 'MissingHourlyTariffError';
    end if;

    select t.amount into daily_amount
      from public.tariffs t
     where t.category_id = p_category_id and t.lot_id = lot
       and t.type = 'daily' and t.active
     order by t.id limit 1;

    select t.amount, t.start_time::time, t.end_time::time
      into nightly_amount, night_start, night_end
      from public.tariffs t
     where t.category_id = p_category_id and t.lot_id = lot
       and t.type = 'nightly' and t.active
     order by t.id limit 1;

    -- Seconds per (calendar day, day|night) bucket; two buckets per day.
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
            bucket_secs := bucket_secs || array[day_secs, night_secs];
            days_charged := days_charged + 1;
        end if;

        day_cursor := day_cursor + 1;
    end loop;

    -- Hours are rounded up once for the whole stay, never per segment.
    billable_hours := ceil(extract(epoch from p_exit_time - p_entry_time) / 3600.0)::integer;
    allocated := public.allocate_billable_hours(bucket_secs, billable_hours);

    for idx in 1 .. days_charged loop
        day_hours := day_hours + allocated[2 * idx - 1];
        night_hours := night_hours + allocated[2 * idx];
        day_charge :=
            allocated[2 * idx - 1] * greatest(hourly_amount, 0)
            + allocated[2 * idx] * greatest(coalesce(nightly_amount, 0), 0);
        if daily_amount is not null and day_charge > greatest(daily_amount, 0) then
            day_charge := greatest(daily_amount, 0);
            cap_applied := true;
        end if;
        total := total + day_charge;
    end loop;

    return jsonb_build_object(
        'amount', greatest(total, 0),
        'hourly_rate', hourly_amount,
        'nightly_rate', nightly_amount,
        'daily_rate', daily_amount,
        'day_hours', day_hours,
        'night_hours', night_hours,
        'days', days_charged,
        'daily_cap_applied', cap_applied,
        'elapsed_seconds', extract(epoch from p_exit_time - p_entry_time)::integer
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Lost ticket amount (single source for check_out and the preview).
-- ---------------------------------------------------------------------------
-- greatest(regular fare, lot lost_ticket_fee | category daily tariff | 0).
-- A missing hourly tariff does not block a lost-ticket charge.
create or replace function public.lost_ticket_amount(
    p_session_id integer,
    p_exit_time timestamptz
)
returns integer
language plpgsql
stable
set search_path = public
as $$
declare
    session public.parking_sessions%rowtype;
    category integer;
    fee integer;
    daily integer;
    fare integer := 0;
begin
    select * into session from public.parking_sessions s where s.id = p_session_id;
    select v.category_id into category from public.vehicles v where v.id = session.vehicle_id;

    select ps.lost_ticket_fee into fee
      from public.parking_settings ps
     where ps.lot_id = session.lot_id;

    select t.amount into daily
      from public.tariffs t
     where t.category_id = category
       and t.lot_id = session.lot_id
       and t.type = 'daily'
       and t.active
     order by t.id
     limit 1;

    begin
        fare := public.calculate_fare(category, session.entry_time, p_exit_time, false);
    exception when others then
        if sqlerrm not like '%MissingHourlyTariffError%' then
            raise;
        end if;
        fare := 0;
    end;

    return greatest(coalesce(fare, 0), coalesce(fee, daily, 0));
end;
$$;

revoke all on function public.lost_ticket_amount(integer, timestamptz) from public;
revoke all on function public.lost_ticket_amount(integer, timestamptz) from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2, 6, 7, 8. check_out.
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

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = session.lot_id;
    tz := coalesce(tz, 'America/Bogota');

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

    if method = 'cash' then
        if cash_in is not null and cash_in < amount then
            raise exception 'InvalidCashReceivedError';
        end if;
        cash_back := case when cash_in is null then null else cash_in - amount end;
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
        'lost_ticket_reason', session.lost_ticket_reason
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, actor_id, 'rpc/check_out', 200, response);
    end if;

    return response;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2, 7. check_out_preview (adds lost_ticket_amount; existing keys kept).
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

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = session.lot_id;
    tz := coalesce(tz, 'America/Bogota');

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

    return breakdown || jsonb_build_object(
        'session_id', session.id,
        'amount', (breakdown ->> 'amount')::integer,
        'has_pass', has_pass,
        'entry_time', session.entry_time,
        'previewed_at', preview_at,
        'lost_ticket_amount', public.lost_ticket_amount(session.id, preview_at)
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. slot_board: has_pass only for passes of the session's lot.
-- ---------------------------------------------------------------------------
create or replace function public.slot_board()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    car_capacity integer := 0;
    moto_capacity integer := 0;
    car_out integer := 0;
    moto_out integer := 0;
    sessions jsonb := '[]'::jsonb;
    holds jsonb := '[]'::jsonb;
    spots jsonb := '[]'::jsonb;
begin
    perform public.require_app_user();

    select coalesce(ps.car_capacity, 0), coalesce(ps.moto_capacity, 0),
           coalesce(ps.car_out_of_service, 0),
           coalesce(ps.moto_out_of_service, 0)
      into car_capacity, moto_capacity, car_out, moto_out
      from public.parking_settings ps
     where ps.lot_id = lot;

    select coalesce(
               jsonb_agg(
                   jsonb_build_object(
                       'id', sp.id,
                       'code', sp.code,
                       'group', sp.group_name,
                       'row', sp.grid_row,
                       'col', sp.grid_col,
                       'active', sp.status = 'active'
                   )
                   order by sp.grid_row, sp.grid_col
               ),
               '[]'::jsonb
           )
      into spots
      from public.parking_spots sp
     where sp.lot_id = lot;

    select coalesce(
               jsonb_agg(item order by (item ->> 'entry_time')::timestamptz),
               '[]'::jsonb
           )
      into sessions
      from (
        select jsonb_build_object(
                   'session_id', s.id,
                   'plate', v.plate,
                   'entry_time', s.entry_time,
                   'left_keys', s.left_keys,
                   'spot_id', s.spot_id,
                   'photo_count', (
                       select count(*) from public.evidence_photos p
                        where p.session_id = s.id and p.kind = 'photo'
                   ),
                   'video_count', (
                       select count(*) from public.evidence_photos p
                        where p.session_id = s.id and p.kind = 'video'
                   ),
                   'has_pass', exists (
                       select 1 from public.monthly_passes mp
                        where mp.vehicle_id = s.vehicle_id
                          and mp.lot_id = s.lot_id
                          and mp.active
                          and mp.start_date <= (now() at time zone tz.name)::date
                          and mp.end_date >= (now() at time zone tz.name)::date
                   ),
                   'group', public.category_group(c.name)
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
          left join lateral (
              select coalesce(ps.business_timezone, 'America/Bogota') as name
                from public.parking_settings ps
               where ps.lot_id = s.lot_id
          ) tz on true
         where s.status = 'open'
           and s.lot_id = lot
      ) rows;

    select coalesce(
               jsonb_agg(item order by (item ->> 'reserved_until')::timestamptz),
               '[]'::jsonb
           )
      into holds
      from (
        select jsonb_build_object(
                   'plate', r.plate,
                   'reserved_until', r.reserved_until,
                   'group', public.category_group(c.name)
               ) as item
          from public.category_reservations r
          join public.categories c on c.id = r.category_id
         where r.lot_id = lot
           and r.status = 'active'
           and r.reserved_until > now()
      ) rows;

    return jsonb_build_object(
        'car_capacity', coalesce(car_capacity, 0),
        'moto_capacity', coalesce(moto_capacity, 0),
        'car_out_of_service', coalesce(car_out, 0),
        'moto_out_of_service', coalesce(moto_out, 0),
        'sessions', sessions,
        'holds', holds,
        'spots', spots
    );
end;
$$;

-- Same lot rule for the open-sessions list (same columns, same order).
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
       s.left_keys
  from public.parking_sessions s
  join public.vehicles v on v.id = s.vehicle_id
  left join lateral (
      select ps.business_timezone as name
        from public.parking_settings ps
       where ps.lot_id = s.lot_id
  ) tz on true
 where s.status = 'open';
