-- Supabase Auth integration: link public.users to auth.users and expose the
-- data through PostgREST with row-level security.
--
-- FastAPI connects as the table owner (postgres), which bypasses RLS, so the
-- existing endpoints keep working while the client migrates to Supabase.

alter table public.users
    add column if not exists auth_user_id uuid unique;

-- Supabase Auth owns the credential (bcrypt in auth.users); the legacy
-- Argon2 hash is only used by the transitional PIN endpoint.
alter table public.users alter column pin_hash drop not null;

-- ---------------------------------------------------------------------------
-- Keep public.users in sync with auth.users
-- ---------------------------------------------------------------------------
create or replace function public.handle_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    uname text := lower(split_part(coalesce(new.email, ''), '@', 1));
    display text := coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), initcap(uname));
    desired_role text := case
        when new.raw_app_meta_data ->> 'role' = 'admin' then 'admin'
        else 'operator'
    end;
begin
    if uname = '' then
        return new;
    end if;

    if exists (select 1 from public.users where auth_user_id = new.id) then
        update public.users
           set username = uname,
               display_name = display,
               role = desired_role,
               is_active = true,
               updated_at = now()
         where auth_user_id = new.id;
        return new;
    end if;

    insert into public.users (auth_user_id, username, display_name, role, is_active)
    values (new.id, uname, display, desired_role, true)
    on conflict (username) do update
        set auth_user_id = excluded.auth_user_id,
            display_name = excluded.display_name,
            role = excluded.role,
            is_active = true,
            updated_at = now();
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_auth_user();

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
    after update of email, raw_app_meta_data on auth.users
    for each row execute function public.handle_auth_user();

-- ---------------------------------------------------------------------------
-- Helpers used by RLS policies (security definer avoids recursive RLS)
-- ---------------------------------------------------------------------------
create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
    select role
      from public.users
     where auth_user_id = auth.uid()
       and is_active
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(public.current_app_role() = 'admin', false)
$$;

-- ---------------------------------------------------------------------------
-- Grants (RLS still decides which rows)
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

grant select on
    public.users,
    public.categories,
    public.tariffs,
    public.vehicles,
    public.parking_sessions,
    public.evidence_photos,
    public.monthly_passes,
    public.parking_settings
to authenticated;

grant insert on public.vehicles to authenticated;

grant insert, update, delete on
    public.categories,
    public.tariffs,
    public.monthly_passes
to authenticated;

grant insert, update on public.parking_settings to authenticated;
grant insert, update, delete on public.users to authenticated;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.categories enable row level security;
alter table public.tariffs enable row level security;
alter table public.vehicles enable row level security;
alter table public.parking_sessions enable row level security;
alter table public.evidence_photos enable row level security;
alter table public.monthly_passes enable row level security;
alter table public.parking_settings enable row level security;

-- Users: own profile for everyone, full access for admins.
drop policy if exists users_select_own_or_admin on public.users;
create policy users_select_own_or_admin on public.users
    for select to authenticated
    using (auth_user_id = auth.uid() or public.is_admin());

drop policy if exists users_admin_write on public.users;
create policy users_admin_write on public.users
    for all to authenticated
    using (public.is_admin())
    with check (public.is_admin());

-- Reference data: read for every signed-in user, write for admins.
drop policy if exists categories_read on public.categories;
create policy categories_read on public.categories
    for select to authenticated using (true);
drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write on public.categories
    for all to authenticated
    using (public.is_admin()) with check (public.is_admin());

drop policy if exists tariffs_read on public.tariffs;
create policy tariffs_read on public.tariffs
    for select to authenticated using (true);
drop policy if exists tariffs_admin_write on public.tariffs;
create policy tariffs_admin_write on public.tariffs
    for all to authenticated
    using (public.is_admin()) with check (public.is_admin());

-- Vehicles: operators register unknown plates during check-in; edits are
-- admin-only.
drop policy if exists vehicles_read on public.vehicles;
create policy vehicles_read on public.vehicles
    for select to authenticated using (true);
drop policy if exists vehicles_operator_insert on public.vehicles;
create policy vehicles_operator_insert on public.vehicles
    for insert to authenticated with check (true);
drop policy if exists vehicles_admin_write on public.vehicles;
create policy vehicles_admin_write on public.vehicles
    for update to authenticated
    using (public.is_admin()) with check (public.is_admin());
drop policy if exists vehicles_admin_delete on public.vehicles;
create policy vehicles_admin_delete on public.vehicles
    for delete to authenticated using (public.is_admin());

-- Sessions/evidence: readable, but writes stay behind the billing RPCs
-- (or the transitional FastAPI service) until check-in/check-out are ported.
drop policy if exists sessions_read on public.parking_sessions;
create policy sessions_read on public.parking_sessions
    for select to authenticated using (true);

drop policy if exists evidence_read on public.evidence_photos;
create policy evidence_read on public.evidence_photos
    for select to authenticated using (true);

drop policy if exists passes_read on public.monthly_passes;
create policy passes_read on public.monthly_passes
    for select to authenticated using (true);
drop policy if exists passes_admin_write on public.monthly_passes;
create policy passes_admin_write on public.monthly_passes
    for all to authenticated
    using (public.is_admin()) with check (public.is_admin());

drop policy if exists settings_read on public.parking_settings;
create policy settings_read on public.parking_settings
    for select to authenticated using (true);
drop policy if exists settings_admin_write on public.parking_settings;
create policy settings_admin_write on public.parking_settings
    for all to authenticated
    using (public.is_admin()) with check (public.is_admin());

-- idempotency_keys intentionally has no policy: service_role only.
alter table public.idempotency_keys enable row level security;
