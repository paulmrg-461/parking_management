-- Offline replays must land in the site where the operator acted, even if the
-- active lot changed before the queue drained. A queued check-in/check-out can
-- carry `p_lot_id`; it is validated against `lot_members` exactly like the
-- `x-lot-id` header.

create or replace function public.resolve_lot(p_lot_id integer)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    uid integer := public.current_app_user_id();
begin
    if p_lot_id is null then
        return public.current_lot_id();
    end if;
    if uid is null then
        raise exception 'InvalidTokenError';
    end if;
    if not exists (
        select 1 from public.lot_members lm
         where lm.user_id = uid and lm.lot_id = p_lot_id
    ) then
        raise exception 'LotRequiredError';
    end if;
    return p_lot_id;
end;
$$;

grant execute on function public.resolve_lot(integer) to authenticated;

drop function if exists public.check_in(text, integer, text, text, jsonb, text, timestamptz);
drop function if exists public.check_out(integer, timestamptz, text, text, integer, text, boolean, text);

create or replace function public.check_in(
    p_plate text,
    p_category_id integer default null,
    p_color text default null,
    p_brand text default null,
    p_photos jsonb default '[]'::jsonb,
    p_idempotency_key text default null,
    p_client_entry_time timestamptz default null,
    p_lot_id integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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

    -- Categories are per lot: reuse the plate's category when it belongs to
    -- this lot, otherwise map it by name or take the operator's choice.
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
            vehicle_id, operator_id, entry_time, status, lot_id
        )
        values (
            vehicle.id, operator_id, entry_at, 'open', lot_value
        )
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
        'lot_id', session.lot_id,
        'photo_count', photo_count
    );

    if p_idempotency_key is not null then
        perform public.remember_idempotent(p_idempotency_key, operator_id, 'rpc/check_in', 201, response);
    end if;

    return response;
end;
$$;

create or replace function public.check_out(
    p_session_id integer,
    p_client_exit_time timestamptz default null,
    p_idempotency_key text default null,
    p_payment_method text default 'cash',
    p_discount_amount integer default 0,
    p_discount_reason text default null,
    p_lost_ticket boolean default false,
    p_lost_ticket_reason text default null,
    p_lot_id integer default null
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
    full_tariff integer;
    discount integer := greatest(coalesce(p_discount_amount, 0), 0);
    amount integer;
    has_pass boolean;
    lost boolean := coalesce(p_lost_ticket, false);
    lost_reason text;
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
    if lost then
        lost_reason := nullif(btrim(coalesce(p_lost_ticket_reason, '')), '');
        if lost_reason is null then
            raise exception 'LostTicketReasonRequired';
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
           and mp.active
           and mp.start_date <= (exit_at at time zone tz)::date
           and mp.end_date >= (exit_at at time zone tz)::date
    ) into has_pass;

    -- A lost ticket ignores the pass: there is no ticket to prove the stay.
    if lost then
        has_pass := false;
    end if;

    gross := public.calculate_fare(vehicle.category_id, session.entry_time, exit_at, has_pass);
    if has_pass then
        method := 'monthly_pass';
        discount := 0;
    end if;

    if lost then
        select t.amount into full_tariff
          from public.tariffs t
         where t.category_id = vehicle.category_id
           and t.type = 'daily'
           and t.active
         order by t.id
         limit 1;
        select coalesce(ls.lost_ticket_fee, full_tariff, gross) into gross
          from public.parking_settings ls
         where ls.id = 1;
        gross := coalesce(gross, full_tariff, 0);
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
       and s.lot_id = session.lot_id
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

grant execute on function public.check_in(text, integer, text, text, jsonb, text, timestamptz, integer) to authenticated;
grant execute on function public.check_out(integer, timestamptz, text, text, integer, text, boolean, text, integer) to authenticated;
