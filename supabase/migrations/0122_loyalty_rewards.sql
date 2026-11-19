-- Loyalty rewards — per-lot visit programs.
--   1. Settings (inert by default) and the redemption choice on the session.
--   2. Four tables: accounts (counter), rewards (snapshot), visits (ledger),
--      adjustments (manual corrections). Admin-readable only.
--   3. `fare_reward_step` (owned by add-merchant-validations) is replaced with
--      the real hook; `fare_quote` and `check_out` are untouched.
--   4. `loyalty_on_session_closed`: accrual and redemption bookkeeping in an
--      AFTER UPDATE trigger that NEVER blocks a customer from leaving.
--   5. Operator read, admin settings/adjustments, internal reversal and the
--      expiry job.
-- One reward is earned every N counted visits; a redeeming visit does not
-- count. Everything new is online only.

alter table public.parking_settings
    add column if not exists loyalty_enabled boolean not null default false,
    add column if not exists loyalty_visits_required integer not null default 5,
    add column if not exists loyalty_reward_kind text not null default 'free_stay',
    add column if not exists loyalty_reward_max_amount integer,
    add column if not exists loyalty_reward_fixed_amount integer not null default 0,
    add column if not exists loyalty_min_amount integer not null default 0,
    add column if not exists loyalty_min_minutes integer not null default 0,
    add column if not exists loyalty_redeem_mode text not null default 'auto',
    add column if not exists loyalty_stack_with_merchant boolean not null default true,
    add column if not exists loyalty_reward_valid_days integer not null default 90;
alter table public.parking_settings drop constraint if exists parking_settings_loyalty_check;
alter table public.parking_settings add constraint parking_settings_loyalty_check check (
    loyalty_visits_required between 2 and 50
    and loyalty_reward_kind in ('free_stay', 'fixed_amount')
    and (loyalty_reward_max_amount is null or loyalty_reward_max_amount > 0)
    and loyalty_reward_fixed_amount >= 0
    and (loyalty_reward_kind <> 'fixed_amount' or loyalty_reward_fixed_amount > 0)
    and loyalty_min_amount >= 0
    and loyalty_min_minutes between 0 and 1440
    and loyalty_redeem_mode in ('auto', 'operator')
    and loyalty_reward_valid_days between 7 and 730);

alter table public.parking_sessions
    add column if not exists loyalty_choice text;
alter table public.parking_sessions drop constraint if exists parking_sessions_loyalty_choice_check;
alter table public.parking_sessions add constraint parking_sessions_loyalty_choice_check
    check (loyalty_choice in ('redeem', 'skip'));

create table if not exists public.loyalty_accounts (
    id               bigserial   primary key,
    lot_id           integer     not null references public.parking_lots(id),
    plate            varchar(20) not null,
    progress         integer     not null default 0 check (progress >= 0),
    earned_total     integer     not null default 0 check (earned_total >= 0),
    redeemed_total   integer     not null default 0 check (redeemed_total >= 0),
    last_counted_day date,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    unique (lot_id, plate)
);

create table if not exists public.loyalty_rewards (
    id                  bigserial   primary key,
    lot_id              integer     not null references public.parking_lots(id),
    plate               varchar(20) not null,
    status              text        not null default 'available'
                        check (status in ('available', 'redeemed', 'expired', 'reversed')),
    kind                text        not null check (kind in ('free_stay', 'fixed_amount')),
    max_amount          integer     check (max_amount is null or max_amount > 0),
    fixed_amount        integer     not null default 0 check (fixed_amount >= 0),
    visits_required     integer     not null check (visits_required >= 2),
    earned_session_id   integer     references public.parking_sessions(id) on delete set null,
    redeemed_session_id integer     references public.parking_sessions(id) on delete set null,
    redeemed_amount     integer     check (redeemed_amount is null or redeemed_amount >= 0),
    expires_at          timestamptz not null,
    created_at          timestamptz not null default now(),
    redeemed_at         timestamptz,
    constraint loyalty_rewards_redeemed_check check (
        (status = 'redeemed') = (redeemed_session_id is not null and redeemed_at is not null))
);
create index if not exists ix_loyalty_rewards_plate_open
    on public.loyalty_rewards (lot_id, plate, created_at, id) where status = 'available';
