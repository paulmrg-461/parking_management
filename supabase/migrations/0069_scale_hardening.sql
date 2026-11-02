-- Scale hardening for production traffic:
--   * trigram search on plates (the records/history filters use ILIKE '%term%')
--   * hot-path composite indexes for the lot-scoped dashboards and lists
--   * data invariants for monthly passes and charged amounts.
-- Safe to re-run: every index uses IF NOT EXISTS and constraints are guarded.

create extension if not exists pg_trgm;

create index if not exists ix_vehicles_plate_trgm
    on public.vehicles using gin (plate gin_trgm_ops);

create index if not exists ix_sessions_lot_entry
    on public.parking_sessions(lot_id, entry_time desc);

create index if not exists ix_passes_lot_end
    on public.monthly_passes(lot_id, end_date);

create index if not exists ix_reservations_lot_until
    on public.category_reservations(lot_id, reserved_until)
    where status = 'active';

create index if not exists ix_notifications_lot_user_created
    on public.notifications(lot_id, user_id, created_at desc);

do $$
begin
    if not exists (
        select 1 from pg_constraint
         where conname = 'monthly_passes_window_check'
           and conrelid = 'public.monthly_passes'::regclass
    ) then
        alter table public.monthly_passes
            add constraint monthly_passes_window_check
            check (end_date >= start_date);
    end if;

    if not exists (
        select 1 from pg_constraint
         where conname = 'monthly_passes_amount_check'
           and conrelid = 'public.monthly_passes'::regclass
    ) then
        alter table public.monthly_passes
            add constraint monthly_passes_amount_check
            check (amount >= 0);
    end if;

    if not exists (
        select 1 from pg_constraint
         where conname = 'parking_sessions_amount_check'
           and conrelid = 'public.parking_sessions'::regclass
    ) then
        alter table public.parking_sessions
            add constraint parking_sessions_amount_check
            check (amount_charged is null or amount_charged >= 0);
    end if;
end $$;

-- Keep the planner honest after the new indexes on a live database.
analyze public.vehicles;
analyze public.parking_sessions;
analyze public.monthly_passes;
analyze public.category_reservations;
analyze public.notifications;
