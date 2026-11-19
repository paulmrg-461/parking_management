-- Damage comparison — exit evidence, the advisory comparison record and the
-- human review workflow. Photos are evidence rows with a `phase`; the AI result
-- is written ONLY by the service role (the model never decides billing).
--
-- Exit photos are captured online at check-out (separate RPC, `check_out` is
-- untouched). The comparison is advisory: nothing here charges, discounts,
-- blocks or blacklists.

alter table public.evidence_photos
    add column if not exists phase text not null default 'entry'
        check (phase in ('entry', 'exit'));
create index if not exists ix_evidence_photos_session_phase
    on public.evidence_photos (session_id, phase);

create table if not exists public.damage_comparisons (
    id                 bigserial   primary key,
    lot_id             integer     not null references public.parking_lots(id) on delete cascade,
    session_id         integer     not null references public.parking_sessions(id) on delete cascade,
    run_number         integer     not null check (run_number >= 1),
    status             text        not null default 'pending'
                       check (status in ('pending', 'completed', 'failed')),
    requested_by       integer     references public.users(id) on delete set null,
    model              text,
    entry_photo_count  integer     not null default 0,
    exit_photo_count   integer     not null default 0,
    overall            text        check (overall in (
        'no_new_damage', 'possible_new_damage', 'insufficient_evidence')),
    summary            text        check (char_length(summary) <= 600),
    quality            jsonb       not null default '{}'::jsonb,
    ai_request_id      bigint      references public.ai_requests(id) on delete set null,
    error_code         text,
    created_at         timestamptz not null default now(),
    completed_at       timestamptz,
    unique (session_id, run_number)
);
create unique index if not exists uq_damage_comparisons_pending
    on public.damage_comparisons (session_id) where status = 'pending';
create index if not exists ix_damage_comparisons_lot_created
    on public.damage_comparisons (lot_id, created_at);

create table if not exists public.damage_findings (
    id               bigserial primary key,
    comparison_id    bigint    not null references public.damage_comparisons(id) on delete cascade,
    lot_id           integer   not null references public.parking_lots(id) on delete cascade,
    position         integer   not null,
    zone             text      not null check (zone in (
        'front', 'rear', 'left', 'right', 'roof', 'wheels', 'windows',
        'interior', 'other')),
    description      text      not null check (char_length(description) between 1 and 400),
    classification   text      not null check (classification in (
        'pre_existing', 'new', 'uncertain')),
    confidence       text      not null check (confidence in ('low', 'medium', 'high')),
    downgraded_from  text      check (downgraded_from in ('new')),
    entry_photo_ids  integer[] not null default '{}',
    exit_photo_ids   integer[] not null default '{}',
    review_status    text      not null default 'open'
                     check (review_status in ('open', 'confirmed', 'dismissed')),
    review_note      text      check (char_length(review_note) between 3 and 400),
    reviewed_by      integer   references public.users(id) on delete set null,
    reviewed_at      timestamptz,
    unique (comparison_id, position)
);
create index if not exists ix_damage_findings_comparison
    on public.damage_findings (comparison_id);

alter table public.damage_comparisons enable row level security;
alter table public.damage_findings enable row level security;
revoke all on public.damage_comparisons, public.damage_findings
    from public, anon, authenticated;
grant select on public.damage_comparisons, public.damage_findings to authenticated;

drop policy if exists damage_comparisons_lot_read on public.damage_comparisons;
create policy damage_comparisons_lot_read on public.damage_comparisons
    for select to authenticated using (lot_id = public.current_lot_id());
drop policy if exists damage_findings_lot_read on public.damage_findings;
create policy damage_findings_lot_read on public.damage_findings
    for select to authenticated using (lot_id = public.current_lot_id());

drop trigger if exists trg_audit_row on public.damage_findings;
create trigger trg_audit_row after update on public.damage_findings
    for each row execute function public.record_audit();

insert into public.ai_features (
    feature, admin_only, default_daily_requests, default_daily_tokens
) values ('damage_compare', false, 60, 1200000)
on conflict (feature) do nothing;

