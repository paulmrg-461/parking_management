-- In-app notification center + device push tokens.
--
-- Delivery model:
--   * PostgreSQL triggers create rows in public.notifications.
--   * Supabase Realtime pushes new rows to connected apps (foreground).
--   * The `push-dispatch` Edge Function sends rows to FCM/APNs for background
--     delivery when the corresponding credentials are configured.
--
-- Notifications are written only by security-definer triggers/RPCs; users can
-- read their own rows and mark them read, never create or edit them.

create table if not exists public.notifications (
    id             bigserial primary key,
    user_id        integer     not null references public.users(id) on delete cascade,
    type           text        not null,
    title          text        not null,
    body           text        not null,
    data           jsonb       not null default '{}'::jsonb,
    read_at        timestamptz,
    pushed_at      timestamptz,
    push_attempts  integer     not null default 0,
    dedupe_key     text unique,
    created_at     timestamptz not null default now()
);

create index if not exists ix_notifications_user_created
    on public.notifications(user_id, created_at desc);
create index if not exists ix_notifications_unread
    on public.notifications(user_id) where read_at is null;
create index if not exists ix_notifications_pending_push
    on public.notifications(created_at)
    where pushed_at is null and push_attempts < 3;

create table if not exists public.device_tokens (
    id           bigserial primary key,
    user_id      integer     not null references public.users(id) on delete cascade,
    token        text        not null unique,
    platform     text        not null check (platform in ('android', 'ios', 'web')),
    created_at   timestamptz not null default now(),
    last_seen_at timestamptz not null default now()
);
create index if not exists ix_device_tokens_user on public.device_tokens(user_id);

alter table public.notifications enable row level security;
alter table public.device_tokens enable row level security;

grant select on public.notifications to authenticated;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications
    for select to authenticated
    using (user_id = public.current_app_user_id());

-- Realtime: new rows reach the signed-in app without polling.
do $$
begin
    if not exists (
        select 1
          from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = 'notifications'
    ) then
        alter publication supabase_realtime add table public.notifications;
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- Client RPCs
-- ---------------------------------------------------------------------------
create or replace function public.mark_notifications_read(p_ids bigint[] default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
    changed integer;
begin
    update public.notifications
       set read_at = now()
     where user_id = uid
       and read_at is null
       and (p_ids is null or id = any (p_ids));
    get diagnostics changed = row_count;
    return changed;
end;
$$;

create or replace function public.register_device_token(
    p_token text,
    p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
begin
    if p_token is null or length(btrim(p_token)) < 10 then
        raise exception 'InvalidDeviceToken';
    end if;
    if p_platform not in ('android', 'ios', 'web') then
        raise exception 'InvalidDevicePlatform';
    end if;
    insert into public.device_tokens (user_id, token, platform)
    values (uid, btrim(p_token), p_platform)
    on conflict (token) do update
        set user_id = excluded.user_id,
            platform = excluded.platform,
            last_seen_at = now();
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
begin
    delete from public.device_tokens
     where token = btrim(p_token) and user_id = uid;
end;
$$;

grant execute on function public.mark_notifications_read(bigint[]) to authenticated;
grant execute on function public.register_device_token(text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Event notifications
-- ---------------------------------------------------------------------------
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
      from public.parking_settings where id = 1;
    tz := coalesce(tz, 'America/Bogota');

    if tg_op = 'INSERT' and new.status = 'open' then
        select v.plate into plate_value from public.vehicles v where v.id = new.vehicle_id;
        insert into public.notifications (user_id, type, title, body, data, dedupe_key)
        select u.id,
               'check_in',
               'Vehículo ' || plate_value || ' ingresó',
               'Entrada registrada a las ' ||
                   to_char(new.entry_time at time zone tz, 'HH24:MI'),
               jsonb_build_object('session_id', new.id, 'plate', plate_value),
               'check_in:' || new.id || ':user:' || u.id
          from public.users u
         where u.role = 'admin' and u.is_active
        on conflict (dedupe_key) do nothing;
    elsif tg_op = 'UPDATE' and new.status = 'closed' and old.status = 'open' then
        select v.plate into plate_value from public.vehicles v where v.id = new.vehicle_id;
        amount_value := coalesce(new.amount_charged, 0);
        insert into public.notifications (user_id, type, title, body, data, dedupe_key)
        select u.id,
               'check_out',
               'Vehículo ' || plate_value || ' salió',
               'Salida registrada. Cobro: $' || amount_value,
               jsonb_build_object(
                   'session_id', new.id,
                   'plate', plate_value,
                   'amount_charged', amount_value,
                   'ticket_number', new.ticket_number
               ),
               'check_out:' || new.id || ':user:' || u.id
          from public.users u
         where u.role = 'admin' and u.is_active
        on conflict (dedupe_key) do nothing;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_notify_session_event on public.parking_sessions;
create trigger trg_notify_session_event
    after insert or update of status on public.parking_sessions
    for each row execute function public.notify_session_event();

-- Monthly passes expiring in three days. Call daily from a scheduler (or
-- pg_cron when enabled in the self-hosted stack).
create or replace function public.notify_expiring_monthly_passes()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    insert into public.notifications (user_id, type, title, body, data, dedupe_key)
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
           'pass_expiry:' || mp.id || ':' || mp.end_date || ':user:' || u.id
      from public.monthly_passes mp
      join public.vehicles v on v.id = mp.vehicle_id
      join public.users u on u.role = 'admin' and u.is_active
     where mp.active
       and mp.end_date = current_date + 3
    on conflict (dedupe_key) do nothing;
    get diagnostics changed = row_count;
    return changed;
end;
$$;

grant execute on function public.notify_expiring_monthly_passes() to authenticated;
