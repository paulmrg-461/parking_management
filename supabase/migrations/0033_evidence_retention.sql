-- Evidence retention per site. `0` keeps photos forever (default); a positive
-- value lets the `evidence-archive` Edge Function delete storage objects and
-- their rows for sessions older than that many days.

alter table public.parking_settings
    add column if not exists evidence_retention_days integer not null default 0;

alter table public.parking_settings
    drop constraint if exists parking_settings_evidence_retention_check;
alter table public.parking_settings
    add constraint parking_settings_evidence_retention_check
    check (evidence_retention_days between 0 and 3650);

-- Photos of one session are all taken at check-in; the function filters by the
-- session entry time so a photo cannot outlive its retention window.
create index if not exists ix_evidence_photos_taken
    on public.evidence_photos(taken_at);
