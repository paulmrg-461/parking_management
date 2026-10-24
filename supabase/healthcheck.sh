#!/bin/sh
# Verifies the running stack: services, HTTP endpoints and operational backlog.
#
#   sh supabase/healthcheck.sh            # human output, exit 1 on failure
#   HEALTHCHECK_WEBHOOK=https://... sh supabase/healthcheck.sh
#
# Cron example (every 5 minutes, alert on failure):
#   */5 * * * * cd /opt/parking && HEALTHCHECK_WEBHOOK=... sh supabase/healthcheck.sh >> /var/log/parking-health.log 2>&1
set -eu

cd "$(dirname "$0")/.."

getenv() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2-; }
api=$(getenv SUPABASE_PUBLIC_URL); api=${api:-http://localhost:8000}
anon=$(getenv ANON_KEY)
db=$(getenv POSTGRES_DB); db=${db:-parking}

failures=0
warnings=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
warn() { echo "WARN: $*"; warnings=$((warnings + 1)); }

sql() {
  docker compose exec -T db psql -U postgres -d "$db" -tAc "$1" 2>/dev/null | tr -d '[:space:]'
}

echo "== services"
for service in db auth rest storage realtime functions api-gw; do
  state=$(docker compose ps --format '{{.Service}} {{.State}}' | awk -v s="$service" '$1==s {print $2}')
  if [ "$state" != "running" ]; then
    fail "service $service is ${state:-missing}"
  fi
done

echo "== endpoints"
code=$(curl -s -o /dev/null -w '%{http_code}' -H "apikey: $anon" "$api/auth/v1/health" || true)
[ "$code" = "200" ] || fail "auth health returned ${code:-no response}"

code=$(curl -s -o /dev/null -w '%{http_code}' -H "apikey: $anon" \
  "$api/rest/v1/parking_settings?select=id&limit=1" || true)
[ "$code" = "200" ] || fail "REST query returned ${code:-no response}"

code=$(curl -s -o /dev/null -w '%{http_code}' "$api/storage/v1/status" || true)
[ "$code" = "200" ] || fail "storage status returned ${code:-no response}"

echo "== database"
applied=$(sql "select count(*) from public.schema_migrations" || true)
[ "${applied:-0}" -gt 0 ] 2>/dev/null || fail "schema_migrations is empty (migrations never ran)"
echo "migrations applied: ${applied:-unknown}"

stale_sessions=$(sql "select count(*) from public.parking_sessions where status = 'open' and entry_time < now() - interval '48 hours'" || true)
if [ "${stale_sessions:-0}" -gt 0 ] 2>/dev/null; then
  warn "$stale_sessions session(s) open for more than 48h (missing check-out?)"
fi

open_shifts=$(sql "select count(*) from public.shifts where closed_at is null and opened_at < now() - interval '12 hours'" || true)
if [ "${open_shifts:-0}" -gt 0 ] 2>/dev/null; then
  warn "$open_shifts shift(s) open for more than 12h (forgotten arqueo?)"
fi

dead_pushes=$(sql "select count(*) from public.notifications where push_attempts >= 3 and pushed_at is null" || true)
if [ "${dead_pushes:-0}" -gt 0 ] 2>/dev/null; then
  warn "$dead_pushes notification(s) could not be pushed after 3 attempts"
fi

if [ -n "$(getenv FCM_SERVICE_ACCOUNT_JSON)$(getenv VAPID_PUBLIC_KEY)" ]; then
  backlog=$(sql "select count(*) from public.notifications where pushed_at is null and push_attempts = 0 and created_at < now() - interval '15 minutes'" || true)
  if [ "${backlog:-0}" -gt 0 ] 2>/dev/null; then
    warn "$backlog notification(s) pending push for more than 15 minutes (is the cron running?)"
  fi
fi

client_errors=$(sql "select count(*) from public.client_error_reports where created_at > now() - interval '24 hours'" || true)
if [ "${client_errors:-0}" -gt 0 ] 2>/dev/null; then
  warn "$client_errors client error report(s) in the last 24h (see diagnostics.sql)"
fi

whatsapp_failed=$(sql "select count(*) from public.whatsapp_messages where status = 'failed'" || true)
if [ "${whatsapp_failed:-0}" -gt 0 ] 2>/dev/null; then
  warn "$whatsapp_failed WhatsApp message(s) failed after 3 attempts"
fi

idempotency=$(sql "select count(*) from public.idempotency_keys" || true)
if [ "${idempotency:-0}" -gt 100000 ] 2>/dev/null; then
  warn "$idempotency idempotency keys stored (purge job not running?)"
fi

echo "== summary"
echo "failures: $failures, warnings: $warnings"

if [ "$failures" -gt 0 ] && [ -n "${HEALTHCHECK_WEBHOOK:-}" ]; then
  payload=$(printf '{"text":"parking healthcheck: %s failure(s), %s warning(s) on %s"}' \
    "$failures" "$warnings" "$(hostname)")
  curl -fsS -X POST "$HEALTHCHECK_WEBHOOK" \
    -H 'Content-Type: application/json' --data "$payload" >/dev/null || \
    echo "WARN: could not deliver the alert webhook"
fi

[ "$failures" -eq 0 ]
