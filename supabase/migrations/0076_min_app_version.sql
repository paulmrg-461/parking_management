-- Minimum supported app version per site. Kiosk/tablet installs check it on
-- startup and show an "update required" banner instead of failing in subtle
-- ways when the APK is older than the database contract.
-- Empty = no minimum; otherwise `major.minor[.patch]`.

alter table public.parking_settings
    add column if not exists min_app_version text not null default '';

alter table public.parking_settings
    drop constraint if exists parking_settings_min_app_version_format;
alter table public.parking_settings
    add constraint parking_settings_min_app_version_format
    check (
        min_app_version = ''
        or min_app_version ~ '^[0-9]+[.][0-9]+([.][0-9]+)?$'
    );

create or replace function public.public_lot_profile(p_lot_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot public.parking_lots%rowtype;
    settings public.parking_settings%rowtype;
begin
    select * into lot from public.parking_lots l where l.id = p_lot_id;
    if not found then
        return null;
    end if;

    select * into settings
      from public.parking_settings ps
     where ps.lot_id = p_lot_id;

    return jsonb_build_object(
        'id', lot.id,
        'name', lot.name,
        'address', coalesce(settings.address, ''),
        'schedule', coalesce(settings.schedule, ''),
        'phone', coalesce(settings.phone, ''),
        'website', coalesce(settings.website, ''),
        'currency', coalesce(settings.currency, 'COP'),
        'min_app_version', coalesce(settings.min_app_version, ''),
        'legal_policy', coalesce(settings.legal_policy, public.default_legal_policy())
    );
end;
$$;

grant execute on function public.public_lot_profile(integer) to anon, authenticated;
