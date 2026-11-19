-- Public booking, part 12: remind the customer before the hold lapses. A
-- booking made at 09:00 for 11:00 is easy to forget; one hour before
-- `reserved_until` the lot sends a WhatsApp with the code, the plate and the
-- time, so a no-show becomes the exception (and the space is freed earlier).
--
-- Only public holds with a mobile and the lot's automated WhatsApp on; the
-- `reminder_sent_at` stamp makes the job idempotent (it runs every 5 minutes).

alter table public.category_reservations
    add column if not exists reminder_sent_at timestamp with time zone;

create index if not exists ix_reservations_reminder_pending
    on public.category_reservations(reserved_until)
    where status = 'active' and reminder_sent_at is null;

create or replace function public.notify_expiring_reservations(
    p_window_minutes integer default 60
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    hold record;
    timezone_name text;
    lot_name text;
    changed integer := 0;
begin
    for hold in
        select r.id, r.lot_id, r.plate, r.reserved_until,
               coalesce(r.customer_name, '') as customer_name,
               r.customer_phone
          from public.category_reservations r
          join public.parking_settings ps on ps.lot_id = r.lot_id
         where r.status = 'active'
           and r.source = 'public'
           and r.customer_phone is not null
           and r.reminder_sent_at is null
           and r.reserved_until > now()
           and r.reserved_until <= now() + make_interval(
                   mins => greatest(coalesce(p_window_minutes, 60), 1)
               )
           and coalesce(ps.whatsapp_auto, false)
    loop
        select coalesce(ps.business_timezone, l.timezone, 'America/Bogota'),
               coalesce(l.name, '')
          into timezone_name, lot_name
          from public.parking_lots l
          left join public.parking_settings ps on ps.lot_id = l.id
         where l.id = hold.lot_id;

        insert into public.whatsapp_messages (
            lot_id, to_phone, template, language, params
        )
        values (
            hold.lot_id,
            hold.customer_phone,
            'reservation_reminder',
            'es',
            jsonb_build_array(
                hold.customer_name,
                hold.plate,
                to_char(
                    hold.reserved_until at time zone timezone_name,
                    'DD/MM HH24:MI'
                ),
                lot_name
            )
        );

        update public.category_reservations
           set reminder_sent_at = now()
         where id = hold.id;
        changed := changed + 1;
    end loop;

    return changed;
end;
$$;

grant execute on function public.notify_expiring_reservations(integer)
    to authenticated;
