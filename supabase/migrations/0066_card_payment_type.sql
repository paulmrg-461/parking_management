-- Card payments must say debit or credit; cash keeps the change calculation
-- on the client (the server only needs the charged amount).

alter table public.parking_sessions
    add column if not exists card_type varchar(10)
        check (card_type in ('debit', 'credit'));

-- Signature change: drop the 9-argument version so PostgREST has one candidate.
do $$
begin
    alter function public.check_out(
        integer, timestamptz, text, text, integer, text, boolean, text, integer
    ) owner to postgres;
exception
    when undefined_function then null;
end $$;

drop function if exists public.check_out(
    integer, timestamptz, text, text, integer, text, boolean, text, integer
);

create or replace function public.check_out(
    p_session_id integer,
    p_client_exit_time timestamptz default null,
    p_idempotency_key text default null,
    p_payment_method text default 'cash',
    p_discount_amount integer default 0,
    p_discount_reason text default null,
    p_lost_ticket boolean default false,
    p_lost_ticket_reason text default null,
    p_lot_id integer default null,
    p_card_type text default null
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
    card_kind text := nullif(lower(btrim(coalesce(p_card_type, ''))), '');
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
           card_type = card_kind,
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


grant execute on function public.check_out(integer, timestamptz, text, text, integer, text, boolean, text, integer, text)
    to authenticated;