-- SQL regression tests for the parts that are hard to cover from Flutter:
-- capacity, shifts/arqueo, discounts, auto-renewal charges and RLS isolation.
-- Runs in one transaction and rolls back; no fixture survives.
begin;

-- The suite runs on the site's business day (UTC-5), so `current_date` in the
-- fixtures matches what the RPCs compute locally. Without this, tests fail
-- between 00:00 and 05:00 UTC (evening in Bogota).
set local timezone = 'America/Bogota';

-- The x-lot-id header is mandatory since the contract migration; the suite
-- runs against the default lot unless a block switches it.
set local request.headers = '{"x-lot-id":"1"}';

-- migrate.sh records applied files; the suite applies them directly, so seed
-- the row the diagnostics snapshot counts.
insert into public.schema_migrations (name) values ('0001_core_schema.sql')
on conflict (name) do nothing;

create temp table _results (
    session_json jsonb,
    receipt jsonb
) on commit drop;

insert into auth.users (id, email, raw_app_meta_data) values
    ('00000000-0000-0000-0000-000000000001', 'admin@parking.local',
     '{"role": "admin"}'::jsonb),
    ('00000000-0000-0000-0000-000000000002', 'operator@parking.local',
     '{"role": "operator"}'::jsonb);

do $$
begin
    if (select count(*) from public.users) <> 2 then
        raise exception 'auth trigger did not mirror profiles';
    end if;
end $$;

update public.categories set capacity = 1 where id = 2;
insert into public.tariffs (category_id, type, amount, active)
values (2, 'hourly', 5000, true);

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
insert into _results (session_json)
select public.check_in('TEST001', 2, null, null, '[]'::jsonb, null, null);

do $$
begin
    begin
        perform public.check_in('TEST002', 2, null, null, '[]'::jsonb, null, null);
        raise exception 'capacity guard did not fire';
    exception when others then
        if sqlerrm not like '%CategoryFullError%' then
            raise;
        end if;
    end;
end $$;
reset request.jwt.claim.sub;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.open_shift(10000);

update _results
   set receipt = public.check_out(
       (session_json ->> 'id')::integer,
       now() + interval '1 minute', null, 'cash', 1000, 'cortesia'
   );

do $$
begin
    if ((select receipt from _results) ->> 'amount_charged')::integer <> 4000 then
        raise exception 'discount was not applied';
    end if;
end $$;

select public.close_shift(14000, 'ok');

do $$
begin
    if (select difference from public.shifts where id = 1) <> 0 then
        raise exception 'shift reconciliation mismatch';
    end if;
end $$;

select public.adjust_shift(1, 13900, 'correccion de prueba');

do $$
begin
    if (select difference from public.shifts where id = 1) <> -100 then
        raise exception 'shift adjustment did not update the difference';
    end if;
    if (select count(*) from public.shift_adjustments where shift_id = 1) <> 1 then
        raise exception 'shift adjustment audit row missing';
    end if;
end $$;

insert into public.vehicles (plate, category_id) values ('REN001', 2);
-- Renewal runs the day after the last valid day (lot business date).
insert into public.monthly_passes (
    vehicle_id, start_date, end_date, amount, active, auto_renew
) select id, current_date - 30, current_date - 1, 80000, true, true
  from public.vehicles where plate = 'REN001';

select public.renew_monthly_passes();

do $$
begin
    if (select count(*) from public.monthly_passes) <> 2 then
        raise exception 'renewal did not create exactly one pass';
    end if;
    if (select count(*) from public.monthly_pass_payments where status = 'pending') < 1 then
        raise exception 'renewal did not create a pending charge';
    end if;
end $$;

-- Lost ticket: the full daily tariff is charged and the reason is stored.
update public.categories set capacity = 0 where id = 2;
insert into public.tariffs (category_id, type, amount, active)
values (2, 'daily', 20000, true);

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
insert into _results (session_json)
select public.check_in('LOST01', 2, null, null, '[]'::jsonb, null, null);

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
begin
    begin
        perform public.check_out(
            (select s.id from public.parking_sessions s
               join public.vehicles v on v.id = s.vehicle_id
              where v.plate = 'LOST01'),
            now() + interval '1 minute', null, 'cash', 0, null, true, null
        );
        raise exception 'lost ticket without a reason was accepted';
    exception when others then
        if sqlerrm not like '%LostTicketReasonRequired%' then
            raise;
        end if;
    end;
end $$;

update _results
   set receipt = public.check_out(
       (select s.id from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
         where v.plate = 'LOST01'),
       now() + interval '1 minute', null, 'cash', 0, null, true, 'cliente sin ticket'
   )
 where session_json ->> 'plate' = 'LOST01';

do $$
begin
    if ((select receipt from _results
          where session_json ->> 'plate' = 'LOST01') ->> 'amount_charged')::integer <> 20000 then
        raise exception 'lost ticket did not charge the full daily tariff';
    end if;
    if ((select receipt from _results
          where session_json ->> 'plate' = 'LOST01') ->> 'lost_ticket')::boolean is not true then
        raise exception 'lost ticket flag missing from the receipt';
    end if;
    if (select lost_ticket_reason from public.parking_sessions
         where lost_ticket) is distinct from 'cliente sin ticket' then
        raise exception 'lost ticket reason was not stored';
    end if;
end $$;

-- Vehicle notes + blacklist: operators annotate, only admins block or clear.
insert into public.vehicles (plate, category_id) values ('BLK001', 2);

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
select public.update_vehicle_flags('BLK001', null, 'rayon puerta izquierda');

do $$
begin
    if (select notes from public.vehicles where plate = 'BLK001')
        is distinct from 'rayon puerta izquierda' then
        raise exception 'operator notes were not stored';
    end if;
    begin
        perform public.update_vehicle_flags('BLK001', true, null);
        raise exception 'operator toggled the blacklist';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.update_vehicle_flags('BLK001', true, null);

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    begin
        perform public.check_in('BLK001', 2, null, null, '[]'::jsonb, null, null);
        raise exception 'blacklisted vehicle checked in';
    exception when others then
        if sqlerrm not like '%VehicleBlacklistedError%' then
            raise;
        end if;
    end;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.update_vehicle_flags('BLK001', false, null);
select public.update_vehicle_flags('BLK001', null, '');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
insert into _results (session_json)
select public.check_in('BLK001', 2, null, null, '[]'::jsonb, null, null);

do $$
begin
    if (select notes from public.vehicles where plate = 'BLK001') is not null then
        raise exception 'empty notes did not clear the field';
    end if;
    if (select is_blacklisted from public.vehicles where plate = 'BLK001') then
        raise exception 'admin could not clear the blacklist';
    end if;
end $$;

-- Reservations hold capacity until used, cancelled or expired.
insert into public.categories (name, capacity) values ('testcap', 1);

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
select public.create_reservation('RES001',
    (select id from public.categories where name = 'testcap'),
    now() + interval '2 hours', 'cliente frecuente');

do $$
begin
    begin
        perform public.create_reservation('RES002',
            (select id from public.categories where name = 'testcap'),
            now() + interval '2 hours', null);
        raise exception 'reservation exceeded the capacity';
    exception when others then
        if sqlerrm not like '%CategoryFullError%' then
            raise;
        end if;
    end;
    if (select count(*) from public.category_reservations where status = 'active') <> 1 then
        raise exception 'reservation was not stored as active';
    end if;
end $$;

select public.cancel_reservation(
    (select id from public.category_reservations where plate = 'RES001')
);

do $$
begin
    if (select status from public.category_reservations where plate = 'RES001') <> 'cancelled' then
        raise exception 'cancel did not update the reservation';
    end if;
end $$;

select public.create_reservation('RES001',
    (select id from public.categories where name = 'testcap'),
    now() + interval '2 hours', null);
select public.check_in('RES001',
    (select id from public.categories where name = 'testcap'),
    null, null, '[]'::jsonb, null, null);

do $$
begin
    if not exists (
        select 1 from public.category_reservations
         where plate = 'RES001' and status = 'used'
    ) then
        raise exception 'check-in did not consume the reservation';
    end if;
    if not exists (
        select 1 from public.occupancy_snapshot() o, jsonb_array_elements(o -> 'by_category') c
         where (c ->> 'category_id')::integer =
               (select id from public.categories where name = 'testcap')
           and (c ->> 'count')::integer = 1
           and (c ->> 'reserved')::integer = 0
           and (c ->> 'is_full')::boolean
    ) then
        raise exception 'occupancy snapshot ignored the reservation';
    end if;
end $$;

-- Web push: one row per endpoint, always owned by auth.uid().
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
select public.save_web_push_subscription('https://push.example/1', 'p256', 'auth');
select public.save_web_push_subscription('https://push.example/1', 'p256b', 'authb');

do $$
begin
    if (select count(*) from public.web_push_subscriptions) <> 1 then
        raise exception 'endpoint upsert created a duplicate row';
    end if;
    if (select p256dh from public.web_push_subscriptions
         where endpoint = 'https://push.example/1') <> 'p256b' then
        raise exception 'endpoint upsert did not refresh the keys';
    end if;
    if (select user_id from public.web_push_subscriptions) <> 2 then
        raise exception 'subscription owner was not derived from auth.uid()';
    end if;
end $$;

select public.delete_web_push_subscription('https://push.example/1');

do $$
begin
    if exists (select 1 from public.web_push_subscriptions) then
        raise exception 'subscription was not deleted';
    end if;
end $$;

-- Multi-lot: two sites coexist, the header selects one and membership gates it.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.create_lot('N2', 'North lot', 'Calle 2', 'America/Bogota');
select public.set_lot_member(2, 2, 'operator');

insert into public.categories (name, capacity, lot_id)
values ('n2car', 1, 2);
insert into public.tariffs (category_id, type, amount, active, lot_id)
select id, 'hourly', 4000, true, 2
  from public.categories where lot_id = 2 and name = 'n2car';

do $$
begin
    if (select count(*) from public.lot_members where user_id = 2) <> 2 then
        raise exception 'lot membership was not created';
    end if;
    if (select count(*) from public.parking_settings where lot_id = 2) <> 1 then
        raise exception 'new lot got no settings row';
    end if;
    if (select count(*) from public.categories where lot_id = 2 and name = 'n2car') <> 1 then
        raise exception 'lot 2 category missing';
    end if;
end $$;

set local request.headers = '{"x-lot-id":"2"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
insert into _results (session_json)
select public.check_in(
    'L2CAR',
    (select id from public.categories where lot_id = 2 and name = 'n2car'),
    null, null, '[]'::jsonb, null, null
);

