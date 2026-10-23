#!/bin/sh
# Human-readable operational snapshot (see diagnostics.sql).
set -eu
cd "$(dirname "$0")/.."

getenv() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2-; }
db=$(getenv POSTGRES_DB); db=${db:-parking}

docker compose exec -T db psql -U postgres -d "$db" -f - < supabase/diagnostics.sql
