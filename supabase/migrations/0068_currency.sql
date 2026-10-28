-- Per-site currency: amounts are stored as integers in the currency's minor
-- unit (COP pesos, USD cents). The client formats and parses with the site's
-- currency; the database math stays integer-only.

alter table public.parking_settings
    add column if not exists currency text not null default 'COP';

alter table public.parking_settings
    drop constraint if exists parking_settings_currency_valid;
alter table public.parking_settings
    add constraint parking_settings_currency_valid
    check (currency in ('COP', 'USD'));

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
        'legal_policy', coalesce(settings.legal_policy, public.default_legal_policy())
    );
end;
$$;

grant execute on function public.public_lot_profile(integer) to anon, authenticated;