do $$
begin
    if not exists (
        select 1 from public.parking_sessions s
         where s.lot_id = 2 and s.status = 'open'
    ) then
        raise exception 'check-in was not stamped with the active lot';
    end if;
    begin
        perform public.check_in(
            'L2SECOND',
            (select id from public.categories where lot_id = 2 and name = 'n2car'),
            null, null, '[]'::jsonb, null, null
        );
        raise exception 'capacity was not enforced per lot';
    exception when others then
        if sqlerrm not like '%CategoryFullError%' then
            raise;
        end if;
    end;
end $$;

set local role authenticated;
set local request.headers = '{"x-lot-id":"1"}';
do $$
begin
    if exists (select 1 from public.parking_sessions where lot_id = 2) then
        raise exception 'RLS leak: lot 1 header sees lot 2 sessions';
    end if;
end $$;
reset role;

set local role authenticated;
set local request.headers = '{"x-lot-id":"2"}';
do $$
begin
    if (select count(*) from public.parking_sessions) <> 1 then
        raise exception 'lot 2 header should see exactly its own session';
    end if;
end $$;
reset role;

set local request.headers = '{"x-lot-id":"3"}';
do $$
begin
    begin
        perform public.current_lot_id();
        raise exception 'forged lot header was accepted';
    exception when others then
        if sqlerrm not like '%LotRequiredError%' then
            raise;
        end if;
    end;
end $$;

-- An explicit lot (offline replay) is honored after a lot switch, but still
-- validated against membership.
insert into public.categories (name, capacity, lot_id) values ('n2free', 0, 2);

set local request.headers = '{"x-lot-id":"1"}';
insert into _results (session_json)
select public.check_in(
    'L2OFF',
    (select id from public.categories where lot_id = 2 and name = 'n2free'),
    null, null, '[]'::jsonb, null, null, 2
);

do $$
begin
    if not exists (
        select 1 from public.parking_sessions s
         where s.lot_id = 2 and s.status = 'open'
           and s.vehicle_id = (select id from public.vehicles where plate = 'L2OFF')
    ) then
        raise exception 'offline replay ignored the captured lot';
    end if;
    begin
        perform public.check_in(
            'L2BAD',
            (select id from public.categories where lot_id = 2 and name = 'n2free'),
            null, null, '[]'::jsonb, null, null, 9
        );
        raise exception 'offline replay accepted a foreign lot';
    exception when others then
        if sqlerrm not like '%LotRequiredError%' then
            raise;
        end if;
    end;
end $$;

-- Lot members listing: admins only, scoped to the requested lot.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.list_lot_members(2);

do $$
begin
    if (select count(*) from jsonb_array_elements(public.list_lot_members(2))) < 1 then
        raise exception 'lot members were not listed';
    end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    begin
        perform public.list_lot_members(2);
        raise exception 'operator listed the lot members';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
end $$;

set local request.headers = '{"x-lot-id":"1"}';

-- Platform-only operations.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    begin
        perform public.create_lot('N3', 'Third lot');
        raise exception 'operator created a lot';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
    begin
        perform public.report_revenue_all(current_date, current_date);
        raise exception 'operator read the consolidated report';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.report_revenue_all(current_date, current_date);

do $$
begin
    begin
        perform public.set_lot_member(1, 2, 'operator');
        raise exception 'last lot admin was demoted';
    exception when others then
        if sqlerrm not like '%LastAdminError%' then
            raise;
        end if;
    end;
end $$;

-- The header is mandatory: omitting it fails closed.
do $$
declare
    saved text := current_setting('request.headers', true);
begin
    perform set_config('request.headers', '', true);
    begin
        perform public.current_lot_id();
        raise exception 'missing lot header was accepted';
    exception when others then
        if sqlerrm not like '%LotRequiredError%' then
            raise;
        end if;
    end;
    perform set_config('request.headers', saved, true);
end $$;

-- Evidence retention is a per-lot, bounded setting (0 = keep forever).
do $$
begin
    if (select evidence_retention_days from public.parking_settings where lot_id = 1) <> 0 then
        raise exception 'evidence retention must default to 0';
    end if;
    begin
        update public.parking_settings set evidence_retention_days = -1 where lot_id = 1;
        raise exception 'negative evidence retention was accepted';
    exception when check_violation then
        null;
    end;
end $$;

-- Diagnostics are admin-only read models over the operational backlog.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    snapshot jsonb := public.diagnostics_snapshot();
    errors jsonb := public.list_client_error_reports(10, 7);
begin
    if (snapshot ->> 'migrations')::integer < 1 then
        raise exception 'diagnostics snapshot has no migrations';
    end if;
    if not (snapshot ? 'notifications') or not (snapshot ? 'storage') then
        raise exception 'diagnostics snapshot is missing sections';
    end if;
    if jsonb_typeof(errors) <> 'array' then
        raise exception 'client error reports were not listed';
    end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    begin
        perform public.diagnostics_snapshot();
        raise exception 'operator read the diagnostics snapshot';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
    begin
        perform public.list_client_error_reports(10, 7);
        raise exception 'operator read the client error reports';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
end $$;

-- Audit log filters: by actor, and the unfiltered call still works.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
begin
    if jsonb_array_length(
           public.list_audit_log(50, null, null, null, 'admin')
       ) < 1 then
        raise exception 'audit actor filter returned nothing';
    end if;
    if jsonb_array_length(
           public.list_audit_log(50, null, null, null, 'ghost')
       ) <> 0 then
        raise exception 'audit actor filter ignored the name';
    end if;
end $$;

-- Today's dashboard summary reflects the check-outs and entries of the lot.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    summary jsonb := public.dashboard_today();
begin
    if (summary ->> 'lot_id')::integer <> 1 then
        raise exception 'dashboard summary used the wrong lot';
    end if;
    if (summary ->> 'revenue')::integer < 1 then
        raise exception 'dashboard summary ignored today revenue';
    end if;
    if (summary ->> 'entries')::integer < 1 then
        raise exception 'dashboard summary ignored today entries';
    end if;
end $$;

-- Consolidated report exposes per-site revenue, tickets and average ticket.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    lots jsonb;
    entry jsonb;
begin
    lots := public.report_revenue_all(current_date, current_date) -> 'by_lot';
    if jsonb_array_length(lots) < 2 then
        raise exception 'consolidated report does not list every site';
    end if;
    select item into entry
      from jsonb_array_elements(lots) item
     where item ->> 'lot_id' = '1';
    if entry is null or not (entry ? 'tickets') or not (entry ? 'avg_ticket') then
        raise exception 'per-site comparison fields are missing';
    end if;
end $$;

-- Vehicle history exposes the discount for reprints.
do $$
declare
    entry jsonb;
begin
    select item into entry
      from jsonb_array_elements(
             public.vehicle_history('TEST001') -> 'sessions'
           ) item
     where item ->> 'status' = 'closed'
     limit 1;
    if entry is null or not (entry ? 'discount_amount') then
        raise exception 'vehicle history does not expose the discount';
    end if;
    if (entry ->> 'discount_amount')::integer <> 1000 then
        raise exception 'vehicle history lost the discount amount';
    end if;
end $$;

-- Customer phone: valid values are stored, invalid ones rejected, and the
-- history exposes it for the WhatsApp action.
select public.update_vehicle_flags('BLK001', null, null, '+57 300 111 2233');

do $$
begin
    if (select owner_phone from public.vehicles where plate = 'BLK001')
        is distinct from '+57 300 111 2233' then
        raise exception 'owner phone was not stored';
    end if;
    if (public.vehicle_history('BLK001') ->> 'owner_phone')
        is distinct from '+57 300 111 2233' then
        raise exception 'vehicle history does not expose the phone';
    end if;
    begin
        perform public.update_vehicle_flags('BLK001', null, null, '123');
        raise exception 'invalid phone was accepted';
    exception when others then
        if sqlerrm not like '%InvalidPhoneError%' then
            raise;
        end if;
    end;
    perform public.update_vehicle_flags('BLK001', null, null, '');
    if (select owner_phone from public.vehicles where plate = 'BLK001') is not null then
        raise exception 'empty phone did not clear the field';
    end if;
end $$;

-- WhatsApp queue: disabled by default, validates the phone, records the lot.
set local request.headers = '{"x-lot-id":"2"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
begin
    begin
        perform public.enqueue_whatsapp_message('573001112233', 'receipt', '["ABC123"]'::jsonb);
        raise exception 'whatsapp queue accepted a disabled site';
    exception when others then
        if sqlerrm not like '%WhatsappDisabledError%' then
            raise;
        end if;
    end;
end $$;

update public.parking_settings set whatsapp_auto = true where lot_id = 2;

do $$
declare
    queued jsonb;
begin
    queued := public.enqueue_whatsapp_message(
        '+57 300 111 2233', 'receipt', '["ABC123","5000","TCK-NORTH-1"]'::jsonb
    );
    if (queued ->> 'status') <> 'pending' then
        raise exception 'queued whatsapp message is not pending';
    end if;
    if (select to_phone from public.whatsapp_messages where id = (queued ->> 'id')::bigint)
        <> '573001112233' then
        raise exception 'whatsapp phone was not normalized';
    end if;
    if (select lot_id from public.whatsapp_messages where id = (queued ->> 'id')::bigint) <> 2 then
        raise exception 'whatsapp message was not stamped with the lot';
    end if;
    begin
        perform public.enqueue_whatsapp_message('123', 'receipt', '[]'::jsonb);
        raise exception 'invalid whatsapp phone was accepted';
    exception when others then
        if sqlerrm not like '%InvalidPhoneError%' then
            raise;
        end if;
    end;
    update public.whatsapp_messages set status = 'sent', sent_at = now();
    if public.purge_whatsapp_messages(90) <> 0 then
        raise exception 'purge removed fresh whatsapp rows';
    end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
set local role authenticated;
do $$
begin
    if exists (select 1 from public.whatsapp_messages) then
        raise exception 'RLS leak: operator reads the whatsapp queue';
    end if;
end $$;
reset role;

-- Diagnostics expose the WhatsApp queue; admins can list it.
set local request.headers = '{"x-lot-id":"2"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    snapshot jsonb;
    queued jsonb;
begin
    perform public.enqueue_whatsapp_message('573001112233', 'receipt', '[]'::jsonb);
    snapshot := public.diagnostics_snapshot();
    queued := public.list_whatsapp_messages(10, 7);
    if not (snapshot ? 'whatsapp') then
        raise exception 'diagnostics snapshot has no whatsapp section';
    end if;
    if (snapshot -> 'whatsapp' ->> 'pending')::integer < 1 then
        raise exception 'whatsapp pending count is wrong';
    end if;
    if jsonb_typeof(queued) <> 'array' then
        raise exception 'whatsapp messages were not listed';
    end if;
    if not exists (
        select 1 from jsonb_array_elements(queued) item
         where item ->> 'to_phone' = '573001112233'
    ) then
        raise exception 'queued whatsapp message is missing from the list';
    end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    begin
        perform public.list_whatsapp_messages(10, 7);
        raise exception 'operator listed the whatsapp queue';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
