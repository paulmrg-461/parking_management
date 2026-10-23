-- Operational visibility without an external APM: the app reports uncaught
-- errors here (best effort, throttled) and admins can read them.

create table if not exists public.client_error_reports (
    id          bigserial   primary key,
    user_id     integer     references public.users(id) on delete set null,
    platform    varchar(20) not null,
    message     text        not null,
    stack       text,
    context     jsonb       not null default '{}'::jsonb,
    app_version varchar(40),
    created_at  timestamptz not null default now()
);
create index if not exists ix_client_errors_created
    on public.client_error_reports(created_at desc);
create index if not exists ix_client_errors_user
    on public.client_error_reports(user_id);

alter table public.client_error_reports enable row level security;
grant select on public.client_error_reports to authenticated;

drop policy if exists client_errors_admin_read on public.client_error_reports;
create policy client_errors_admin_read on public.client_error_reports
    for select to authenticated using (public.is_admin());

-- Writes come from the app through this RPC: the actor is auth.uid() and the
-- payload is bounded so a broken client cannot flood the table with MBs.
create or replace function public.report_client_error(
    p_platform text,
    p_message text,
    p_stack text default null,
    p_context jsonb default '{}'::jsonb,
    p_app_version text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    inserted public.client_error_reports%rowtype;
begin
    if nullif(btrim(coalesce(p_message, '')), '') is null then
        raise exception 'InvalidDataError';
    end if;

    insert into public.client_error_reports (
        user_id, platform, message, stack, context, app_version
    )
    values (
        actor,
        left(coalesce(nullif(btrim(p_platform), ''), 'unknown'), 20),
        left(btrim(p_message), 2000),
        left(p_stack, 8000),
        coalesce(p_context, '{}'::jsonb),
        left(p_app_version, 40)
    )
    returning * into inserted;

    return jsonb_build_object('id', inserted.id, 'created_at', inserted.created_at);
end;
$$;

grant execute on function public.report_client_error(text, text, text, jsonb, text) to authenticated;

-- Old reports are noise after a month; the cron calls this with the rest of
-- the retention jobs.
create or replace function public.purge_client_error_reports(p_days integer default 30)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    delete from public.client_error_reports r
     where r.created_at < now() - make_interval(days => greatest(coalesce(p_days, 1), 1));
    get diagnostics changed = row_count;
    return changed;
end;
$$;

grant execute on function public.purge_client_error_reports(integer) to authenticated;
