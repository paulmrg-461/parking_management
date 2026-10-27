-- Lot scoping for RPCs, policies and reports.
--
-- The active lot comes from `current_lot_id()` (x-lot-id header validated
-- against `lot_members`, falling back to the user's lowest membership). Every
-- security-definer RPC filters or stamps that lot explicitly, because definer
-- functions bypass RLS.

-- ---------------------------------------------------------------------------
-- Active lot resolution. The `x-lot-id` header selects a lot; membership is
-- always validated here, so a forged header can never read another site.
-- Without a header (console, cron, single-lot installs) the user's lowest
-- membership wins.
-- ---------------------------------------------------------------------------
create or replace function public.lot_from_header()
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    raw text;
begin
    begin
        raw := coalesce(
            current_setting('request.headers', true)::json ->> 'x-lot-id', ''
        );
    exception when others then
        raw := '';
    end;
    if raw ~ '^[0-9]+$' then
        return raw::integer;
    end if;
    return null;
end;
$$;

create or replace function public.current_lot_id()
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    uid integer := public.current_app_user_id();
    candidate integer := public.lot_from_header();
    lot integer;
begin
    if uid is null then
        raise exception 'InvalidTokenError';
    end if;
    if candidate is not null then
        if exists (
            select 1 from public.lot_members lm
             where lm.user_id = uid and lm.lot_id = candidate
        ) then
            return candidate;
        end if;
        raise exception 'LotRequiredError';
    end if;
    select lm.lot_id into lot
      from public.lot_members lm
     where lm.user_id = uid
     order by lm.lot_id
     limit 1;
    if lot is null then
        raise exception 'LotRequiredError';
    end if;
    return lot;
end;
$$;

create or replace function public.is_lot_admin(p_lot_id integer default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select public.is_admin() or exists (
        select 1 from public.lot_members lm
         where lm.user_id = public.current_app_user_id()
           and lm.lot_id = coalesce(p_lot_id, public.current_lot_id())
           and lm.role = 'admin'
    );
$$;

create or replace function public.require_lot_admin()
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
begin
    if not public.is_lot_admin(lot) then
        raise exception 'AdminRequiredError';
    end if;
    return lot;
end;
$$;

-- ---------------------------------------------------------------------------
-- Lot administration (platform admins only).
-- ---------------------------------------------------------------------------
create or replace function public.create_lot(
    p_code text,
    p_name text,
    p_address text default '',
    p_timezone text default 'America/Bogota'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_admin();
    code text := upper(btrim(coalesce(p_code, '')));
    lot public.parking_lots%rowtype;
begin
    if code !~ '^[A-Z0-9]{2,10}$' then
        raise exception 'InvalidLotCodeError';
    end if;
    if nullif(btrim(coalesce(p_name, '')), '') is null then
        raise exception 'InvalidDataError';
    end if;

    begin
        insert into public.parking_lots (code, name, address, timezone)
        values (code, btrim(p_name), coalesce(p_address, ''), coalesce(p_timezone, 'America/Bogota'))
        returning * into lot;
    exception when unique_violation then
        raise exception 'DuplicateLotCodeError';
    end;

    insert into public.parking_settings (lot_id, name, address)
    values (lot.id, lot.name, lot.address)
    on conflict (lot_id) do nothing;

    insert into public.lot_members (user_id, lot_id, role)
    values (actor, lot.id, 'admin')
    on conflict (user_id, lot_id) do update set role = 'admin';

    return jsonb_build_object(
        'id', lot.id,
        'code', lot.code,
        'name', lot.name,
        'address', lot.address,
        'timezone', lot.timezone,
        'active', lot.active
    );
end;
$$;

create or replace function public.update_lot(
    p_id integer,
    p_name text default null,
    p_address text default null,
    p_timezone text default null,
    p_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot public.parking_lots%rowtype;
begin
    perform public.require_admin();
    select * into lot from public.parking_lots l where l.id = p_id for update;
    if not found then
        raise exception 'LotNotFoundError';
    end if;
    update public.parking_lots
       set name = coalesce(nullif(btrim(coalesce(p_name, '')), ''), name),
           address = coalesce(p_address, address),
           timezone = coalesce(nullif(btrim(coalesce(p_timezone, '')), ''), timezone),
           active = coalesce(p_active, active)
     where id = lot.id
     returning * into lot;
    return jsonb_build_object(
        'id', lot.id,
        'code', lot.code,
        'name', lot.name,
        'address', lot.address,
        'timezone', lot.timezone,
        'active', lot.active
    );
end;
$$;

create or replace function public.list_lots()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    result jsonb;
begin
    perform public.require_admin();
    select coalesce(jsonb_agg(item order by item ->> 'name'), '[]'::jsonb)
      into result
      from (
        select jsonb_build_object(
                   'id', l.id,
                   'code', l.code,
                   'name', l.name,
                   'address', l.address,
                   'timezone', l.timezone,
                   'active', l.active,
                   'members', (select count(*) from public.lot_members lm where lm.lot_id = l.id)
               ) as item
          from public.parking_lots l
      ) rows;
    return result;
end;
$$;

create or replace function public.my_lots()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
    result jsonb;
begin
    select coalesce(jsonb_agg(item order by item ->> 'name'), '[]'::jsonb)
      into result
      from (
        select jsonb_build_object(
                   'id', l.id,
                   'code', l.code,
                   'name', l.name,
                   'timezone', l.timezone,
                   'role', lm.role,
                   'active', l.active
               ) as item
          from public.lot_members lm
          join public.parking_lots l on l.id = lm.lot_id
         where lm.user_id = uid
      ) rows;
    return result;
end;
$$;

create or replace function public.set_lot_member(
    p_user_id integer,
    p_lot_id integer,
    p_role text default 'operator'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    role_value text := coalesce(p_role, 'operator');
    existing_role text;
begin
    perform public.require_admin();
    if role_value not in ('operator', 'admin') then
        raise exception 'InvalidDataError';
    end if;
    if not exists (select 1 from public.parking_lots l where l.id = p_lot_id) then
        raise exception 'LotNotFoundError';
    end if;
    if not exists (select 1 from public.users u where u.id = p_user_id) then
        raise exception 'UserNotFoundError';
    end if;

    select lm.role into existing_role
      from public.lot_members lm
     where lm.user_id = p_user_id and lm.lot_id = p_lot_id;

    if existing_role = 'admin' and role_value <> 'admin' then
        if not exists (
            select 1 from public.lot_members lm
             where lm.lot_id = p_lot_id
               and lm.role = 'admin'
               and lm.user_id <> p_user_id
        ) then
            raise exception 'LastAdminError';
        end if;
    end if;

    insert into public.lot_members (user_id, lot_id, role)
    values (p_user_id, p_lot_id, role_value)
    on conflict (user_id, lot_id) do update set role = excluded.role;

    return jsonb_build_object(
        'user_id', p_user_id,
        'lot_id', p_lot_id,
        'role', role_value
    );
end;
$$;


-- ---------------------------------------------------------------------------
-- Re-scope every site-owned table. Reads resolve the active lot; writes stay
-- with lot admins (or platform admins).
-- ---------------------------------------------------------------------------
drop policy if exists categories_read on public.categories;
create policy categories_read on public.categories
    for select to authenticated
    using (lot_id = public.current_lot_id());

drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write on public.categories
    for all to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id))
    with check (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop policy if exists tariffs_read on public.tariffs;
create policy tariffs_read on public.tariffs
    for select to authenticated
    using (lot_id = public.current_lot_id());

drop policy if exists tariffs_admin_write on public.tariffs;
create policy tariffs_admin_write on public.tariffs
    for all to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id))
    with check (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop policy if exists sessions_read on public.parking_sessions;
create policy sessions_read on public.parking_sessions
    for select to authenticated
    using (lot_id = public.current_lot_id());

drop policy if exists evidence_read on public.evidence_photos;
create policy evidence_read on public.evidence_photos
    for select to authenticated
    using (
        exists (
            select 1 from public.parking_sessions s
             where s.id = session_id
               and s.lot_id = public.current_lot_id()
        )
    );

drop policy if exists passes_read on public.monthly_passes;
create policy passes_read on public.monthly_passes
    for select to authenticated
    using (lot_id = public.current_lot_id());

drop policy if exists passes_admin_write on public.monthly_passes;
create policy passes_admin_write on public.monthly_passes
    for all to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id))
    with check (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop policy if exists settings_read on public.parking_settings;
create policy settings_read on public.parking_settings
    for select to authenticated
    using (lot_id = public.current_lot_id());

-- Branding must render on the login screen before sign-in: we cannot resolve a
-- lot there, so anonymous clients only see the first lot's identity.
drop policy if exists settings_public_read on public.parking_settings;
create policy settings_public_read on public.parking_settings
    for select to anon
    using (lot_id = (select min(l.id) from public.parking_lots l));

drop policy if exists settings_admin_write on public.parking_settings;
create policy settings_admin_write on public.parking_settings
    for all to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id))
    with check (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop policy if exists pass_payments_admin_read on public.monthly_pass_payments;
create policy pass_payments_admin_read on public.monthly_pass_payments
    for select to authenticated
    using (public.is_lot_admin(lot_id) and lot_id = public.current_lot_id());

drop policy if exists reservation_read on public.category_reservations;
create policy reservation_read on public.category_reservations
    for select to authenticated
    using (lot_id = public.current_lot_id());

drop policy if exists shifts_read_own_or_admin on public.shifts;
create policy shifts_read_own_or_admin on public.shifts
    for select to authenticated
    using (
        lot_id = public.current_lot_id()
        and (operator_id = public.current_app_user_id() or public.is_lot_admin(lot_id))
    );

drop policy if exists cash_movements_read_own_or_admin on public.cash_movements;
create policy cash_movements_read_own_or_admin on public.cash_movements
    for select to authenticated
    using (
        exists (
            select 1 from public.shifts s
             where s.id = shift_id
               and s.lot_id = public.current_lot_id()
               and (s.operator_id = public.current_app_user_id()
                    or public.is_lot_admin(s.lot_id))
        )
    );

drop policy if exists shift_adjustments_admin_read on public.shift_adjustments;
create policy shift_adjustments_admin_read on public.shift_adjustments
    for select to authenticated
    using (
        exists (
            select 1 from public.shifts s
             where s.id = shift_id
               and s.lot_id = public.current_lot_id()
               and public.is_lot_admin(s.lot_id)
        )
    );

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications
    for select to authenticated
    using (
        user_id = public.current_app_user_id()
        and (lot_id is null or lot_id = public.current_lot_id())
    );

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
    discounts bigint;
    discounted_sessions bigint;
    pass_revenue bigint;
    by_day jsonb;
    by_category jsonb;
    by_payment jsonb;
    pass_by_payment jsonb;
    audit jsonb;
begin
    perform public.require_admin();
    if p_start_date > p_end_date then
        raise exception 'InvalidReportRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where lot_id = public.current_lot_id();
    tz := coalesce(tz, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    select coalesce(sum(s.amount_charged), 0),
           coalesce(sum(s.discount_amount), 0),
           count(*) filter (where s.discount_amount > 0)
      into total, discounts, discounted_sessions
      from public.parking_sessions s
     where s.status = 'closed'
       and s.lot_id = public.current_lot_id()
       and s.exit_time >= window_start
       and s.exit_time < window_end;

    select coalesce(sum(p.amount), 0) into pass_revenue
      from public.monthly_pass_payments p
     where p.status = 'paid'
       and p.paid_at >= window_start
       and p.paid_at < window_end;

    select coalesce(jsonb_agg(item order by item ->> 'date'), '[]'::jsonb) into by_day
      from (
        select jsonb_build_object(
                   'date', to_char(exit_time at time zone tz, 'YYYY-MM-DD'),
                   'amount', coalesce(sum(amount_charged), 0)
               ) as item
          from public.parking_sessions s
         where s.status = 'closed'
       and s.lot_id = public.current_lot_id()
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
       and s.lot_id = public.current_lot_id()
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
       and s.lot_id = public.current_lot_id()
           and s.exit_time >= window_start
           and s.exit_time < window_end
         group by coalesce(payment_method, 'unknown')
      ) payments;

    select coalesce(jsonb_agg(item order by item ->> 'payment_method'), '[]'::jsonb)
      into pass_by_payment
      from (
        select jsonb_build_object(
                   'payment_method', p.payment_method,
                   'amount', coalesce(sum(p.amount), 0)
               ) as item
          from public.monthly_pass_payments p
         where p.status = 'paid'
           and p.paid_at >= window_start
           and p.paid_at < window_end
         group by p.payment_method
      ) pass_payments;

    select coalesce(jsonb_agg(item order by item ->> 'discount_at' desc), '[]'::jsonb)
      into audit
      from (
        select jsonb_build_object(
                   'session_id', s.id,
                   'plate', v.plate,
                   'ticket_number', s.ticket_number,
                   'amount_charged', s.amount_charged,
                   'discount_amount', s.discount_amount,
                   'discount_reason', s.discount_reason,
                   'discount_at', s.discount_at,
                   'admin', u.username
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.users u on u.id = s.discount_by
         where s.status = 'closed'
       and s.lot_id = public.current_lot_id()
           and s.discount_amount > 0
           and s.exit_time >= window_start
           and s.exit_time < window_end
         order by s.discount_at desc
         limit 50
      ) discounts_log;

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'total', total,
        'pass_revenue', pass_revenue,
        'total_discounts', discounts,
        'discounted_sessions', discounted_sessions,
        'by_day', by_day,
        'by_category', by_category,
        'by_payment', by_payment,
        'pass_by_payment', pass_by_payment,
        'discount_audit', audit
    );
end;
$$;

create or replace function public.report_revenue_all(p_start_date date, p_end_date date)
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
    discounts bigint;
    discounted_sessions bigint;
    pass_revenue bigint;
    by_day jsonb;
    by_category jsonb;
    by_payment jsonb;
    pass_by_payment jsonb;
    audit jsonb;
begin
    perform public.require_admin();
    if p_start_date > p_end_date then
        raise exception 'InvalidReportRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where lot_id = public.current_lot_id();
    tz := coalesce(tz, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    select coalesce(sum(s.amount_charged), 0),
           coalesce(sum(s.discount_amount), 0),
           count(*) filter (where s.discount_amount > 0)
      into total, discounts, discounted_sessions
      from public.parking_sessions s
     where s.status = 'closed'
       and s.exit_time >= window_start
       and s.exit_time < window_end;

    select coalesce(sum(p.amount), 0) into pass_revenue
      from public.monthly_pass_payments p
     where p.status = 'paid'
       and p.paid_at >= window_start
       and p.paid_at < window_end;

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

    select coalesce(jsonb_agg(item order by item ->> 'payment_method'), '[]'::jsonb)
      into pass_by_payment
      from (
        select jsonb_build_object(
                   'payment_method', p.payment_method,
                   'amount', coalesce(sum(p.amount), 0)
               ) as item
          from public.monthly_pass_payments p
         where p.status = 'paid'
           and p.paid_at >= window_start
           and p.paid_at < window_end
         group by p.payment_method
      ) pass_payments;

    select coalesce(jsonb_agg(item order by item ->> 'discount_at' desc), '[]'::jsonb)
      into audit
      from (
        select jsonb_build_object(
                   'session_id', s.id,
                   'plate', v.plate,
                   'ticket_number', s.ticket_number,
                   'amount_charged', s.amount_charged,
                   'discount_amount', s.discount_amount,
                   'discount_reason', s.discount_reason,
                   'discount_at', s.discount_at,
                   'admin', u.username
               ) as item
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.users u on u.id = s.discount_by
         where s.status = 'closed'
           and s.discount_amount > 0
           and s.exit_time >= window_start
           and s.exit_time < window_end
         order by s.discount_at desc
         limit 50
      ) discounts_log;

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'total', total,
        'by_lot', (
            select coalesce(jsonb_agg(item order by item ->> 'lot'), '[]'::jsonb)
              from (
                select jsonb_build_object(
                           'lot', l.name,
                           'lot_id', l.id,
                           'amount', coalesce(sum(s.amount_charged), 0)
                       ) as item
                  from public.parking_sessions s
                  join public.parking_lots l on l.id = s.lot_id
                 where s.status = 'closed'
                   and s.exit_time >= window_start
                   and s.exit_time < window_end
                 group by l.id, l.name
              ) lots
        ),
        'pass_revenue', pass_revenue,
        'total_discounts', discounts,
        'discounted_sessions', discounted_sessions,
        'by_day', by_day,
        'by_category', by_category,
        'by_payment', by_payment,
        'pass_by_payment', pass_by_payment,
        'discount_audit', audit
    );
end;
$$;

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

    select coalesce(ps.business_timezone, 'America/Bogota') into tz
      from public.parking_settings ps
      join public.categories c on c.lot_id = ps.lot_id
     where c.id = p_category_id;
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
       and public.current_app_role() is distinct from 'admin' then
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

create or replace function public.open_shift(p_opening_float integer default 0)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
    shift_id bigint;
begin
    if coalesce(p_opening_float, 0) < 0 then
        raise exception 'InvalidOpeningFloatError';
    end if;
    begin
        insert into public.shifts (operator_id, opening_float, lot_id)
        values (uid, coalesce(p_opening_float, 0), public.current_lot_id())
        returning id into shift_id;
    exception when unique_violation then
        raise exception 'ShiftAlreadyOpenError';
    end;
    return public.shift_totals(shift_id);
end;
$$;

create or replace function public.current_shift()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    shift_id bigint;
begin
    select s.id into shift_id
      from public.shifts s
     where s.operator_id = public.current_app_user_id()
       and s.lot_id = public.current_lot_id()
       and s.closed_at is null
     order by s.opened_at desc
     limit 1;
    if shift_id is null then
        return null;
    end if;
    return public.shift_totals(shift_id);
end;
$$;

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
begin
    if counted < 0 then
        raise exception 'InvalidCountedCashError';
    end if;

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

    insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
    select u.id,
           'shift_closed',
           'Turno cerrado',
           'Diferencia de caja: $' || (counted - expected),
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

create or replace function public.add_cash_movement(
    p_type text,
    p_amount integer,
    p_reason text
)
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
     limit 1;
    if shift_id is null then
        raise exception 'NoOpenShiftError';
    end if;

    insert into public.cash_movements (shift_id, type, amount, reason, created_by)
    values (shift_id, p_type, p_amount, btrim(p_reason), uid);

    return public.shift_totals(shift_id);
end;
$$;

create or replace function public.list_shifts(p_limit integer default 20)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    result jsonb;
begin
    perform public.require_admin();
    select coalesce(jsonb_agg(item order by item ->> 'opened_at' desc), '[]'::jsonb)
      into result
      from (
        select public.shift_totals(s.id) as item
          from (
            select id from public.shifts
             where lot_id = public.current_lot_id()
             order by opened_at desc
             limit greatest(p_limit, 1)
          ) s
      ) rows;
    return result;
end;
$$;

create or replace function public.adjust_shift(
    p_shift_id bigint,
    p_counted_cash integer,
    p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_admin();
    shift public.shifts%rowtype;
    new_difference integer;
begin
    if coalesce(p_counted_cash, -1) < 0 then
        raise exception 'InvalidCountedCashError';
    end if;
    if p_reason is null or length(btrim(p_reason)) = 0 then
        raise exception 'ShiftAdjustmentReasonRequired';
    end if;

    select * into shift from public.shifts s where s.id = p_shift_id for update;
    if not found then
        raise exception 'ShiftNotFoundError';
    end if;
    if shift.closed_at is null then
        raise exception 'ShiftStillOpenError';
    end if;
    if shift.lot_id <> public.current_lot_id() then
        raise exception 'LotRequiredError';
    end if;

    new_difference := p_counted_cash - shift.expected_cash;

    insert into public.shift_adjustments (
        shift_id, old_counted, new_counted,
        old_difference, new_difference, reason, adjusted_by
    )
    values (
        shift.id, coalesce(shift.counted_cash, 0), p_counted_cash,
        coalesce(shift.difference, 0), new_difference,
        btrim(p_reason), actor
    );

    update public.shifts
       set counted_cash = p_counted_cash,
           difference = new_difference
     where id = shift.id;

    return public.shift_totals(shift.id);
end;
$$;

create or replace function public.pending_pass_payments()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    result jsonb;
begin
    perform public.require_admin();
    select coalesce(jsonb_agg(item order by item ->> 'due_date'), '[]'::jsonb)
      into result
      from (
        select jsonb_build_object(
                   'id', p.id,
                   'monthly_pass_id', p.monthly_pass_id,
                   'vehicle_id', mp.vehicle_id,
                   'plate', v.plate,
                   'start_date', mp.start_date,
                   'end_date', mp.end_date,
                   'amount', p.amount,
                   'payment_method', p.payment_method,
                   'status', p.status,
                   'due_date', p.due_date
               ) as item
          from public.monthly_pass_payments p
          join public.monthly_passes mp on mp.id = p.monthly_pass_id
          join public.vehicles v on v.id = mp.vehicle_id
         where p.status = 'pending'
           and p.lot_id = public.current_lot_id()
         order by p.due_date
      ) rows;
    return result;
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
         limit 1;
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

    with candidates as (
        select mp.*, (mp.end_date - mp.start_date + 1) as duration_days
          from public.monthly_passes mp
         where mp.active
           and mp.auto_renew
           and mp.end_date <= current_date
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
               c.end_date + c.duration_days,
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

    update public.monthly_passes mp
       set active = false
     where mp.id in (select renewed_from_id from renewed_passes)
       and mp.end_date <= current_date;

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

create or replace function public.notify_expiring_monthly_passes()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
    select u.id,
           'monthly_pass_expiring',
           'Mensualidad por vencer',
           'La mensualidad del vehículo ' || v.plate || ' vence el ' ||
               to_char(mp.end_date, 'DD/MM/YYYY'),
           jsonb_build_object(
               'monthly_pass_id', mp.id,
               'vehicle_id', mp.vehicle_id,
               'plate', v.plate,
               'end_date', mp.end_date
           ),
           'pass_expiry:' || mp.id || ':' || mp.end_date || ':user:' || u.id,
           mp.lot_id
      from public.monthly_passes mp
      join public.vehicles v on v.id = mp.vehicle_id
      join public.users u on u.role = 'admin' and u.is_active
     where mp.active
       and not mp.auto_renew
       and exists (
           select 1 from public.lot_members lm
            where lm.user_id = u.id and lm.lot_id = mp.lot_id
       )
       and mp.end_date = current_date + 3
    on conflict (dedupe_key) do nothing;
    get diagnostics changed = row_count;
    return changed;
end;
$$;

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
      from public.parking_settings where lot_id = new.lot_id;
    tz := coalesce(tz, 'America/Bogota');

    if tg_op = 'INSERT' and new.status = 'open' then
        select v.plate into plate_value from public.vehicles v where v.id = new.vehicle_id;
        insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
        select u.id,
               'check_in',
               'Vehículo ' || plate_value || ' ingresó',
               'Entrada registrada a las ' ||
                   to_char(new.entry_time at time zone tz, 'HH24:MI'),
               jsonb_build_object('session_id', new.id, 'plate', plate_value),
               'check_in:' || new.id || ':user:' || u.id,
               new.lot_id
          from public.users u
         where u.role = 'admin' and u.is_active
           and exists (
               select 1 from public.lot_members lm
                where lm.user_id = u.id and lm.lot_id = new.lot_id
           )
        on conflict (dedupe_key) do nothing;
    elsif tg_op = 'UPDATE' and new.status = 'closed' and old.status = 'open' then
        select v.plate into plate_value from public.vehicles v where v.id = new.vehicle_id;
        amount_value := coalesce(new.amount_charged, 0);
        insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
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
               'check_out:' || new.id || ':user:' || u.id,
               new.lot_id
          from public.users u
         where u.role = 'admin' and u.is_active
           and exists (
               select 1 from public.lot_members lm
                where lm.user_id = u.id and lm.lot_id = new.lot_id
           )
        on conflict (dedupe_key) do nothing;
    end if;
    return new;
end;
$$;

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
    select overstay_hours into hours
      from public.parking_settings
     where lot_id = public.current_lot_id();
    hours := coalesce(hours, 24);

    insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
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
           'overstay:' || s.id || ':' || current_date || ':user:' || u.id,
           s.lot_id
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.users u on u.role = 'admin' and u.is_active
      cross join lateral (
          select coalesce(business_timezone, 'America/Bogota') as tz
            from public.parking_settings where id = 1
      ) zone
     where s.status = 'open'
       and s.lot_id = public.current_lot_id()
       and s.entry_time < now() - make_interval(hours => hours)
       and exists (
           select 1 from public.lot_members lm
            where lm.user_id = u.id and lm.lot_id = s.lot_id
       )
    on conflict (dedupe_key) do nothing;

    get diagnostics changed = row_count;
    return changed;
end;
$$;

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
        if not exists (
            select 1 from public.categories c
             where c.id = p_category_id
               and c.lot_id = public.current_lot_id()
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
           and c.lot_id = public.current_lot_id()
    ) then
        if p_category_id is not null and exists (
            select 1 from public.categories c
             where c.id = p_category_id
               and c.lot_id = public.current_lot_id()
        ) then
            vehicle.category_id := p_category_id;
        else
            select c2.id into vehicle.category_id
              from public.categories c2
              join public.categories c1 on c1.name = c2.name
             where c1.id = vehicle.category_id
               and c2.lot_id = public.current_lot_id()
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
       and lot_id = public.current_lot_id()
       and status = 'active'
       and reserved_until > now();

    begin
        insert into public.parking_sessions (
            vehicle_id, operator_id, entry_time, status, lot_id
        )
        values (
            vehicle.id, operator_id, entry_at, 'open', public.current_lot_id()
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
    p_lost_ticket_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor_id integer := public.require_app_user();
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
    if session.lot_id <> public.current_lot_id() then
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

create or replace function public.enforce_category_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    category integer;
    capacity integer;
    open_count integer;
    reserved_count integer;
begin
    select v.category_id into category from public.vehicles v where v.id = new.vehicle_id;
    if category is null then
        return new;
    end if;
    perform pg_advisory_xact_lock(hashtext('category:' || category));
    select c.capacity into capacity from public.categories c where c.id = category;
    if coalesce(capacity, 0) > 0 then
        select count(*) into open_count
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where v.category_id = category
           and s.status = 'open'
           and s.lot_id = new.lot_id;
        select count(*) into reserved_count
          from public.category_reservations r
         where r.category_id = category
           and r.lot_id = new.lot_id
           and r.status = 'active'
           and r.reserved_until > now();
        if open_count + reserved_count >= capacity then
            raise exception 'CategoryFullError';
        end if;
    end if;
    return new;
end;
$$;

create or replace function public.occupancy_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    total bigint;
    total_capacity bigint;
    total_reserved bigint;
    by_category jsonb;
begin
    perform public.require_app_user();

    select count(*) into total
      from public.parking_sessions s
     where s.status = 'open'
       and s.lot_id = public.current_lot_id();

    select coalesce(sum(c.capacity), 0) into total_capacity
      from public.categories c
     where c.capacity > 0
       and c.lot_id = public.current_lot_id();

    select count(*) into total_reserved
      from public.category_reservations r
     where r.status = 'active'
       and r.reserved_until > now()
       and r.lot_id = public.current_lot_id();

    select coalesce(jsonb_agg(item order by item ->> 'category_name'), '[]'::jsonb)
      into by_category
      from (
        select jsonb_build_object(
                   'category_id', c.id,
                   'category_name', c.name,
                   'count', count(s.id),
                   'capacity', c.capacity,
                   'reserved', coalesce((
                       select count(*) from public.category_reservations r
                        where r.category_id = c.id
                          and r.lot_id = public.current_lot_id()
                          and r.status = 'active'
                          and r.reserved_until > now()
                   ), 0),
                   'available', greatest(
                       c.capacity
                       - count(s.id)
                       - coalesce((
                           select count(*) from public.category_reservations r
                            where r.category_id = c.id
                              and r.status = 'active'
                              and r.reserved_until > now()
                         ), 0),
                       0
                   ),
                   'is_full', (
                       c.capacity > 0
                       and count(s.id) + coalesce((
                           select count(*) from public.category_reservations r
                            where r.category_id = c.id
                              and r.lot_id = public.current_lot_id()
                              and r.status = 'active'
                              and r.reserved_until > now()
                         ), 0) >= c.capacity
                   )
               ) as item
          from public.categories c
          left join public.vehicles v on v.category_id = c.id
          left join public.parking_sessions s
            on s.vehicle_id = v.id and s.status = 'open'
           and s.lot_id = public.current_lot_id()
         where c.lot_id = public.current_lot_id()
         group by c.id, c.name, c.capacity
      ) categories;

    return jsonb_build_object(
        'total_open', total,
        'total_reserved', total_reserved,
        'lot_id', public.current_lot_id(),
        'total_capacity', total_capacity,
        'by_category', by_category
    );
end;
$$;

create or replace function public.create_reservation(
    p_plate text,
    p_category_id integer,
    p_until timestamptz,
    p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    capacity integer;
    open_count integer;
    reserved_count integer;
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

    perform pg_advisory_xact_lock(hashtext('category:' || p_category_id));

    select c.capacity into capacity
      from public.categories c
     where c.id = p_category_id
       and c.lot_id = public.current_lot_id();
    if not found then
        raise exception 'CategoryNotFoundError';
    end if;

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
           and s.lot_id = public.current_lot_id();
        select count(*) into reserved_count
          from public.category_reservations r
         where r.category_id = p_category_id
           and r.lot_id = public.current_lot_id()
           and r.status = 'active'
           and r.reserved_until > now();
        if open_count + reserved_count >= capacity then
            raise exception 'CategoryFullError';
        end if;
    end if;

    insert into public.category_reservations (
        plate, category_id, reserved_until, notes, created_by, lot_id
    )
    values (
        normalized, p_category_id, p_until,
        nullif(btrim(coalesce(p_notes, '')), ''), actor, public.current_lot_id()
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

create or replace function public.cancel_reservation(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    reservation public.category_reservations%rowtype;
begin
    perform public.require_app_user();
    select * into reservation
      from public.category_reservations r
     where r.id = p_id
     for update;
    if not found then
        raise exception 'ReservationNotFoundError';
    end if;
    if reservation.lot_id <> public.current_lot_id() then
        raise exception 'LotRequiredError';
    end if;
    if reservation.status <> 'active' then
        raise exception 'ReservationNotActiveError';
    end if;
    update public.category_reservations
       set status = 'cancelled'
     where id = reservation.id
     returning * into reservation;
    return jsonb_build_object('id', reservation.id, 'status', reservation.status);
end;
$$;

create or replace function public.vehicle_history(p_plate text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    vehicle public.vehicles%rowtype;
    category_name text;
    result jsonb;
begin
    perform public.require_app_user();
    if normalized = '' then
        raise exception 'VehicleNotFoundError';
    end if;

    select * into vehicle from public.vehicles v where v.plate = normalized;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;
    select c.name into category_name
      from public.categories c where c.id = vehicle.category_id;

    select jsonb_build_object(
        'plate', vehicle.plate,
        'vehicle_id', vehicle.id,
        'category_id', vehicle.category_id,
        'category_name', category_name,
        'color', vehicle.color,
        'brand', vehicle.brand,
        'is_blacklisted', vehicle.is_blacklisted,
        'notes', vehicle.notes,
        'visits', count(*),
        'current_lot_visits', count(*) filter (where s.lot_id = public.current_lot_id()),
        'total_spent', coalesce(sum(s.amount_charged) filter (where s.status = 'closed'), 0),
        'open_sessions', count(*) filter (where s.status = 'open'),
        'sessions', coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'id', s.id,
                    'entry_time', s.entry_time,
                    'exit_time', s.exit_time,
                    'status', s.status,
                    'amount_charged', s.amount_charged,
                    'ticket_number', s.ticket_number,
                    'payment_method', s.payment_method,
                    'lost_ticket', s.lost_ticket,
                    'lot_id', s.lot_id,
                    'lot_name', (select l.name from public.parking_lots l where l.id = s.lot_id),
                    'duration_seconds', case
                        when s.exit_time is not null
                            then extract(epoch from s.exit_time - s.entry_time)::bigint
                        else extract(epoch from now() - s.entry_time)::bigint
                    end
                )
                order by s.entry_time desc
            ),
            '[]'::jsonb
        )
    ) into result
      from public.parking_sessions s
     where s.vehicle_id = vehicle.id;

    return result;
end;
$$;

grant execute on function public.current_lot_id() to authenticated;
grant execute on function public.is_lot_admin(integer) to authenticated;
grant execute on function public.require_lot_admin() to authenticated;
grant execute on function public.create_lot(text, text, text, text) to authenticated;
grant execute on function public.update_lot(integer, text, text, text, boolean) to authenticated;
grant execute on function public.list_lots() to authenticated;
grant execute on function public.my_lots() to authenticated;
grant execute on function public.set_lot_member(integer, integer, text) to authenticated;
grant execute on function public.report_revenue_all(date, date) to authenticated;

grant execute on function public.report_revenue_all(date, date) to authenticated;
grant execute on function public.calculate_fare(integer, timestamptz, timestamptz, boolean) to authenticated;