end $$;

-- WhatsApp delivery metrics for the consolidated admin report.
set local request.headers = '{"x-lot-id":"2"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    -- The business day is the site's local date; `current_date` is UTC and
    -- would miss a message sent in the evening at UTC-5 (test flake at UTC
    -- midnight). A ±1 day window is deterministic.
    local_date date := (now() at time zone 'America/Bogota')::date;
    report jsonb := public.report_whatsapp(local_date - 1, local_date + 1);
begin
    if (report ->> 'sent')::integer < 1 then
        raise exception 'whatsapp report ignored sent messages';
    end if;
    if jsonb_typeof(report -> 'by_day') <> 'array' then
        raise exception 'whatsapp report has no daily breakdown';
    end if;
end $$;

-- Fare preview: same math as check-out, no side effects.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    preview jsonb;
    with_pass jsonb;
begin
    -- Entry in the past: the preview runs in the same transaction, and `now()`
    -- is constant there, so entry == now would be an empty billing period.
    insert into _results (session_json)
    select public.check_in(
        'PREVIEW1', 2, null, null, '[]'::jsonb, null,
        now() - interval '1 hour'
    );

    preview := public.check_out_preview(
        (select (session_json ->> 'id')::integer from _results
          where session_json ->> 'plate' = 'PREVIEW1')
    );
    if (preview ->> 'amount')::integer <> 5000 then
        raise exception 'fare preview did not match the hourly tariff';
    end if;
    if (preview ->> 'has_pass')::boolean then
        raise exception 'fare preview invented a pass';
    end if;
    if (select status from public.parking_sessions
         where id = (preview ->> 'session_id')::integer) <> 'open' then
        raise exception 'fare preview closed the session';
    end if;

    insert into public.monthly_passes (vehicle_id, start_date, end_date, amount)
    select id, current_date, current_date + 30, 80000
      from public.vehicles where plate = 'PREVIEW1';
    with_pass := public.check_out_preview((preview ->> 'session_id')::integer);
    if (with_pass ->> 'amount')::integer <> 0
       or not (with_pass ->> 'has_pass')::boolean then
        raise exception 'fare preview ignored the active pass';
    end if;

    if not (
        select has_pass from public.open_sessions_view
         where id = (preview ->> 'session_id')::integer
    ) then
        raise exception 'open sessions view did not report the active pass';
    end if;
end $$;

-- Branding is per lot: only the active lot's row changes.
set local request.headers = '{"x-lot-id":"2"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.set_branding_logo('logo_2');

do $$
begin
    if (select logo_version from public.parking_settings where lot_id = 2) <> 1 then
        raise exception 'logo version was not bumped for lot 2';
    end if;
    if (select logo_path from public.parking_settings where lot_id = 2) <> 'logo_2' then
        raise exception 'logo path was not stored for lot 2';
    end if;
    if (select logo_version from public.parking_settings where lot_id = 1) <> 0 then
        raise exception 'lot 1 branding was modified';
    end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    begin
        perform public.set_branding_logo('logo_2_b');
        raise exception 'operator changed the branding';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
end $$;

set local request.headers = '{"x-lot-id":"1"}';

-- Evidence objects must stay inside the active lot (policy regression guard).
do $$
begin
    if not exists (
        select 1 from pg_policies
         where schemaname = 'storage'
           and tablename = 'objects'
           and policyname = 'evidence_objects_read'
           and qual like '%can_read_evidence%'
    ) then
        raise exception 'evidence read policy is not scoped to the lot';
    end if;
end $$;

-- Retention and expiry jobs (called by pg_cron or the external cron).
insert into public.category_reservations (
    plate, category_id, reserved_from, reserved_until, status, lot_id
)
select 'OLDHOLD', (select id from public.categories where lot_id = 2 and name = 'n2free'),
       now() - interval '5 days', now() - interval '3 days', 'active', 2;

do $$
declare
    expired integer;
    purged integer;
begin
    expired := public.expire_reservations(24);
    if expired < 1 then
        raise exception 'expired reservations were not closed';
    end if;
    if not exists (
        select 1 from public.category_reservations
         where plate = 'OLDHOLD' and status = 'expired'
    ) then
        raise exception 'reservation did not move to expired';
    end if;

    insert into public.notifications (user_id, type, title, body, read_at, created_at)
    values (1, 'check_in', 'old read', 'x', now() - interval '200 days', now() - interval '200 days');
    insert into public.notifications (user_id, type, title, body, created_at)
    values (1, 'check_in', 'old unread', 'x', now() - interval '400 days');
    insert into public.notifications (user_id, type, title, body, created_at)
    values (1, 'check_in', 'fresh', 'x', now());

    purged := public.purge_stale_notifications(90);
    if purged <> 2 then
        raise exception 'stale notifications purge removed % rows', purged;
    end if;
    if not exists (
        select 1 from public.notifications where title = 'fresh'
    ) then
        raise exception 'purge removed a fresh notification';
    end if;
end $$;

-- Shift history filters: a range that excludes the shift returns nothing.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
begin
    if jsonb_array_length(
           public.list_shifts(20, current_date + 10, current_date + 11)
       ) <> 0 then
        raise exception 'shift filter ignored the requested range';
    end if;
    if jsonb_array_length(public.list_shifts(20)) < 1 then
        raise exception 'unfiltered shift history is empty';
    end if;
end $$;

-- Client error reports: bounded payload, own actor, admins only for reads.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
select public.report_client_error(
    'android',
    repeat('x', 3000),
    'stack',
    '{"screen": "check_in"}'::jsonb,
    '1.2.3'
);

do $$
begin
    if (select length(message) from public.client_error_reports) <> 2000 then
        raise exception 'client error message was not bounded';
    end if;
    if (select user_id from public.client_error_reports) <> 2 then
        raise exception 'client error owner was not derived from auth.uid()';
    end if;
end $$;

set local role authenticated;
do $$
begin
    if exists (select 1 from public.client_error_reports) then
        raise exception 'RLS leak: operator reads client error reports';
    end if;
end $$;
reset role;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.purge_client_error_reports(30);

do $$
begin
    if public.purge_client_error_reports(1) <> 0 then
        raise exception 'purge removed a fresh client error report';
    end if;
end $$;

-- Audit trail: reference-data changes are recorded with their actor, lot and
-- changed columns; only platform admins can read it.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
set local request.headers = '{"x-lot-id":"2"}';
insert into public.categories (name, capacity, lot_id) values ('audited', 2, 2);
update public.categories set capacity = 3 where name = 'audited' and lot_id = 2;

do $$
begin
    if (select count(*) from public.audit_log where table_name = 'categories') < 2 then
        raise exception 'category changes were not audited';
    end if;
    if (select actor_id from public.audit_log
         where table_name = 'categories' and action = 'update'
         order by id desc limit 1) <> 1 then
        raise exception 'audit actor was not derived from auth.uid()';
    end if;
    if not exists (
        select 1 from public.audit_log
         where table_name = 'categories' and action = 'update'
           and after ? 'capacity' and not after ? 'name'
    ) then
        raise exception 'audit did not keep only the changed columns';
    end if;
    if (select lot_id from public.audit_log
         where table_name = 'categories' and action = 'insert'
           and after ->> 'name' = 'audited'
         order by id desc limit 1) <> 2 then
        raise exception 'audit row was not stamped with the lot';
    end if;
    if (select count(*) from jsonb_array_elements(public.list_audit_log(50, null, null, 'categories'))) < 2 then
        raise exception 'audit log listing is incomplete';
    end if;
end $$;

set local request.headers = '{"x-lot-id":"1"}';

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    begin
        perform public.list_audit_log(10, null, null, null);
        raise exception 'operator read the audit log';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
end $$;
set local role authenticated;
do $$
begin
    if exists (select 1 from public.audit_log) then
        raise exception 'RLS leak: operator reads audit_log';
    end if;
end $$;
reset role;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
begin
    if public.purge_audit_log(365) <> 0 then
        raise exception 'purge removed fresh audit rows';
    end if;
end $$;

-- RLS: users only read their own rows. Operators now receive the site's
-- activity alerts, but never anyone else's.
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    if exists (select 1 from public.notifications where user_id <> 2) then
        raise exception 'RLS leak: operator reads another user''s notifications';
    end if;
    if not exists (select 1 from public.notifications where user_id = 2) then
        raise exception 'the operator lost their own activity alerts';
    end if;
end $$;
reset role;

-- Realtime evaluates the same policy with no x-lot-id header: a membership
-- check must not raise LotRequiredError there.
set local request.headers = '{}';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    if not exists (
        select 1 from public.notifications
         where user_id = 2 and lot_id = 1
    ) then
        raise exception 'the operator lost their own lot alerts';
    end if;
    if public.can_read_lot(999) then
        raise exception 'lot membership helper invented a membership';
    end if;
    if exists (
        select 1 from public.notifications
         where user_id = 2 and lot_id is not null and not public.can_read_lot(lot_id)
    ) then
        raise exception 'the operator read a lot they do not belong to';
    end if;
end $$;
reset role;
set local request.headers = '{"x-lot-id":"1"}';

-- Capacity groups: cars/pickups share the lot's car spots, motorcycles have
-- their own, and cars that leave their keys have a separate cap. Trucks and
-- buses are not limited by these settings.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    car_cat integer;
    moto_cat integer;
    car_open integer;
    moto_open integer;
    keys_open integer;
    refused boolean := false;
