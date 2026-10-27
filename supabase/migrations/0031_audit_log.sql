-- Admin audit trail for reference data and site configuration. Money-touching
-- changes have their own audit (discounts, shift adjustments, pass payments);
-- this covers users, categories, tariffs, vehicles, passes, settings, lots and
-- memberships.

create table if not exists public.audit_log (
    id            bigserial   primary key,
    actor_id      integer     references public.users(id) on delete set null,
    action        text        not null check (action in ('insert', 'update', 'delete')),
    table_name    text        not null,
    entity_id     text,
    lot_id        integer     references public.parking_lots(id) on delete set null,
    before        jsonb,
    after         jsonb,
    created_at    timestamptz not null default now()
);
create index if not exists ix_audit_log_created on public.audit_log(created_at desc);
create index if not exists ix_audit_log_table on public.audit_log(table_name, created_at desc);
create index if not exists ix_audit_log_actor on public.audit_log(actor_id);

alter table public.audit_log enable row level security;
grant select on public.audit_log to authenticated;

drop policy if exists audit_log_admin_read on public.audit_log;
create policy audit_log_admin_read on public.audit_log
    for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Generic row trigger. It records the actor from auth.uid(), drops secrets and
-- keeps only the columns that actually changed on updates.
-- ---------------------------------------------------------------------------
create or replace function public.record_audit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.current_app_user_id();
    before_row jsonb;
    after_row jsonb;
    changed jsonb;
    entity text;
    lot integer;
begin
    if tg_op in ('UPDATE', 'DELETE') then
        before_row := to_jsonb(old) - 'pin_hash';
    end if;
    if tg_op in ('INSERT', 'UPDATE') then
        after_row := to_jsonb(new) - 'pin_hash';
    end if;

    if tg_op = 'UPDATE' then
        select jsonb_object_agg(key, value)
          into changed
          from jsonb_each(after_row)
         where before_row -> key is distinct from value;
        if changed is null or changed = '{}'::jsonb then
            return new;
        end if;
        after_row := changed;
    end if;

    entity := coalesce(after_row ->> 'id', before_row ->> 'id');
    lot := coalesce(
        (after_row ->> 'lot_id')::integer,
        (before_row ->> 'lot_id')::integer
    );

    insert into public.audit_log (
        actor_id, action, table_name, entity_id, lot_id, before, after
    )
    values (
        actor,
        lower(tg_op),
        tg_table_name,
        entity,
        lot,
        before_row,
        after_row
    );
    return coalesce(new, old);
end;
$$;

do $$
declare
    target text;
begin
    foreach target in array array[
        'categories', 'tariffs', 'vehicles', 'monthly_passes',
        'parking_settings', 'parking_lots', 'lot_members'
    ] loop
        execute format(
            'drop trigger if exists trg_audit_row on public.%I', target
        );
        execute format(
            'create trigger trg_audit_row after insert or update or delete '
            'on public.%I for each row execute function public.record_audit()',
            target
        );
    end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Read model + retention.
-- ---------------------------------------------------------------------------
create or replace function public.list_audit_log(
    p_limit integer default 100,
    p_start_date date default null,
    p_end_date date default null,
    p_table text default null
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
      ) rows;
    return result;
end;
$$;

grant execute on function public.list_audit_log(integer, date, date, text) to authenticated;

create or replace function public.purge_audit_log(p_days integer default 365)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    delete from public.audit_log a
     where a.created_at < now() - make_interval(days => greatest(coalesce(p_days, 30), 30));
    get diagnostics changed = row_count;
    return changed;
end;
$$;

grant execute on function public.purge_audit_log(integer) to authenticated;
