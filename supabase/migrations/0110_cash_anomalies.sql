-- Cash anomalies: eight deterministic rules over the rows the lot already has.
--
-- Shifts, sessions, adjustments, discounts and notifications carry every datum
-- the standard cash-leak patterns need. This migration materialises one row per
-- detected anomaly (`cash_anomalies`, deduped per lot and subject), keeps the
-- thresholds in an **admin-only** table (`anomaly_settings`; `parking_settings`
-- is readable by every member, so the thresholds must not live there), and adds
-- the review workflow, the admin-only notification and the jobs entry points.
--
-- Thresholds are integers (percentages as whole percent, money in minor units)
-- so no floating-point comparison appears in the rules.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.anomaly_settings (
    id                       serial primary key,
    lot_id                   integer not null unique
                             references public.parking_lots(id) on delete cascade,
    enabled                  boolean not null default true,
    disabled_rules           text[]  not null default '{}',
    window_days              integer not null default 14
        check (window_days between 3 and 90),
    shortage_min_amount      integer not null default 5000
        check (shortage_min_amount between 1 and 100000000),
    shortage_min_shifts      integer not null default 3
        check (shortage_min_shifts between 2 and 20),
    lost_ticket_min_closed   integer not null default 10
        check (lost_ticket_min_closed between 3 and 1000),
    lost_ticket_min_rate_pct integer not null default 10
        check (lost_ticket_min_rate_pct between 1 and 100),
    lost_ticket_factor_pct   integer not null default 200
        check (lost_ticket_factor_pct between 110 and 1000),
    adjustment_min_amount    integer not null default 1000
        check (adjustment_min_amount between 0 and 100000000),
    short_stay_minutes       integer not null default 30
        check (short_stay_minutes between 1 and 720),
    discount_min_count       integer not null default 3
        check (discount_min_count between 1 and 1000),
    discount_share_pct       integer not null default 10
        check (discount_share_pct between 1 and 100),
    shift_open_hours         integer not null default 16
        check (shift_open_hours between 2 and 72),
    session_open_days        integer not null default 7
        check (session_open_days between 1 and 90),
    updated_at               timestamptz not null default now()
);

create table if not exists public.cash_anomalies (
    id              bigserial primary key,
    lot_id          integer not null references public.parking_lots(id) on delete cascade,
    rule            text    not null check (rule in (
        'shift_shortage', 'lost_ticket_rate', 'post_close_adjustment',
        'zero_charge', 'short_lost_ticket', 'discount_rate',
        'shift_open_long', 'session_open_long')),
    severity        text    not null check (severity in ('low', 'medium', 'high')),
    dedupe_key      text    not null,
    subject_user_id integer references public.users(id) on delete set null,
    shift_id        bigint  references public.shifts(id) on delete set null,
    session_id      integer references public.parking_sessions(id) on delete set null,
    details         jsonb   not null default '{}'::jsonb,
    status          text    not null default 'open'
        check (status in ('open', 'acknowledged', 'dismissed')),
    detected_at     timestamptz not null default now(),
    notified_at     timestamptz,
    resolved_by     integer references public.users(id) on delete set null,
    resolved_at     timestamptz,
    note            text check (note is null or char_length(btrim(note)) between 3 and 300),
    constraint cash_anomalies_dedupe unique (lot_id, dedupe_key)
);
create index if not exists ix_cash_anomalies_lot_status
    on public.cash_anomalies (lot_id, status, detected_at desc);
create index if not exists ix_cash_anomalies_unnotified
    on public.cash_anomalies (lot_id) where notified_at is null;

-- Supporting indexes (all `if not exists`; the first one is also declared by
-- the reports change, with the same definition, so the order does not matter).
create index if not exists ix_sessions_lot_exit_closed
    on public.parking_sessions (lot_id, exit_time) where status = 'closed';
create index if not exists ix_sessions_lot_exit_lost
    on public.parking_sessions (lot_id, exit_time) where lost_ticket;
create index if not exists ix_sessions_lot_exit_discount
    on public.parking_sessions (lot_id, exit_time) where discount_amount > 0;
create index if not exists ix_sessions_lot_exit_zero
    on public.parking_sessions (lot_id, exit_time)
    where status = 'closed' and amount_charged = 0;
