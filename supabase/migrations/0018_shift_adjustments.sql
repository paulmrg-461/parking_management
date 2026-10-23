-- A closed shift can be corrected by an admin with a mandatory reason; the
-- previous and new reconciliation stay in an audit table.

create table if not exists public.shift_adjustments (
    id             bigserial primary key,
    shift_id       bigint      not null references public.shifts(id) on delete cascade,
    old_counted    integer     not null,
    new_counted    integer     not null,
    old_difference integer     not null,
    new_difference integer     not null,
    reason         text        not null,
    adjusted_by    integer     references public.users(id),
    adjusted_at    timestamptz not null default now()
);
create index if not exists ix_shift_adjustments_shift
    on public.shift_adjustments(shift_id, adjusted_at desc);

alter table public.shift_adjustments enable row level security;
grant select on public.shift_adjustments to authenticated;

drop policy if exists shift_adjustments_admin_read on public.shift_adjustments;
create policy shift_adjustments_admin_read on public.shift_adjustments
    for select to authenticated using (public.is_admin());

create or replace function public.adjust_shift(
    p_shift_id bigint,
    p_counted_cash integer,
    p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_admin();
    shift public.shifts%rowtype;
    new_difference integer;
begin
    if coalesce(p_counted_cash, -1) < 0 then
        raise exception 'InvalidCountedCashError';
    end if;
    if p_reason is null or length(btrim(p_reason)) = 0 then
        raise exception 'ShiftAdjustmentReasonRequired';
    end if;

    select * into shift from public.shifts s where s.id = p_shift_id for update;
    if not found then
        raise exception 'ShiftNotFoundError';
    end if;
    if shift.closed_at is null then
        raise exception 'ShiftStillOpenError';
    end if;

    new_difference := p_counted_cash - shift.expected_cash;

    insert into public.shift_adjustments (
        shift_id, old_counted, new_counted,
        old_difference, new_difference, reason, adjusted_by
    )
    values (
        shift.id, coalesce(shift.counted_cash, 0), p_counted_cash,
        coalesce(shift.difference, 0), new_difference,
        btrim(p_reason), actor
    );

    update public.shifts
       set counted_cash = p_counted_cash,
           difference = new_difference
     where id = shift.id;

    return public.shift_totals(shift.id);
end;
$$;

grant execute on function public.adjust_shift(bigint, integer, text) to authenticated;
