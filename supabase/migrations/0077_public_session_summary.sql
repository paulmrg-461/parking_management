-- Public summary for the customer QR page: duration and the current fare
-- (or the final charged amount for a closed session). The plate is the access
-- key, exactly like the public-evidence Edge Function; no other session data
-- is exposed.

create or replace function public.public_session_summary(
    p_session_id bigint,
    p_plate text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    row public.parking_sessions%rowtype;
    category_id integer;
    tz text;
    currency_code text;
    has_pass boolean;
    exit_at timestamptz;
    breakdown jsonb;
    amount integer;
begin
    if p_session_id is null or p_session_id <= 0 or length(normalized) < 3 then
        return null;
    end if;

    select s.* into row
      from public.parking_sessions s
     where s.id = p_session_id;
    if not found then
        return null;
    end if;

    select v.category_id into category_id
      from public.vehicles v
     where v.id = row.vehicle_id
       and upper(regexp_replace(v.plate, '\s', '', 'g')) = normalized;
    if not found then
        return null;
    end if;

    select coalesce(ps.business_timezone, 'America/Bogota'),
           coalesce(ps.currency, 'COP')
      into tz, currency_code
      from public.parking_settings ps
     where ps.lot_id = row.lot_id;
    tz := coalesce(tz, 'America/Bogota');
    currency_code := coalesce(currency_code, 'COP');

    exit_at := coalesce(row.exit_time, now());
    has_pass := exists (
        select 1
          from public.monthly_passes mp
         where mp.vehicle_id = row.vehicle_id
           and mp.lot_id = row.lot_id
           and mp.active
           and mp.start_date <= (now() at time zone tz)::date
           and mp.end_date >= (now() at time zone tz)::date
    );

    breakdown := public.fare_breakdown(
        category_id,
        row.entry_time,
        exit_at,
        has_pass
    );

    amount := case
        when row.status = 'closed'
            then coalesce(row.amount_charged, (breakdown ->> 'amount')::int)
        else (breakdown ->> 'amount')::int
    end;

    return jsonb_build_object(
        'session_id', row.id,
        'status', row.status,
        'entry_time', row.entry_time,
        'exit_time', row.exit_time,
        'duration_seconds', greatest(
            0,
            extract(epoch from (exit_at - row.entry_time))::int
        ),
        'currency', currency_code,
        'has_pass', has_pass,
        'amount', amount,
        'breakdown', breakdown
    );
end;
$$;

revoke all on function public.public_session_summary(bigint, text) from public;
grant execute on function public.public_session_summary(bigint, text)
    to anon, authenticated;
