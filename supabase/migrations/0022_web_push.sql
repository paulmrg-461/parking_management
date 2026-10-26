-- Browser push subscriptions (VAPID). Each row is one browser/device for one
-- operator; `push-dispatch` reads them with the service role and sends the
-- notification through the Web Push protocol.

create table if not exists public.web_push_subscriptions (
    id         bigserial   primary key,
    user_id    integer     not null references public.users(id) on delete cascade,
    endpoint   text        not null unique,
    p256dh     text        not null,
    auth       text        not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index if not exists ix_web_push_user on public.web_push_subscriptions(user_id);

alter table public.web_push_subscriptions enable row level security;
grant select, delete on public.web_push_subscriptions to authenticated;

drop policy if exists web_push_own on public.web_push_subscriptions;
create policy web_push_own on public.web_push_subscriptions
    for select to authenticated
    using (user_id = public.current_app_user_id());

-- ---------------------------------------------------------------------------
-- Browser writes go through these RPCs so the owner always comes from
-- auth.uid(); the endpoint is the natural key (one row per browser).
-- ---------------------------------------------------------------------------
create or replace function public.save_web_push_subscription(
    p_endpoint text,
    p_p256dh text,
    p_auth text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    saved public.web_push_subscriptions%rowtype;
begin
    if nullif(btrim(coalesce(p_endpoint, '')), '') is null
       or nullif(btrim(coalesce(p_p256dh, '')), '') is null
       or nullif(btrim(coalesce(p_auth, '')), '') is null then
        raise exception 'InvalidPushSubscriptionError';
    end if;

    insert into public.web_push_subscriptions (user_id, endpoint, p256dh, auth)
    values (actor, btrim(p_endpoint), btrim(p_p256dh), btrim(p_auth))
    on conflict (endpoint) do update
        set user_id = excluded.user_id,
            p256dh = excluded.p256dh,
            auth = excluded.auth,
            updated_at = now()
    returning * into saved;

    return jsonb_build_object(
        'id', saved.id,
        'endpoint', saved.endpoint,
        'user_id', saved.user_id
    );
end;
$$;

create or replace function public.delete_web_push_subscription(p_endpoint text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
begin
    delete from public.web_push_subscriptions w
     where w.endpoint = p_endpoint
       and w.user_id = actor;
    return jsonb_build_object('deleted', found);
end;
$$;

grant execute on function public.save_web_push_subscription(text, text, text) to authenticated;
grant execute on function public.delete_web_push_subscription(text) to authenticated;
