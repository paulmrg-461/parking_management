-- Automated WhatsApp messages (Meta Cloud API) are queued by the app and sent
-- by the `whatsapp-dispatch` Edge Function, which holds the token. The app can
-- only enqueue, and only when the site opted in.

alter table public.parking_settings
    add column if not exists whatsapp_auto boolean not null default false;

create table if not exists public.whatsapp_messages (
    id         bigserial   primary key,
    user_id    integer     references public.users(id) on delete set null,
    lot_id     integer     references public.parking_lots(id) on delete set null,
    to_phone   varchar(32) not null,
    template   varchar(60) not null,
    language   varchar(10) not null default 'es',
    params     jsonb       not null default '[]'::jsonb,
    status     text        not null default 'pending'
               check (status in ('pending', 'sent', 'failed')),
    attempts   integer     not null default 0,
    error      text,
    created_at timestamptz not null default now(),
    sent_at    timestamptz
);
create index if not exists ix_whatsapp_pending
    on public.whatsapp_messages(status, created_at);
create index if not exists ix_whatsapp_created
    on public.whatsapp_messages(created_at desc);

alter table public.whatsapp_messages enable row level security;
grant select on public.whatsapp_messages to authenticated;

drop policy if exists whatsapp_admin_read on public.whatsapp_messages;
create policy whatsapp_admin_read on public.whatsapp_messages
    for select to authenticated using (public.is_admin());

create or replace function public.enqueue_whatsapp_message(
    p_to_phone text,
    p_template text,
    p_params jsonb default '[]'::jsonb,
    p_language text default 'es'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    actor integer := public.require_app_user();
    lot integer := public.current_lot_id();
    digits text := regexp_replace(coalesce(p_to_phone, ''), '\D', '', 'g');
    enabled boolean;
    inserted public.whatsapp_messages%rowtype;
begin
    select coalesce(whatsapp_auto, false) into enabled
      from public.parking_settings where lot_id = lot;
    if not coalesce(enabled, false) then
        raise exception 'WhatsappDisabledError';
    end if;
    if length(digits) not between 7 and 15 then
        raise exception 'InvalidPhoneError';
    end if;
    if nullif(btrim(coalesce(p_template, '')), '') is null then
        raise exception 'InvalidDataError';
    end if;
    if jsonb_typeof(coalesce(p_params, '[]'::jsonb)) <> 'array' then
        raise exception 'InvalidDataError';
    end if;

    insert into public.whatsapp_messages (
        user_id, lot_id, to_phone, template, language, params
    )
    values (
        actor, lot, digits, left(btrim(p_template), 60),
        left(coalesce(nullif(btrim(p_language), ''), 'es'), 10),
        coalesce(p_params, '[]'::jsonb)
    )
    returning * into inserted;

    return jsonb_build_object(
        'id', inserted.id,
        'status', inserted.status,
        'to_phone', inserted.to_phone
    );
end;
$$;

grant execute on function public.enqueue_whatsapp_message(text, text, jsonb, text) to authenticated;

create or replace function public.purge_whatsapp_messages(p_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    delete from public.whatsapp_messages m
     where m.status in ('sent', 'failed')
       and m.created_at < now() - make_interval(days => greatest(coalesce(p_days, 1), 1));
    get diagnostics changed = row_count;
    return changed;
end;
$$;

grant execute on function public.purge_whatsapp_messages(integer) to authenticated;
