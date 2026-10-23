-- Database-level validation: PostgREST writes no longer pass through a
-- service layer, so the rules that used to live in FastAPI belong here.

alter table public.users drop constraint if exists users_role_check;
alter table public.users add constraint users_role_check
    check (role in ('admin', 'operator'));

alter table public.users drop constraint if exists users_username_check;
alter table public.users add constraint users_username_check
    check (char_length(btrim(username)) between 1 and 50);

alter table public.categories drop constraint if exists categories_name_check;
alter table public.categories add constraint categories_name_check
    check (char_length(btrim(name)) between 1 and 50);

alter table public.tariffs drop constraint if exists tariffs_amount_check;
alter table public.tariffs add constraint tariffs_amount_check
    check (amount > 0);

alter table public.tariffs drop constraint if exists tariffs_type_check;
alter table public.tariffs add constraint tariffs_type_check
    check (type in ('hourly', 'daily', 'nightly', 'monthly'));

alter table public.tariffs drop constraint if exists tariffs_window_check;
alter table public.tariffs add constraint tariffs_window_check
    check (
        (type = 'nightly'
            and start_time is not null
            and end_time is not null
            and start_time <> end_time
            and start_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
            and end_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
        or
        (type <> 'nightly' and start_time is null and end_time is null)
    );

alter table public.vehicles drop constraint if exists vehicles_plate_check;
alter table public.vehicles add constraint vehicles_plate_check
    check (char_length(btrim(plate)) between 1 and 20);

alter table public.monthly_passes drop constraint if exists monthly_passes_dates_check;
alter table public.monthly_passes add constraint monthly_passes_dates_check
    check (end_date > start_date);

alter table public.monthly_passes drop constraint if exists monthly_passes_amount_check;
alter table public.monthly_passes add constraint monthly_passes_amount_check
    check (amount > 0);

alter table public.parking_sessions drop constraint if exists parking_sessions_status_check;
alter table public.parking_sessions add constraint parking_sessions_status_check
    check (status in ('open', 'closed'));

alter table public.parking_sessions drop constraint if exists parking_sessions_amount_check;
alter table public.parking_sessions add constraint parking_sessions_amount_check
    check (amount_charged is null or amount_charged >= 0);

alter table public.parking_settings drop constraint if exists parking_settings_name_check;
alter table public.parking_settings add constraint parking_settings_name_check
    check (char_length(btrim(name)) between 1 and 80);

alter table public.evidence_photos drop constraint if exists evidence_photos_path_check;
alter table public.evidence_photos add constraint evidence_photos_path_check
    check (char_length(btrim(file_path)) between 1 and 255);
