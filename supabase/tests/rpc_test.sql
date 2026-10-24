-- SQL regression tests for the parts that are hard to cover from Flutter:
-- capacity, shifts/arqueo, discounts, auto-renewal charges and RLS isolation.
-- Runs in one transaction and rolls back; no fixture survives.
begin;

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
insert into public.monthly_passes (
    vehicle_id, start_date, end_date, amount, active, auto_renew
) select id, current_date - 29, current_date, 80000, true, true
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

-- RLS: the operator must not read the admin's notifications.
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$
begin
    if (select count(*) from public.notifications) <> 0 then
        raise exception 'RLS leak: operator can read admin notifications';
    end if;
end $$;
reset role;

rollback;
