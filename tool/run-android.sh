#!/usr/bin/env sh
# Runs the Android app against the local Supabase stack over an adb reverse
# tunnel (no LAN IP, no firewall rule). Wireless adb drops the mapping when the
# device reconnects, so this script re-applies it on every launch.
#
#   sh tool/run-android.sh [serial]
#
# The anon key is read from $SUPABASE_ANON_KEY or from .env (ANON_KEY=...).
set -eu

SERIAL=${1:-$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}
[ -n "${SERIAL:-}" ] || { echo "No adb device found (adb devices)." >&2; exit 1; }

ANON_KEY=${SUPABASE_ANON_KEY:-}
if [ -z "$ANON_KEY" ] && [ -f .env ]; then
    ANON_KEY=$(grep -E '^ANON_KEY=' .env | cut -d= -f2-)
fi
[ -n "$ANON_KEY" ] || { echo "ANON_KEY missing (.env) or SUPABASE_ANON_KEY unset." >&2; exit 1; }

adb -s "$SERIAL" reverse tcp:8000 tcp:8000 >/dev/null
echo "adb reverse tcp:8000 -> $SERIAL (localhost:8000 on the phone)"

exec flutter run -d "$SERIAL" \
    --dart-define=SUPABASE_URL=http://localhost:8000 \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"
