#!/bin/sh
# Runs the notification tasks that have no built-in scheduler.
#
#   * * * * *  /path/to/repo/supabase/notifications-cron.sh >> /tmp/parking-notify.log 2>&1
#
# - notify_expiring_monthly_passes() / notify_overstays() are idempotent
#   (dedupe_key), so running them every minute is harmless and still produces
#   one alert per pass / per vehicle per day.
# - push-dispatch returns {configured:false} until FCM_SERVICE_ACCOUNT_JSON is
#   set; in-app notifications do not depend on it.
set -eu

cd "$(dirname "$0")/.."

SERVICE_KEY=$(grep -E '^SERVICE_ROLE_KEY=' .env | head -1 | cut -d= -f2-)
API_URL=$(grep -E '^SUPABASE_PUBLIC_URL=' .env | head -1 | cut -d= -f2-)
DB_NAME=$(grep -E '^POSTGRES_DB=' .env | head -1 | cut -d= -f2-)
DB_NAME=${DB_NAME:-parking}

docker compose exec -T db psql -U postgres -d "$DB_NAME" -tAc \
  "select public.notify_expiring_monthly_passes();" >/dev/null
docker compose exec -T db psql -U postgres -d "$DB_NAME" -tAc \
  "select public.notify_overstays();" >/dev/null

curl -fsS -X POST "${API_URL:-http://localhost:8000}/functions/v1/push-dispatch" \
  -H "Authorization: Bearer ${SERVICE_KEY}" >/dev/null
