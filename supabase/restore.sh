#!/bin/sh
# Restores a backup produced by backup.sh. Destructive: requires
# RESTORE_CONFIRM=yes.
set -eu

if [ "${RESTORE_CONFIRM:-}" != "yes" ]; then
  echo "refusing to restore without RESTORE_CONFIRM=yes" >&2
  exit 2
fi
if [ $# -lt 1 ]; then
  echo "usage: RESTORE_CONFIRM=yes $0 backups/<timestamp>" >&2
  exit 2
fi

BACKUP=$1
cd "$(dirname "$0")/.."
test -s "$BACKUP/parking.dump" || { echo "missing $BACKUP/parking.dump" >&2; exit 1; }

DB_NAME=$(grep -E '^POSTGRES_DB=' .env | head -1 | cut -d= -f2-)
DB_NAME=${DB_NAME:-parking}

echo "stopping writers..."
docker compose stop auth rest realtime storage functions supavisor >/dev/null 2>&1 || true

echo "restoring database $DB_NAME..."
docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "select pg_terminate_backend(pid) from pg_stat_activity where datname = '$DB_NAME' and pid <> pg_backend_pid();" >/dev/null
# `supabase_admin` owns the app objects and was the grantor in the dump;
# restoring as postgres makes every ACL fail ("grant options cannot be granted
# back to your own grantor").
docker compose exec -T db pg_restore -U supabase_admin -d "$DB_NAME" --clean --if-exists --no-owner < "$BACKUP/parking.dump"

if [ -s "$BACKUP/storage.tgz" ]; then
  echo "restoring storage..."
  docker run --rm -v "$PWD/supabase/volumes:/v" -v "$PWD/$BACKUP:/backup:ro" alpine \
    sh -c 'rm -rf /v/storage && tar xzf /backup/storage.tgz -C /v'
fi

echo "starting services..."
docker compose up -d
echo "restore complete"
