-- Owner contact details are optional: a monthly-pass customer or someone who
-- left their keys can be reached by name + phone. Plates without them keep
-- working exactly as before.

alter table public.vehicles
    add column if not exists owner_name varchar(120);

alter table public.vehicles
    drop constraint if exists vehicles_owner_name_check;
alter table public.vehicles
    add constraint vehicles_owner_name_check
    check (
        owner_name is null
        or length(btrim(owner_name)) between 2 and 120
    );

drop function if exists public.update_vehicle_flags(text, boolean, text, text);

create function public.update_vehicle_flags(
    p_plate text,
    p_blacklisted boolean default null,
    p_notes text default null,
    p_owner_phone text default null,
    p_owner_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    vehicle public.vehicles%rowtype;
    phone text;
    normalized_name text;
begin
    perform public.require_app_user();
    if normalized = '' then
        raise exception 'VehicleNotFoundError';
    end if;
    if p_blacklisted is not null
       and public.current_app_role() is distinct from 'admin' then
        raise exception 'AdminRequiredError';
    end if;

    if p_owner_phone is not null then
        phone := nullif(btrim(p_owner_phone), '');
        if phone is not null
           and length(regexp_replace(phone, '\D', '', 'g')) not between 7 and 15 then
            raise exception 'InvalidPhoneError';
        end if;
    end if;

    if p_owner_name is not null then
        normalized_name := nullif(btrim(p_owner_name), '');
        if normalized_name is not null and length(normalized_name) < 2 then
            raise exception 'InvalidOwnerNameError';
        end if;
    end if;

    select * into vehicle
      from public.vehicles v
     where v.plate = normalized
     for update;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;

    update public.vehicles
       set is_blacklisted = coalesce(p_blacklisted, is_blacklisted),
           notes = case
               when p_notes is null then notes
               else nullif(btrim(p_notes), '')
           end,
           owner_phone = case
               when p_owner_phone is null then owner_phone
               else phone
           end,
           owner_name = case
               when p_owner_name is null then owner_name
               else normalized_name
           end
     where id = vehicle.id
     returning * into vehicle;

    return jsonb_build_object(
        'plate', vehicle.plate,
        'is_blacklisted', vehicle.is_blacklisted,
        'notes', vehicle.notes,
        'owner_phone', vehicle.owner_phone,
        'owner_name', vehicle.owner_name
    );
end;
$$;

grant execute on function public.update_vehicle_flags(
    text, boolean, text, text, text
) to authenticated;

-- The timeline returns the owner so the app can offer contact/edit actions.
create or replace function public.vehicle_history(p_plate text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    normalized text := upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g'));
    vehicle public.vehicles%rowtype;
    category_name text;
    result jsonb;
begin
    perform public.require_app_user();
    if normalized = '' then
        raise exception 'VehicleNotFoundError';
    end if;

    select * into vehicle from public.vehicles v where v.plate = normalized;
    if not found then
        raise exception 'VehicleNotFoundError';
    end if;
    select c.name into category_name
      from public.categories c where c.id = vehicle.category_id;

    select jsonb_build_object(
        'plate', vehicle.plate,
        'vehicle_id', vehicle.id,
        'category_id', vehicle.category_id,
        'category_name', category_name,
        'color', vehicle.color,
        'brand', vehicle.brand,
        'is_blacklisted', vehicle.is_blacklisted,
        'notes', vehicle.notes,
        'owner_phone', vehicle.owner_phone,
        'owner_name', vehicle.owner_name,
        'visits', count(*),
        'current_lot_visits', count(*) filter (where s.lot_id = public.current_lot_id()),
        'total_spent', coalesce(sum(s.amount_charged) filter (where s.status = 'closed'), 0),
        'open_sessions', count(*) filter (where s.status = 'open'),
        'sessions', coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'id', s.id,
                    'entry_time', s.entry_time,
                    'exit_time', s.exit_time,
                    'status', s.status,
                    'amount_charged', s.amount_charged,
                    'ticket_number', s.ticket_number,
                    'payment_method', s.payment_method,
                    'lost_ticket', s.lost_ticket,
                    'discount_amount', s.discount_amount,
                    'discount_reason', s.discount_reason,
                    'lot_id', s.lot_id,
                    'lot_name', (select l.name from public.parking_lots l where l.id = s.lot_id),
                    'duration_seconds', case
                        when s.exit_time is not null
                            then extract(epoch from s.exit_time - s.entry_time)::bigint
                        else extract(epoch from now() - s.entry_time)::bigint
                    end
                )
                order by s.entry_time desc
            ),
            '[]'::jsonb
        )
    ) into result
      from public.parking_sessions s
     where s.vehicle_id = vehicle.id;

    return result;
end;
$$;

grant execute on function public.vehicle_history(text) to authenticated;