create index if not exists ix_shifts_lot_closed
    on public.shifts (lot_id, closed_at) where closed_at is not null;
create index if not exists ix_shifts_lot_open
    on public.shifts (lot_id, opened_at) where closed_at is null;
create index if not exists ix_shift_adjustments_adjusted
    on public.shift_adjustments (adjusted_at desc);

-- ---------------------------------------------------------------------------
-- RLS, grants and audit
-- ---------------------------------------------------------------------------

alter table public.anomaly_settings enable row level security;
alter table public.cash_anomalies enable row level security;
revoke all on public.anomaly_settings, public.cash_anomalies from anon, authenticated;
grant select on public.anomaly_settings, public.cash_anomalies to authenticated;

drop policy if exists anomaly_settings_admin_read on public.anomaly_settings;
create policy anomaly_settings_admin_read on public.anomaly_settings
    for select to authenticated
    using (public.is_lot_admin(lot_id) and lot_id = public.current_lot_id());

drop policy if exists cash_anomalies_admin_read on public.cash_anomalies;
create policy cash_anomalies_admin_read on public.cash_anomalies
    for select to authenticated
    using (public.is_lot_admin(lot_id) and lot_id = public.current_lot_id());

drop trigger if exists trg_audit_row on public.cash_anomalies;
create trigger trg_audit_row after insert or update on public.cash_anomalies
    for each row execute function public.record_audit();

drop trigger if exists trg_audit_row on public.anomaly_settings;
create trigger trg_audit_row after insert or update on public.anomaly_settings
    for each row execute function public.record_audit();

insert into public.anomaly_settings (lot_id)
select l.id from public.parking_lots l
on conflict (lot_id) do nothing;

-- ---------------------------------------------------------------------------
-- Extension point: a later change (merchant validations, loyalty) explains
-- some zero charges; today none is explained.
-- ---------------------------------------------------------------------------

create or replace function public.anomaly_zero_charge_excluded(p_session_id integer)
returns boolean
language sql
stable
set search_path = public
as $$ select false $$;

revoke all on function public.anomaly_zero_charge_excluded(integer)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Rules. Each returns the number of rows inserted; every insert is deduped.
-- ---------------------------------------------------------------------------

create or replace function public.anomaly_rule_shift_shortage(
    p_lot integer,
    p_cfg public.anomaly_settings
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer;
    ws timestamptz := now() - make_interval(days => p_cfg.window_days);
begin
    insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key,
                                       subject_user_id, shift_id, details)
    select s.lot_id, 'shift_shortage',
           case when count(*) >= p_cfg.shortage_min_shifts * 2
                then 'high' else 'medium' end,
           'shift_shortage:' || s.operator_id || ':' || max(s.id),
           s.operator_id, max(s.id),
           jsonb_build_object(
               'shifts', count(*),
               'total_shortage', -sum(s.difference),
               'shift_ids', jsonb_agg(s.id order by s.id),
               'min_amount', p_cfg.shortage_min_amount,
               'window_days', p_cfg.window_days
           )
      from public.shifts s
     where s.lot_id = p_lot
       and s.closed_at >= ws
       and s.difference <= -p_cfg.shortage_min_amount
     group by s.lot_id, s.operator_id
    having count(*) >= p_cfg.shortage_min_shifts
    on conflict (lot_id, dedupe_key) do nothing;
    get diagnostics n = row_count;
    return n;
end;
$$;

