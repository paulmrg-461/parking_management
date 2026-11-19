-- LPR gate — operator inbox, confirmation and the retention jobs.
--
-- Pending reads are resolved by a signed-in member: `confirm_lpr_entry` runs
-- the normal `check_in` as that operator (deterministic idempotency key), so
-- billing, shifts and evidence rules stay in one place. `dismiss_lpr_event`
-- closes an item with an optional note. The jobs expire old pending items,
-- confirm unpaid exits whose session was closed by the desk, and purge old
-- reads/events while returning the snapshot paths the storage janitor must
-- delete.

create or replace function public.list_lpr_events(
    p_status text default 'pending',
    p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    status_filter text := coalesce(nullif(btrim(p_status), ''), 'pending');
    max_rows integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
    perform public.require_app_user();
    if status_filter <> 'all'
       and status_filter not in ('pending','done','blocked','confirmed',
                                 'dismissed','expired') then
        raise exception 'InvalidDataError';
    end if;
    return coalesce((
        select jsonb_agg(public.lpr_event_json(e) ||
                   jsonb_build_object('device_name', d.name)
                   order by e.created_at desc, e.id desc)
          from (
              select * from public.lpr_events ev
               where ev.lot_id = lot
                 and (status_filter = 'all' or ev.status = status_filter)
               order by ev.created_at desc, ev.id desc
               limit max_rows
          ) e
          left join public.lot_devices d on d.id = e.device_id
    ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_lpr_events(text, integer) from public;
grant execute on function public.list_lpr_events(text, integer) to authenticated;

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
    target_plate text;
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
    if p_category_id is not null and not exists (
        select 1 from public.categories c
         where c.id = p_category_id and c.lot_id = lot
    ) then
        raise exception 'CategoryNotFoundError';
    end if;

    result := public.check_in(
        p_plate => target_plate,
        p_category_id => p_category_id,
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

create or replace function public.dismiss_lpr_event(
    p_event_id bigint,
    p_note text default null
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
    note text := left(btrim(coalesce(p_note, '')), 200);
begin
    select * into event from public.lpr_events e
     where e.id = p_event_id and e.lot_id = lot;
    if not found then
        raise exception 'LprEventNotFoundError';
    end if;
    if event.status not in ('pending', 'blocked') then
        raise exception 'LprEventResolvedError';
    end if;
    update public.lpr_events e
       set status = 'dismissed',
           resolved_by = actor,
           resolved_at = now(),
           detail = case when note = '' then e.detail
                         else e.detail || jsonb_build_object('note', note) end
     where e.id = event.id;
    return jsonb_build_object('event_id', event.id, 'status', 'dismissed');
end;
$$;

revoke all on function public.dismiss_lpr_event(bigint, text) from public;
grant execute on function public.dismiss_lpr_event(bigint, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Jobs (service role only).
-- ---------------------------------------------------------------------------
create or replace function public.expire_lpr_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer := 0;
    n integer;
begin
    update public.lpr_events e
       set status = 'expired', resolved_at = now()
      from public.lpr_settings s
     where e.status = 'pending'
       and e.lot_id = s.lot_id
       and e.created_at < now() - make_interval(mins => s.pending_expire_minutes);
    get diagnostics n = row_count;
    changed := changed + n;

    -- Lots without a settings row use the documented 60-minute default.
    update public.lpr_events e
       set status = 'expired', resolved_at = now()
     where e.status = 'pending'
       and not exists (
           select 1 from public.lpr_settings s where s.lot_id = e.lot_id
       )
       and e.created_at < now() - interval '60 minutes';
    get diagnostics n = row_count;
    changed := changed + n;

    -- An unpaid exit stops being actionable when the desk closes the session.
    update public.lpr_events e
       set status = 'confirmed', resolved_at = now()
      from public.parking_sessions s
     where e.status = 'pending'
       and e.reason = 'exit_unpaid'
       and e.session_id = s.id
       and s.status = 'closed';
    get diagnostics n = row_count;
    changed := changed + n;

    return changed;
end;
$$;

revoke all on function public.expire_lpr_events()
    from public, anon, authenticated;
grant execute on function public.expire_lpr_events() to service_role;

create or replace function public.purge_lpr_events(p_days integer default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    cutoff timestamptz := now() - make_interval(
        days => greatest(coalesce(p_days, 30), 1));
    paths jsonb;
begin
    select coalesce(jsonb_agg(distinct e.snapshot_path), '[]'::jsonb)
      into paths
      from public.lpr_events e
     where e.created_at < cutoff
       and e.snapshot_path is not null
       and not exists (
           select 1 from public.evidence_photos p
            where p.file_path = e.snapshot_path
       );
    delete from public.lpr_reads r where r.created_at < cutoff;
    delete from public.lpr_events e where e.created_at < cutoff;
    return paths;
end;
$$;

revoke all on function public.purge_lpr_events(integer)
    from public, anon, authenticated;
grant execute on function public.purge_lpr_events(integer) to service_role;
