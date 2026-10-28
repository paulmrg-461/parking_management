-- Per-site legal policy / service contract: a default template the admin can
-- edit in Ajustes, shown to customers on the public evidence page (and linked
-- from it). The public profile exposes only identity/contact + the policy.

alter table public.parking_settings
    add column if not exists legal_policy text;

create or replace function public.default_legal_policy()
returns text
language sql
immutable
as $policy$
    select $text$POLÍTICAS Y CONTRATO DE SERVICIO — {{parking}}

1. {{parking}} presta el servicio de custodia temporal de vehículos en {{address}}, en el horario {{schedule}}.
2. La tarifa se liquida por fracción de hora vencida según la categoría del vehículo y las tarifas publicadas; aplican el tope diario y la tarifa nocturna cuando correspondan.
3. El estado del vehículo se registra al ingreso con fotos y, opcionalmente, un video de evidencia. Esos archivos se conservan según la política de retención del parqueadero y se usan únicamente para atender reclamaciones.
4. El parqueadero no responde por objetos de valor, dinero o documentos dejados dentro del vehículo.
5. El vehículo debe retirarse dentro del horario de atención; el tiempo adicional se cobra según la tarifa vigente.
6. La pérdida del ticket genera el cobro de la tarifa diaria completa y requiere la justificación del cliente.
7. Los vehículos reportados o bloqueados no podrán ingresar.
8. Las reservas de cupo se mantienen hasta la hora acordada; después se liberan automáticamente.
9. Para reclamaciones, presenta el ticket y la placa del vehículo en {{phone}}.
10. El ingreso del vehículo implica la aceptación de estas políticas.
$text$;
$policy$;

grant execute on function public.default_legal_policy() to authenticated;

-- Existing sites start with the template so the admin only edits it.
update public.parking_settings
   set legal_policy = public.default_legal_policy()
 where legal_policy is null;

create or replace function public.reset_legal_policy()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
begin
    perform public.require_app_user();
    if not public.is_lot_admin(lot) then
        raise exception 'AdminRequiredError';
    end if;

    update public.parking_settings
       set legal_policy = public.default_legal_policy()
     where lot_id = lot;
    return public.default_legal_policy();
end;
$$;

grant execute on function public.reset_legal_policy() to authenticated;

-- Public read model for the customer pages (no login): identity, contact and
-- the policy only.
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
        'legal_policy', coalesce(settings.legal_policy, public.default_legal_policy())
    );
end;
$$;

grant execute on function public.public_lot_profile(integer) to anon, authenticated;
