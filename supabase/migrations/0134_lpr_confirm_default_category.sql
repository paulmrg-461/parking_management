-- LPR gate — confirmation falls back to the lot's default category.
--
-- The gate dialog lets the operator correct a misread plate; when the plate is
-- unknown and the lot configured a default category for new vehicles, the
-- confirmation may omit the category and the server applies that default. An
-- explicit category is still validated against the lot.

create or replace function public.confirm_lpr_entry(
    p_event_id bigint,
    p_plate text default null,
    p_category_id integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    event public.lpr_events%rowtype;
    settings public.lpr_settings%rowtype;
    target_plate text;
    category integer;
    result jsonb;
    new_session integer;
begin
    select * into event from public.lpr_events e
     where e.id = p_event_id and e.lot_id = lot;
    if not found then
        raise exception 'LprEventNotFoundError';
    end if;
    if event.status in ('done', 'blocked', 'dismissed', 'expired') then
        raise exception 'LprEventResolvedError';
    end if;
    if event.direction <> 'entry' then
        raise exception 'LprEventKindError';
    end if;
    target_plate := upper(regexp_replace(coalesce(p_plate, event.plate), '\s', '', 'g'));
    if target_plate !~ '^[A-Z0-9]{4,10}$' then
        raise exception 'InvalidPlateError';
    end if;
    settings := public.lpr_effective_settings(lot);
    category := coalesce(p_category_id, settings.default_category_id);
    if p_category_id is not null and not exists (
        select 1 from public.categories c
         where c.id = p_category_id and c.lot_id = lot
    ) then
        raise exception 'CategoryNotFoundError';
    end if;

    result := public.check_in(
        p_plate => target_plate,
        p_category_id => category,
        p_client_entry_time => event.created_at,
        p_lot_id => lot,
        p_idempotency_key => 'lpr-confirm:' || event.id::text
    );
    new_session := (result ->> 'id')::integer;

    update public.lpr_events e
       set status = 'confirmed',
           plate = target_plate,
           session_id = new_session,
           vehicle_id = (result ->> 'vehicle_id')::integer,
           resolved_by = actor,
           resolved_at = coalesce(e.resolved_at, now())
     where e.id = event.id;

    if event.snapshot_path is not null and not exists (
        select 1 from public.evidence_photos p
         where p.session_id = new_session and p.file_path = event.snapshot_path
    ) then
        insert into public.evidence_photos (session_id, file_path, taken_at)
        values (new_session, event.snapshot_path, now());
    end if;

    return result || jsonb_build_object('event_id', event.id);
end;
$$;

revoke all on function public.confirm_lpr_entry(bigint, text, integer) from public;
grant execute on function public.confirm_lpr_entry(bigint, text, integer) to authenticated;

