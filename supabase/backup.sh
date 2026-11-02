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
# Validate the archive before declaring the backup usable.
docker compose exec -T db pg_restore --list < "$OUT/parking.dump" >/dev/null \
  || { echo "database dump failed pg_restore --list" >&2; exit 1; }

echo "archiving storage..."
tar -czf "$OUT/storage.tgz" -C supabase/volumes storage 2>/dev/null || true
if [ -f "$OUT/storage.tgz" ]; then
  test -s "$OUT/storage.tgz" || { echo "empty storage archive" >&2; exit 1; }
fi

(cd "$OUT" && sha256sum parking.dump storage.tgz 2>/dev/null > SHA256SUMS) \
  || echo "WARN: could not write SHA256SUMS" >&2

cat > "$OUT/manifest.txt" <<MANIFEST
created_at=$STAMP
database=$DB_NAME
database_dump=parking.dump
storage_archive=storage.tgz
notes=Keep .env separately; it is not part of this backup.
checksums=SHA256SUMS (verify with: sha256sum -c SHA256SUMS)
MANIFEST

# Optional retention: BACKUP_KEEP=14 keeps the newest 14 archives.
KEEP=${BACKUP_KEEP:-0}
case "$KEEP" in
  ''|*[!0-9]*) echo "WARN: BACKUP_KEEP must be a number, skipping pruning" >&2 ;;
  *)
    if [ "$KEEP" -gt 0 ]; then
      ls -1dt backups/*/ 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
        case "$old" in
          backups/*) echo "pruning $old"; rm -rf "$old" ;;
        esac
      done
    fi
    ;;
esac

echo "backup written to $OUT"
