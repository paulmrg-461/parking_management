-- Operational snapshot for support: run with
--   docker compose exec -T db psql -U postgres -d parking -f - < supabase/diagnostics.sql
-- or `sh supabase/diagnostics.sh` (wraps this file).
\pset pager off
\echo '== migrations'
select count(*) as applied, max(applied_at) as last_applied from public.schema_migrations;

\echo '== lots'
select l.id, l.code, l.name, l.active,
       (select count(*) from public.categories c where c.lot_id = l.id) as categories,
       (select count(*) from public.parking_sessions s
         where s.lot_id = l.id and s.status = 'open') as open_sessions
  from public.parking_lots l order by l.id;

\echo '== open sessions older than 24h'
select s.id, v.plate, s.entry_time, s.lot_id,
       round(extract(epoch from now() - s.entry_time) / 3600) as hours
  from public.parking_sessions s
  join public.vehicles v on v.id = s.vehicle_id
 where s.status = 'open' and s.entry_time < now() - interval '24 hours'
 order by s.entry_time;

\echo '== shifts open for more than 12h'
select s.id, u.username, s.lot_id, s.opened_at,
       round(extract(epoch from now() - s.opened_at) / 3600) as hours
  from public.shifts s
  join public.users u on u.id = s.operator_id
 where s.closed_at is null and s.opened_at < now() - interval '12 hours'
 order by s.opened_at;

\echo '== pending pass payments'
select status, count(*), coalesce(sum(amount), 0) as amount
  from public.monthly_pass_payments group by status order by status;

\echo '== reservations by status'
select status, count(*) from public.category_reservations group by status order by status;

\echo '== notification backlog'
select count(*) filter (where pushed_at is null and push_attempts = 0) as pending_push,
       count(*) filter (where push_attempts >= 3 and pushed_at is null) as dead,
       count(*) filter (where read_at is null) as unread,
       count(*) as total
  from public.notifications;

\echo '== client errors (last 7 days, top 10)'
select count(*) as hits, platform, left(message, 120) as message
  from public.client_error_reports
 where created_at > now() - interval '7 days'
 group by platform, left(message, 120)
 order by hits desc
 limit 10;

\echo '== whatsapp queue'
select status, count(*), max(created_at) as newest
  from public.whatsapp_messages group by status order by status;

\echo '== idempotency keys'
select count(*) as keys, min(created_at) as oldest from public.idempotency_keys;

\echo '== table sizes (top 12)'
select relname as table, n_live_tup as rows,
       pg_size_pretty(pg_total_relation_size(relid)) as size
  from pg_stat_user_tables
 order by pg_total_relation_size(relid) desc
 limit 12;

\echo '== storage objects (by bucket)'
select bucket_id, count(*) as objects,
       pg_size_pretty(coalesce(sum((metadata ->> 'size')::bigint), 0)) as size
  from storage.objects group by bucket_id order by bucket_id;
