-- Public booking, part 10: one place decides the grace window. The board was
-- filtering in PostgREST with a Dart copy of the 15 minutes, so a change in
-- SQL would silently disagree with the app. This function returns the active
-- holds the lot should see, with the grace already applied by the server, and
-- a ready-made `in_grace` flag for the card.
--
-- Security invoker: RLS keeps scoping the rows to the caller's lot (the app
-- sends `x-lot-id`, which `current_lot_id()` reads).

create or replace function public.list_active_reservations()
returns table (
    id bigint,
    plate text,
    category_id integer,
    category_name text,
    reserved_until timestamp with time zone,
    status text,
    notes text,
    customer_name text,
    customer_phone text,
    source text,
    in_grace boolean
)
language sql
stable
security invoker
set search_path = public
as $$
    select
        r.id,
        r.plate::text,
        r.category_id,
        coalesce(c.name, '')::text as category_name,
        r.reserved_until,
        r.status,
        r.notes,
        r.customer_name,
        r.customer_phone,
        r.source,
        (
            r.reserved_until <= now()
            and r.reserved_until + public.reservation_grace() > now()
        ) as in_grace
      from public.category_reservations r
      left join public.categories c on c.id = r.category_id
     where r.status = 'active'
       and r.reserved_until + public.reservation_grace() > now()
     order by r.reserved_until;
$$;

revoke all on function public.list_active_reservations() from public;
grant execute on function public.list_active_reservations() to authenticated;
