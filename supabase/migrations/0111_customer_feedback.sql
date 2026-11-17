-- Customer feedback: one short survey per closed session, keyed by the
-- session id plus the plate the receipt already carries.
--
-- The table is read-only for clients. Both public functions are security
-- definer (the caller is anonymous) and derive the lot from the session, never
-- from the request. The report is admin-only and lot-scoped like every other
-- report.

create table if not exists public.session_feedback (
    id          bigint generated always as identity primary key,
    lot_id      integer     not null references public.parking_lots(id),
    session_id  bigint      not null references public.parking_sessions(id),
    rating      smallint    not null check (rating between 1 and 5),
    comment     text        not null default '' check (char_length(comment) <= 500),
    created_at  timestamptz not null default now(),
    unique (session_id)
);

create index if not exists ix_feedback_lot_created
    on public.session_feedback(lot_id, created_at desc);

alter table public.session_feedback enable row level security;

revoke all on public.session_feedback from public, anon, authenticated;
grant select on public.session_feedback to authenticated;

drop policy if exists feedback_read_lot on public.session_feedback;
create policy feedback_read_lot on public.session_feedback
    for select to authenticated
    using (lot_id = public.current_lot_id());

-- ---------------------------------------------------------------------------
-- Public lookup: what the survey page shows before the customer rates.
-- Unknown session or a wrong plate returns null (no "not found" error for a
-- customer who mistyped the plate).
-- ---------------------------------------------------------------------------
create or replace function public.public_feedback_session(
    p_session_id bigint,
    p_plate text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    found_session record;
    rated smallint;
begin
    if p_session_id is null or normalized = '' then
        return null;
    end if;

    select s.id, s.lot_id, s.exit_time, l.name as lot_name
      into found_session
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.parking_lots l on l.id = s.lot_id
     where s.id = p_session_id
       and upper(regexp_replace(v.plate, '\s', '', 'g')) = normalized;

    if not found then
        return null;
    end if;

    select f.rating into rated
      from public.session_feedback f
     where f.session_id = found_session.id;

    return jsonb_build_object(
        'lot_id', found_session.lot_id,
        'lot_name', found_session.lot_name,
        'rateable', found_session.exit_time is not null,
        'rated', rated is not null,
        'rating', rated
    );
end;
$$;

revoke all on function public.public_feedback_session(bigint, text)
    from public, anon;
grant execute on function public.public_feedback_session(bigint, text)
    to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Public submit: the plate is the key, the session must be closed and the row
-- is written once.
-- ---------------------------------------------------------------------------
create or replace function public.public_submit_feedback(
    p_session_id bigint,
    p_plate text,
    p_rating integer,
    p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    trimmed text := btrim(coalesce(p_comment, ''));
    found_session record;
    stored public.session_feedback%rowtype;
begin
    if p_rating is null or p_rating < 1 or p_rating > 5 then
        raise exception 'InvalidDataError';
    end if;
    if char_length(trimmed) > 500 then
        raise exception 'InvalidDataError';
    end if;

    select s.id, s.lot_id
      into found_session
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
     where s.id = p_session_id
       and s.exit_time is not null
       and upper(regexp_replace(v.plate, '\s', '', 'g')) = normalized;

    if not found then
        raise exception 'SessionNotFoundError';
    end if;

    insert into public.session_feedback (lot_id, session_id, rating, comment)
    values (found_session.lot_id, found_session.id, p_rating::smallint, trimmed)
    on conflict (session_id) do nothing
    returning * into stored;

    if stored.id is null then
        raise exception 'FeedbackAlreadyError';
    end if;

    return jsonb_build_object(
        'rating', stored.rating,
        'created_at', stored.created_at
    );
end;
$$;

revoke all on function public.public_submit_feedback(bigint, text, integer, text)
    from public, anon;
grant execute on function public.public_submit_feedback(bigint, text, integer, text)
    to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Admin report: integer-only figures so the client never averages floats.
-- ---------------------------------------------------------------------------
create or replace function public.feedback_summary(
    p_days integer default 30
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
    start_date date;
    end_date date;
    total integer;
    average_x10 integer;
    closed_sessions integer;
    low_count integer;
    response_rate_bp integer;
    distribution jsonb;
    recent jsonb;
begin
    perform public.require_admin();

    if p_days is null or p_days < 1 or p_days > 365 then
        raise exception 'InvalidReportRangeError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');

    end_date := (now() at time zone tz)::date;
    start_date := end_date - (p_days - 1);

    select count(*),
           coalesce(round(avg(f.rating) * 10)::integer, 0),
           coalesce(count(*) filter (where f.rating <= 3), 0)
      into total, average_x10, low_count
      from public.session_feedback f
     where f.lot_id = lot
       and (f.created_at at time zone tz)::date between start_date and end_date;

    select count(*) into closed_sessions
      from public.parking_sessions s
     where s.lot_id = lot
       and s.exit_time is not null
       and (s.exit_time at time zone tz)::date between start_date and end_date;

    response_rate_bp := case
        when closed_sessions = 0 then 0
        else round(total * 10000.0 / closed_sessions)::integer
    end;

    select jsonb_object_agg(b.rating::text, b.total order by b.rating) into distribution
      from (
          select g.rating, count(f.id) as total
            from generate_series(1, 5) as g(rating)
            left join public.session_feedback f
              on f.rating = g.rating
             and f.lot_id = lot
             and (f.created_at at time zone tz)::date between start_date and end_date
           group by g.rating
      ) b;

    select coalesce(jsonb_agg(row_to_json(r)::jsonb order by r.created_at desc, r.id desc), '[]'::jsonb)
      into recent
      from (
          select f.id, f.session_id, v.plate, f.rating, f.comment, f.created_at
            from public.session_feedback f
            join public.parking_sessions s on s.id = f.session_id
            join public.vehicles v on v.id = s.vehicle_id
           where f.lot_id = lot
             and (f.created_at at time zone tz)::date between start_date and end_date
           order by f.created_at desc, f.id desc
           limit 20
      ) r;

    return jsonb_build_object(
        'days', p_days,
        'start_date', start_date,
        'end_date', end_date,
        'timezone', tz,
        'total', total,
        'average_x10', average_x10,
        'closed_sessions', closed_sessions,
        'response_rate_bp', response_rate_bp,
        'low_count', low_count,
        'distribution', distribution,
        'recent', recent
    );
end;
$$;

revoke all on function public.feedback_summary(integer)
    from public, anon;
grant execute on function public.feedback_summary(integer) to authenticated;
