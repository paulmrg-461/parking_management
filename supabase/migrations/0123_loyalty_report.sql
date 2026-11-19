-- Loyalty rewards — the admin report and the members list.
-- Both are read-only and lot-admin only; the tables are admin-readable, but
-- operators get counts through `loyalty_plate_status` only.

create or replace function public.list_loyalty_accounts(
    p_search text default null,
    p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    search text := public.loyalty_norm_plate(p_search);
    max_rows integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
    return coalesce((
        select jsonb_agg(jsonb_build_object(
                   'plate', a.plate,
                   'progress', a.progress,
                   'earned_total', a.earned_total,
                   'redeemed_total', a.redeemed_total,
                   'reward_count', (
                       select count(*) from public.loyalty_rewards r
                        where r.lot_id = a.lot_id
                          and r.plate = a.plate
                          and r.status = 'available'
                          and r.expires_at > now()
                   ),
                   'last_counted_day', a.last_counted_day
               ) order by a.updated_at desc, a.id desc)
          from (
              select * from public.loyalty_accounts a
               where a.lot_id = lot
                 and (search = '' or a.plate like search || '%')
               order by a.updated_at desc, a.id desc
               limit max_rows
          ) a
    ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_loyalty_accounts(text, integer) from public;
grant execute on function public.list_loyalty_accounts(text, integer)
    to authenticated;

create or replace function public.report_loyalty(
    p_start_date date,
    p_end_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    settings public.parking_settings%rowtype;
    tz text;
    window_start timestamptz;
    window_end timestamptz;
    members integer;
    active_members integer;
    counted integer;
    skipped integer;
    reversed_visits integer;
    skipped_by_reason jsonb;
    earned integer;
    redeemed integer;
    expired integer;
    rewards_reversed integer;
    available integer;
    discount_given bigint;
    top_plates jsonb;
begin
    if p_start_date is null or p_end_date is null or p_start_date > p_end_date then
        raise exception 'InvalidReportRangeError';
    end if;
    if p_end_date - p_start_date > 366 then
        raise exception 'InvalidReportRangeError';
    end if;

    select * into settings from public.parking_settings ps where ps.lot_id = lot;
    tz := coalesce(settings.business_timezone, 'America/Bogota');
    window_start := p_start_date::timestamp at time zone tz;
    window_end := (p_end_date + 1)::timestamp at time zone tz;

    select count(*) into members
      from public.loyalty_accounts a
     where a.lot_id = lot
       and a.created_at < window_end;

    select coalesce(count(distinct v.plate), 0) into active_members
      from public.loyalty_visits v
     where v.lot_id = lot
       and v.status = 'counted'
       and v.created_at >= window_start
       and v.created_at < window_end;

    select count(*) filter (where v.status = 'counted'),
           count(*) filter (where v.status = 'skipped'),
           count(*) filter (where v.status = 'reversed')
      into counted, skipped, reversed_visits
      from public.loyalty_visits v
     where v.lot_id = lot
       and v.created_at >= window_start
       and v.created_at < window_end;

    select coalesce(jsonb_agg(jsonb_build_object(
               'reason', s.reason, 'count', s.total
           ) order by s.total desc, s.reason), '[]'::jsonb)
      into skipped_by_reason
      from (
          select v.skip_reason as reason, count(*) as total
            from public.loyalty_visits v
           where v.lot_id = lot
             and v.status = 'skipped'
             and v.skip_reason is not null
             and v.created_at >= window_start
             and v.created_at < window_end
           group by v.skip_reason
      ) s;

    select count(*) filter (where r.created_at >= window_start and r.created_at < window_end),
           count(*) filter (where r.redeemed_at >= window_start and r.redeemed_at < window_end),
           count(*) filter (where r.status = 'expired'
                              and r.created_at >= window_start
                              and r.created_at < window_end),
           count(*) filter (where r.status = 'reversed'
                              and r.created_at >= window_start
                              and r.created_at < window_end)
      into earned, redeemed, expired, rewards_reversed
      from public.loyalty_rewards r
     where r.lot_id = lot;

    select count(*) into available
      from public.loyalty_rewards r
     where r.lot_id = lot
       and r.status = 'available'
       and r.expires_at > now();

    select coalesce(sum(r.redeemed_amount), 0) into discount_given
      from public.loyalty_rewards r
     where r.lot_id = lot
       and r.redeemed_at >= window_start
       and r.redeemed_at < window_end;

    select coalesce(jsonb_agg(jsonb_build_object(
               'plate', t.plate,
               'counted', t.counted,
               'redeemed', t.redeemed,
               'discount', t.discount
           ) order by t.counted desc, t.plate), '[]'::jsonb)
      into top_plates
      from (
          select v.plate,
                 count(*) as counted,
                 (
                     select count(*) from public.loyalty_rewards r
                      where r.lot_id = lot
                        and r.plate = v.plate
                        and r.redeemed_at >= window_start
                        and r.redeemed_at < window_end
                 ) as redeemed,
                 (
                     select coalesce(sum(r.redeemed_amount), 0)
                       from public.loyalty_rewards r
                      where r.lot_id = lot
                        and r.plate = v.plate
                        and r.redeemed_at >= window_start
                        and r.redeemed_at < window_end
                 ) as discount
            from public.loyalty_visits v
           where v.lot_id = lot
             and v.status = 'counted'
             and v.created_at >= window_start
             and v.created_at < window_end
           group by v.plate
           order by count(*) desc, v.plate
           limit 10
      ) t;

    return jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'enabled', coalesce(settings.loyalty_enabled, false),
        'members', members,
        'active_members', active_members,
        'visits', jsonb_build_object(
            'counted', counted,
            'skipped', skipped,
            'reversed', reversed_visits,
            'skipped_by_reason', skipped_by_reason
        ),
        'rewards', jsonb_build_object(
            'earned', earned,
            'redeemed', redeemed,
            'expired', expired,
            'reversed', rewards_reversed,
            'available', available
        ),
        'discount_given', discount_given,
        'top_plates', top_plates
    );
end;
$$;

revoke all on function public.report_loyalty(date, date) from public;
grant execute on function public.report_loyalty(date, date)
    to authenticated;