create index if not exists ix_loyalty_rewards_expiry
    on public.loyalty_rewards (expires_at) where status = 'available';

create table if not exists public.loyalty_visits (
    id               bigserial   primary key,
    lot_id           integer     not null references public.parking_lots(id),
    plate            varchar(20) not null,
    session_id       integer     not null unique references public.parking_sessions(id) on delete cascade,
    business_day     date        not null,
    status           text        not null check (status in ('counted', 'skipped', 'reversed')),
    skip_reason      text        check (skip_reason in (
        'pass', 'lost_ticket', 'exempt', 'below_amount', 'below_minutes',
        'same_day', 'reward_redeemed', 'error')),
    amount           integer     not null default 0,
    progress_before  integer     not null default 0,
    earned_reward_id bigint      references public.loyalty_rewards(id) on delete set null,
    created_at       timestamptz not null default now(),
    reversed_at      timestamptz,
    reverse_reason   text,
    constraint loyalty_visits_skip_check check ((status = 'skipped') = (skip_reason is not null)
        or status = 'reversed')
);
create index if not exists ix_loyalty_visits_plate_day
    on public.loyalty_visits (lot_id, plate, business_day) where status = 'counted';
create index if not exists ix_loyalty_visits_created on public.loyalty_visits (lot_id, created_at);

create table if not exists public.loyalty_adjustments (
    id         bigserial   primary key,
    lot_id     integer     not null references public.parking_lots(id),
    plate      varchar(20) not null,
    delta      integer     not null check (delta <> 0 and delta between -50 and 50),
    reason     varchar(200) not null check (length(btrim(reason)) between 3 and 200),
    actor_id   integer     references public.users(id) on delete set null,
    progress_after integer not null,
    created_at timestamptz not null default now()
);

alter table public.loyalty_accounts enable row level security;
alter table public.loyalty_rewards enable row level security;
alter table public.loyalty_visits enable row level security;
alter table public.loyalty_adjustments enable row level security;
revoke all on public.loyalty_accounts from anon, authenticated;
revoke all on public.loyalty_rewards from anon, authenticated;
revoke all on public.loyalty_visits from anon, authenticated;
revoke all on public.loyalty_adjustments from anon, authenticated;
grant select on public.loyalty_accounts to authenticated;
grant select on public.loyalty_rewards to authenticated;
grant select on public.loyalty_visits to authenticated;
grant select on public.loyalty_adjustments to authenticated;

drop policy if exists loyalty_accounts_read on public.loyalty_accounts;
create policy loyalty_accounts_read on public.loyalty_accounts
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop policy if exists loyalty_rewards_read on public.loyalty_rewards;
create policy loyalty_rewards_read on public.loyalty_rewards
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop policy if exists loyalty_visits_read on public.loyalty_visits;
create policy loyalty_visits_read on public.loyalty_visits
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop policy if exists loyalty_adjustments_read on public.loyalty_adjustments;
create policy loyalty_adjustments_read on public.loyalty_adjustments
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop trigger if exists trg_audit_row on public.loyalty_rewards;
create trigger trg_audit_row after insert or update or delete
    on public.loyalty_rewards for each row execute function public.record_audit();
drop trigger if exists trg_audit_row on public.loyalty_adjustments;
create trigger trg_audit_row after insert or update or delete
    on public.loyalty_adjustments for each row execute function public.record_audit();

-- ---------------------------------------------------------------------------
-- Plate helper.
-- ---------------------------------------------------------------------------
create or replace function public.loyalty_norm_plate(p_plate text)
returns text
language sql
immutable
set search_path = public
as $$
    select upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
$$;

