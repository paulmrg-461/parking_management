-- First-steps checklist for a site: tells the home whether the active lot can
-- actually register vehicles (categories + tariffs + capacity/space map) and
-- whether its receipts/QR pages have the identity they need (address + phone).

create or replace function public.lot_setup_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    actor integer := public.require_app_user();
    categories integer := 0;
    tariffs integer := 0;
    car_capacity integer := 0;
    moto_capacity integer := 0;
    spots integer := 0;
    has_address boolean := false;
    has_phone boolean := false;
begin
    select count(*) into categories
      from public.categories c
     where c.lot_id = lot;

    select count(*) into tariffs
      from public.tariffs t
     where t.lot_id = lot
       and t.active;

    select coalesce(ps.car_capacity, 0),
           coalesce(ps.moto_capacity, 0),
           coalesce(btrim(ps.address), '') <> '',
           coalesce(btrim(ps.phone), '') <> ''
      into car_capacity, moto_capacity, has_address, has_phone
      from public.parking_settings ps
     where ps.lot_id = lot;

    select count(*) into spots
      from public.parking_spots sp
     where sp.lot_id = lot
       and sp.status = 'active';

    return jsonb_build_object(
        'categories', categories,
        'tariffs', tariffs,
        'car_capacity', car_capacity,
        'moto_capacity', moto_capacity,
        'spots', spots,
        'has_address', has_address,
        'has_phone', has_phone,
        'complete', categories > 0
            and tariffs > 0
            and (car_capacity > 0 or moto_capacity > 0 or spots > 0)
            and has_address
            and has_phone
    );
end;
$$;

grant execute on function public.lot_setup_status() to authenticated;