begin
    insert into public.parking_settings (lot_id) values (1)
    on conflict do nothing;

    select id into car_cat from public.categories
     where lot_id = 1 and lower(name) = 'car';
    select id into moto_cat from public.categories
     where lot_id = 1 and lower(name) = 'moto';
    if car_cat is null or moto_cat is null then
        raise exception 'capacity test needs the seeded car and moto categories';
    end if;

    -- Isolate the group caps from the per-category capacity.
    update public.categories set capacity = 0 where id in (car_cat, moto_cat);

    select count(*) into car_open
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.categories c on c.id = v.category_id
     where s.status = 'open' and s.lot_id = 1
       and lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv');
    select count(*) into moto_open
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.categories c on c.id = v.category_id
     where s.status = 'open' and s.lot_id = 1
       and lower(c.name) in ('moto', 'motos', 'motorcycle');
    select count(*) into keys_open
      from public.parking_sessions s
     where s.status = 'open' and s.lot_id = 1 and s.left_keys;

    update public.parking_settings
       set car_capacity = car_open + 1,
           moto_capacity = moto_open + 1,
           key_capacity = keys_open + 1
     where lot_id = 1;

    perform public.check_in('CAPCAR1', car_cat, null, null, '[]'::jsonb);
    begin
        perform public.check_in('CAPCAR2', car_cat, null, null, '[]'::jsonb);
    exception when others then
        if sqlerrm like '%ParkingFullError%' then
            refused := true;
        else
            raise;
        end if;
    end;
    if not refused then
        raise exception 'car space capacity was not enforced';
    end if;
    refused := false;

    perform public.check_in('CAPMOTO1', moto_cat, null, null, '[]'::jsonb);

    -- Room for the key test cars; the key cap is what must stop the second.
    update public.parking_settings set car_capacity = car_open + 3 where lot_id = 1;
    perform public.check_in(p_plate => 'CAPKEY1', p_category_id => car_cat, p_left_keys => true);
    begin
        perform public.check_in(p_plate => 'CAPKEY2', p_category_id => car_cat, p_left_keys => true);
    exception when others then
        if sqlerrm like '%KeysFullError%' then
            refused := true;
        else
            raise;
        end if;
    end;
    if not refused then
        raise exception 'key capacity was not enforced';
    end if;

    if not (select left_keys from public.parking_sessions s
              join public.vehicles v on v.id = s.vehicle_id
             where v.plate = 'CAPKEY1' and s.status = 'open') then
        raise exception 'left_keys was not stored on the session';
    end if;
    if not (select left_keys from public.open_sessions_view v
             where v.plate = 'CAPKEY1') then
        raise exception 'open_sessions_view did not expose left_keys';
    end if;

    update public.parking_settings
       set car_capacity = 0, moto_capacity = 0, key_capacity = 0
     where lot_id = 1;
end $$;

-- Holds consume the same group spaces as parked cars: a site cannot promise
-- more spots than it has, and a walk-in cannot take a promised one.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    car_cat integer;
    car_open integer;
    car_reserved integer;
    refused boolean := false;
begin
    select id into car_cat from public.categories
     where lot_id = 1 and lower(name) = 'car';
    update public.categories set capacity = 0 where id = car_cat;
    update public.parking_settings
       set car_capacity = 0, moto_capacity = 0, key_capacity = 0
     where lot_id = 1;

    select count(*) into car_open
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
      join public.categories c on c.id = v.category_id
     where s.status = 'open' and s.lot_id = 1
       and lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv');
    select count(*) into car_reserved
      from public.category_reservations r
      join public.categories c on c.id = r.category_id
     where r.status = 'active' and r.reserved_until > now() and r.lot_id = 1
       and lower(c.name) in ('car', 'carro', 'auto', 'camioneta', 'suv');

    update public.parking_settings
       set car_capacity = car_open + car_reserved + 2
     where lot_id = 1;

    perform public.create_reservation('HOLDG1', car_cat, now() + interval '2 hours');
    perform public.create_reservation('HOLDG2', car_cat, now() + interval '2 hours');

    begin
        perform public.create_reservation('HOLDG3', car_cat, now() + interval '2 hours');
    exception when others then
        if sqlerrm like '%ParkingFullError%' or sqlerrm like '%CategoryFullError%' then
            refused := true;
        else
            raise;
        end if;
    end;
    if not refused then
        raise exception 'reservations ignored the group capacity';
    end if;

    refused := false;
    begin
        perform public.check_in('CAPWALK1', car_cat, null, null, '[]'::jsonb);
    exception when others then
        if sqlerrm like '%ParkingFullError%' or sqlerrm like '%CategoryFullError%' then
            refused := true;
        else
            raise;
        end if;
    end;
    if not refused then
        raise exception 'a walk-in took a reserved space';
    end if;

    update public.parking_settings
       set car_capacity = 0, moto_capacity = 0, key_capacity = 0
     where lot_id = 1;
end $$;

-- Fare breakdown: the explanation shown to the operator is the same math the
-- server charges, including the night window and the daily cap.
do $$
declare
    brk_cat integer;
    night_cat integer;
    breakdown jsonb;
    night jsonb;
    entry_at timestamptz := timestamptz '2026-03-10 10:15:00-05';
    exit_at timestamptz := timestamptz '2026-03-10 13:40:00-05';
begin
    insert into public.categories (name, capacity, lot_id)
    values ('brkcar', 0, 1)
    returning id into brk_cat;
    insert into public.tariffs (category_id, type, amount, active, lot_id) values
        (brk_cat, 'hourly', 3000, true, 1),
        (brk_cat, 'daily', 10000, true, 1);

    breakdown := public.fare_breakdown(brk_cat, entry_at, exit_at, false);
    if (breakdown ->> 'amount')::integer
       <> public.calculate_fare(brk_cat, entry_at, exit_at, false) then
        raise exception 'fare breakdown disagrees with calculate_fare';
    end if;
    if (breakdown ->> 'day_hours')::integer <> 4 then
        raise exception 'fare breakdown billed the wrong day hours: %', breakdown;
    end if;
    if (breakdown ->> 'night_hours')::integer <> 0
       or (breakdown ->> 'days')::integer <> 1 then
        raise exception 'fare breakdown invented night hours: %', breakdown;
    end if;
    if not (breakdown ->> 'daily_cap_applied')::boolean
       or (breakdown ->> 'amount')::integer <> 10000 then
        raise exception 'fare breakdown ignored the daily cap: %', breakdown;
    end if;
    if (breakdown ->> 'elapsed_seconds')::integer <> 12300 then
        raise exception 'fare breakdown lost the elapsed time: %', breakdown;
    end if;

    if (public.fare_breakdown(brk_cat, entry_at, exit_at, true) ->> 'amount')::integer <> 0 then
        raise exception 'a monthly pass was charged';
    end if;

    insert into public.categories (name, capacity, lot_id)
    values ('brknight', 0, 1)
    returning id into night_cat;
    insert into public.tariffs (
        category_id, type, amount, active, lot_id, start_time, end_time
    ) values
        (night_cat, 'hourly', 3000, true, 1, null, null),
        (night_cat, 'nightly', 9000, true, 1, '20:00', '06:00');

    night := public.fare_breakdown(
        night_cat,
        timestamptz '2026-03-10 21:00:00-05',
        timestamptz '2026-03-10 23:00:00-05',
        false
    );
    if (night ->> 'night_hours')::integer <> 2
       or (night ->> 'day_hours')::integer <> 0
       or (night ->> 'amount')::integer <> 18000 then
        raise exception 'night window was not billed separately: %', night;
    end if;

    begin
        perform public.fare_breakdown(brk_cat, exit_at, entry_at, false);
        raise exception 'an empty billing period was accepted';
    exception when others then
        if sqlerrm not like '%InvalidBillingPeriodError%' then
            raise;
        end if;
    end;
end $$;

-- Slot board: the visual map is lot-scoped and groups by category.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    free_cat integer;
    board jsonb;
begin
    insert into public.categories (name, capacity, lot_id)
    values ('brdwalk', 0, 1)
    returning id into free_cat;

    perform public.check_in('BOARD1', free_cat, null, null, '[]'::jsonb);

    board := public.slot_board();
    if (board ->> 'car_capacity')::integer
       <> (select car_capacity from public.parking_settings where lot_id = 1) then
        raise exception 'slot board lost the car capacity';
    end if;
    if not exists (
        select 1 from jsonb_array_elements(board -> 'sessions') item
         where item ->> 'plate' = 'BOARD1'
           and item ->> 'group' = 'heavy'
    ) then
        raise exception 'slot board did not paint the vehicle inside: %', board;
    end if;

    set local request.headers = '{"x-lot-id":"2"}';
    board := public.slot_board();
    if exists (
        select 1 from jsonb_array_elements(board -> 'sessions') item
         where item ->> 'plate' = 'BOARD1'
    ) then
        raise exception 'slot board leaked another lot';
    end if;
    set local request.headers = '{"x-lot-id":"1"}';
end $$;

-- Out-of-service spots: they stay in the configured capacity but are never
-- offered, neither to a walk-in nor to a hold.
set local request.headers = '{"x-lot-id":"2"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    moto_cat integer;
    refused boolean := false;
    snapshot jsonb;
    board jsonb;
begin
    insert into public.categories (name, capacity, lot_id)
    values ('moto', 0, 2)
    returning id into moto_cat;
    update public.parking_settings
       set moto_capacity = 2, moto_out_of_service = 2
     where lot_id = 2;

    snapshot := public.capacity_snapshot();
    if (snapshot ->> 'moto_capacity')::integer <> 2
       or (snapshot ->> 'moto_available')::integer <> 0
       or (snapshot ->> 'moto_out_of_service')::integer <> 2 then
        raise exception 'snapshot ignored the out-of-service spots: %', snapshot;
    end if;

    board := public.slot_board();
    if (board ->> 'moto_out_of_service')::integer <> 2
       or (board ->> 'moto_capacity')::integer <> 2 then
        raise exception 'board ignored the out-of-service spots: %', board;
    end if;

    begin
        perform public.check_in('OOSM1', moto_cat, null, null, '[]'::jsonb);
        raise exception 'a check-in took a spot out of service';
    exception when others then
        if sqlerrm not like '%ParkingFullError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'out-of-service check-in was accepted';
    end if;

    refused := false;
    begin
        perform public.create_reservation('OOSM2', moto_cat, now() + interval '1 hour');
        raise exception 'a hold took a spot out of service';
    exception when others then
        if sqlerrm not like '%ParkingFullError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'out-of-service hold was accepted';
    end if;

    -- One usable spot: it can be sold once, never twice.
    update public.parking_settings set moto_out_of_service = 1 where lot_id = 2;
    perform public.check_in('OOSM3', moto_cat, null, null, '[]'::jsonb);

    refused := false;
    begin
        perform public.check_in('OOSM4', moto_cat, null, null, '[]'::jsonb);
    exception when others then
        if sqlerrm not like '%ParkingFullError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'the usable spot was oversold';
    end if;

    update public.parking_settings
       set moto_capacity = 0, moto_out_of_service = 0
     where lot_id = 2;
end $$;
set local request.headers = '{"x-lot-id":"1"}';

-- Live activity: the whole site is told who registered an entry/exit, and the
-- alert never leaves the lot.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    rtn_cat integer;
    session_json jsonb;
    session_id integer;
    actor_name text;
    alert jsonb;
    outsider integer;