-- ---------------------------------------------------------------------------
-- Exit evidence (check_out is not modified).
-- ---------------------------------------------------------------------------
create or replace function public.add_exit_evidence(
    p_session_id integer,
    p_photos jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    session public.parking_sessions%rowtype;
    item jsonb;
    path text;
    taken timestamptz;
    existing integer;
    total integer;
begin
    select * into session from public.parking_sessions s where s.id = p_session_id;
    if not found or session.lot_id <> lot then
        raise exception 'SessionNotFoundError';
    end if;
    if p_photos is null or jsonb_typeof(p_photos) <> 'array'
       or jsonb_array_length(p_photos) < 1
       or jsonb_array_length(p_photos) > 5 then
        raise exception 'InvalidDataError';
    end if;

    for item in select value from jsonb_array_elements(p_photos) loop
        path := btrim(coalesce(item ->> 'path', ''));
        if path = '' then
            raise exception 'InvalidDataError';
        end if;
        taken := coalesce((item ->> 'taken_at')::timestamptz, now());

        select count(*) into existing
          from public.evidence_photos e
         where e.session_id = session.id and e.file_path = path and e.phase = 'exit';
        if existing > 0 then
            continue;
        end if;
        perform public.require_evidence_object(path);
        insert into public.evidence_photos (
            session_id, file_path, taken_at, kind, phase
        ) values (session.id, path, taken, 'photo', 'exit');
    end loop;

    select count(*) into total
      from public.evidence_photos e
     where e.session_id = session.id and e.phase = 'exit' and e.kind = 'photo';
    if total > 5 then
        raise exception 'EvidenceLimitError';
    end if;

    return jsonb_build_object(
        'session_id', session.id,
        'exit_photo_count', total
    );
end;
$$;

revoke all on function public.add_exit_evidence(integer, jsonb)
    from public, anon;
grant execute on function public.add_exit_evidence(integer, jsonb)
    to authenticated;

-- ---------------------------------------------------------------------------
-- Begin: validates both sets, expires a stale pending run and reserves the
-- next run number. It never calls the model.
-- ---------------------------------------------------------------------------
create or replace function public.begin_damage_comparison(
    p_session_id integer,
    p_max_per_set integer default 5
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    session public.parking_sessions%rowtype;
    cap integer := least(greatest(coalesce(p_max_per_set, 5), 1), 8);
    entries jsonb;
    exits jsonb;
    entry_count integer;
    exit_count integer;
    comparison_id bigint;
    run integer;
begin
    select * into session from public.parking_sessions s where s.id = p_session_id;
    if not found or session.lot_id <> lot then
        raise exception 'SessionNotFoundError';
    end if;

    update public.damage_comparisons c
       set status = 'failed', error_code = 'AiTimeoutError'
     where c.session_id = session.id
       and c.status = 'pending'
       and c.created_at < now() - interval '3 minutes';

    select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'path', e.file_path)
                              order by e.taken_at, e.id), '[]'::jsonb)
      into entries
      from (
          select * from public.evidence_photos e
           where e.session_id = session.id and e.phase = 'entry'
             and e.kind = 'photo'
           order by e.taken_at, e.id
           limit cap
      ) e;
    select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'path', e.file_path)
                              order by e.taken_at, e.id), '[]'::jsonb)
      into exits
      from (
          select * from public.evidence_photos e
           where e.session_id = session.id and e.phase = 'exit'
             and e.kind = 'photo'
           order by e.taken_at, e.id
           limit cap
      ) e;
    entry_count := jsonb_array_length(entries);
    exit_count := jsonb_array_length(exits);
    if entry_count = 0 or exit_count = 0 then
        raise exception 'InsufficientEvidenceError';
    end if;
    if exists (
        select 1 from public.damage_comparisons c
         where c.session_id = session.id and c.status = 'pending'
    ) then
        raise exception 'ComparisonInProgressError';
    end if;
    if not public.is_lot_admin(lot) and exists (
        select 1 from public.damage_comparisons c
         where c.session_id = session.id and c.status = 'completed'
    ) then
        raise exception 'ComparisonAlreadyExistsError';
    end if;

    select coalesce(max(c.run_number), 0) + 1 into run
      from public.damage_comparisons c where c.session_id = session.id;

    insert into public.damage_comparisons (
        lot_id, session_id, run_number, status, requested_by
    ) values (lot, session.id, run, 'pending', actor)
    returning id into comparison_id;

    return jsonb_build_object(
        'comparison_id', comparison_id,
        'run_number', run,
        'entry_photos', entries,
        'exit_photos', exits
    );
