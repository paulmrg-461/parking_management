-- Tighten two policies that were broader than the app needs.
-- Check-in/check-out are security-definer RPCs, so operators never insert
-- vehicles or profiles through PostgREST directly.

revoke insert on public.users from authenticated;

drop policy if exists users_admin_write on public.users;
drop policy if exists users_admin_update on public.users;
create policy users_admin_update on public.users
    for update to authenticated
    using (public.is_admin()) with check (public.is_admin());

drop policy if exists users_admin_delete on public.users;
create policy users_admin_delete on public.users
    for delete to authenticated using (public.is_admin());

drop policy if exists vehicles_operator_insert on public.vehicles;
drop policy if exists vehicles_admin_insert on public.vehicles;
create policy vehicles_admin_insert on public.vehicles
    for insert to authenticated with check (public.is_admin());