create or replace function public.anomaly_rule_lost_ticket_rate(
    p_lot integer,
    p_cfg public.anomaly_settings
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer;
    ws timestamptz := now() - make_interval(days => p_cfg.window_days);
    tz text;
begin
    select coalesce(ps.business_timezone, 'America/Bogota') into tz
      from public.parking_settings ps where ps.lot_id = p_lot;
    tz := coalesce(tz, 'America/Bogota');
    with closed as (
        select sh.operator_id, s.lost_ticket
          from public.parking_sessions s
          join public.shifts sh on sh.id = s.shift_id
         where s.lot_id = p_lot and s.status = 'closed' and s.exit_time >= ws
    ), per_op as (
        select operator_id, count(*) as n, count(*) filter (where lost_ticket) as lost
          from closed group by operator_id
    ), tot as (
        -- Qualified: the plpgsql variable `n` is in scope too.
        select sum(po.n) as n, sum(po.lost) as lost from per_op po
    )
    insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key,
                                       subject_user_id, details)
    select p_lot, 'lost_ticket_rate',
           case when t.lost - p.lost = 0
                  or p.lost * 100 * (t.n - p.n) >= 300 * (t.lost - p.lost) * p.n
                then 'high' else 'medium' end,
           'lost_ticket_rate:' || p.operator_id || ':'
               || to_char(now() at time zone tz, 'IYYY-IW'),
           p.operator_id,
           jsonb_build_object(
               'closed', p.n, 'lost', p.lost,
               'rate_pct', round(p.lost * 100.0 / p.n, 1),
               'baseline_pct', round((t.lost - p.lost) * 100.0 / (t.n - p.n), 1),
               'window_days', p_cfg.window_days
           )
      from per_op p cross join tot t
     where p.n >= p_cfg.lost_ticket_min_closed
       and t.n > p.n
       and p.lost * 100 >= p_cfg.lost_ticket_min_rate_pct * p.n
       and p.lost * 100 * (t.n - p.n)
           >= p_cfg.lost_ticket_factor_pct * (t.lost - p.lost) * p.n
    on conflict (lot_id, dedupe_key) do nothing;
    get diagnostics n = row_count;
    return n;
end;
$$;

create or replace function public.anomaly_rule_post_close_adjustment(
    p_lot integer,
    p_cfg public.anomaly_settings
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer;
    ws timestamptz := now() - make_interval(days => p_cfg.window_days);
begin
    insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key,
                                       subject_user_id, shift_id, details)
    select sh.lot_id, 'post_close_adjustment',
           case when sa.old_difference < 0
                  and sa.new_difference > sa.old_difference
                then 'high' else 'medium' end,
           'post_close_adjustment:' || sa.id, sh.operator_id, sh.id,
           jsonb_build_object(
               'adjustment_id', sa.id,
               'old_difference', sa.old_difference,
               'new_difference', sa.new_difference,
               'reason', sa.reason,
               'adjusted_by', sa.adjusted_by,
               'adjusted_by_name', u.display_name
           )
      from public.shift_adjustments sa
      join public.shifts sh on sh.id = sa.shift_id
      left join public.users u on u.id = sa.adjusted_by
     where sh.lot_id = p_lot
       and sa.adjusted_at >= ws
       and abs(sa.new_difference - sa.old_difference) >= p_cfg.adjustment_min_amount
    on conflict (lot_id, dedupe_key) do nothing;
    get diagnostics n = row_count;
    return n;
end;
$$;

create or replace function public.anomaly_rule_zero_charge(
    p_lot integer,
    p_cfg public.anomaly_settings
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer;
    ws timestamptz := now() - make_interval(days => p_cfg.window_days);
begin
    insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key,
                                       subject_user_id, shift_id, session_id, details)
    select s.lot_id, 'zero_charge',
           case when s.payment_method in ('cash', 'card', 'transfer')
                  and s.discount_amount = 0
                then 'high' else 'medium' end,
           'zero_charge:' || s.id, sh.operator_id, s.shift_id, s.id,
           jsonb_build_object(
               'plate', v.plate,
               'ticket_number', s.ticket_number,
               'payment_method', s.payment_method,
               'discount_amount', s.discount_amount,
               'discount_reason', s.discount_reason,
               'exit_time', s.exit_time
           )
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      left join public.shifts sh on sh.id = s.shift_id
     where s.lot_id = p_lot
       and s.status = 'closed'
       and s.exit_time >= ws
       and s.amount_charged = 0
       and coalesce(s.payment_method, '') <> 'monthly_pass'
       and not public.anomaly_zero_charge_excluded(s.id)
    on conflict (lot_id, dedupe_key) do nothing;
    get diagnostics n = row_count;
    return n;
end;
$$;

