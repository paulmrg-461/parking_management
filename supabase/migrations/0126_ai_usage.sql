-- Shared AI accounting for the Claude/DeepSeek-backed Edge Functions.
-- This change creates the platform: per-feature defaults, per-lot limits, the
-- reservation/usage ledger and the retention job. It never stores question or
-- answer text. `add-ai-damage-comparison` reuses these tables/functions.
--
-- Cost control, not a security boundary: the reservation is the worst case and
-- the Edge Function reports actual usage through the caller's own JWT.

create table if not exists public.ai_features (
    feature                 text    primary key check (feature ~ '^[a-z][a-z_]{2,39}$'),
    admin_only              boolean not null,
    default_daily_requests  integer not null check (default_daily_requests between 0 and 10000),
    default_daily_tokens    integer not null check (default_daily_tokens between 0 and 50000000)
);

insert into public.ai_features (feature, admin_only, default_daily_requests, default_daily_tokens)
values ('report_assistant', true, 100, 1000000)
on conflict (feature) do nothing;

create table if not exists public.ai_limits (
    lot_id          integer     not null references public.parking_lots(id) on delete cascade,
    feature         text        not null references public.ai_features(feature),
    daily_requests  integer     not null check (daily_requests between 0 and 10000),
    daily_tokens    integer     not null check (daily_tokens between 0 and 50000000),
    updated_at      timestamptz not null default now(),
    primary key (lot_id, feature)
);

create table if not exists public.ai_requests (
    id                 bigserial   primary key,
    lot_id             integer     not null references public.parking_lots(id) on delete cascade,
    feature            text        not null references public.ai_features(feature),
    actor_id           integer     references public.users(id) on delete set null,
    status             text        not null default 'reserved'
                       check (status in ('reserved', 'ok', 'error', 'refused', 'timeout')),
    model              text,
    reserved_tokens    integer     not null check (reserved_tokens >= 0),
    input_tokens       integer     not null default 0 check (input_tokens >= 0),
    output_tokens      integer     not null default 0 check (output_tokens >= 0),
    cache_read_tokens  integer     not null default 0 check (cache_read_tokens >= 0),
    cache_write_tokens integer     not null default 0 check (cache_write_tokens >= 0),
    tool_calls         integer     not null default 0,
    duration_ms        integer,
    error_code         text,
    business_day       date        not null,
    created_at         timestamptz not null default now(),
    finished_at        timestamptz
);
create index if not exists ix_ai_requests_budget
    on public.ai_requests (lot_id, feature, business_day);
create index if not exists ix_ai_requests_created on public.ai_requests (created_at);

alter table public.ai_features enable row level security;
alter table public.ai_limits enable row level security;
alter table public.ai_requests enable row level security;
revoke all on public.ai_features, public.ai_limits, public.ai_requests
    from public, anon, authenticated;
grant select on public.ai_limits, public.ai_requests to authenticated;

drop policy if exists ai_limits_admin_read on public.ai_limits;
create policy ai_limits_admin_read on public.ai_limits
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));
drop policy if exists ai_requests_admin_read on public.ai_requests;
create policy ai_requests_admin_read on public.ai_requests
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop trigger if exists trg_audit_row on public.ai_limits;
create trigger trg_audit_row after insert or update or delete on public.ai_limits
    for each row execute function public.record_audit();

-- ---------------------------------------------------------------------------
-- Feature defaults (internal).
-- ---------------------------------------------------------------------------
create or replace function public.ai_default_limit(p_feature text)
returns public.ai_features
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    result public.ai_features%rowtype;
begin
    select * into result from public.ai_features f where f.feature = p_feature;
    if not found then
        raise exception 'AiFeatureUnknownError';
    end if;
    return result;
end;
$$;

