-- Diagnostics also report the WhatsApp queue so failed customer messages are
-- visible in the panel, not just in SQL.

create or replace function public.diagnostics_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    result jsonb;
begin
    perform public.require_admin();

    select jsonb_build_object(
        'migrations', (select count(*) from public.schema_migrations),
        'last_migration_at', (select max(applied_at) from public.schema_migrations),
        'lots', (select count(*) from public.parking_lots),
        'active_lots', (select count(*) from public.parking_lots where active),
        'open_sessions', (
            select count(*) from public.parking_sessions where status = 'open'
        ),
        'stale_sessions_24h', (
            select count(*) from public.parking_sessions
             where status = 'open' and entry_time < now() - interval '24 hours'
        ),
        'open_shifts_12h', (
            select count(*) from public.shifts
             where closed_at is null and opened_at < now() - interval '12 hours'
        ),
        'pending_pass_payments', (
            select count(*) from public.monthly_pass_payments where status = 'pending'
        ),
        'active_reservations', (
            select count(*) from public.category_reservations
             where status = 'active' and reserved_until > now()
        ),
        'notifications', jsonb_build_object(
            'pending_push', (
                select count(*) from public.notifications
                 where pushed_at is null and push_attempts = 0
            ),
            'dead_push', (
                select count(*) from public.notifications
                 where push_attempts >= 3 and pushed_at is null
            ),
            'unread', (
                select count(*) from public.notifications where read_at is null
            ),
            'total', (select count(*) from public.notifications)
        ),
        'client_errors_24h', (
            select count(*) from public.client_error_reports
             where created_at > now() - interval '24 hours'
        ),
        'whatsapp', jsonb_build_object(
            'pending', (
                select count(*) from public.whatsapp_messages
                 where status = 'pending'
            ),
            'failed', (
                select count(*) from public.whatsapp_messages
                 where status = 'failed'
            ),
            'sent_24h', (
                select count(*) from public.whatsapp_messages
                 where status = 'sent'
                   and sent_at > now() - interval '24 hours'
            ),
            'oldest_pending_at', (
                select min(created_at) from public.whatsapp_messages
                 where status = 'pending'
            )
        ),
        'idempotency_keys', (select count(*) from public.idempotency_keys),
        'storage', (
            select coalesce(jsonb_agg(item order by item ->> 'bucket'), '[]'::jsonb)
              from (
                select jsonb_build_object(
                           'bucket', o.bucket_id,
                           'objects', count(*),
                           'bytes', coalesce(sum((o.metadata ->> 'size')::bigint), 0)
                       ) as item
                  from storage.objects o
                 group by o.bucket_id
              ) buckets
        )
    ) into result;

    return result;
end;
$$;

create or replace function public.list_whatsapp_messages(
    p_limit integer default 50,
    p_days integer default 7
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    result jsonb;
begin
    perform public.require_admin();
    select coalesce(jsonb_agg(item order by item ->> 'created_at' desc), '[]'::jsonb)
      into result
      from (
        select jsonb_build_object(
                   'id', m.id,
                   'to_phone', m.to_phone,
                   'template', m.template,
                   'language', m.language,
                   'params', m.params,
                   'status', m.status,
                   'attempts', m.attempts,
                   'error', m.error,
                   'created_at', m.created_at,
                   'sent_at', m.sent_at,
                   'actor', u.username,
                   'lot', l.name
               ) as item
          from (
            select *
              from public.whatsapp_messages
             where created_at > now() - make_interval(days => greatest(coalesce(p_days, 1), 1))
             order by created_at desc
             limit greatest(coalesce(p_limit, 50), 1)
          ) m
          left join public.users u on u.id = m.user_id
          left join public.parking_lots l on l.id = m.lot_id
      ) rows;
    return result;
end;
$$;

grant execute on function public.list_whatsapp_messages(integer, integer) to authenticated;
