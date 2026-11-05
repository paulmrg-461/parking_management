-- The nearest police quadrant operators call in an emergency. Optional: when
-- empty the app offers the national emergency line (123) as a fallback, so the
-- action is still useful before the site configures a local number.

alter table public.parking_settings
    add column if not exists police_phone varchar(32) not null default '';

alter table public.parking_settings
    drop constraint if exists parking_settings_police_phone_check;
alter table public.parking_settings
    add constraint parking_settings_police_phone_check
    check (
        police_phone = ''
        or length(regexp_replace(police_phone, '\D', '', 'g')) between 3 and 15
    );