begin
    insert into public.categories (name, capacity, lot_id)
    values ('rtncat', 0, 1)
    returning id into rtn_cat;
    insert into public.tariffs (category_id, type, amount, active, lot_id)
    values (rtn_cat, 'hourly', 1000, true, 1);

    session_json := public.check_in(
        'RTN001', rtn_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 minute'
    );
    session_id := (session_json ->> 'id')::integer;
    select display_name into actor_name from public.users where id = 2;

    select to_jsonb(n) into alert
      from public.notifications n
     where n.type = 'check_in'
       and n.user_id = 2
       and n.data ->> 'session_id' = session_id::text;
    if alert is null then
        raise exception 'the operator did not get the activity alert';
    end if;
    if (alert ->> 'body') not like '%' || actor_name || '%'
       or (alert ->> 'body') not like '%RTN001%' then
        raise exception 'the activity alert does not name actor and plate: %', alert;
    end if;
    if (alert -> 'data' ->> 'action') <> 'check_in' then
        raise exception 'the activity alert has no action payload: %', alert;
    end if;

    select u.id into outsider
      from public.users u
     where u.username = 'norte2';
    if exists (
        select 1 from public.notifications n
         where n.user_id = outsider
           and n.data ->> 'session_id' = session_id::text
    ) then
        raise exception 'the activity alert leaked to another lot';
    end if;

    -- Someone else closes it: the alert names the actual actor.
    set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
    perform public.check_out(session_id, null, null, 'cash');

    select to_jsonb(n) into alert
      from public.notifications n
     where n.type = 'check_out'
       and n.user_id = 2
       and n.data ->> 'session_id' = session_id::text;
    if alert is null then
        raise exception 'the operator did not get the exit alert';
    end if;
    if (alert ->> 'body') not like '%Cobro%'
       or (alert -> 'data' ->> 'action') <> 'check_out'
       or (alert -> 'data' ->> 'amount_charged') is null then
        raise exception 'the exit alert has no charge: %', alert;
    end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';

-- Physical spots: the map defines the group capacity, check-in takes the
-- chosen spot or the first free one, and check-out frees it.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    spot_cat integer;
    spot_a integer;
    spot_b integer;
    spot_oos integer;
    first_in jsonb;
    second_in jsonb;
    board jsonb;
    moved jsonb;
    refused boolean;
begin
    -- Deterministic: no other open session competes for the group's spots.
    update public.parking_sessions
       set status = 'closed', exit_time = now(), amount_charged = 0
     where status = 'open' and lot_id = 1;

    insert into public.categories (name, capacity, lot_id)
    values ('spotcar', 0, 1)
    returning id into spot_cat;
    insert into public.tariffs (category_id, type, amount, active, lot_id)
    values (spot_cat, 'hourly', 1000, true, 1);

    delete from public.parking_spots where lot_id = 1;

    spot_a := (public.save_parking_spot('T1', 'heavy', 0, 0) ->> 'id')::integer;
    spot_b := (public.save_parking_spot('T2', 'heavy', 0, 1) ->> 'id')::integer;
    spot_oos := (
        public.save_parking_spot('T3', 'heavy', 1, 0, null, false) ->> 'id'
    )::integer;

    -- Out of service is not offered, even when requested.
    refused := false;
    begin
        perform public.check_in(
            'SPOTA0', spot_cat, null, null, '[]'::jsonb, null, null, null,
            false, spot_oos
        );
        raise exception 'an out-of-service spot was accepted';
    exception when others then
        if sqlerrm not like '%SpotOutOfServiceError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'out-of-service spot was not refused';
    end if;

    -- Automatic: first free spot, top-left first.
    first_in := public.check_in(
        'SPOTA1', spot_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 minute'
    );
    if first_in ->> 'spot_code' <> 'T1' then
        raise exception 'auto-assignment did not take the first spot: %', first_in;
    end if;

    -- Explicit spot, when the operator picks one.
    second_in := public.check_in(
        'SPOTA2', spot_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 minute', null, false, spot_b
    );
    if (second_in ->> 'spot_id')::integer <> spot_b then
        raise exception 'the requested spot was ignored: %', second_in;
    end if;

    -- The map defines the capacity: two active spots, both taken.
    refused := false;
    begin
        perform public.check_in('SPOTA3', spot_cat);
        raise exception 'a third car took a spot that does not exist';
    exception when others then
        if sqlerrm not like '%ParkingFullError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'the map capacity was ignored';
    end if;

    -- Moving: a taken spot is refused; automatic keeps the current one.
    refused := false;
    begin
        perform public.assign_session_spot(
            (second_in ->> 'id')::integer, spot_a
        );
        raise exception 'two cars shared a spot';
    exception when others then
        if sqlerrm not like '%SpotTakenError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'spot conflict was not refused';
    end if;

    moved := public.assign_session_spot((first_in ->> 'id')::integer, null);
    if (moved ->> 'spot_id')::integer <> spot_a then
        raise exception 'automatic move changed the spot: %', moved;
    end if;

    -- A spot with a car inside cannot be removed.
    refused := false;
    begin
        perform public.delete_parking_spot(spot_a);
        raise exception 'an occupied spot was deleted';
    exception when others then
        if sqlerrm not like '%SpotOccupiedError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'occupied spot deletion was not refused';
    end if;

    board := public.slot_board();
    if jsonb_array_length(board -> 'spots') <> 3 then
        raise exception 'board did not paint the map: %', board;
    end if;
    if not exists (
        select 1 from jsonb_array_elements(board -> 'sessions') item
         where item ->> 'plate' = 'SPOTA1'
           and (item ->> 'spot_id')::integer = spot_a
    ) then
        raise exception 'board lost the assigned spot';
    end if;

    -- Check-out frees the spot for the next car.
    perform public.check_out((first_in ->> 'id')::integer, null, null, 'cash');
    perform public.check_out((second_in ->> 'id')::integer, null, null, 'cash');
    perform public.delete_parking_spot(spot_a);
    perform public.delete_parking_spot(spot_b);
    perform public.delete_parking_spot(spot_oos);

    -- A clean map keeps the configured capacity and no spots.
    board := public.slot_board();
    if jsonb_array_length(board -> 'spots') <> 0 then
        raise exception 'spots survived deletion';
    end if;
end $$;

-- The configured capacity is the number of bays: no more, no fewer.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    car_space jsonb;
    refused boolean;
begin
    update public.parking_settings
       set car_capacity = 2, moto_capacity = 0
     where lot_id = 1;
    delete from public.parking_spots where lot_id = 1;

    perform public.save_parking_spot('C1', 'car', 0, 0);
    perform public.save_parking_spot('C2', 'car', 0, 1);

    -- The snapshot keeps the configured target next to the drawn bays.
    update public.parking_settings set car_capacity = 3 where lot_id = 1;
    select public.capacity_snapshot() into car_space;
    if (car_space ->> 'car_capacity')::integer <> 2
       or (car_space ->> 'car_target_capacity')::integer <> 3 then
        raise exception 'snapshot lost drawn vs target bays: %', car_space;
    end if;
    update public.parking_settings set car_capacity = 2 where lot_id = 1;

    refused := false;
    begin
        perform public.save_parking_spot('C3', 'car', 1, 0);
        raise exception 'the map exceeded the configured capacity';
    exception when others then
        if sqlerrm not like '%SpotCapacityReachedError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'extra bay was accepted';
    end if;

    refused := false;
    begin
        perform public.delete_parking_spot(
            (select id from public.parking_spots where lot_id = 1 and code = 'C1')
        );
        raise exception 'the map went below the configured capacity';
    exception when others then
        if sqlerrm not like '%SpotCapacityRequiredError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'bay deletion below capacity was accepted';
    end if;

    -- Lowering the target first makes the removal legal.
    update public.parking_settings set car_capacity = 1 where lot_id = 1;
    perform public.delete_parking_spot(
        (select id from public.parking_spots where lot_id = 1 and code = 'C2')
    );
    update public.parking_settings
       set car_capacity = 0, moto_capacity = 0
     where lot_id = 1;
    delete from public.parking_spots where lot_id = 1;

    select public.capacity_snapshot() into car_space;
    if (car_space ->> 'car_available')::integer <> 0 then
        raise exception 'snapshot kept stale bays: %', car_space;
    end if;
end $$;

-- Records log: lot-scoped, plate filter, totals and paging.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    car_cat integer;
    closed_id integer;
    result jsonb;
begin
    select id into car_cat
      from public.categories
     where lot_id = 1 and lower(name) = 'car'
     limit 1;

    perform public.check_in(
        'REC001', car_cat, null, null, '[]'::jsonb, null,
        now() - interval '2 hours'
    );
    select s.id into closed_id
      from public.parking_sessions s
      join public.vehicles v on v.id = s.vehicle_id
     where v.plate = 'REC001' and s.status = 'open' and s.lot_id = 1
     order by s.id desc limit 1;
    perform public.check_out(closed_id, null, null, 'cash');

    perform public.check_in(
        'REC002', car_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 hour'
    );

    result := public.session_records('REC00', 10, 0);
    if (result ->> 'total')::integer <> 2 then
        raise exception 'records lost the plate filter: %', result;
    end if;
    if not exists (
        select 1 from jsonb_array_elements(result -> 'records') item
         where item ->> 'plate' = 'REC001'
           and item ->> 'status' = 'closed'
           and item ->> 'exit_time' is not null
           and (item ->> 'duration_seconds')::integer >= 3600
    ) then
        raise exception 'closed record is incomplete: %', result;
    end if;
    if not exists (
        select 1 from jsonb_array_elements(result -> 'records') item
         where item ->> 'plate' = 'REC002'
           and item ->> 'status' = 'open'
           and item ->> 'exit_time' is null
    ) then
        raise exception 'open record is incomplete: %', result;
    end if;

    result := public.session_records('REC001', 10, 0);
    if (result ->> 'total')::integer <> 1 then
        raise exception 'records ignored the exact plate: %', result;
    end if;

    result := public.session_records('ZZZ999', 10, 0);
    if (result ->> 'total')::integer <> 0
       or jsonb_array_length(result -> 'records') <> 0 then
        raise exception 'records invented rows: %', result;
    end if;

    -- Business-date range (inclusive) and validation.
    result := public.session_records(null, 10, 0, current_date, current_date);
    if (result ->> 'total')::integer < 2 then
        raise exception 'date range lost today''s rows: %', result;
    end if;
    result := public.session_records(
        null, 10, 0, current_date + 1, current_date + 7
    );
    if (result ->> 'total')::integer <> 0 then
        raise exception 'future range returned rows: %', result;
    end if;
    begin
        perform public.session_records(
            null, 10, 0, current_date, current_date - 1
        );
        raise exception 'an inverted range was accepted';
    exception when others then
        if sqlerrm not like '%InvalidReportRangeError%' then
            raise;
        end if;
    end;

    -- Another lot never sees these rows.
    set local request.headers = '{"x-lot-id":"2"}';
    result := public.session_records('REC001', 10, 0);
    if (result ->> 'total')::integer <> 0 then
        raise exception 'records leaked to another lot: %', result;
    end if;
    set local request.headers = '{"x-lot-id":"1"}';
end $$;

-- Optional walk-around video: stored as evidence media and painted on the board.
-- check_in only accepts paths the operator actually uploaded.
insert into storage.objects (bucket_id, name, owner)
values ('evidence', 'video/ev.mp4', '00000000-0000-0000-0000-000000000002');
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    car_cat integer;
    entry jsonb;
    vid_session integer;
    board jsonb;
