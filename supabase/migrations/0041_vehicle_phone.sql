-- The customer's phone, so an operator can send the receipt over WhatsApp.
-- Optional: plates without a phone keep working exactly as before.

alter table public.vehicles
    add column if not exists owner_phone varchar(32);

alter table public.vehicles
    drop constraint if exists vehicles_owner_phone_check;
alter table public.vehicles
    add constraint vehicles_owner_phone_check
    check (
        owner_phone is null
        or length(regexp_replace(owner_phone, '\D', '', 'g')) between 7 and 15
    );

drop function if exists public.update_vehicle_flags(text, boolean, text);

create function public.update_vehicle_flags(
    p_plate text,
    p_blacklisted boolean default null,
    p_notes text default null,
    p_owner_phone text default null
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
           end
     where id = vehicle.id
     returning * into vehicle;

    return jsonb_build_object(
        'plate', vehicle.plate,
        'is_blacklisted', vehicle.is_blacklisted,
        'notes', vehicle.notes,
        'owner_phone', vehicle.owner_phone
    );
end;
$$;

grant execute on function public.update_vehicle_flags(text, boolean, text, text) to authenticated;

-- The timeline returns the phone so the app can offer the WhatsApp action.
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
