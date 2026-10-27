#!/usr/bin/env sh
# Runs the Android app against the local Supabase stack over an adb reverse
# tunnel (no LAN IP, no firewall rule). Wireless adb drops the mapping when the
# device reconnects, so this script re-applies it on every launch.
#
#   sh tool/run-android.sh [serial]
#
# The anon key is read from $SUPABASE_ANON_KEY or from .env (ANON_KEY=...);
# the gateway port comes from $SUPABASE_PORT or .env API_GW_HTTP_PORT.
set -eu

SERIAL=${1:-$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}
[ -n "${SERIAL:-}" ] || { echo "No adb device found (adb devices)." >&2; exit 1; }

ANON_KEY=${SUPABASE_ANON_KEY:-}
if [ -z "$ANON_KEY" ] && [ -f .env ]; then
    ANON_KEY=$(grep -E '^ANON_KEY=' .env | cut -d= -f2-)
fi
[ -n "$ANON_KEY" ] || { echo "ANON_KEY missing (.env) or SUPABASE_ANON_KEY unset." >&2; exit 1; }

PORT=${SUPABASE_PORT:-}
if [ -z "$PORT" ] && [ -f .env ]; then
    PORT=$(grep -E '^API_GW_HTTP_PORT=' .env | cut -d= -f2-)
fi
PORT=${PORT:-8000}

adb -s "$SERIAL" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null
echo "adb reverse tcp:$PORT -> $SERIAL (localhost:$PORT on the phone)"

exec flutter run -d "$SERIAL" \
    --dart-define=SUPABASE_URL="http://localhost:$PORT" \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"