begin
    select id into car_cat
      from public.categories
     where lot_id = 1 and lower(name) = 'car'
     limit 1;

    entry := public.check_in(
        'VID001', car_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 minute', null, false, null,
        '[{"path":"video/ev.mp4","duration_seconds":42}]'::jsonb
    );
    vid_session := (entry ->> 'id')::integer;

    if (entry ->> 'video_count')::integer <> 1 then
        raise exception 'the video was not counted: %', entry;
    end if;
    if not exists (
        select 1 from public.evidence_photos p
         where p.session_id = vid_session
           and p.kind = 'video'
           and p.file_path = 'video/ev.mp4'
           and p.duration_seconds = 42
    ) then
        raise exception 'the video row is missing';
    end if;

    board := public.slot_board();
    if not exists (
        select 1 from jsonb_array_elements(board -> 'sessions') item
         where item ->> 'plate' = 'VID001'
           and (item ->> 'video_count')::integer = 1
    ) then
        raise exception 'board lost the video count: %', board;
    end if;

    perform public.check_out(vid_session, null, null, 'cash');
    delete from public.evidence_photos where session_id = vid_session;
end $$;

-- Legal policy: a public profile for customers and an admin-only template reset.
set local request.headers = '{"x-lot-id":"1"}';
set local role anon;
do $$
declare
    profile jsonb;
begin
    profile := public.public_lot_profile(1);
    if profile is null
       or coalesce(profile ->> 'legal_policy', '') = ''
       or coalesce(profile ->> 'name', '') = '' then
        raise exception 'public profile is incomplete: %', profile;
    end if;
    if profile ? 'pin_hash' or profile ? 'whatsapp_auto'
       or profile ? 'key_capacity' then
        raise exception 'public profile leaked private settings: %', profile;
    end if;
end $$;
reset role;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    begin
        perform public.reset_legal_policy();
        raise exception 'an operator reset the legal policy';
    exception when others then
        if sqlerrm not like '%AdminRequiredError%' then
            raise;
        end if;
    end;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    template text;
begin
    update public.parking_settings
       set legal_policy = 'texto temporal'
     where lot_id = 1;
    template := public.reset_legal_policy();
    if template is null or template not like '%POLÍTICAS Y CONTRATO%' then
        raise exception 'reset did not return the template';
    end if;
    if (select legal_policy from public.parking_settings where lot_id = 1)
       <> template then
        raise exception 'reset did not store the template';
    end if;
end $$;
reset role;

-- Card payments must say debit or credit; cash ignores the field.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    card_cat integer;
    entry jsonb;
    sid integer;
    receipt jsonb;
    refused boolean;
begin
    insert into public.categories (name, capacity, lot_id)
    values ('cardpay', 0, 1)
    returning id into card_cat;
    insert into public.tariffs (category_id, type, amount, active, lot_id)
    values (card_cat, 'hourly', 1000, true, 1);

    entry := public.check_in(
        'CARD01', card_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 minute'
    );
    sid := (entry ->> 'id')::integer;

    refused := false;
    begin
        perform public.check_out(sid, null, null, 'card');
        raise exception 'a card payment without debit/credit was accepted';
    exception when others then
        if sqlerrm not like '%InvalidCardTypeError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'card type was not required';
    end if;

    receipt := public.check_out(
        sid, null, null, 'card', 0, null, false, null, null, 'debit'
    );
    if receipt ->> 'card_type' <> 'debit' then
        raise exception 'card type was not stored: %', receipt;
    end if;
    if (select card_type from public.parking_sessions where id = sid)
       <> 'debit' then
        raise exception 'session lost the card type';
    end if;

    -- Cash can record the amount received and the change; short cash is refused.
    entry := public.check_in(
        'CASH01', card_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 minute'
    );
    sid := (entry ->> 'id')::integer;
    receipt := public.check_out(
        sid, null, null, 'cash', 0, null, false, null, null, null, 5000
    );
    if (receipt ->> 'cash_received')::integer <> 5000
       or (receipt ->> 'cash_change')::integer <> 4000 then
        raise exception 'cash change was not stored: %', receipt;
    end if;
    if (select cash_received from public.parking_sessions where id = sid) <> 5000
       or (select cash_change from public.parking_sessions where id = sid) <> 4000 then
        raise exception 'session lost the cash change';
    end if;

    entry := public.check_in(
        'CASH02', card_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 minute'
    );
    sid := (entry ->> 'id')::integer;
    refused := false;
    begin
        perform public.check_out(
            sid, null, null, 'cash', 0, null, false, null, null, null, 500
        );
        raise exception 'short cash was accepted';
    exception when others then
        if sqlerrm not like '%InvalidCashReceivedError%' then
            raise;
        end if;
        refused := true;
    end;
    if not refused then
        raise exception 'short cash was not refused';
    end if;
    perform public.check_out(sid, null, null, 'cash');

    -- Cash with a stray card type is ignored (no card fields).
    entry := public.check_in(
        'CARD02', card_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 minute'
    );
    sid := (entry ->> 'id')::integer;
    receipt := public.check_out(
        sid, null, null, 'cash', 0, null, false, null, null, 'credit'
    );
    if receipt ->> 'card_type' is not null then
        raise exception 'cash kept a card type: %', receipt;
    end if;
end $$;

-- Currency: integer amounts in COP pesos or USD cents; only supported codes.
set local request.headers = '{"x-lot-id":"1"}';
reset role;
do $$
declare
    code text;
begin
    select currency into code from public.parking_settings where lot_id = 1;
    if code <> 'COP' then
        raise exception 'currency default is not COP: %', code;
    end if;

    update public.parking_settings set currency = 'USD' where lot_id = 1;

    begin
        update public.parking_settings set currency = 'EUR' where lot_id = 1;
        raise exception 'an unsupported currency was accepted';
    exception when check_violation then
        null;
    end;
end $$;

set local role anon;
do $$
declare
    profile jsonb;
begin
    profile := public.public_lot_profile(1);
    if profile ->> 'currency' <> 'USD' then
        raise exception 'public profile lost the currency: %', profile;
    end if;
end $$;

reset role;
update public.parking_settings set currency = 'COP' where lot_id = 1;

-- Scale hardening (0069): search indexes exist and invariants hold.
do $$
begin
    if to_regclass('public.ix_vehicles_plate_trgm') is null then
        raise exception 'missing vehicles trigram index';
    end if;
    if to_regclass('public.ix_sessions_lot_entry') is null
       or to_regclass('public.ix_passes_lot_end') is null
       or to_regclass('public.ix_reservations_lot_until') is null
       or to_regclass('public.ix_notifications_lot_user_created') is null then
        raise exception 'missing hot-path index';
    end if;
    if not exists (
        select 1 from pg_extension where extname = 'pg_trgm'
    ) then
        raise exception 'pg_trgm is not installed';
    end if;
end $$;

do $$
declare
    vehicle integer := (select id from public.vehicles order by id limit 1);
begin
    begin
        insert into public.monthly_passes (
            vehicle_id, start_date, end_date, amount
        ) values (vehicle, '2026-02-01', '2026-01-01', 1000);
        raise exception 'a pass with end < start was accepted';
    exception when check_violation then
        null;
    end;

    begin
        insert into public.monthly_passes (
            vehicle_id, start_date, end_date, amount
        ) values (vehicle, '2026-01-01', '2026-02-01', -1);
        raise exception 'a negative pass amount was accepted';
    exception when check_violation then
        null;
    end;

    begin
        update public.parking_sessions set amount_charged = -1 where id = (
            select id from public.parking_sessions order by id limit 1
        );
        raise exception 'a negative charge was accepted';
    exception when check_violation then
        null;
    end;
end $$;

-- ===========================================================================
-- Audit fixes 0072/0073 (2026-11).
-- ===========================================================================
reset role;
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';

insert into auth.users (id, email, raw_app_meta_data) values
    ('00000000-0000-0000-0000-000000000003', 'shiftop@parking.local',
     '{"role": "operator"}'::jsonb),
    ('00000000-0000-0000-0000-000000000004', 'lotadmin2@parking.local',
     '{"role": "operator"}'::jsonb);

select public.set_lot_member(
    (select id from public.users where username = 'shiftop' limit 1),
    2, 'operator');
select public.set_lot_member(
    (select id from public.users where username = 'lotadmin2' limit 1),
    2, 'admin');

-- Fix 1: billable hours are rounded up once for the whole stay.
insert into public.categories (name, capacity, lot_id) values
    ('fx1plain', 0, 1),
    ('fx1night', 0, 1);
insert into public.tariffs (category_id, type, amount, active, lot_id)
select id, 'hourly', 3000, true, 1 from public.categories where name = 'fx1plain'
union all
select id, 'daily', 10000, true, 1 from public.categories where name = 'fx1plain';
insert into public.tariffs (
    category_id, type, amount, active, lot_id, start_time, end_time
)
select id, 'hourly', 3000, true, 1, null, null from public.categories where name = 'fx1night'
union all
select id, 'nightly', 2000, true, 1, '18:00', '06:00' from public.categories where name = 'fx1night';

do $$
declare
    plain_cat integer := (select id from public.categories where name = 'fx1plain');
    night_cat integer := (select id from public.categories where name = 'fx1night');
    fare jsonb;
