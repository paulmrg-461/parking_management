-- Live activity feed for the whole site: every check-in/check-out notifies the
-- active members of the lot (not only admins), naming the user who registered
-- it, so the other devices (the admin desk, a colleague's phone) see it as it
-- happens through Realtime. The acting device also gets the row: the client
-- ignores the snackbar echo of its own write but keeps the inbox entry.

create or replace function public.notify_session_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    plate_value text;
    tz text;
    amount_value integer;
    actor_id integer;
    actor_name text;
    actor_role text;
    event_type text;
    event_title text;
    event_body text;
    event_data jsonb;
begin
    select coalesce(ps.business_timezone, 'America/Bogota') into tz
      from public.parking_settings ps
     where ps.lot_id = new.lot_id;
    tz := coalesce(tz, 'America/Bogota');

    select v.plate into plate_value
      from public.vehicles v
     where v.id = new.vehicle_id;

    if tg_op = 'INSERT' and new.status = 'open' then
        actor_id := new.operator_id;
        event_type := 'check_in';
        event_title := 'Entrada registrada';
        event_data := jsonb_build_object(
            'action', 'check_in',
            'session_id', new.id,
            'plate', plate_value,
            'entry_time', new.entry_time
        );
    elsif tg_op = 'UPDATE' and new.status = 'closed' and old.status = 'open' then
        -- The trigger runs inside the check-out transaction, so the actor is
        -- still the signed-in user (the row only stores the entry operator).
        actor_id := public.current_app_user_id();
        amount_value := coalesce(new.amount_charged, 0);
        event_type := 'check_out';
        event_title := 'Salida registrada';
        event_data := jsonb_build_object(
            'action', 'check_out',
            'session_id', new.id,
            'plate', plate_value,
            'amount_charged', amount_value,
            'ticket_number', new.ticket_number,
            'payment_method', new.payment_method,
            'exit_time', new.exit_time
        );
    else
        return new;
    end if;

    select u.display_name,
           case when u.role = 'admin' then 'Administrador' else 'Operador' end
      into actor_name, actor_role
      from public.users u
     where u.id = actor_id;

    event_data := event_data || jsonb_build_object(
        'actor_id', actor_id,
        'actor_name', actor_name,
        'actor_role', actor_role
    );

    if event_type = 'check_in' then
        event_body := coalesce(actor_name, 'Un usuario') || ' (' ||
            coalesce(actor_role, 'Operador') || ') registró el ingreso de ' ||
            coalesce(plate_value, 'un vehículo') || ' · ' ||
            to_char(new.entry_time at time zone tz, 'HH24:MI');
    else
        event_body := coalesce(actor_name, 'Un usuario') || ' (' ||
            coalesce(actor_role, 'Operador') || ') registró la salida de ' ||
            coalesce(plate_value, 'un vehículo') || ' · Cobro: $' ||
            amount_value;
    end if;

    insert into public.notifications (
        user_id, type, title, body, data, dedupe_key, lot_id
    )
    select u.id,
           event_type,
           event_title,
           event_body,
           event_data,
           event_type || ':' || new.id || ':user:' || u.id,
           new.lot_id
      from public.lot_members lm
      join public.users u on u.id = lm.user_id
     where lm.lot_id = new.lot_id
       and u.is_active
    on conflict (dedupe_key) do nothing;

    return new;
end;
$$;

drop trigger if exists trg_notify_session_event on public.parking_sessions;
create trigger trg_notify_session_event
    after insert or update of status on public.parking_sessions
    for each row execute function public.notify_session_event();
