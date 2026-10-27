-- Membership listing for the lot administration screen. Lot admins see the
-- members of their own lot; platform admins can read any lot.

create or replace function public.list_lot_members(p_lot_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    result jsonb;
begin
    if not public.is_lot_admin(p_lot_id) then
        raise exception 'AdminRequiredError';
    end if;
    select coalesce(jsonb_agg(item order by item ->> 'display_name'), '[]'::jsonb)
      into result
      from (
        select jsonb_build_object(
                   'user_id', u.id,
                   'username', u.username,
                   'display_name', u.display_name,
                   'role', lm.role,
                   'is_active', u.is_active
               ) as item
          from public.lot_members lm
          join public.users u on u.id = lm.user_id
         where lm.lot_id = p_lot_id
      ) rows;
    return result;
end;
$$;

grant execute on function public.list_lot_members(integer) to authenticated;