begin

    -- Success: 2 minutes across midnight is one hour, not two.
    fare := public.fare_breakdown(plain_cat,
        timestamptz '2026-03-10 23:59:00-05', timestamptz '2026-03-11 00:01:00-05');
    if (fare ->> 'amount')::integer <> 3000
       or (fare ->> 'day_hours')::integer <> 1
       or (fare ->> 'days')::integer <> 2 then
        raise exception 'fix1: 23:59->00:01 must bill one hour: %', fare;
    end if;

    fare := public.fare_breakdown(plain_cat,
        timestamptz '2026-03-10 23:30:00-05', timestamptz '2026-03-11 00:30:00-05');
    if (fare ->> 'amount')::integer <> 3000 or (fare ->> 'day_hours')::integer <> 1 then
        raise exception 'fix1: 23:30->00:30 must bill one hour: %', fare;
    end if;

    -- Success: crossing the night window start bills one hour, to the
    -- bucket with the largest share (3 of 5 minutes are night).
    fare := public.fare_breakdown(night_cat,
        timestamptz '2026-03-10 17:58:00-05', timestamptz '2026-03-10 18:03:00-05');
    if (fare ->> 'day_hours')::integer + (fare ->> 'night_hours')::integer <> 1
       or (fare ->> 'night_hours')::integer <> 1
       or (fare ->> 'amount')::integer <> 2000 then
        raise exception 'fix1: 17:58->18:03 must bill one hour: %', fare;
    end if;

    -- Exact hours stay exact; the cap still applies per calendar day.
    fare := public.fare_breakdown(plain_cat,
        timestamptz '2026-03-10 10:00:00-05', timestamptz '2026-03-10 12:00:00-05');
    if (fare ->> 'amount')::integer <> 6000 then
        raise exception 'fix1: two exact hours must bill 6000: %', fare;
    end if;
    fare := public.fare_breakdown(plain_cat,
        timestamptz '2026-03-10 08:00:00-05', timestamptz '2026-03-11 10:00:00-05');
    if (fare ->> 'day_hours')::integer <> 26
       or (fare ->> 'amount')::integer <> 20000
       or not (fare ->> 'daily_cap_applied')::boolean then
        raise exception 'fix1: per-day cap lost: %', fare;
    end if;

    -- Allocation helper: deterministic and conserves the hours.
    if public.allocate_billable_hours(array[120, 180]::numeric[], 1) <> array[0, 1] then
        raise exception 'fix1: largest remainder picked the wrong bucket';
    end if;
    if public.allocate_billable_hours(array[60, 60]::numeric[], 1) <> array[1, 0] then
        raise exception 'fix1: ties must go to the earliest bucket';
    end if;
    if public.allocate_billable_hours(array[]::numeric[], 0) <> array[]::integer[] then
        raise exception 'fix1: empty allocation must be empty';
    end if;
end $$;

-- Fix 3: a tariff cannot point at another lot's category, and fare_breakdown
-- ignores rows that bypassed the constraint.
do $$
declare
    plain_cat integer := (select id from public.categories where name = 'fx1plain' and lot_id = 1);
    fare jsonb;
begin
    begin
        insert into public.tariffs (category_id, type, amount, active, lot_id)
        values (plain_cat, 'hourly', 1, true, 2);
        raise exception 'fix3: cross-lot tariff was accepted';
    exception when foreign_key_violation then
        null;
    end;

    set local session_replication_role = replica;
    insert into public.tariffs (category_id, type, amount, active, lot_id)
    values (plain_cat, 'daily', 1, true, 2);
    set local session_replication_role = origin;

    fare := public.fare_breakdown(plain_cat,
        timestamptz '2026-03-10 10:00:00-05', timestamptz '2026-03-10 12:00:00-05');
    if (fare ->> 'daily_rate')::integer is distinct from 10000
       or (fare ->> 'amount')::integer is distinct from 6000 then
        raise exception 'fix3: fare used a foreign-lot tariff: %', fare;
    end if;
    delete from public.tariffs where category_id = plain_cat and lot_id = 2;
end $$;

-- Fix 2: a pass of another lot does not make a stay free.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    plain_cat integer := (select id from public.categories where name = 'fx1plain' and lot_id = 1);
    session_id integer;
    preview jsonb;
    board jsonb;
    receipt jsonb;
begin
    session_id := (public.check_in(
        'PASSX1', plain_cat, null, null, '[]'::jsonb, null,
        now() - interval '30 minutes'
    ) ->> 'id')::integer;
    insert into public.monthly_passes (vehicle_id, start_date, end_date, amount, lot_id)
    select id, current_date - 1, current_date + 30, 50000, 2
      from public.vehicles where plate = 'PASSX1';

    preview := public.check_out_preview(session_id);
    if (preview ->> 'has_pass')::boolean
       or (preview ->> 'amount')::integer is distinct from 3000 then
        raise exception 'fix2: preview honored a foreign-lot pass: %', preview;
    end if;
    board := public.slot_board();
    if exists (
        select 1 from jsonb_array_elements(board -> 'sessions') item
         where item ->> 'plate' = 'PASSX1' and (item ->> 'has_pass')::boolean
    ) then
        raise exception 'fix2: slot board honored a foreign-lot pass';
    end if;
    if exists (
        select 1 from public.open_sessions_view
         where plate = 'PASSX1' and has_pass
    ) then
        raise exception 'fix2: open sessions view honored a foreign-lot pass';
    end if;
    receipt := public.check_out(session_id, null, null, 'cash');
    if receipt ->> 'payment_method' is distinct from 'cash'
       or (receipt ->> 'amount_charged')::integer is distinct from 3000 then
        raise exception 'fix2: check_out honored a foreign-lot pass: %', receipt;
    end if;

    -- Success: a pass of the same lot still applies.
    session_id := (public.check_in(
        'PASSX1', plain_cat, null, null, '[]'::jsonb, null,
        now() - interval '30 minutes'
    ) ->> 'id')::integer;
    insert into public.monthly_passes (vehicle_id, start_date, end_date, amount, lot_id)
    select id, current_date - 1, current_date + 30, 50000, 1
      from public.vehicles where plate = 'PASSX1';
    receipt := public.check_out(session_id, null, null, 'cash');
    if receipt ->> 'payment_method' is distinct from 'monthly_pass' then
        raise exception 'fix2: same-lot pass was ignored: %', receipt;
    end if;
end $$;

-- Fix 4: create_reservation locks the group key before the category key,
-- exactly like check_in -> enforce_category_capacity.
do $$
declare
    src text := pg_get_functiondef('public.create_reservation(text,integer,timestamptz,text)'::regprocedure);
begin
    if position('''group:''' in src) = 0
       or position('''category:''' in src) = 0
       or position('''group:''' in src) > position('''category:''' in src)
       or src not like '%category_group(category_name)%' then
        raise exception 'fix4: reservation lock keys/order differ from check_in';
    end if;
end $$;

-- Fix 5: renewal uses the lot's business date and calendar months.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    vehicle integer;
    behind_today date := (now() at time zone 'Pacific/Pago_Pago')::date;
    today_pass integer;
    ended_pass integer;
    month_pass integer;
    child public.monthly_passes%rowtype;
begin
    update public.parking_settings set business_timezone = 'Pacific/Pago_Pago' where lot_id = 2;
    insert into public.vehicles (plate, category_id) values ('RENTZ1', 2) returning id into vehicle;

    -- Pago Pago (UTC-11) is never ahead of Bogota: a pass ending on the
    -- Bogota date has not ended there yet.
    insert into public.monthly_passes (vehicle_id, start_date, end_date, amount, auto_renew, lot_id)
    values (vehicle, current_date - 10, current_date, 1000, true, 2)
    returning id into today_pass;
    insert into public.monthly_passes (vehicle_id, start_date, end_date, amount, auto_renew, lot_id)
    values (vehicle, behind_today - 10, behind_today - 1, 1000, true, 2)
    returning id into ended_pass;
    insert into public.monthly_passes (vehicle_id, start_date, end_date, amount, auto_renew, lot_id)
    values (vehicle, date '2025-11-01', date '2025-11-30', 80000, true, 1)
    returning id into month_pass;

    perform public.renew_monthly_passes();

    if exists (select 1 from public.monthly_passes where renewed_from_id = today_pass)
       or not (select active from public.monthly_passes where id = today_pass) then
        raise exception 'fix5: a pass was renewed/deactivated on its last valid day';
    end if;
    if not exists (select 1 from public.monthly_passes where renewed_from_id = ended_pass)
       or (select active from public.monthly_passes where id = ended_pass) then
        raise exception 'fix5: an ended pass was not renewed';
    end if;

    select * into child from public.monthly_passes where renewed_from_id = month_pass;
    if child.start_date is distinct from date '2025-12-01'
       or child.end_date is distinct from date '2025-12-31'
       or child.amount is distinct from 80000 then
        raise exception 'fix5: renewal drifted from calendar months: % - %',
            child.start_date, child.end_date;
    end if;
    if public.pass_period_months(date '2026-01-31', date '2026-02-27') is distinct from 1
       or public.pass_period_months(date '2026-01-01', date '2026-01-20') is not null then
        raise exception 'fix5: pass_period_months is wrong';
    end if;

    update public.parking_settings set business_timezone = 'America/Bogota' where lot_id = 2;
end $$;

-- Fix 6: sales only attach to the actor's open shift; the writers lock it.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$
declare
    plain_cat integer := (select id from public.categories where name = 'fx1plain' and lot_id = 1);
    first_session integer;
    second_session integer;
    first_shift bigint;
    second_shift bigint;
begin
    first_shift := (public.open_shift(0) ->> 'id')::bigint;
    first_session := (public.check_in('SHFT01', plain_cat, null, null, '[]'::jsonb, null,
        now() - interval '2 hours') ->> 'id')::integer;
    second_session := (public.check_in('SHFT02', plain_cat, null, null, '[]'::jsonb, null,
        now() - interval '2 hours') ->> 'id')::integer;
    perform public.close_shift(0, null);

    -- Failure path: an exit after the close never lands in the closed shift
    -- (now() equals closed_at inside this transaction, the old window matched).
    perform public.check_out(first_session, now(), null, 'cash');
    if (select shift_id from public.parking_sessions where id = first_session) is not null then
        raise exception 'fix6: a sale was attached to a closed shift';
    end if;

    -- Success: the replay goes to the current open shift.
    second_shift := (public.open_shift(0) ->> 'id')::bigint;
    perform public.check_out(second_session, now() - interval '1 minute', null, 'cash');
    if (select shift_id from public.parking_sessions where id = second_session)
       is distinct from second_shift then
        raise exception 'fix6: the replay did not reach the open shift';
    end if;
    perform public.close_shift(6000, null);

    -- Security/race guard: every shift writer locks the shift row.
    if pg_get_functiondef('public.add_cash_movement(text,integer,text)'::regprocedure) not ilike '%for share%'
       or pg_get_functiondef('public.register_pass_payment(bigint,text)'::regprocedure) not ilike '%for share%'
       or pg_get_functiondef('public.check_out(integer,timestamptz,text,text,integer,text,boolean,text,integer,text,integer)'::regprocedure) not ilike '%for share%' then
        raise exception 'fix6: a shift writer does not lock the shift';
    end if;
    if first_shift is not distinct from second_shift then
        raise exception 'fix6: shifts were not distinct';
    end if;
end $$;

-- Fixes 7 and 8: lost ticket from the session lot; offline exit freshness.
set local request.headers = '{"x-lot-id":"2"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    lost_cat integer;
    short_stay integer;
    long_stay integer;
    pass_stay integer;
    stale_stay integer;
    preview jsonb;
    receipt jsonb;
