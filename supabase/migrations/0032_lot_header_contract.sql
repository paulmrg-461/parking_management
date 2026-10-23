-- Contract step of the multi-lot rollout: the `x-lot-id` header is now
-- mandatory. Every client sends it (the Flutter app sets it at startup and
-- after login), so an absent header is a bug and fails closed instead of
-- silently writing to the user's first lot.
--
-- Console/Studio sessions run as a superuser (no RLS helper involved) and the
-- scheduled jobs avoid `current_lot_id()` entirely, so they keep working.

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
begin
    if uid is null then
        raise exception 'InvalidTokenError';
    end if;
    if candidate is null then
        raise exception 'LotRequiredError';
    end if;
    if not exists (
        select 1 from public.lot_members lm
         where lm.user_id = uid and lm.lot_id = candidate
    ) then
        raise exception 'LotRequiredError';
    end if;
    return candidate;
end;
$$;

-- Overstay alerts are a cron job and no longer tied to one active lot: each
-- session is measured against its own lot's threshold and timezone, and only
-- the admins of that lot are notified.
create or replace function public.notify_overstays()
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
           'overstay',
           'Vehículo ' || v.plate || ' lleva más de ' ||
               coalesce(ps.overstay_hours, 24) || ' h',
           'Ingresó el ' || to_char(
               s.entry_time at time zone coalesce(ps.business_timezone, 'America/Bogota'),
               'DD/MM/YYYY HH24:MI'
           ),
           jsonb_build_object(
               'session_id', s.id,
               'plate', v.plate,
               'entry_time', s.entry_time,
               'hours', coalesce(ps.overstay_hours, 24)
           ),
           'overstay:' || s.id || ':' || current_date || ':user:' || u.id,
           s.lot_id
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.parking_settings ps on ps.lot_id = s.lot_id
      join public.users u on u.role = 'admin' and u.is_active
     where s.status = 'open'
       and s.entry_time < now() - make_interval(
           hours => coalesce(ps.overstay_hours, 24)
       )
       and exists (
           select 1 from public.lot_members lm
            where lm.user_id = u.id and lm.lot_id = s.lot_id
       )
    on conflict (dedupe_key) do nothing;

    get diagnostics changed = row_count;
    return changed;
end;
$$;

grant execute on function public.notify_overstays() to authenticated;
