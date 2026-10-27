-- Audit log filtering by actor (username) for the admin screen and exports.

drop function if exists public.list_audit_log(integer, date, date, text);

create function public.list_audit_log(
    p_limit integer default 100,
    p_start_date date default null,
    p_end_date date default null,
    p_table text default null,
    p_actor text default null
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

    select coalesce(jsonb_agg(item order by item ->> 'created_at' desc), '[]'::jsonb)
      into result
      from (
        select jsonb_build_object(
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
          from (
            select *
              from public.audit_log
             where (window_start is null or created_at >= window_start)
               and (window_end is null or created_at < window_end)
               and (p_table is null or table_name = p_table)
             order by created_at desc
             limit greatest(coalesce(p_limit, 100), 1)
          ) a
          left join public.users u on u.id = a.actor_id
          left join public.parking_lots l on l.id = a.lot_id
         where actor_name is null or lower(u.username) = lower(actor_name)
      ) rows;
    return result;
end;
$$;

grant execute on function public.list_audit_log(integer, date, date, text, text) to authenticated;