begin
    insert into public.categories (name, capacity, lot_id)
    values ('fx7lost', 0, 2) returning id into lost_cat;
    insert into public.tariffs (category_id, type, amount, active, lot_id)
    values (lost_cat, 'hourly', 3000, true, 2);
    update public.parking_settings set lost_ticket_fee = null where lot_id = 1;
    update public.parking_settings set lost_ticket_fee = 9000 where lot_id = 2;

    short_stay := (public.check_in('LOST71', lost_cat, null, null, '[]'::jsonb, null,
        now() - interval '90 minutes') ->> 'id')::integer;
    long_stay := (public.check_in('LOST72', lost_cat, null, null, '[]'::jsonb, null,
        now() - interval '10 hours') ->> 'id')::integer;
    pass_stay := (public.check_in('LOST73', lost_cat, null, null, '[]'::jsonb, null,
        now() - interval '1 hour') ->> 'id')::integer;
    stale_stay := (public.check_in('LOST74', lost_cat, null, null, '[]'::jsonb, null,
        now() - interval '20 hours') ->> 'id')::integer;

    -- The preview tells the client what a lost ticket would cost.
    preview := public.check_out_preview(short_stay);
    if (preview ->> 'lost_ticket_amount')::integer is distinct from 9000
       or (preview ->> 'amount')::integer is distinct from 6000
       or not preview ? 'session_id' or not preview ? 'daily_rate' then
        raise exception 'fix7: preview lost_ticket_amount/shape is wrong: %', preview;
    end if;

    -- Success: the session lot's fee wins over a cheaper fare.
    receipt := public.check_out(short_stay, null, null, 'cash', 0, null, true, 'perdido');
    if (receipt ->> 'amount_charged')::integer is distinct from 9000 then
        raise exception 'fix7: lost ticket ignored the lot fee: %', receipt;
    end if;
    -- A higher regular fare is never undercut by the fee.
    receipt := public.check_out(long_stay, null, null, 'cash', 0, null, true, 'perdido');
    if (receipt ->> 'amount_charged')::integer is distinct from 30000 then
        raise exception 'fix7: lost ticket undercut the fare: %', receipt;
    end if;

    -- Failure: a lost ticket cannot be settled as a monthly pass.
    begin
        perform public.check_out(pass_stay, null, null, 'monthly_pass', 0, null, true, 'perdido');
        raise exception 'fix7: monthly_pass accepted for a lost ticket';
    exception when others then
        if sqlerrm not like '%LostTicketPassMethodError%' then
            raise;
        end if;
    end;

    -- Fix 8 failure: an offline exit older than 12 h is refused.
    begin
        perform public.check_out(stale_stay, now() - interval '13 hours', null, 'cash');
        raise exception 'fix8: a stale offline exit was accepted';
    exception when others then
        if sqlerrm not like '%StaleExitTimeError%' then
            raise;
        end if;
    end;
    -- Success: within 12 h it is kept, and the server time is recorded.
    perform public.check_out(stale_stay, now() - interval '11 hours', null, 'cash');
    if not exists (
        select 1 from public.parking_sessions
         where id = stale_stay
           and exit_time = now() - interval '11 hours'
           and closed_recorded_at = now()
    ) then
        raise exception 'fix8: exit/server close times were not recorded';
    end if;

    update public.parking_settings set lost_ticket_fee = null where lot_id = 2;
end $$;

-- Fix 9: a lot admin (not a platform admin) can list the lot's shifts.
set local request.headers = '{"x-lot-id":"2"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
select public.open_shift(0);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000004';
do $$
declare
    other_shift bigint := (
        select s.id from public.shifts s
          join public.users u on u.id = s.operator_id
         where s.lot_id = 2 and u.username = 'shiftop'
         limit 1
    );
    lot1_shift bigint := (select id from public.shifts where lot_id = 1 order by id limit 1);
begin
    if public.current_app_role() = 'admin' then
        raise exception 'fix9: fixture user must not be a platform admin';
    end if;
    if other_shift is null
       or jsonb_array_length(public.list_shifts(50)) < 1
       or (public.shift_totals(other_shift) ->> 'id')::bigint is distinct from other_shift then
        raise exception 'fix9: lot admin could not read the lot shifts';
    end if;
    -- Security: the shift of another lot stays out of reach.
    begin
        perform public.shift_totals(lot1_shift);
        raise exception 'fix9: a lot admin read another lot shift';
    exception when others then
        if sqlerrm not like '%LotRequiredError%' then
            raise;
        end if;
    end;
end $$;
-- Security: a plain member (operator) still cannot read someone else's shift.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    perform public.shift_totals((
        select s.id from public.shifts s
          join public.users u on u.id = s.operator_id
         where s.lot_id = 2 and u.username = 'shiftop'
         limit 1
    ));
    raise exception 'fix9: an operator read another operator shift';
exception when others then
    if sqlerrm not like '%AdminRequiredError%' then
        raise;
    end if;
end $$;

-- Fixes 10 and 11: evidence paths must be the caller's uploaded objects.
set local request.headers = '{"x-lot-id":"1"}';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
insert into storage.objects (bucket_id, name, owner) values
    ('evidence', 'ref-ev1/0.jpg', '00000000-0000-0000-0000-000000000002'),
    ('evidence', 'ref-ev1/video.mp4', '00000000-0000-0000-0000-000000000002'),
    ('evidence', 'ref-ev2/0.jpg', '00000000-0000-0000-0000-000000000001'),
    ('branding', 'ref-ev3/0.jpg', '00000000-0000-0000-0000-000000000002');
do $$
declare
    plain_cat integer := (select id from public.categories where name = 'fx1plain' and lot_id = 1);
    entry jsonb;
    path text;
begin
    -- Success: deterministic '<clientRef>/<i><ext>' and '<clientRef>/video<ext>'.
    entry := public.check_in('EVID01', plain_cat, null, null,
        '[{"path":"ref-ev1/0.jpg"}]'::jsonb, null, null, null, false, null,
        '[{"path":"ref-ev1/video.mp4","duration_seconds":5}]'::jsonb);
    if (entry ->> 'photo_count')::integer <> 1 or (entry ->> 'video_count')::integer <> 1 then
        raise exception 'fix10: valid evidence was rejected: %', entry;
    end if;

    -- Failure: missing object, another user's object, wrong bucket.
    foreach path in array array['ref-missing/0.jpg', 'ref-ev2/0.jpg', 'ref-ev3/0.jpg'] loop
        begin
            perform public.check_in('EVID02', plain_cat, null, null,
                jsonb_build_array(jsonb_build_object('path', path)));
            raise exception 'fix10: foreign/missing evidence % was accepted', path;
        exception when others then
            if sqlerrm not like '%EvidenceNotFoundError%' then
                raise;
            end if;
        end;
    end loop;

    -- Security: an already referenced object cannot back a second session.
    begin
        perform public.check_in('EVID03', plain_cat, null, null,
            '[{"path":"ref-ev1/0.jpg"}]'::jsonb);
        raise exception 'fix10: reused evidence was accepted';
    exception when others then
        if sqlerrm not like '%EvidenceAlreadyUsedError%' then
            raise;
        end if;
    end;

    if not exists (
        select 1 from pg_indexes
         where schemaname = 'public' and tablename = 'evidence_photos'
           and indexname = 'uq_evidence_photos_file_path'
           and indexdef like 'CREATE UNIQUE INDEX%(file_path)%'
    ) then
        raise exception 'fix11: evidence_photos(file_path) unique index missing';
    end if;
    begin
        insert into public.evidence_photos (session_id, file_path)
        values ((entry ->> 'id')::integer, 'ref-ev1/0.jpg');
        raise exception 'fix11: duplicate evidence path was stored';
    exception when unique_violation then
        null;
    end;
end $$;

-- Fix 12: notification amounts follow the lot currency.
do $$
declare
    plain_cat integer := (select id from public.categories where name = 'fx1plain' and lot_id = 1);
    session_id integer;
    body text;
begin
    if public.format_money(5000, 'COP') <> '$5.000'
       or public.format_money(1234567, 'COP') <> '$1.234.567'
       or public.format_money(-1500, 'COP') <> '-$1.500'
       or public.format_money(0, 'COP') <> '$0'
       or public.format_money(123450, 'USD') <> 'US$1,234.50'
       or public.format_money(5, 'USD') <> 'US$0.05'
       or public.format_money(-250, 'USD') <> '-US$2.50' then
        raise exception 'fix12: format_money does not match Money.format';
    end if;

    update public.parking_settings set currency = 'USD' where lot_id = 1;
    session_id := (public.check_in('CURR01', plain_cat, null, null, '[]'::jsonb, null,
        now() - interval '30 minutes') ->> 'id')::integer;
    perform public.check_out(session_id, null, null, 'cash');
    select n.body into body from public.notifications n
     where n.type = 'check_out' and (n.data ->> 'session_id')::integer = session_id
     limit 1;
    if coalesce(body, '') not like '%Cobro: US$30.00' then
        raise exception 'fix12: check-out notification ignored the currency: %', body;
    end if;
    update public.parking_settings set currency = 'COP' where lot_id = 1;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.open_shift(1000);
select public.close_shift(0, null);
do $$
begin
    if not exists (
        select 1 from public.notifications
         where type = 'shift_closed' and body = 'Diferencia de caja: -$1.000'
    ) then
        raise exception 'fix12: shift close notification is not COP-formatted';
    end if;
end $$;

-- Every public table must have RLS enabled (service-role-only tables included;
-- they simply have no policies). This catches new tables shipped without it.
do $$
declare
    missing text;
begin
    select string_agg(c.relname, ', ' order by c.relname)
      into missing
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind = 'r'
       and not c.relrowsecurity;
    if missing is not null then
        raise exception 'public tables without RLS: %', missing;
    end if;
end $$;

-- 0074: request timeouts are installed for the PostgREST roles. The settings
-- live in rolconfig (applied on login); SET ROLE does not re-apply them.
do $$
declare
    cfg text[];
begin
    select rolconfig into cfg from pg_roles where rolname = 'authenticated';
    if not ('statement_timeout=15000' = any(cfg)) then
        raise exception 'authenticated statement_timeout missing: %', cfg;
    end if;
    if not ('idle_in_transaction_session_timeout=30000' = any(cfg)) then
        raise exception 'authenticated idle timeout missing: %', cfg;
    end if;

    select rolconfig into cfg from pg_roles where rolname = 'anon';
    if not ('statement_timeout=5000' = any(cfg)) then
        raise exception 'anon statement_timeout missing: %', cfg;
    end if;
end $$;

-- 0075: admins may edit a vehicle; operators are still blocked by RLS.
set local request.headers = '{"x-lot-id":"1"}';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
    changed integer;
begin
    update public.vehicles set color = 'Azul'
     where plate = 'LOST01';
    get diagnostics changed = row_count;
    if changed <> 1 then
        raise exception 'admin vehicle update changed % rows', changed;
    end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
declare
    changed integer;
begin
    update public.vehicles set color = 'Rojo'
     where plate = 'LOST01';
    get diagnostics changed = row_count;
    if changed <> 0 then
        raise exception 'operator updated % vehicle rows', changed;
    end if;
end $$;
reset role;

rollback;