revoke all on function public.ai_default_limit(text)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Reservation: authenticates the caller, enforces the lot budget and writes
-- the reserved row. A crashed request keeps its reservation until the day ends.
-- ---------------------------------------------------------------------------
create or replace function public.ai_budget_reserve(
    p_feature text,
    p_est_tokens integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    feature public.ai_features%rowtype;
    limits public.ai_limits%rowtype;
    tz text;
    day date;
    daily_requests integer;
    daily_tokens integer;
    used_requests integer;
    used_tokens bigint;
    request_id bigint;
begin
    select * into feature from public.ai_features f where f.feature = p_feature;
    if not found then
        raise exception 'AiFeatureUnknownError';
    end if;
    if feature.admin_only and not public.is_lot_admin(lot) then
        raise exception 'AdminRequiredError';
    end if;
    if p_est_tokens is null or p_est_tokens < 1 or p_est_tokens > 2000000 then
        raise exception 'InvalidDataError';
    end if;

    perform pg_advisory_xact_lock(hashtext('ai_budget'), lot);

    select * into limits from public.ai_limits l
     where l.lot_id = lot and l.feature = p_feature;
    daily_requests := coalesce(limits.daily_requests, feature.default_daily_requests);
    daily_tokens := coalesce(limits.daily_tokens, feature.default_daily_tokens);

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    day := (now() at time zone tz)::date;

    select count(*),
           coalesce(sum(case when r.status = 'reserved'
                             then r.reserved_tokens
                             else r.input_tokens + r.output_tokens
                                  + r.cache_read_tokens + r.cache_write_tokens
                        end), 0)
      into used_requests, used_tokens
      from public.ai_requests r
     where r.lot_id = lot
       and r.feature = p_feature
       and r.business_day = day;

    if used_requests + 1 > daily_requests
       or used_tokens + p_est_tokens > daily_tokens then
        raise exception 'AiBudgetExceededError';
    end if;

    insert into public.ai_requests (
        lot_id, feature, actor_id, status, reserved_tokens, business_day
    )
    values (lot, p_feature, actor, 'reserved', p_est_tokens, day)
    returning id into request_id;

    return jsonb_build_object(
        'request_id', request_id,
        'lot_id', lot,
        'feature', p_feature,
        'business_day', day,
        'daily_requests', daily_requests,
        'daily_tokens', daily_tokens,
        'remaining_requests', daily_requests - used_requests - 1,
        'remaining_tokens', daily_tokens - used_tokens - p_est_tokens
    );
end;
$$;

revoke all on function public.ai_budget_reserve(text, integer)
    from public, anon;
grant execute on function public.ai_budget_reserve(text, integer)
    to authenticated;

-- ---------------------------------------------------------------------------
-- Usage: the function closes its own reservation with actual numbers.
-- ---------------------------------------------------------------------------
create or replace function public.ai_usage_record(
    p_request_id bigint,
    p_usage jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.current_app_user_id();
    request public.ai_requests%rowtype;
    status_value text := lower(btrim(coalesce(p_usage ->> 'status', '')));
    error_value text := nullif(left(btrim(coalesce(p_usage ->> 'error_code', '')), 64), '');
begin
    select * into request
      from public.ai_requests r
     where r.id = p_request_id
     for update;
    if not found
       or request.actor_id is distinct from actor
       or request.status <> 'reserved' then
        raise exception 'AiRequestNotFoundError';
    end if;
    if status_value not in ('ok', 'error', 'refused', 'timeout') then
        raise exception 'InvalidDataError';
    end if;

    update public.ai_requests r
       set status = status_value,
           model = left(nullif(btrim(coalesce(p_usage ->> 'model', '')), ''), 64),
           input_tokens = least(greatest(coalesce((p_usage ->> 'input_tokens')::integer, 0), 0), 10000000),
           output_tokens = least(greatest(coalesce((p_usage ->> 'output_tokens')::integer, 0), 0), 10000000),
           cache_read_tokens = least(greatest(coalesce((p_usage ->> 'cache_read_tokens')::integer, 0), 0), 10000000),
           cache_write_tokens = least(greatest(coalesce((p_usage ->> 'cache_write_tokens')::integer, 0), 0), 10000000),
           tool_calls = least(greatest(coalesce((p_usage ->> 'tool_calls')::integer, 0), 0), 100000),
           duration_ms = least(greatest(coalesce((p_usage ->> 'duration_ms')::integer, 0), 0), 86400000),
           error_code = error_value,
           finished_at = now()
     where r.id = request.id;
end;
$$;

revoke all on function public.ai_usage_record(bigint, jsonb)
    from public, anon;
grant execute on function public.ai_usage_record(bigint, jsonb)
    to authenticated;

-- ---------------------------------------------------------------------------
-- Reads and limits.
-- ---------------------------------------------------------------------------
create or replace function public.ai_budget_status(p_feature text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer;
    feature public.ai_features%rowtype;
    limits public.ai_limits%rowtype;
    tz text;
    day date;
    daily_requests integer;
    daily_tokens integer;
    used_requests integer;
    used_tokens bigint;
begin
    perform public.require_app_user();
    lot := public.current_lot_id();
    select * into feature from public.ai_features f where f.feature = p_feature;
    if not found then
        raise exception 'AiFeatureUnknownError';
    end if;
    if feature.admin_only and not public.is_lot_admin(lot) then
        raise exception 'AdminRequiredError';
    end if;

    select * into limits from public.ai_limits l
     where l.lot_id = lot and l.feature = p_feature;
    daily_requests := coalesce(limits.daily_requests, feature.default_daily_requests);
    daily_tokens := coalesce(limits.daily_tokens, feature.default_daily_tokens);
    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    day := (now() at time zone tz)::date;

    select count(*),
           coalesce(sum(case when r.status = 'reserved'
                             then r.reserved_tokens
                             else r.input_tokens + r.output_tokens
                                  + r.cache_read_tokens + r.cache_write_tokens
                        end), 0)
      into used_requests, used_tokens
      from public.ai_requests r
     where r.lot_id = lot
       and r.feature = p_feature
       and r.business_day = day;

    return jsonb_build_object(
        'lot_id', lot,
        'feature', p_feature,
        'business_day', day,
        'daily_requests', daily_requests,
        'daily_tokens', daily_tokens,
        'used_requests', used_requests,
        'used_tokens', used_tokens,
        'remaining_requests', greatest(daily_requests - used_requests, 0),
        'remaining_tokens', greatest(daily_tokens - used_tokens, 0)
    );
end;
$$;

revoke all on function public.ai_budget_status(text) from public, anon;
grant execute on function public.ai_budget_status(text) to authenticated;

create or replace function public.set_ai_limit(
    p_feature text,
    p_daily_requests integer,
    p_daily_tokens integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
begin
    perform public.ai_default_limit(p_feature);
    if p_daily_requests is null or p_daily_requests < 0 or p_daily_requests > 10000
       or p_daily_tokens is null or p_daily_tokens < 0 or p_daily_tokens > 50000000 then
        raise exception 'InvalidDataError';
    end if;

    insert into public.ai_limits (lot_id, feature, daily_requests, daily_tokens, updated_at)
    values (lot, p_feature, p_daily_requests, p_daily_tokens, now())
    on conflict (lot_id, feature) do update
       set daily_requests = excluded.daily_requests,
           daily_tokens = excluded.daily_tokens,
           updated_at = now();

    return jsonb_build_object(
        'lot_id', lot,
        'feature', p_feature,
        'daily_requests', p_daily_requests,
        'daily_tokens', p_daily_tokens
    );
end;
$$;

revoke all on function public.set_ai_limit(text, integer, integer) from public, anon;
grant execute on function public.set_ai_limit(text, integer, integer)
    to authenticated;

create or replace function public.purge_ai_requests(p_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    days integer := greatest(coalesce(p_days, 90), 30);
    removed integer;
begin
    delete from public.ai_requests r
     where r.created_at < now() - make_interval(days => days);
    get diagnostics removed = row_count;
    return removed;
end;
$$;

revoke all on function public.purge_ai_requests(integer)
    from public, anon, authenticated;
