-- Retention and expiry jobs. With pg_cron available they run inside Postgres;
-- otherwise `supabase/notifications-cron.sh` calls the same functions, so the
-- behavior is identical either way.

alter table public.category_reservations
    drop constraint if exists category_reservations_status_check;
alter table public.category_reservations
    add constraint category_reservations_status_check
    check (status in ('active', 'cancelled', 'used', 'expired'));

-- A hold that was never used stops occupying capacity once it expires.
create or replace function public.expire_reservations(p_grace_hours integer default 24)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    update public.category_reservations
       set status = 'expired'
     where status = 'active'
       and reserved_until < now() - make_interval(hours => greatest(coalesce(p_grace_hours, 0), 0));
    get diagnostics changed = row_count;
    return changed;
end;
$$;

-- Read notifications older than `p_days` are dropped; anything older than a
-- year goes even if it was never read (it cannot be acted on anymore).
create or replace function public.purge_stale_notifications(p_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    delete from public.notifications n
     where (n.read_at is not null
            and n.created_at < now() - make_interval(days => greatest(coalesce(p_days, 1), 1)))
        or n.created_at < now() - interval '365 days';
    get diagnostics changed = row_count;
    return changed;
end;
$$;

grant execute on function public.expire_reservations(integer) to authenticated;
grant execute on function public.purge_stale_notifications(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Scheduling (best effort: the self-hosted image may not ship pg_cron).
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
        create extension if not exists pg_cron;
    end if;
exception when others then
    raise notice 'pg_cron unavailable (enable it in the app database, see README): %', sqlerrm;
end $$;

do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.schedule(
            'parking-purge-idempotency',
            '*/15 * * * *',
            'select public.purge_expired_idempotency()'
        );
        perform cron.schedule(
            'parking-stale-notifications',
            '15 3 * * *',
            'select public.purge_stale_notifications(90)'
        );
        perform cron.schedule(
            'parking-expire-reservations',
            '7 * * * *',
            'select public.expire_reservations(24)'
        );
    else
        raise notice 'pg_cron missing: keep supabase/notifications-cron.sh scheduled';
    end if;
exception when others then
    raise notice 'pg_cron scheduling skipped: %', sqlerrm;
end $$;
