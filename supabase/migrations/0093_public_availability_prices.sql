-- Public booking, part 7: the customer should know the price before choosing
-- a vehicle type. Each category now carries its active hourly tariff (minor
-- units, 0 when the lot has not configured one), so /reserve can show a real
-- "desde $X/hora" instead of sending people to call.

create or replace function public.public_availability(p_lot_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot public.parking_lots%rowtype;
    settings public.parking_settings%rowtype;
    category public.categories%rowtype;
    tz text;
    spot_group text;
    group_configured boolean;
    group_capacity integer;
    spots_total integer;
    open_cat integer;
    reserved_cat integer;
    open_group integer;
    reserved_group integer;
    available integer;
    group_available integer;
    items jsonb := '[]'::jsonb;
begin
    select * into lot
      from public.parking_lots l
     where l.id = p_lot_id and l.active;
    if not found then
        return null;
    end if;
    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;
    tz := coalesce(settings.business_timezone, lot.timezone, 'America/Bogota');

    for category in
        select * from public.categories c
         where c.lot_id = p_lot_id
         order by c.id
    loop
        spot_group := public.category_group(category.name);
        select count(*) into spots_total
          from public.parking_spots sp
         where sp.lot_id = p_lot_id
           and sp.group_name = spot_group;
        if spots_total > 0 then
            group_configured := true;
            select count(*) into group_capacity
              from public.parking_spots sp
             where sp.lot_id = p_lot_id
               and sp.group_name = spot_group
               and sp.status = 'active';
        else
            group_configured := case
                when spot_group = 'car' then coalesce(settings.car_capacity, 0) > 0
                when spot_group = 'moto' then coalesce(settings.moto_capacity, 0) > 0
                else false
            end;
            group_capacity := case
                when spot_group = 'car' then public.usable_capacity(
                    coalesce(settings.car_capacity, 0),
                    coalesce(settings.car_out_of_service, 0)
                )
                when spot_group = 'moto' then public.usable_capacity(
                    coalesce(settings.moto_capacity, 0),
                    coalesce(settings.moto_out_of_service, 0)
                )
                else 0
            end;
        end if;

        select count(*) into open_cat
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where s.lot_id = p_lot_id
           and s.status = 'open'
           and v.category_id = category.id;
        select count(*) into reserved_cat
          from public.category_reservations r
         where r.lot_id = p_lot_id
           and r.category_id = category.id
           and r.status = 'active'
           and r.reserved_until > now();

        available := null;
        if coalesce(category.capacity, 0) > 0 then
            available := greatest(category.capacity - open_cat - reserved_cat, 0);
        end if;

        if group_configured then
            select count(*) into open_group
              from public.parking_sessions s
              join public.vehicles v on v.id = s.vehicle_id
              join public.categories c on c.id = v.category_id
             where s.lot_id = p_lot_id
               and s.status = 'open'
               and public.category_group(c.name) = spot_group;
            select count(*) into reserved_group
              from public.category_reservations r
              join public.categories c on c.id = r.category_id
             where r.lot_id = p_lot_id
               and r.status = 'active'
               and r.reserved_until > now()
               and public.category_group(c.name) = spot_group;
            group_available := greatest(group_capacity - open_group - reserved_group, 0);
            if available is null or group_available < available then
                available := group_available;
            end if;
        end if;

        items := items || jsonb_build_object(
            'id', category.id,
            'name', category.name,
            'group', spot_group,
            'hourly_amount', coalesce((
                select t.amount
                  from public.tariffs t
                 where t.category_id = category.id
                   and t.type = 'hourly'
                   and t.active
                 order by t.id
                 limit 1
            ), 0),
            'category_capacity', coalesce(category.capacity, 0),
            'group_capacity', case when group_configured then group_capacity else 0 end,
            'occupied', open_cat,
            'reserved', reserved_cat,
            'available', available,
            'is_full', available is not null and available <= 0
        );
    end loop;

    return jsonb_build_object(
        'lot', jsonb_build_object(
            'id', lot.id,
            'name', lot.name,
            'address', coalesce(settings.address, ''),
            'schedule', coalesce(settings.schedule, ''),
            'phone', coalesce(settings.phone, ''),
            'whatsapp', coalesce(settings.whatsapp, ''),
            'logo_path', coalesce(settings.logo_path, ''),
            'timezone', tz,
            'currency', coalesce(settings.currency, 'COP')
        ),
        'max_reservation_hours', 24,
        'categories', items
    );
end;
$$;

grant execute on function public.public_availability(integer) to anon, authenticated;
