-- Merchant agreements — the single fare composer.
-- `fare_quote` decides what a session owes at a given exit instant: base fare,
-- the (future) dynamic-pricing step, one line per pending merchant validation,
-- the (future) loyalty reward and the manual discount. `check_out`, the preview
-- and the public summary all call it, so those four views can never drift.
--
-- Three hooks keep the later money changes out of this function:
--   * `fare_pricing_step` (add-dynamic-pricing replaces it),
--   * `fare_reward_step` (add-loyalty-rewards replaces it).

create or replace function public.fare_pricing_step(
    p_session_id integer,
    p_base integer
)
returns jsonb
language sql
stable
set search_path = public
as $$
    select jsonb_build_object('amount', p_base, 'pricing', null);
$$;

revoke all on function public.fare_pricing_step(integer, integer)
    from public, anon, authenticated;

create or replace function public.fare_reward_step(
    p_session_id integer,
    p_running integer,
    p_merchant_total integer
)
returns jsonb
language sql
stable
set search_path = public
as $$
    select jsonb_build_object('amount', 0, 'line', null, 'info', null);
$$;

revoke all on function public.fare_reward_step(integer, integer, integer)
    from public, anon, authenticated;

create or replace function public.fare_quote(
    p_session_id integer,
    p_exit_time timestamp with time zone,
    p_discount_amount integer default 0,
    p_lost_ticket boolean default false
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
    exit_at timestamptz := p_exit_time;
    tz text;
    has_pass boolean;
    lost boolean := coalesce(p_lost_ticket, false);
    effective_pass boolean;
    base integer := 0;
    gross integer := 0;
    pricing jsonb;
    step jsonb;
    running integer;
    line record;
    raw integer;
    benefit integer;
    shortened timestamptz;
    shortened_base integer;
    adjustments jsonb := '[]'::jsonb;
    adjustments_total integer := 0;
    merchant_total integer := 0;
    reward_step jsonb;
    reward_amount integer;
    reward jsonb;
    discount integer;
    due integer;
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
           and mp.start_date <= (exit_at at time zone tz)::date
           and mp.end_date >= (exit_at at time zone tz)::date
    ) into has_pass;
    effective_pass := has_pass and not lost;

    if effective_pass then
        base := 0;
        gross := 0;
        pricing := null;
    elsif lost then
        base := public.lost_ticket_amount(session.id, exit_at);
        gross := base;
        pricing := null;
    else
        base := (public.fare_breakdown(
            vehicle.category_id, session.entry_time, exit_at, false
        ) ->> 'amount')::integer;
        step := public.fare_pricing_step(session.id, base);
        gross := coalesce((step ->> 'amount')::integer, base);
        pricing := step -> 'pricing';
    end if;

    running := gross;

    if not effective_pass and not lost then
        for line in
            select v.id, v.terms
              from public.merchant_validations v
             where v.session_id = session.id
               and v.status = 'pending'
             order by v.created_at, v.id
        loop
            raw := 0;
            if line.terms ->> 'benefit_kind' = 'free_minutes' then
                shortened := exit_at -
                    ((line.terms ->> 'benefit_value')::integer * interval '1 minute');
                if shortened <= session.entry_time then
                    raw := running;
                else
                    shortened_base := (public.fare_breakdown(
                        vehicle.category_id, session.entry_time, shortened, false
                    ) ->> 'amount')::integer;
                    raw := gross - coalesce(
                        (public.fare_pricing_step(session.id, shortened_base) ->> 'amount')::integer,
                        shortened_base
                    );
                end if;
            elsif line.terms ->> 'benefit_kind' = 'percentage' then
                raw := ((running::bigint * (line.terms ->> 'benefit_value')::integer + 50) / 100)::integer;
            else
                raw := (line.terms ->> 'benefit_value')::integer;
            end if;

            benefit := least(greatest(raw, 0), running);
            if (line.terms ->> 'max_amount') is not null then
                benefit := least(benefit, (line.terms ->> 'max_amount')::integer);
            end if;
            benefit := greatest(benefit, 0);

            if benefit > 0 then
                adjustments := adjustments || jsonb_build_object(
                    'type', 'merchant',
                    'ref_id', line.id,
                    'label', line.terms ->> 'merchant_name',
                    'kind', line.terms ->> 'benefit_kind',
                    'amount', benefit
                );
                adjustments_total := adjustments_total + benefit;
                merchant_total := merchant_total + benefit;
                running := running - benefit;
            end if;
        end loop;

        reward_step := public.fare_reward_step(session.id, running, merchant_total);
        reward_amount := least(
            greatest(coalesce((reward_step ->> 'amount')::integer, 0), 0),
            running
        );
        if reward_amount > 0 and (reward_step -> 'line') is not null then
            adjustments := adjustments || (reward_step -> 'line');
            adjustments_total := adjustments_total + reward_amount;
            running := running - reward_amount;
        end if;
        reward := reward_step -> 'info';
    end if;

    discount := greatest(coalesce(p_discount_amount, 0), 0);
    if discount > running then
        raise exception 'InvalidDiscountError';
    end if;
    due := running - discount;

    return jsonb_build_object(
        'session_id', session.id,
        'exit_time', exit_at,
        'has_pass', effective_pass,
        'lost_ticket', lost,
        'base_amount', base,
        'pricing', pricing,
        'gross', gross,
        'adjustments', adjustments,
        'adjustments_total', adjustments_total,
        'discount_amount', discount,
        'amount_due', due,
        'reward', reward
    );
end;
$$;

revoke all on function public.fare_quote(integer, timestamptz, integer, boolean)
    from public, anon, authenticated;