create or replace function public.anomaly_rule_short_lost_ticket(
    p_lot integer,
    p_cfg public.anomaly_settings
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer;
    ws timestamptz := now() - make_interval(days => p_cfg.window_days);
begin
    insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key,
                                       subject_user_id, shift_id, session_id, details)
    select s.lot_id, 'short_lost_ticket', 'high',
           'short_lost_ticket:' || s.id, sh.operator_id, s.shift_id, s.id,
           jsonb_build_object(
               'plate', v.plate,
               'stay_minutes',
                   round(extract(epoch from s.exit_time - s.entry_time) / 60),
               'lost_ticket_reason', s.lost_ticket_reason,
               'amount_charged', s.amount_charged
           )
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      left join public.shifts sh on sh.id = s.shift_id
     where s.lot_id = p_lot
       and s.status = 'closed'
       and s.lost_ticket
       and s.exit_time >= ws
       and s.exit_time - s.entry_time
           < make_interval(mins => p_cfg.short_stay_minutes)
    on conflict (lot_id, dedupe_key) do nothing;
    get diagnostics n = row_count;
    return n;
end;
$$;

create or replace function public.anomaly_rule_discount_rate(
    p_lot integer,
    p_cfg public.anomaly_settings
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer;
    ws timestamptz := now() - make_interval(days => p_cfg.window_days);
    tz text;
begin
    select coalesce(ps.business_timezone, 'America/Bogota') into tz
      from public.parking_settings ps where ps.lot_id = p_lot;
    tz := coalesce(tz, 'America/Bogota');
    with d as (
        select s.discount_by as admin_id, count(*) as n,
               sum(s.discount_amount) as amount
          from public.parking_sessions s
         where s.lot_id = p_lot and s.status = 'closed'
           and s.exit_time >= ws
           and s.discount_amount > 0 and s.discount_by is not null
         group by s.discount_by
    ), tot as (
        select count(*) as n
          from public.parking_sessions s
         where s.lot_id = p_lot and s.status = 'closed' and s.exit_time >= ws
    )
    insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key,
                                       subject_user_id, details)
    select p_lot, 'discount_rate',
           case when d.n * 100 >= 300 * p_cfg.discount_share_pct * t.n
                then 'high' else 'medium' end,
           'discount_rate:' || d.admin_id || ':'
               || to_char(now() at time zone tz, 'IYYY-IW'),
           d.admin_id,
           jsonb_build_object(
               'discounts', d.n,
               'amount', d.amount,
               'share_pct', round(d.n * 100.0 / t.n, 1),
               'closed_total', t.n,
               'window_days', p_cfg.window_days
           )
      from d cross join tot t
     where d.n >= p_cfg.discount_min_count
       and d.n * 100 >= p_cfg.discount_share_pct * t.n
    on conflict (lot_id, dedupe_key) do nothing;
    get diagnostics n = row_count;
    return n;
end;
$$;

create or replace function public.anomaly_rule_shift_open_long(
    p_lot integer,
    p_cfg public.anomaly_settings
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer;
begin
    insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key,
                                       subject_user_id, shift_id, details)
    select s.lot_id, 'shift_open_long',
           case when s.opened_at <= now() - make_interval(hours => p_cfg.shift_open_hours * 2)
                then 'high' else 'medium' end,
           'shift_open_long:' || s.id, s.operator_id, s.id,
           jsonb_build_object(
               'opened_at', s.opened_at,
               'open_hours',
                   floor(extract(epoch from now() - s.opened_at) / 3600),
               'opening_float', s.opening_float
           )
      from public.shifts s
     where s.lot_id = p_lot
       and s.closed_at is null
       and s.opened_at < now() - make_interval(hours => p_cfg.shift_open_hours)
    on conflict (lot_id, dedupe_key) do nothing;
    get diagnostics n = row_count;
    return n;
end;
$$;

create or replace function public.anomaly_rule_session_open_long(
    p_lot integer,
    p_cfg public.anomaly_settings
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer;
    tz text;
begin
    select coalesce(ps.business_timezone, 'America/Bogota') into tz
      from public.parking_settings ps where ps.lot_id = p_lot;
    tz := coalesce(tz, 'America/Bogota');
    insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key,
                                       subject_user_id, session_id, details)
    select s.lot_id, 'session_open_long',
           case when s.entry_time
                     <= now() - make_interval(days => p_cfg.session_open_days * 2)
                then 'medium' else 'low' end,
           'session_open_long:' || s.id, s.operator_id, s.id,
           jsonb_build_object(
               'plate', v.plate,
               'open_days', floor(extract(epoch from now() - s.entry_time) / 86400),
               'entry_time', s.entry_time
           )
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
     where s.lot_id = p_lot
       and s.status = 'open'
       and s.entry_time < now() - make_interval(days => p_cfg.session_open_days)
       and not exists (
           select 1 from public.monthly_passes mp
            where mp.vehicle_id = s.vehicle_id
              and mp.lot_id = s.lot_id
              and mp.active
              and mp.start_date <= (now() at time zone tz)::date
              and mp.end_date >= (now() at time zone tz)::date
       )
    on conflict (lot_id, dedupe_key) do nothing;
    get diagnostics n = row_count;
    return n;
