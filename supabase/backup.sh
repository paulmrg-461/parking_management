#!/bin/sh
# Backs up the Supabase database and Storage volume into backups/<timestamp>/.
# Secrets live in .env and are NOT included: keep .env separately.
set -eu

cd "$(dirname "$0")/.."
DB_NAME=$(grep -E '^POSTGRES_DB=' .env | head -1 | cut -d= -f2-)
DB_NAME=${DB_NAME:-parking}
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT="backups/$STAMP"

mkdir -p "$OUT"
echo "dumping database $DB_NAME..."
docker compose exec -T db pg_dump -U postgres -d "$DB_NAME" -Fc > "$OUT/parking.dump"
test -s "$OUT/parking.dump" || { echo "empty database dump" >&2; exit 1; }

echo "archiving storage..."
tar -czf "$OUT/storage.tgz" -C supabase/volumes storage 2>/dev/null || true
if [ -f "$OUT/storage.tgz" ]; then
  test -s "$OUT/storage.tgz" || { echo "empty storage archive" >&2; exit 1; }
fi

cat > "$OUT/manifest.txt" <<MANIFEST
created_at=$STAMP
database=$DB_NAME
database_dump=parking.dump
storage_archive=storage.tgz
notes=Keep .env separately; it is not part of this backup.
MANIFEST

echo "backup written to $OUT"
