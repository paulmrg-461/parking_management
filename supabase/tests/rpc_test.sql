-- SQL regression tests for the parts that are hard to cover from Flutter:
-- capacity, shifts/arqueo, discounts, auto-renewal charges and RLS isolation.
-- Runs in one transaction and rolls back; no fixture survives.
begin;

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
