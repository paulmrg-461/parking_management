-- The configured capacity is the number of bays to draw: a group can never
-- have more bays than its capacity, and cannot drop below it (lower the
-- capacity first to remove bays). `0` stays "no limit", so heavy vehicles and
-- sites without a configured capacity are unconstrained.

create or replace function public.spot_target_capacity(p_lot integer, p_group text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select case
        when p_group = 'car' then coalesce(ps.car_capacity, 0)
        when p_group = 'moto' then coalesce(ps.moto_capacity, 0)
        else 0
    end
      from public.parking_settings ps
     where ps.lot_id = p_lot;
$$;

grant execute on function public.spot_target_capacity(integer, text) to authenticated;

create or replace function public.save_parking_spot(
    p_code text,
    p_group text,
    p_row integer,
    p_col integer,
    p_id integer default null,
    p_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    normalized text := upper(btrim(coalesce(p_code, '')));
    spot public.parking_spots%rowtype;
    target integer;
    current_group text;
    drawn integer;
begin
    perform public.require_admin();

    if normalized !~ '^[A-Z0-9-]{1,16}$' then
        raise exception 'InvalidSpotCodeError';
    end if;
    if p_group not in ('car', 'moto', 'heavy') then
        raise exception 'InvalidSpotGroupError';
    end if;
    if p_row is null or p_col is null or p_row < 0 or p_col < 0 then
        raise exception 'InvalidSpotPositionError';
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
        select ps.group_name into current_group
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

grant execute on function public.save_parking_spot(text, text, integer, integer, integer, boolean)
    to authenticated;

create or replace function public.delete_parking_spot(p_id integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    spot public.parking_spots%rowtype;
    target integer;
    drawn integer;
begin
    perform public.require_admin();

    select * into spot
      from public.parking_spots ps
     where ps.id = p_id and ps.lot_id = lot;
    if not found then
        raise exception 'SpotNotFoundError';
    end if;

    if exists (
        select 1 from public.parking_sessions s
         where s.spot_id = p_id and s.status = 'open'
    ) then
        raise exception 'SpotOccupiedError';
    end if;

    target := public.spot_target_capacity(lot, spot.group_name);
    if target > 0 then
        select count(*) into drawn
          from public.parking_spots ps
         where ps.lot_id = lot and ps.group_name = spot.group_name;
        if drawn <= target then
            raise exception 'SpotCapacityRequiredError';
        end if;
    end if;

    delete from public.parking_spots ps
     where ps.id = p_id and ps.lot_id = lot;
end;
$$;

grant execute on function public.delete_parking_spot(integer) to authenticated;
