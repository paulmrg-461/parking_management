-- Per-bay maintenance history: taking a bay out of service (or bringing it
-- back) now keeps who, when and why. The map editor writes the transition in
-- the same transaction that changes the status, so the log can never drift
-- from the bay.

create table if not exists public.parking_spot_events (
    id          bigserial   primary key,
    lot_id      integer     not null references public.parking_lots(id) on delete cascade,
    spot_id     integer     references public.parking_spots(id) on delete set null,
    spot_code   varchar(16) not null,
    status      text        not null check (status in ('active', 'out_of_service')),
    reason      text        check (
                    reason is null
                    or length(btrim(reason)) between 3 and 200
                ),
    actor_id    integer     references public.users(id) on delete set null,
    created_at  timestamptz not null default now()
);

create index if not exists ix_spot_events_lot_created
    on public.parking_spot_events(lot_id, created_at desc);
create index if not exists ix_spot_events_spot_created
    on public.parking_spot_events(spot_id, created_at desc);

alter table public.parking_spot_events enable row level security;
grant select on public.parking_spot_events to authenticated;

drop policy if exists spot_events_read on public.parking_spot_events;
create policy spot_events_read on public.parking_spot_events
    for select to authenticated
    using (lot_id = public.current_lot_id());

-- Writes go through `save_parking_spot` (security definer); no write grants.

-- The 6-argument overload must stay dropped: with the trailing default on the
-- new signature, leaving it would make 6-argument calls ambiguous.
drop function if exists public.save_parking_spot(
    text, text, integer, integer, integer, boolean
);

create or replace function public.save_parking_spot(
    p_code text,
    p_group text,
    p_row integer,
    p_col integer,
    p_id integer default null,
    p_active boolean default true,
    p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_admin();
    lot integer := public.current_lot_id();
    normalized text := upper(btrim(coalesce(p_code, '')));
    normalized_reason text := nullif(btrim(coalesce(p_reason, '')), '');
    spot public.parking_spots%rowtype;
    target integer;
    current_group text;
    previous_status text;
    drawn integer;
begin
    if normalized !~ '^[A-Z0-9-]{1,16}$' then
        raise exception 'InvalidSpotCodeError';
    end if;
    if p_group not in ('car', 'moto', 'heavy') then
        raise exception 'InvalidSpotGroupError';
    end if;
    if p_row is null or p_col is null or p_row < 0 or p_col < 0 then
        raise exception 'InvalidSpotPositionError';
    end if;
    if normalized_reason is not null
       and length(normalized_reason) not between 3 and 200 then
        raise exception 'InvalidSpotReasonError';
    end if;

    if exists (
        select 1 from public.parking_spots ps
         where ps.lot_id = lot
           and ps.code = normalized
           and ps.id is distinct from p_id
    ) then
        raise exception 'SpotCodeTakenError';
    end if;
    if exists (
        select 1 from public.parking_spots ps
         where ps.lot_id = lot
           and ps.grid_row = p_row
           and ps.grid_col = p_col
           and ps.id is distinct from p_id
    ) then
        raise exception 'SpotCellTakenError';
    end if;

    if p_id is not null then
        select ps.group_name, ps.status into current_group, previous_status
          from public.parking_spots ps
         where ps.id = p_id and ps.lot_id = lot;
        if current_group is null then
            raise exception 'SpotNotFoundError';
        end if;
    end if;

    target := public.spot_target_capacity(lot, p_group);

    -- Only a spot entering the group (new, or changed group) needs room.
    if target > 0 and current_group is distinct from p_group then
        select count(*) into drawn
          from public.parking_spots ps
         where ps.lot_id = lot and ps.group_name = p_group;
        if drawn >= target then
            raise exception 'SpotCapacityReachedError';
        end if;
    end if;

    if p_id is null then
        insert into public.parking_spots (
            lot_id, code, group_name, grid_row, grid_col, status
        )
        values (
            lot, normalized, p_group, p_row, p_col,
            case when p_active then 'active' else 'out_of_service' end
        )
        returning * into spot;
    else
        update public.parking_spots ps
           set code = normalized,
               group_name = p_group,
               grid_row = p_row,
               grid_col = p_col,
               status = case when p_active then 'active' else 'out_of_service' end
         where ps.id = p_id
           and ps.lot_id = lot
        returning * into spot;
    end if;

    -- Log real transitions only: renaming or moving a bay keeps its status and
    -- does not pollute the maintenance history.
    if (p_id is null and spot.status = 'out_of_service')
       or (p_id is not null and previous_status is distinct from spot.status) then
        insert into public.parking_spot_events (
            lot_id, spot_id, spot_code, status, reason, actor_id
        )
        values (
            lot, spot.id, spot.code, spot.status, normalized_reason, actor
        );
    end if;

    return jsonb_build_object(
        'id', spot.id,
        'code', spot.code,
        'group', spot.group_name,
        'row', spot.grid_row,
        'col', spot.grid_col,
        'active', spot.status = 'active'
    );
end;
$$;

grant execute on function public.save_parking_spot(
    text, text, integer, integer, integer, boolean, text
) to authenticated;

create or replace function public.list_spot_events(
    p_spot_id integer,
    p_limit integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    result jsonb;
begin
    if p_limit is null or p_limit < 1 or p_limit > 100 then
        raise exception 'InvalidSpotEventLimitError';
    end if;

    select coalesce(jsonb_agg(item order by created_at desc, id desc), '[]'::jsonb)
      into result
      from (
        select e.id,
               e.created_at,
               jsonb_build_object(
                   'id', e.id,
                   'spot_id', e.spot_id,
                   'spot_code', e.spot_code,
                   'status', e.status,
                   'active', e.status = 'active',
                   'reason', e.reason,
                   'actor_name', u.display_name,
                   'created_at', e.created_at
               ) as item
          from public.parking_spot_events e
          left join public.users u on u.id = e.actor_id
         where e.lot_id = lot
           and e.spot_id = p_spot_id
         order by e.created_at desc, e.id desc
         limit p_limit
      ) rows;

    return result;
end;
$$;

grant execute on function public.list_spot_events(integer, integer) to authenticated;