end;
$$;

revoke all on function public.anomaly_rule_shift_shortage(integer, public.anomaly_settings)
    from public, anon, authenticated;
revoke all on function public.anomaly_rule_lost_ticket_rate(integer, public.anomaly_settings)
    from public, anon, authenticated;
revoke all on function public.anomaly_rule_post_close_adjustment(integer, public.anomaly_settings)
    from public, anon, authenticated;
revoke all on function public.anomaly_rule_zero_charge(integer, public.anomaly_settings)
    from public, anon, authenticated;
revoke all on function public.anomaly_rule_short_lost_ticket(integer, public.anomaly_settings)
    from public, anon, authenticated;
revoke all on function public.anomaly_rule_discount_rate(integer, public.anomaly_settings)
    from public, anon, authenticated;
revoke all on function public.anomaly_rule_shift_open_long(integer, public.anomaly_settings)
    from public, anon, authenticated;
revoke all on function public.anomaly_rule_session_open_long(integer, public.anomaly_settings)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Detection and notification
-- ---------------------------------------------------------------------------

create or replace function public.detect_cash_anomalies()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    lot record;
    cfg public.anomaly_settings%rowtype;
    created integer := 0;
    fresh record;
begin
    if not pg_try_advisory_xact_lock(hashtext('detect_cash_anomalies')) then
        return 0;
    end if;
    for lot in select l.id from public.parking_lots l where l.active loop
        insert into public.anomaly_settings (lot_id) values (lot.id)
        on conflict (lot_id) do nothing;
        select * into cfg from public.anomaly_settings s where s.lot_id = lot.id;
        continue when not cfg.enabled;

        if not ('shift_shortage' = any (cfg.disabled_rules)) then
            created := created + public.anomaly_rule_shift_shortage(lot.id, cfg);
        end if;
        if not ('lost_ticket_rate' = any (cfg.disabled_rules)) then
            created := created + public.anomaly_rule_lost_ticket_rate(lot.id, cfg);
        end if;
        if not ('post_close_adjustment' = any (cfg.disabled_rules)) then
            created := created + public.anomaly_rule_post_close_adjustment(lot.id, cfg);
        end if;
        if not ('zero_charge' = any (cfg.disabled_rules)) then
            created := created + public.anomaly_rule_zero_charge(lot.id, cfg);
        end if;
        if not ('short_lost_ticket' = any (cfg.disabled_rules)) then
            created := created + public.anomaly_rule_short_lost_ticket(lot.id, cfg);
        end if;
        if not ('discount_rate' = any (cfg.disabled_rules)) then
            created := created + public.anomaly_rule_discount_rate(lot.id, cfg);
        end if;
        if not ('shift_open_long' = any (cfg.disabled_rules)) then
            created := created + public.anomaly_rule_shift_open_long(lot.id, cfg);
        end if;
        if not ('session_open_long' = any (cfg.disabled_rules)) then
            created := created + public.anomaly_rule_session_open_long(lot.id, cfg);
        end if;

        select count(*) as total,
               count(*) filter (where a.severity = 'high') as high,
               max(a.id) as last_id
          into fresh
          from public.cash_anomalies a
         where a.lot_id = lot.id
           and a.notified_at is null
           and a.severity in ('medium', 'high');
        if fresh.total > 0 then
            insert into public.notifications (
                user_id, type, title, body, data, dedupe_key, lot_id
            )
            select u.id, 'cash_anomaly', 'Anomalías de caja detectadas',
                   fresh.total || ' nuevas (' || fresh.high
                       || ' de severidad alta)',
                   jsonb_build_object(
                       'count', fresh.total,
                       'high', fresh.high,
                       'last_id', fresh.last_id
                   ),
                   'cash_anomaly:' || lot.id || ':' || fresh.last_id
                       || ':user:' || u.id,
                   lot.id
              from public.users u
             where u.is_active
               and exists (
                   select 1 from public.lot_members lm
                    where lm.user_id = u.id
                      and lm.lot_id = lot.id
                      and (u.role = 'admin' or lm.role = 'admin')
               )
            on conflict (dedupe_key) do nothing;
        end if;
        update public.cash_anomalies a
           set notified_at = now()
         where a.lot_id = lot.id and a.notified_at is null;
    end loop;
    return created;
