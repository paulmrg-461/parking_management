-- Reports, period comparison: one request returns the trailing N calendar
-- months, each with the month before and the same month last year, so the app
-- never does date arithmetic. A running month is compared against the same
-- number of elapsed days (`is_partial`), which is what keeps "November, 10
-- days" from looking like a collapse next to a whole October.
--
-- Facts only: `covered` says whether the lot existed before the window; the
-- client decides whether a delta chip is meaningful (periodDelta).

create index if not exists ix_sessions_lot_exit_closed
    on public.parking_sessions (lot_id, exit_time)
    where status = 'closed';

create index if not exists ix_pass_payments_lot_paid
    on public.monthly_pass_payments (lot_id, paid_at)
    where status = 'paid';

create index if not exists ix_reservations_lot_from
    on public.category_reservations (lot_id, reserved_from);

analyze public.parking_sessions;
analyze public.monthly_pass_payments;
analyze public.category_reservations;

create or replace function public.report_period_comparison(
    p_months integer default 6,
    p_as_of date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    tz text;
    today date;
    as_of date;
    elapsed integer;
    first_activity date;
    buckets jsonb;
begin
    perform public.require_admin();

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    today := (now() at time zone tz)::date;
    as_of := coalesce(p_as_of, today);

    if p_months is null or p_months < 1 or p_months > 24 or as_of > today then
        raise exception 'InvalidReportRangeError';
    end if;
    elapsed := extract(day from as_of)::integer;

    select (min(s.entry_time) at time zone tz)::date into first_activity
      from public.parking_sessions s
     where s.lot_id = lot;

    with months as (
        select g as idx,
               (date_trunc('month', as_of::timestamp)
                    - make_interval(months => p_months - 1 - g))::date as m0
          from generate_series(0, p_months - 1) as g
    ),
    flagged as (
        select idx, m0,
               (m0 + interval '1 month')::date as m1,
               (idx = p_months - 1
                and (as_of < (m0 + interval '1 month')::date - 1 or as_of = today)
               ) as partial
          from months
    ),
    windows as (
        -- d0 inclusive, d1 exclusive, month_end = first day after the base month
        select idx, m0, partial, 'current'::text as kind,
               m0 as d0,
               case when partial then as_of + 1 else m1 end as d1,
               m1 as month_end
          from flagged
        union all
        select idx, m0, partial, 'previous_month',
               (m0 - interval '1 month')::date,
               case when partial
                    then least((m0 - interval '1 month')::date + elapsed, m0)
                    else m0 end,
               m0
          from flagged
        union all
        select idx, m0, partial, 'previous_year',
               (m0 - interval '1 year')::date,
               case when partial
                    then least((m0 - interval '1 year')::date + elapsed,
                               (m0 - interval '1 year' + interval '1 month')::date)
                    else (m0 - interval '1 year' + interval '1 month')::date end,
               (m0 - interval '1 year' + interval '1 month')::date
          from flagged
    ),
    measured as (
        select w.*, x.revenue, x.exits, x.stay_seconds,
               e.entries, p.pass_revenue, r.reservations, r.reservations_used
          from windows w
          cross join lateral (
              select coalesce(sum(s.amount_charged), 0) as revenue,
                     count(*) as exits,
                     coalesce(avg(extract(epoch from s.exit_time - s.entry_time)), 0)
                         as stay_seconds
                from public.parking_sessions s
               where s.lot_id = lot
                 and s.status = 'closed'
                 and s.exit_time >= w.d0::timestamp at time zone tz
                 and s.exit_time <  w.d1::timestamp at time zone tz
          ) x
          cross join lateral (
              select count(*) as entries
                from public.parking_sessions s
               where s.lot_id = lot
                 and s.entry_time >= w.d0::timestamp at time zone tz
                 and s.entry_time <  w.d1::timestamp at time zone tz
          ) e
          cross join lateral (
              select coalesce(sum(p.amount), 0) as pass_revenue
                from public.monthly_pass_payments p
               where p.lot_id = lot
                 and p.status = 'paid'
                 and p.paid_at >= w.d0::timestamp at time zone tz
                 and p.paid_at <  w.d1::timestamp at time zone tz
          ) p
          cross join lateral (
              select count(*) as reservations,
                     count(*) filter (where r.status = 'used') as reservations_used
                from public.category_reservations r
               where r.lot_id = lot
                 and r.reserved_from >= w.d0::timestamp at time zone tz
                 and r.reserved_from <  w.d1::timestamp at time zone tz
          ) r
    ),
    shaped as (
        select idx, m0, partial, kind,
               jsonb_build_object(
                   'start_date', to_char(d0, 'YYYY-MM-DD'),
                   'end_date', to_char(d1 - 1, 'YYYY-MM-DD'),
                   'days', d1 - d0,
                   'full_month', d1 = month_end,
                   'covered', first_activity is not null and first_activity <= d0,
                   'revenue', revenue,
                   'entries', entries,
                   'exits', exits,
                   'avg_ticket', case when exits = 0 then 0
                                      else (revenue / exits)::integer end,
                   'avg_stay_minutes', round(stay_seconds / 60.0)::integer,
                   'pass_revenue', pass_revenue,
                   'reservations', reservations,
                   'reservations_used', reservations_used
               ) as win
          from measured
    )
    select coalesce(jsonb_agg(bucket order by idx), '[]'::jsonb)
      into buckets
      from (
        select idx,
               jsonb_build_object(
                   'month', to_char(m0, 'YYYY-MM'),
                   'is_partial', bool_or(partial)
               ) || jsonb_object_agg(kind, win) as bucket
          from shaped
         group by idx, m0
      ) grouped;

    return jsonb_build_object(
        'lot_id', lot,
        'timezone', tz,
        'as_of', to_char(as_of, 'YYYY-MM-DD'),
        'months', p_months,
        'first_activity_date', case when first_activity is null then null
                                    else to_char(first_activity, 'YYYY-MM-DD') end,
        'buckets', buckets
    );
end;
$$;

revoke all on function public.report_period_comparison(integer, date) from public, anon;
grant execute on function public.report_period_comparison(integer, date) to authenticated;
