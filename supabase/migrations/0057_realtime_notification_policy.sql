-- Realtime evaluates RLS without the `x-lot-id` header, so a policy that calls
-- current_lot_id() raises LotRequiredError and silently kills the subscription
-- (same class of bug as the Storage evidence policy). Membership is enough to
-- read your own notifications, with a security-definer helper so the check does
-- not depend on the caller's lot or re-enter the lot_members RLS.

create or replace function public.can_read_lot(p_lot_id integer)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
          from public.lot_members lm
         where lm.user_id = public.current_app_user_id()
           and lm.lot_id = p_lot_id
    );
$$;

grant execute on function public.can_read_lot(integer) to authenticated;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications
    for select to authenticated
    using (
        user_id = public.current_app_user_id()
        and (lot_id is null or public.can_read_lot(lot_id))
    );