end;
$$;

revoke all on function public.detect_cash_anomalies() from public, anon, authenticated;

create or replace function public.purge_cash_anomalies(p_days integer default 365)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    removed integer;
    stale integer;
    window_days integer := greatest(coalesce(p_days, 365), 30);
begin
    delete from public.cash_anomalies a
     where a.status <> 'open'
       and a.resolved_at < now() - make_interval(days => window_days);
    get diagnostics removed = row_count;
    delete from public.cash_anomalies a
     where a.status = 'open'
       and a.detected_at < now() - make_interval(days => window_days * 2);
    get diagnostics stale = row_count;
    removed := removed + stale;
    return removed;
end;
$$;

revoke all on function public.purge_cash_anomalies(integer)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Review RPCs (lot admin only)
-- ---------------------------------------------------------------------------

create or replace function public.list_cash_anomalies(
    p_status text default null,
    p_rule text default null,
    p_severity text default null,
    p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    items jsonb;
    open_total integer;
    limit_n integer := least(greatest(coalesce(p_limit, 100), 1), 500);
begin
    if p_status is not null
       and p_status not in ('open', 'acknowledged', 'dismissed') then
        raise exception 'InvalidDataError';
    end if;
    if p_severity is not null
       and p_severity not in ('low', 'medium', 'high') then
        raise exception 'InvalidDataError';
    end if;
    if p_rule is not null
       and p_rule not in ('shift_shortage', 'lost_ticket_rate',
                          'post_close_adjustment', 'zero_charge',
                          'short_lost_ticket', 'discount_rate',
                          'shift_open_long', 'session_open_long') then
        raise exception 'InvalidDataError';
    end if;

    select count(*) into open_total
      from public.cash_anomalies a
     where a.lot_id = lot and a.status = 'open';

    select coalesce(jsonb_agg(item order by detected_at desc, id desc), '[]'::jsonb)
      into items
      from (
          select jsonb_build_object(
                     'id', a.id, 'rule', a.rule, 'severity', a.severity,
                     'status', a.status, 'detected_at', a.detected_at,
                     'operator_id', a.subject_user_id,
                     'operator_name', u.display_name,
                     'shift_id', a.shift_id, 'session_id', a.session_id,
                     'plate', a.details ->> 'plate',
                     'details', a.details,
                     'resolved_at', a.resolved_at,
                     'resolved_by_name', ru.display_name,
                     'note', a.note
                 ) as item,
                 a.detected_at, a.id
            from public.cash_anomalies a
            left join public.users u on u.id = a.subject_user_id
            left join public.users ru on ru.id = a.resolved_by
           where a.lot_id = lot
             and (p_status is null or a.status = p_status)
             and (p_rule is null or a.rule = p_rule)
             and (p_severity is null or a.severity = p_severity)
           order by a.detected_at desc, a.id desc
           limit limit_n
      ) rows;

    return jsonb_build_object('open_count', open_total, 'items', items);
end;
$$;

revoke all on function public.list_cash_anomalies(text, text, text, integer)
    from public, anon;
grant execute on function public.list_cash_anomalies(text, text, text, integer)
    to authenticated;

create or replace function public.resolve_cash_anomaly(
    p_id bigint,
    p_status text,
    p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    actor integer := public.current_app_user_id();
    entry public.cash_anomalies%rowtype;
    clean_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
    if p_status not in ('acknowledged', 'dismissed') then
        raise exception 'InvalidAnomalyStatusError';
    end if;
    if p_status = 'dismissed'
       and (clean_note is null or char_length(clean_note) < 3
            or char_length(clean_note) > 300) then
        raise exception 'AnomalyNoteRequiredError';
    end if;

    select * into entry
      from public.cash_anomalies a
     where a.id = p_id
       for update;
    if not found or entry.lot_id <> lot then
        raise exception 'AnomalyNotFoundError';
    end if;
    if entry.status <> 'open' then
        raise exception 'AnomalyAlreadyResolvedError';
    end if;

    update public.cash_anomalies
       set status = p_status,
           resolved_by = actor,
           resolved_at = now(),
           note = clean_note
     where id = p_id
    returning * into entry;

    return jsonb_build_object(
        'id', entry.id, 'rule', entry.rule, 'severity', entry.severity,
        'status', entry.status, 'detected_at', entry.detected_at,
        'operator_id', entry.subject_user_id,
        'operator_name',
            (select u.display_name from public.users u where u.id = entry.subject_user_id),
        'shift_id', entry.shift_id, 'session_id', entry.session_id,
        'plate', entry.details ->> 'plate',
        'details', entry.details,
        'resolved_at', entry.resolved_at,
        'resolved_by_name',
            (select u.display_name from public.users u where u.id = entry.resolved_by),
        'note', entry.note
    );
end;
$$;

revoke all on function public.resolve_cash_anomaly(bigint, text, text)
    from public, anon;
grant execute on function public.resolve_cash_anomaly(bigint, text, text)
    to authenticated;

create or replace function public.get_anomaly_settings()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    cfg public.anomaly_settings%rowtype;
begin
    insert into public.anomaly_settings (lot_id) values (lot)
    on conflict (lot_id) do nothing;
    select * into cfg from public.anomaly_settings s where s.lot_id = lot;
    return jsonb_build_object(
        'enabled', cfg.enabled,
        'disabled_rules', to_jsonb(cfg.disabled_rules),
        'window_days', cfg.window_days,
        'shortage_min_amount', cfg.shortage_min_amount,
        'shortage_min_shifts', cfg.shortage_min_shifts,
        'lost_ticket_min_closed', cfg.lost_ticket_min_closed,
        'lost_ticket_min_rate_pct', cfg.lost_ticket_min_rate_pct,
        'lost_ticket_factor_pct', cfg.lost_ticket_factor_pct,
        'adjustment_min_amount', cfg.adjustment_min_amount,
        'short_stay_minutes', cfg.short_stay_minutes,
        'discount_min_count', cfg.discount_min_count,
        'discount_share_pct', cfg.discount_share_pct,
        'shift_open_hours', cfg.shift_open_hours,
        'session_open_days', cfg.session_open_days
    );
end;
$$;

revoke all on function public.get_anomaly_settings() from public, anon;
grant execute on function public.get_anomaly_settings() to authenticated;

create or replace function public.set_anomaly_settings(p_settings jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    cfg public.anomaly_settings%rowtype;
    key text;
    value jsonb;
    known text[] := array[
        'enabled', 'disabled_rules', 'window_days',
        'shortage_min_amount', 'shortage_min_shifts',
        'lost_ticket_min_closed', 'lost_ticket_min_rate_pct',
        'lost_ticket_factor_pct', 'adjustment_min_amount',
        'short_stay_minutes', 'discount_min_count', 'discount_share_pct',
        'shift_open_hours', 'session_open_days'
    ];
    rules text[] := array[
        'shift_shortage', 'lost_ticket_rate', 'post_close_adjustment',
        'zero_charge', 'short_lost_ticket', 'discount_rate',
        'shift_open_long', 'session_open_long'
    ];
    next_enabled boolean;
    next_rules text[];
    next_window integer;
    next_shortage_amount integer;
    next_shortage_shifts integer;
    next_lost_closed integer;
    next_lost_rate integer;
    next_lost_factor integer;
    next_adjustment integer;
    next_short_stay integer;
    next_discount_count integer;
    next_discount_share integer;
    next_shift_hours integer;
    next_session_days integer;
begin
    if p_settings is null or jsonb_typeof(p_settings) <> 'object' then
        raise exception 'InvalidAnomalySettingError';
    end if;
    for key, value in select * from jsonb_each(p_settings) loop
        if key <> all (known) then
            raise exception 'InvalidAnomalySettingError';
        end if;
        if key = 'enabled' then
            if jsonb_typeof(value) <> 'boolean' then
                raise exception 'InvalidAnomalySettingError';
            end if;
        elsif key = 'disabled_rules' then
            if jsonb_typeof(value) <> 'array'
               or exists (
                   select 1 from jsonb_array_elements_text(value) r
                    where r <> all (rules)
               ) then
                raise exception 'InvalidAnomalySettingError';
            end if;
        elsif jsonb_typeof(value) <> 'number'
              or (value #>> '{}')::numeric <> trunc((value #>> '{}')::numeric) then
            raise exception 'InvalidAnomalySettingError';
        end if;
    end loop;

    insert into public.anomaly_settings (lot_id) values (lot)
    on conflict (lot_id) do nothing;
    select * into cfg from public.anomaly_settings s where s.lot_id = lot;

    -- Validate the resulting row before touching it, so a bad combination is a
    -- typed error and not a check-constraint violation.
    next_enabled := coalesce((p_settings ->> 'enabled')::boolean, cfg.enabled);
    next_rules := coalesce(
        (select array_agg(r) from jsonb_array_elements_text(p_settings -> 'disabled_rules') r),
        cfg.disabled_rules
    );
    if p_settings ? 'disabled_rules' and p_settings -> 'disabled_rules' = '[]'::jsonb then
        next_rules := '{}';
    end if;
    next_window := coalesce((p_settings ->> 'window_days')::integer, cfg.window_days);
    next_shortage_amount := coalesce(
        (p_settings ->> 'shortage_min_amount')::integer, cfg.shortage_min_amount);
    next_shortage_shifts := coalesce(
        (p_settings ->> 'shortage_min_shifts')::integer, cfg.shortage_min_shifts);
    next_lost_closed := coalesce(
        (p_settings ->> 'lost_ticket_min_closed')::integer, cfg.lost_ticket_min_closed);
    next_lost_rate := coalesce(
        (p_settings ->> 'lost_ticket_min_rate_pct')::integer, cfg.lost_ticket_min_rate_pct);
    next_lost_factor := coalesce(
        (p_settings ->> 'lost_ticket_factor_pct')::integer, cfg.lost_ticket_factor_pct);
    next_adjustment := coalesce(
        (p_settings ->> 'adjustment_min_amount')::integer, cfg.adjustment_min_amount);
    next_short_stay := coalesce(
        (p_settings ->> 'short_stay_minutes')::integer, cfg.short_stay_minutes);
    next_discount_count := coalesce(
        (p_settings ->> 'discount_min_count')::integer, cfg.discount_min_count);
    next_discount_share := coalesce(
        (p_settings ->> 'discount_share_pct')::integer, cfg.discount_share_pct);
    next_shift_hours := coalesce(
        (p_settings ->> 'shift_open_hours')::integer, cfg.shift_open_hours);
    next_session_days := coalesce(
        (p_settings ->> 'session_open_days')::integer, cfg.session_open_days);

    if next_window not between 3 and 90
       or next_shortage_amount not between 1 and 100000000
       or next_shortage_shifts not between 2 and 20
       or next_lost_closed not between 3 and 1000
       or next_lost_rate not between 1 and 100
       or next_lost_factor not between 110 and 1000
       or next_adjustment not between 0 and 100000000
       or next_short_stay not between 1 and 720
       or next_discount_count not between 1 and 1000
       or next_discount_share not between 1 and 100
       or next_shift_hours not between 2 and 72
       or next_session_days not between 1 and 90 then
        raise exception 'InvalidAnomalySettingError';
    end if;

    update public.anomaly_settings
       set enabled = next_enabled,
           disabled_rules = next_rules,
           window_days = next_window,
           shortage_min_amount = next_shortage_amount,
           shortage_min_shifts = next_shortage_shifts,
           lost_ticket_min_closed = next_lost_closed,
           lost_ticket_min_rate_pct = next_lost_rate,
           lost_ticket_factor_pct = next_lost_factor,
           adjustment_min_amount = next_adjustment,
           short_stay_minutes = next_short_stay,
           discount_min_count = next_discount_count,
           discount_share_pct = next_discount_share,
           shift_open_hours = next_shift_hours,
           session_open_days = next_session_days,
           updated_at = now()
     where lot_id = lot;

    return public.get_anomaly_settings();
end;
$$;

revoke all on function public.set_anomaly_settings(jsonb) from public, anon;
grant execute on function public.set_anomaly_settings(jsonb) to authenticated;
