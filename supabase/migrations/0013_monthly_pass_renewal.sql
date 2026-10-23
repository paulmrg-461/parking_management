-- Monthly passes can renew themselves for the same duration/amount when they
-- expire. Each renewal is a new row linked to the previous one, so the history
-- stays auditable.

alter table public.monthly_passes
    add column if not exists auto_renew boolean not null default false;
alter table public.monthly_passes
    add column if not exists renewed_from_id bigint unique
    references public.monthly_passes(id);

create index if not exists ix_monthly_passes_renewal
    on public.monthly_passes(renewed_from_id);

create or replace function public.renew_monthly_passes()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    create temp table if not exists renewed_passes (
        id bigint,
        vehicle_id integer,
        start_date date,
        end_date date,
        amount integer,
        renewed_from_id bigint
    ) on commit drop;

    truncate renewed_passes;

    with candidates as (
        select mp.*, (mp.end_date - mp.start_date + 1) as duration_days
          from public.monthly_passes mp
         where mp.active
           and mp.auto_renew
           and mp.end_date <= current_date
           and not exists (
               select 1 from public.monthly_passes child
                where child.renewed_from_id = mp.id
           )
    ),
    inserted as (
        insert into public.monthly_passes (
            vehicle_id, start_date, end_date, amount, active, auto_renew, renewed_from_id
        )
        select c.vehicle_id,
               c.end_date + 1,
               c.end_date + c.duration_days,
               c.amount,
               true,
               c.auto_renew,
               c.id
          from candidates c
        on conflict (renewed_from_id) do nothing
        returning id, vehicle_id, start_date, end_date, amount, renewed_from_id
    )
    insert into renewed_passes (id, vehicle_id, start_date, end_date, amount, renewed_from_id)
    select id, vehicle_id, start_date, end_date, amount, renewed_from_id from inserted;

    select count(*) into changed from renewed_passes;

    update public.monthly_passes mp
       set active = false
     where mp.id in (select renewed_from_id from renewed_passes)
       and mp.end_date <= current_date;

    insert into public.notifications (user_id, type, title, body, data, dedupe_key)
    select u.id,
           'monthly_pass_renewed',
           'Mensualidad renovada',
           'Vehículo ' || v.plate || ': ' ||
               to_char(rp.start_date, 'DD/MM/YYYY') || ' - ' ||
               to_char(rp.end_date, 'DD/MM/YYYY'),
           jsonb_build_object(
               'monthly_pass_id', rp.id,
               'vehicle_id', rp.vehicle_id,
               'plate', v.plate,
               'start_date', rp.start_date,
               'end_date', rp.end_date,
               'amount', rp.amount
           ),
           'pass_renew:' || rp.renewed_from_id || ':' || rp.id || ':user:' || u.id
      from renewed_passes rp
      join public.vehicles v on v.id = rp.vehicle_id
      join public.users u on u.role = 'admin' and u.is_active
    on conflict (dedupe_key) do nothing;

    return changed;
end;
$$;

grant execute on function public.renew_monthly_passes() to authenticated;

-- Auto-renewing passes are handled by the renewal job; only manual passes
-- need the "expires in 3 days" reminder.
create or replace function public.notify_expiring_monthly_passes()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    insert into public.notifications (user_id, type, title, body, data, dedupe_key)
    select u.id,
           'monthly_pass_expiring',
           'Mensualidad por vencer',
           'La mensualidad del vehículo ' || v.plate || ' vence el ' ||
               to_char(mp.end_date, 'DD/MM/YYYY'),
           jsonb_build_object(
               'monthly_pass_id', mp.id,
               'vehicle_id', mp.vehicle_id,
               'plate', v.plate,
               'end_date', mp.end_date
           ),
           'pass_expiry:' || mp.id || ':' || mp.end_date || ':user:' || u.id
      from public.monthly_passes mp
      join public.vehicles v on v.id = mp.vehicle_id
      join public.users u on u.role = 'admin' and u.is_active
     where mp.active
       and not mp.auto_renew
       and mp.end_date = current_date + 3
    on conflict (dedupe_key) do nothing;
    get diagnostics changed = row_count;
    return changed;
end;
$$;