end;
$$;

revoke all on function public.begin_damage_comparison(integer, integer)
    from public, anon;
grant execute on function public.begin_damage_comparison(integer, integer)
    to authenticated;

-- ---------------------------------------------------------------------------
-- Service-role-only writers.
-- ---------------------------------------------------------------------------
create or replace function public.store_damage_comparison(
    p_comparison_id bigint,
    p_result jsonb,
    p_meta jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    comparison public.damage_comparisons%rowtype;
    finding jsonb;
    position integer := 0;
    total integer;
begin
    select * into comparison
      from public.damage_comparisons c
     where c.id = p_comparison_id
     for update;
    if not found or comparison.status <> 'pending' then
        raise exception 'ComparisonNotFoundError';
    end if;

    total := jsonb_array_length(coalesce(p_result -> 'findings', '[]'::jsonb));
    if total > 12 then
        raise exception 'InvalidDataError';
    end if;

    update public.damage_comparisons
       set status = 'completed',
           overall = p_result ->> 'overall',
           summary = left(coalesce(p_result ->> 'summary', ''), 600),
           quality = coalesce(p_result -> 'quality', '{}'::jsonb),
           model = left(coalesce(p_meta ->> 'model', ''), 64),
           entry_photo_count = coalesce((p_meta ->> 'entry_photo_count')::integer, 0),
           exit_photo_count = coalesce((p_meta ->> 'exit_photo_count')::integer, 0),
           ai_request_id = (p_meta ->> 'ai_request_id')::bigint,
           completed_at = now(),
           error_code = null
     where id = comparison.id;

    for finding in
        select value from jsonb_array_elements(
            coalesce(p_result -> 'findings', '[]'::jsonb))
    loop
        position := position + 1;
        insert into public.damage_findings (
            comparison_id, lot_id, position, zone, description, classification,
            confidence, downgraded_from, entry_photo_ids, exit_photo_ids
        ) values (
            comparison.id, comparison.lot_id, position,
            coalesce(finding ->> 'zone', 'other'),
            left(coalesce(finding ->> 'description', 'Hallazgo'), 400),
            coalesce(finding ->> 'classification', 'uncertain'),
            coalesce(finding ->> 'confidence', 'low'),
            nullif(finding ->> 'downgraded_from', ''),
            array(select jsonb_array_elements_text(
                coalesce(finding -> 'entry_photo_ids', '[]'::jsonb))::integer),
            array(select jsonb_array_elements_text(
                coalesce(finding -> 'exit_photo_ids', '[]'::jsonb))::integer)
        );
    end loop;
end;
$$;

revoke all on function public.store_damage_comparison(bigint, jsonb, jsonb)
    from public, anon, authenticated;
grant execute on function public.store_damage_comparison(bigint, jsonb, jsonb)
    to service_role;

create or replace function public.fail_damage_comparison(
    p_comparison_id bigint,
    p_error_code text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.damage_comparisons c
       set status = 'failed',
           error_code = left(coalesce(p_error_code, 'AiUpstreamError'), 64)
     where c.id = p_comparison_id and c.status = 'pending';
    if not found then
        raise exception 'ComparisonNotFoundError';
    end if;
end;
$$;

revoke all on function public.fail_damage_comparison(bigint, text)
    from public, anon, authenticated;
grant execute on function public.fail_damage_comparison(bigint, text)
    to service_role;

-- ---------------------------------------------------------------------------
-- Reads and review (audited).
-- ---------------------------------------------------------------------------
create or replace function public.get_damage_comparison(
    p_session_id integer,
    p_run integer default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer;
    session public.parking_sessions%rowtype;
    comparison public.damage_comparisons%rowtype;
    runs integer;
    entry_now integer;
    exit_now integer;
    findings jsonb;
begin
    perform public.require_app_user();
    lot := public.current_lot_id();
    select * into session from public.parking_sessions s where s.id = p_session_id;
    if not found or session.lot_id <> lot then
        raise exception 'SessionNotFoundError';
    end if;

    select count(*) into runs
      from public.damage_comparisons c where c.session_id = session.id;

    select * into comparison
      from public.damage_comparisons c
     where c.session_id = session.id
       and (p_run is null or c.run_number = p_run)
       and (p_run is not null or c.status <> 'pending' or c.id = (
           select c2.id from public.damage_comparisons c2
            where c2.session_id = session.id
            order by c2.run_number desc limit 1))
     order by c.run_number desc
     limit 1;
    if not found then
        return jsonb_build_object(
            'session_id', session.id, 'runs', runs, 'stale', false,
            'comparison', null);
    end if;

    select count(*) into entry_now from public.evidence_photos e
     where e.session_id = session.id and e.phase = 'entry' and e.kind = 'photo';
    select count(*) into exit_now from public.evidence_photos e
     where e.session_id = session.id and e.phase = 'exit' and e.kind = 'photo';

    select coalesce(jsonb_agg(jsonb_build_object(
               'id', f.id,
               'position', f.position,
               'zone', f.zone,
               'description', f.description,
               'classification', f.classification,
               'confidence', f.confidence,
               'downgraded_from', f.downgraded_from,
               'entry_photo_ids', f.entry_photo_ids,
               'exit_photo_ids', f.exit_photo_ids,
               'review_status', f.review_status,
               'review_note', f.review_note,
               'reviewed_by', f.reviewed_by,
               'reviewed_by_name', u.display_name,
               'reviewed_at', f.reviewed_at
           ) order by f.position), '[]'::jsonb)
      into findings
      from public.damage_findings f
      left join public.users u on u.id = f.reviewed_by
     where f.comparison_id = comparison.id;

    return jsonb_build_object(
        'session_id', session.id,
        'runs', runs,
        'stale', comparison.status = 'completed' and (
            entry_now <> comparison.entry_photo_count
            or exit_now <> comparison.exit_photo_count),
        'comparison', jsonb_build_object(
            'id', comparison.id,
            'run_number', comparison.run_number,
            'status', comparison.status,
            'overall', comparison.overall,
            'summary', comparison.summary,
            'quality', comparison.quality,
            'model', comparison.model,
            'entry_photo_count', comparison.entry_photo_count,
            'exit_photo_count', comparison.exit_photo_count,
            'error_code', comparison.error_code,
            'created_at', comparison.created_at,
            'completed_at', comparison.completed_at,
            'findings', findings
        )
    );
end;
$$;

revoke all on function public.get_damage_comparison(integer, integer)
    from public, anon;
grant execute on function public.get_damage_comparison(integer, integer)
    to authenticated;

create or replace function public.review_damage_finding(
    p_finding_id bigint,
    p_status text,
    p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    finding public.damage_findings%rowtype;
    status_value text := lower(btrim(coalesce(p_status, '')));
    note text := btrim(coalesce(p_note, ''));
begin
    select * into finding
      from public.damage_findings f
     where f.id = p_finding_id
     for update;
    if not found or finding.lot_id <> lot then
        raise exception 'FindingNotFoundError';
    end if;
    if status_value not in ('confirmed', 'dismissed', 'open') then
        raise exception 'InvalidDataError';
    end if;
    if status_value = 'open' then
        if not public.is_lot_admin(lot) then
            raise exception 'AdminRequiredError';
        end if;
    elsif length(note) < 3 or length(note) > 400 then
        raise exception 'InvalidDataError';
    end if;

    update public.damage_findings
       set review_status = status_value,
           review_note = case when status_value = 'open' then null else note end,
           reviewed_by = case when status_value = 'open' then null else actor end,
           reviewed_at = case when status_value = 'open' then null else now() end
     where id = finding.id
     returning * into finding;

    return jsonb_build_object(
        'id', finding.id,
        'review_status', finding.review_status,
        'review_note', finding.review_note,
        'reviewed_by', finding.reviewed_by,
        'reviewed_at', finding.reviewed_at
    );
end;
$$;

revoke all on function public.review_damage_finding(bigint, text, text)
    from public, anon;
grant execute on function public.review_damage_finding(bigint, text, text)
    to authenticated;

create or replace function public.purge_damage_comparisons()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    removed integer;
begin
    delete from public.damage_comparisons c
     using public.parking_settings ps
     where ps.lot_id = c.lot_id
       and ps.evidence_retention_days > 0
       and c.created_at < now() - make_interval(days => ps.evidence_retention_days);
    get diagnostics removed = row_count;
    return removed;
end;
$$;

revoke all on function public.purge_damage_comparisons()
    from public, anon, authenticated;