revoke all on function public.loyalty_norm_plate(text)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Internal readers shared by the hook, the trigger and the RPCs.
-- ---------------------------------------------------------------------------
create or replace function public.loyalty_settings_json(p_lot_id integer)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'enabled', coalesce(ps.loyalty_enabled, false),
        'visits_required', coalesce(ps.loyalty_visits_required, 5),
        'reward_kind', coalesce(ps.loyalty_reward_kind, 'free_stay'),
        'reward_max_amount', ps.loyalty_reward_max_amount,
        'reward_fixed_amount', coalesce(ps.loyalty_reward_fixed_amount, 0),
        'min_amount', coalesce(ps.loyalty_min_amount, 0),
        'min_minutes', coalesce(ps.loyalty_min_minutes, 0),
        'redeem_mode', coalesce(ps.loyalty_redeem_mode, 'auto'),
        'stack_with_merchant', coalesce(ps.loyalty_stack_with_merchant, true),
        'reward_valid_days', coalesce(ps.loyalty_reward_valid_days, 90)
    )
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;
$$;

revoke all on function public.loyalty_settings_json(integer)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The hook: reads, never writes, so the preview has no side effect.
-- ---------------------------------------------------------------------------
create or replace function public.fare_reward_step(
    p_session_id integer,
    p_running integer,
    p_merchant_total integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    session public.parking_sessions%rowtype;
    settings public.parking_settings%rowtype;
    plate_value text;
    progress integer := 0;
    required integer := 0;
    mode text := 'auto';
    reward public.loyalty_rewards%rowtype;
    available boolean := false;
    reason text;
    value integer := 0;
    amount integer := 0;
    info jsonb;
begin
    select * into session from public.parking_sessions s where s.id = p_session_id;
    if not found then
        return jsonb_build_object('amount', 0, 'line', null, 'info', null);
    end if;
    select * into settings from public.parking_settings ps where ps.lot_id = session.lot_id;
    if not found or not coalesce(settings.loyalty_enabled, false) then
        return jsonb_build_object('amount', 0, 'line', null, 'info', null);
    end if;

    select public.loyalty_norm_plate(v.plate) into plate_value
      from public.vehicles v where v.id = session.vehicle_id;
    select a.progress into progress
      from public.loyalty_accounts a
     where a.lot_id = session.lot_id and a.plate = plate_value;
    progress := coalesce(progress, 0);
    required := settings.loyalty_visits_required;
    mode := settings.loyalty_redeem_mode;

    select * into reward
      from public.loyalty_rewards r
     where r.lot_id = session.lot_id
       and r.plate = plate_value
       and r.status = 'available'
       and r.expires_at > now()
     order by r.created_at, r.id
     limit 1;
    available := found;

    info := jsonb_build_object(
        'available', available,
        'applied', false,
        'mode', mode,
        'progress', jsonb_build_object('visits', progress, 'required', required),
        'reason', null
    );

    if not available then
        return jsonb_build_object(
            'amount', 0, 'line', null,
            'info', info || jsonb_build_object('reason', 'none')
        );
    end if;

    -- Choice: `auto` applies unless the operator skipped it; `operator` only
    -- applies on an explicit `redeem`.
    if mode = 'operator' then
        if session.loyalty_choice is distinct from 'redeem' then
            reason := case when session.loyalty_choice = 'skip'
                then 'skipped' else 'operator_choice_pending' end;
        end if;
    elsif session.loyalty_choice = 'skip' then
        reason := 'skipped';
    end if;

    if reason is null
       and not coalesce(settings.loyalty_stack_with_merchant, true)
       and coalesce(p_merchant_total, 0) > 0 then
        reason := 'merchant';
    end if;

    if reason is null then
        if reward.kind = 'free_stay' then
            value := case when reward.max_amount is null then p_running
                else least(p_running, reward.max_amount) end;
        else
            value := least(p_running, reward.fixed_amount);
        end if;
        -- A reward never subsidises money already paid online (no refunds).
        value := least(value, greatest(p_running - coalesce(session.online_paid_amount, 0), 0));
        amount := least(greatest(value, 0), p_running);
        if amount <= 0 then
            reason := 'zero';
        end if;
    end if;

    if reason is not null then
        return jsonb_build_object(
            'amount', 0, 'line', null,
            'info', info || jsonb_build_object('reason', reason)
        );
    end if;

    return jsonb_build_object(
        'amount', amount,
        'line', jsonb_build_object(
            'type', 'reward',
            'ref_id', reward.id,
            'label', 'loyalty',
            'kind', reward.kind,
            'amount', amount
        ),
        'info', info || jsonb_build_object('applied', true, 'reason', null)
    );
end;
$$;

revoke all on function public.fare_reward_step(integer, integer, integer)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Accrual and redemption bookkeeping. Never raises: a loyalty bug must never
-- keep a customer inside.
-- ---------------------------------------------------------------------------
create or replace function public.loyalty_on_session_closed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    settings public.parking_settings%rowtype;
    account public.loyalty_accounts%rowtype;
    lot integer := new.lot_id;
    plate_value text;
    day_value date;
    tz text;
    line jsonb;
    redeemed_count integer := 0;
    skip_reason_value text;
    progress_after integer;
    reward_id bigint;
    required_value integer;
    today_count integer;
begin
    select * into settings from public.parking_settings ps where ps.lot_id = new.lot_id;
    if not found or not coalesce(settings.loyalty_enabled, false) then
        return new;
    end if;

    begin
        select public.loyalty_norm_plate(v.plate) into plate_value
          from public.vehicles v where v.id = new.vehicle_id;
        if plate_value is null or plate_value = '' then
            return new;
        end if;

        tz := coalesce(settings.business_timezone, 'America/Bogota');
        day_value := ((coalesce(new.exit_time, now())) at time zone tz)::date;

        perform pg_advisory_xact_lock(hashtext('loyalty:' || lot || ':' || plate_value));

        insert into public.loyalty_accounts (lot_id, plate)
        values (lot, plate_value)
        on conflict (lot_id, plate) do nothing;
        select * into account
          from public.loyalty_accounts a
         where a.lot_id = lot and a.plate = plate_value
         for update;

        -- A closing session that carries a reward line consumes it.
        for line in
            select value
              from jsonb_array_elements(coalesce(new.fare_adjustments, '[]'::jsonb))
             where value ->> 'type' = 'reward'
        loop
            update public.loyalty_rewards r
               set status = 'redeemed',
                   redeemed_session_id = new.id,
                   redeemed_at = now(),
                   redeemed_amount = coalesce((line ->> 'amount')::integer, 0)
             where r.id = (line ->> 'ref_id')::bigint
               and r.lot_id = lot
               and r.plate = plate_value
               and r.status = 'available';
            if found then
                redeemed_count := redeemed_count + 1;
            end if;
        end loop;

        if redeemed_count > 0 then
            update public.loyalty_accounts
               set redeemed_total = redeemed_total + redeemed_count,
                   updated_at = now()
             where id = account.id;
            account.redeemed_total := account.redeemed_total + redeemed_count;
        end if;

        -- First failing rule wins and is stored as the skip reason.
        required_value := settings.loyalty_visits_required;
        if redeemed_count > 0 then
            skip_reason_value := 'reward_redeemed';
        elsif new.payment_method = 'monthly_pass' then
            skip_reason_value := 'pass';
        elsif coalesce(new.lost_ticket, false) then
            skip_reason_value := 'lost_ticket';
        elsif new.payment_method = 'exempt' then
            skip_reason_value := 'exempt';
        elsif coalesce(new.amount_charged, 0) <= 0
           or coalesce(new.amount_charged, 0) < settings.loyalty_min_amount then
            skip_reason_value := 'below_amount';
        elsif new.exit_time is null
           or new.exit_time - new.entry_time
              < make_interval(mins => settings.loyalty_min_minutes) then
            skip_reason_value := 'below_minutes';
        else
            select count(*) into today_count
              from public.loyalty_visits v
             where v.lot_id = lot
               and v.plate = plate_value
               and v.business_day = day_value
               and v.status = 'counted';
            if today_count > 0 then
                skip_reason_value := 'same_day';
            end if;
        end if;

        if skip_reason_value is not null then
            insert into public.loyalty_visits (
                lot_id, plate, session_id, business_day, status, skip_reason,
                amount, progress_before
            )
            values (
                lot, plate_value, new.id, day_value, 'skipped', skip_reason_value,
                coalesce(new.amount_charged, 0), account.progress
            )
            on conflict (session_id) do nothing;
            return new;
        end if;

        insert into public.loyalty_visits (
            lot_id, plate, session_id, business_day, status,
            amount, progress_before
        )
        values (
            lot, plate_value, new.id, day_value, 'counted',
            coalesce(new.amount_charged, 0), account.progress
        )
        on conflict (session_id) do nothing;

        progress_after := account.progress + 1;
        update public.loyalty_accounts
           set progress = progress_after,
               last_counted_day = day_value,
               updated_at = now()
         where id = account.id;

        if progress_after >= required_value then
            insert into public.loyalty_rewards (
                lot_id, plate, kind, max_amount, fixed_amount, visits_required,
                earned_session_id, expires_at
            )
            values (
                lot, plate_value, settings.loyalty_reward_kind,
                settings.loyalty_reward_max_amount,
                settings.loyalty_reward_fixed_amount, required_value, new.id,
                now() + make_interval(days => settings.loyalty_reward_valid_days)
            )
            returning id into reward_id;

            update public.loyalty_visits
               set earned_reward_id = reward_id
             where session_id = new.id;

            update public.loyalty_accounts
               set progress = 0,
                   earned_total = earned_total + 1,
                   updated_at = now()
             where id = account.id;
        end if;

        return new;
    exception when others then
        begin
            insert into public.loyalty_visits (
                lot_id, plate, session_id, business_day, status, skip_reason,
                amount, progress_before
            )
            values (
                lot, coalesce(plate_value, ''), new.id,
                coalesce(day_value, current_date), 'skipped', 'error',
                coalesce(new.amount_charged, 0), coalesce(account.progress, 0)
            )
            on conflict (session_id) do nothing;
        exception when others then
            null;
        end;
        raise warning 'loyalty_on_session_closed: %', sqlerrm;
        return new;
    end;
end;
$$;

revoke all on function public.loyalty_on_session_closed()
    from public, anon, authenticated;

drop trigger if exists trg_loyalty_session_closed on public.parking_sessions;
create trigger trg_loyalty_session_closed
    after update of status on public.parking_sessions
    for each row
    when (old.status = 'open' and new.status = 'closed')
    execute function public.loyalty_on_session_closed();

-- ---------------------------------------------------------------------------
-- Redemption choice (before check-out, online only).
-- ---------------------------------------------------------------------------
create or replace function public.choose_loyalty_redemption(
    p_session_id integer,
    p_choice text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
    lot integer := public.current_lot_id();
    choice text := lower(btrim(coalesce(p_choice, '')));
    session public.parking_sessions%rowtype;
    settings public.parking_settings%rowtype;
    plate_value text;
    reward_available boolean := false;
begin
    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    if not found or not coalesce(settings.loyalty_enabled, false) then
        raise exception 'LoyaltyDisabledError';
    end if;
    if choice not in ('redeem', 'skip', 'auto') then
        raise exception 'InvalidLoyaltyChoiceError';
    end if;

    select * into session from public.parking_sessions s where s.id = p_session_id;
    if not found then
        raise exception 'SessionNotFoundError';
    end if;
    if session.status = 'closed' then
        raise exception 'SessionAlreadyClosedError';
    end if;
    if session.lot_id <> lot then
        raise exception 'LotRequiredError';
    end if;

    select public.loyalty_norm_plate(v.plate) into plate_value
      from public.vehicles v where v.id = session.vehicle_id;
    select exists (
        select 1 from public.loyalty_rewards r
         where r.lot_id = lot
           and r.plate = plate_value
           and r.status = 'available'
           and r.expires_at > now()
    ) into reward_available;

    if choice = 'redeem' and not reward_available then
        raise exception 'NoRewardAvailableError';
    end if;

    update public.parking_sessions
       set loyalty_choice = case when choice = 'auto' then null else choice end
     where id = session.id;

    return jsonb_build_object(
        'session_id', session.id,
        'choice', case when choice = 'auto' then null else choice end,
        'reward_available', reward_available
    );
end;
$$;

revoke all on function public.choose_loyalty_redemption(integer, text) from public;
grant execute on function public.choose_loyalty_redemption(integer, text)
    to authenticated;

-- ---------------------------------------------------------------------------
-- Operator read: counts only, never the visit history.
-- ---------------------------------------------------------------------------
create or replace function public.loyalty_plate_status(p_plate text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer;
    settings public.parking_settings%rowtype;
    plate_value text := public.loyalty_norm_plate(p_plate);
    visits integer := 0;
    required integer;
    reward_count integer := 0;
    soonest timestamptz;
    tz text;
    counted_today boolean := false;
begin
    perform public.require_app_user();
    lot := public.current_lot_id();
    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    if not found or not coalesce(settings.loyalty_enabled, false) then
        return jsonb_build_object('enabled', false);
    end if;
    if plate_value !~ '^[A-Z0-9-]{3,20}$' then
        raise exception 'InvalidPlateError';
    end if;

    required := settings.loyalty_visits_required;
    select coalesce(a.progress, 0) into visits
      from public.loyalty_accounts a
     where a.lot_id = lot and a.plate = plate_value;
    visits := coalesce(visits, 0);

    select count(*), min(r.expires_at)
      into reward_count, soonest
      from public.loyalty_rewards r
     where r.lot_id = lot
       and r.plate = plate_value
       and r.status = 'available'
       and r.expires_at > now();

    tz := coalesce(settings.business_timezone, 'America/Bogota');
    select exists (
        select 1 from public.loyalty_visits v
         where v.lot_id = lot
           and v.plate = plate_value
           and v.business_day = (now() at time zone tz)::date
           and v.status = 'counted'
    ) into counted_today;

    return jsonb_build_object(
        'enabled', true,
        'plate', plate_value,
        'visits', visits,
        'required', required,
        'next_visit', visits + 1,
        'reward_count', coalesce(reward_count, 0),
        'reward_expires_at', soonest,
        'redeem_mode', settings.loyalty_redeem_mode,
        'counted_today', counted_today
    );
end;
$$;

revoke all on function public.loyalty_plate_status(text) from public;
grant execute on function public.loyalty_plate_status(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Settings (lot admins).
-- ---------------------------------------------------------------------------
create or replace function public.get_loyalty_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
begin
    return public.loyalty_settings_json(lot);
end;
$$;

revoke all on function public.get_loyalty_settings() from public;
grant execute on function public.get_loyalty_settings() to authenticated;

create or replace function public.set_loyalty_settings(p_settings jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    settings public.parking_settings%rowtype;
    enabled boolean;
    required integer;
    kind text;
    max_amount integer;
    fixed_amount integer;
    min_amount integer;
    min_minutes integer;
    mode text;
    stack boolean;
    valid_days integer;
begin
    if p_settings is null or jsonb_typeof(p_settings) <> 'object' then
        raise exception 'InvalidLoyaltySettingsError';
    end if;
    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    if not found then
        raise exception 'LotRequiredError';
    end if;

    enabled := case when p_settings ? 'enabled'
        then coalesce((p_settings ->> 'enabled')::boolean, settings.loyalty_enabled)
        else settings.loyalty_enabled end;
    required := case when p_settings ? 'visits_required'
        then (p_settings ->> 'visits_required')::integer
        else settings.loyalty_visits_required end;
    kind := case when p_settings ? 'reward_kind'
        then (p_settings ->> 'reward_kind')
        else settings.loyalty_reward_kind end;
    max_amount := case when p_settings ? 'reward_max_amount'
        then (p_settings ->> 'reward_max_amount')::integer
        else settings.loyalty_reward_max_amount end;
    fixed_amount := case when p_settings ? 'reward_fixed_amount'
        then (p_settings ->> 'reward_fixed_amount')::integer
        else settings.loyalty_reward_fixed_amount end;
    min_amount := case when p_settings ? 'min_amount'
        then (p_settings ->> 'min_amount')::integer
        else settings.loyalty_min_amount end;
    min_minutes := case when p_settings ? 'min_minutes'
        then (p_settings ->> 'min_minutes')::integer
        else settings.loyalty_min_minutes end;
    mode := case when p_settings ? 'redeem_mode'
        then (p_settings ->> 'redeem_mode')
        else settings.loyalty_redeem_mode end;
    stack := case when p_settings ? 'stack_with_merchant'
        then (p_settings ->> 'stack_with_merchant')::boolean
        else settings.loyalty_stack_with_merchant end;
    valid_days := case when p_settings ? 'reward_valid_days'
        then (p_settings ->> 'reward_valid_days')::integer
        else settings.loyalty_reward_valid_days end;

    if required is null or required not between 2 and 50
       or kind is null or kind not in ('free_stay', 'fixed_amount')
       or (max_amount is not null and max_amount <= 0)
       or fixed_amount is null or fixed_amount < 0
       or (kind = 'fixed_amount' and fixed_amount <= 0)
       or min_amount is null or min_amount < 0
       or min_minutes is null or min_minutes not between 0 and 1440
       or mode is null or mode not in ('auto', 'operator')
       or valid_days is null or valid_days not between 7 and 730 then
        raise exception 'InvalidLoyaltySettingsError';
    end if;

    update public.parking_settings
       set loyalty_enabled = coalesce(enabled, false),
           loyalty_visits_required = required,
           loyalty_reward_kind = kind,
           loyalty_reward_max_amount = max_amount,
           loyalty_reward_fixed_amount = fixed_amount,
           loyalty_min_amount = min_amount,
           loyalty_min_minutes = min_minutes,
           loyalty_redeem_mode = mode,
           loyalty_stack_with_merchant = coalesce(stack, true),
           loyalty_reward_valid_days = valid_days
     where lot_id = lot;

    return public.loyalty_settings_json(lot);
end;
$$;

revoke all on function public.set_loyalty_settings(jsonb) from public;
grant execute on function public.set_loyalty_settings(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Manual correction (lot admins): bounded, audited, never mints a reward.
-- ---------------------------------------------------------------------------
create or replace function public.adjust_loyalty_progress(
    p_plate text,
    p_delta integer,
    p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    settings public.parking_settings%rowtype;
    plate_value text := public.loyalty_norm_plate(p_plate);
    reason text := btrim(coalesce(p_reason, ''));
    account public.loyalty_accounts%rowtype;
    next_progress integer;
begin
    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    if not found or not coalesce(settings.loyalty_enabled, false) then
        raise exception 'LoyaltyDisabledError';
    end if;
    if plate_value !~ '^[A-Z0-9-]{3,20}$' then
        raise exception 'InvalidPlateError';
    end if;
    if length(reason) < 3 or length(reason) > 200 then
        raise exception 'LoyaltyReasonRequiredError';
    end if;
    if p_delta is null or p_delta = 0 or p_delta not between -50 and 50 then
        raise exception 'LoyaltyAdjustRangeError';
    end if;

    select * into account
      from public.loyalty_accounts a
     where a.lot_id = lot and a.plate = plate_value
     for update;
    if not found then
        raise exception 'LoyaltyAccountNotFoundError';
    end if;

    next_progress := account.progress + p_delta;
    if next_progress < 0 or next_progress > settings.loyalty_visits_required - 1 then
        raise exception 'LoyaltyAdjustRangeError';
    end if;

    update public.loyalty_accounts
       set progress = next_progress, updated_at = now()
     where id = account.id;

    insert into public.loyalty_adjustments (
        lot_id, plate, delta, reason, actor_id, progress_after
    )
    values (
        lot, plate_value, p_delta, reason, public.current_app_user_id(), next_progress
    );

    return jsonb_build_object(
        'plate', plate_value,
        'progress', next_progress,
        'required', settings.loyalty_visits_required,
        'delta', p_delta
    );
end;
$$;

revoke all on function public.adjust_loyalty_progress(text, integer, text) from public;
grant execute on function public.adjust_loyalty_progress(text, integer, text)
    to authenticated;

-- ---------------------------------------------------------------------------
-- Reversal (internal): a future void feature, or by hand as postgres.
-- Reversal never creates a reward.
-- ---------------------------------------------------------------------------
create or replace function public.loyalty_reverse_visit(p_session_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    visit public.loyalty_visits%rowtype;
    account public.loyalty_accounts%rowtype;
    settings public.parking_settings%rowtype;
    reward public.loyalty_rewards%rowtype;
    new_progress integer;
    restored boolean := false;
    reversed_reward boolean := false;
begin
    select * into visit
      from public.loyalty_visits v
     where v.session_id = p_session_id
     for update;
    if not found or visit.status = 'reversed' then
        return jsonb_build_object(
            'reversed', false,
            'reward_reversed', false,
            'reward_restored', false,
            'progress', null
        );
    end if;

    perform pg_advisory_xact_lock(
        hashtext('loyalty:' || visit.lot_id || ':' || visit.plate)
    );
    select * into settings from public.parking_settings ps where ps.lot_id = visit.lot_id;
    select * into account
      from public.loyalty_accounts a
     where a.lot_id = visit.lot_id and a.plate = visit.plate
     for update;
    new_progress := coalesce(account.progress, 0);

    -- A reward consumed by this session comes back when it has not expired.
    select * into reward
      from public.loyalty_rewards r
     where r.lot_id = visit.lot_id
       and r.plate = visit.plate
       and r.redeemed_session_id = p_session_id
     order by r.id
     limit 1;
    if found then
        if reward.expires_at > now() then
            update public.loyalty_rewards
               set status = 'available',
                   redeemed_session_id = null,
                   redeemed_at = null,
                   redeemed_amount = null
             where id = reward.id;
            restored := true;
        else
            update public.loyalty_rewards
               set status = 'expired',
                   redeemed_session_id = null,
                   redeemed_at = null,
                   redeemed_amount = null
             where id = reward.id;
        end if;
        update public.loyalty_accounts
           set redeemed_total = greatest(redeemed_total - 1, 0),
               updated_at = now()
         where id = account.id;
    end if;

    if visit.status = 'counted' then
        if visit.earned_reward_id is not null then
            select * into reward from public.loyalty_rewards r
             where r.id = visit.earned_reward_id;
            if found and reward.status = 'available' then
                update public.loyalty_rewards
                   set status = 'reversed'
                 where id = reward.id;
                new_progress := greatest(
                    coalesce(settings.loyalty_visits_required, 5) - 1, 0);
                update public.loyalty_accounts
                   set progress = new_progress,
                       earned_total = greatest(earned_total - 1, 0),
                       updated_at = now()
                 where id = account.id;
                reversed_reward := true;
            end if;
            -- A redeemed (or expired) reward is kept: no clawback of a benefit
            -- already given.
        else
            new_progress := greatest(account.progress - 1, 0);
            update public.loyalty_accounts
               set progress = new_progress,
                   updated_at = now()
             where id = account.id;
        end if;
    end if;

    update public.loyalty_visits
       set status = 'reversed',
           reversed_at = now(),
           reverse_reason = 'void'
     where id = visit.id;

    update public.loyalty_accounts
       set last_counted_day = (
               select max(v.business_day) from public.loyalty_visits v
                where v.lot_id = visit.lot_id
                  and v.plate = visit.plate
                  and v.status = 'counted'
           ),
           updated_at = now()
     where id = account.id;

    return jsonb_build_object(
        'reversed', true,
        'reward_reversed', reversed_reward,
        'reward_restored', restored,
        'progress', new_progress
    );
end;
$$;

revoke all on function public.loyalty_reverse_visit(integer)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Expiry job.
-- ---------------------------------------------------------------------------
create or replace function public.loyalty_expire_rewards()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    expired integer;
begin
    update public.loyalty_rewards r
       set status = 'expired'
     where r.status = 'available'
       and r.expires_at <= now();
    get diagnostics expired = row_count;
    return expired;
end;
$$;

revoke all on function public.loyalty_expire_rewards()
    from public, anon, authenticated;
grant execute on function public.loyalty_expire_rewards() to service_role;
