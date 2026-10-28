#!/bin/sh
# Deletes evidence photos past each site's retention window
# (`parking_settings.evidence_retention_days`, 0 = keep forever).
#
#   sh supabase/evidence-archive.sh            # real run
#   DRY_RUN=1 sh supabase/evidence-archive.sh  # report only
#   DAYS=30 sh supabase/evidence-archive.sh    # override every site
#
# Cron example (daily, after the backup):
#   40 3 * * * cd /opt/parking && sh supabase/evidence-archive.sh >> /var/log/parking-evidence.log 2>&1
#
# Run a backup first when shrinking a retention window: the daily dump +
# storage tar in `supabase/backup.sh` is the archive of record.
set -eu

cd "$(dirname "$0")/.."

getenv() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2-; }
api=${SUPABASE_PUBLIC_URL:-$(getenv SUPABASE_PUBLIC_URL)}
api=${api:-http://localhost:8000}
service=${SERVICE_ROLE_KEY:-$(getenv SERVICE_ROLE_KEY)}

[ -n "$service" ] || { echo "missing SERVICE_ROLE_KEY in .env" >&2; exit 2; }

query=""
if [ "${DRY_RUN:-0}" = "1" ]; then query="dry_run=true"; fi
if [ -n "${DAYS:-}" ]; then
  query="${query:+$query&}days=$DAYS"
fi

url="$api/functions/v1/evidence-archive"
[ -n "$query" ] && url="$url?$query"

curl -fsS -X POST "$url" -H "Authorization: Bearer $service"
echo
