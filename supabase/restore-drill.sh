#!/bin/sh
# Restores a backup into a SCRATCH database and validates it, without touching
# the live one. Safe to run on a production host: it only reads the source DB.
#
#   sh supabase/restore-drill.sh                 # fresh backup, then drill
#   sh supabase/restore-drill.sh backups/<stamp> # drill an existing backup
#
# Exit codes: 0 = the backup is restorable and complete, 1 = mismatch/error.
set -eu

cd "$(dirname "$0")/.."

getenv() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2-; }
DB_NAME=$(getenv POSTGRES_DB); DB_NAME=${DB_NAME:-parking}

if [ $# -ge 1 ]; then
  BACKUP=$1
else
  echo "== creating a fresh backup"
  sh supabase/backup.sh
  BACKUP=$(ls -1d backups/*/ | sort | tail -1)
fi
BACKUP=${BACKUP%/}
test -s "$BACKUP/parking.dump" || { echo "missing $BACKUP/parking.dump" >&2; exit 1; }

SCRATCH="restore_drill_$$"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }

sql() {
  docker compose exec -T db psql -U postgres -d "$1" -tAc "$2" 2>/dev/null | tr -d '[:space:]'
}

drop_scratch() {
  docker compose exec -T db psql -U postgres -d postgres \
    -c "drop database if exists \"$SCRATCH\";" >/dev/null 2>&1 || true
}
trap drop_scratch EXIT INT TERM

echo "== restoring $BACKUP into $SCRATCH"
docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "drop database if exists \"$SCRATCH\";" >/dev/null
docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "create database \"$SCRATCH\";" >/dev/null
if ! docker compose exec -T db pg_restore -U supabase_admin -d "$SCRATCH" --no-owner \
  < "$BACKUP/parking.dump" >/tmp/parking-restore-drill.log 2>&1; then
  # pg_restore warns about pre-existing roles/ownership; only real errors fail.
  if grep -qiE "error:" /tmp/parking-restore-drill.log; then
    echo "pg_restore reported errors:" >&2
    grep -iE "error:" /tmp/parking-restore-drill.log | head -20 >&2
    fail "the dump did not restore cleanly"
  fi
fi

echo "== validating schema and data"
source_migrations=$(sql "$DB_NAME" "select count(*) from public.schema_migrations")
scratch_migrations=$(sql "$SCRATCH" "select count(*) from public.schema_migrations")
[ "$source_migrations" = "$scratch_migrations" ] || \
  fail "schema_migrations: source=$source_migrations restored=$scratch_migrations"

source_policies=$(sql "$DB_NAME" \
  "select count(*) from pg_policies where schemaname in ('public','storage')")
scratch_policies=$(sql "$SCRATCH" \
  "select count(*) from pg_policies where schemaname in ('public','storage')")
[ "$source_policies" = "$scratch_policies" ] || \
  fail "RLS policies: source=$source_policies restored=$scratch_policies"

grants_ok=$(sql "$SCRATCH" \
  "select has_table_privilege('authenticated','public.parking_sessions','SELECT') \
      and has_table_privilege('authenticated','public.parking_settings','SELECT') \
      and has_table_privilege('authenticated','public.notifications','SELECT')")
[ "$grants_ok" = "t" ] || fail "authenticated table grants were not restored"

source_rpcs=$(sql "$DB_NAME" \
  "select count(*) from pg_proc where proname in ('check_in','check_out','dashboard_today','report_revenue','list_audit_log','current_lot_id')")
scratch_rpcs=$(sql "$SCRATCH" \
  "select count(*) from pg_proc where proname in ('check_in','check_out','dashboard_today','report_revenue','list_audit_log','current_lot_id')")
[ "$source_rpcs" = "$scratch_rpcs" ] || \
  fail "core RPCs: source=$source_rpcs restored=$scratch_rpcs"

for table in users parking_lots lot_members categories tariffs vehicles \
             parking_sessions shifts monthly_passes notifications audit_log; do
  source_count=$(sql "$DB_NAME" "select count(*) from public.$table")
  scratch_count=$(sql "$SCRATCH" "select count(*) from public.$table")
  if [ "$source_count" != "$scratch_count" ]; then
    fail "$table: source=$source_count restored=$scratch_count"
  else
    echo "  $table: $scratch_count rows"
  fi
done

if [ -s "$BACKUP/storage.tgz" ]; then
  objects=$(tar -tzf "$BACKUP/storage.tgz" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$objects" -lt 1 ]; then
    fail "storage archive is empty"
  else
    echo "  storage archive: $objects entries"
  fi
else
  echo "  WARN: no storage archive in this backup (database only)"
fi

echo "== summary"
if [ "$failures" -ne 0 ]; then
  echo "restore drill FAILED ($failures problem(s))" >&2
  exit 1
fi
echo "restore drill OK: $BACKUP is restorable"
