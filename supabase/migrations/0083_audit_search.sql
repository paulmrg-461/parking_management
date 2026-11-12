-- Audit free-text search for the admin screen and exports. The previous
-- function applied the page limit *before* the actor filter, so selecting an
-- actor only looked at the newest rows; filters now run inside the scan and
-- the limit applies to the already-filtered page.
--
-- The 5-argument overload is dropped on purpose: with the trailing default on
-- the new signature, keeping both would make 5-argument calls ambiguous.

drop function if exists public.list_audit_log(integer, date, date, text, text);

create function public.list_audit_log(
    p_limit integer default 100,
    p_start_date date default null,
    p_end_date date default null,
    p_table text default null,
    p_actor text default null,
    p_search text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    tz text;
    window_start timestamptz;
    window_end timestamptz;
    actor_name text := nullif(btrim(coalesce(p_actor, '')), '');
    search_term text := nullif(btrim(coalesce(p_search, '')), '');
    result jsonb;
begin
    perform public.require_admin();
    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = public.current_lot_id();
    tz := coalesce(tz, 'America/Bogota');
    window_start := case
        when p_start_date is null then null
        else p_start_date::timestamp at time zone tz
    end;
    window_end := case
        when p_end_date is null then null
        else (p_end_date + 1)::timestamp at time zone tz
    end;

    select coalesce(jsonb_agg(item order by created_at desc), '[]'::jsonb)
      into result
      from (
        select a.created_at,
               jsonb_build_object(
                   'id', a.id,
                   'actor', u.username,
                   'action', a.action,
                   'table_name', a.table_name,
                   'entity_id', a.entity_id,
                   'lot', l.name,
                   'before', a.before,
                   'after', a.after,
                   'created_at', a.created_at
               ) as item
          from public.audit_log a
          left join public.users u on u.id = a.actor_id
          left join public.parking_lots l on l.id = a.lot_id
         where (window_start is null or a.created_at >= window_start)
           and (window_end is null or a.created_at < window_end)
           and (p_table is null or a.table_name = p_table)
           and (actor_name is null or lower(u.username) = lower(actor_name))
           and (
               search_term is null
               or a.entity_id ilike '%' || search_term || '%'
               or a.table_name ilike '%' || search_term || '%'
               or coalesce(u.username, '') ilike '%' || search_term || '%'
               or coalesce(u.display_name, '') ilike '%' || search_term || '%'
               or coalesce(a.after ->> 'plate', '') ilike '%' || search_term || '%'
               or coalesce(a.before ->> 'plate', '') ilike '%' || search_term || '%'
               or coalesce(a.after ->> 'name', '') ilike '%' || search_term || '%'
               or coalesce(a.before ->> 'name', '') ilike '%' || search_term || '%'
           )
         order by a.created_at desc
         limit greatest(coalesce(p_limit, 100), 1)
      ) rows;

    return result;
end;
$$;

grant execute on function public.list_audit_log(integer, date, date, text, text, text)
    to authenticated;
