#!/usr/bin/env sh
# Runs the Android app against the local Supabase stack.
#
# Default: LAN mode (http://<host-ip>:<port>). Wireless adb only installs the
# APK; the app does not depend on the adb reverse tunnel, so a dropped adb
# connection or a new DHCP lease no longer breaks the app.
#
#   sh tool/run-android.sh [serial]                 # LAN (recommended)
#   ANDROID_MODE=localhost sh tool/run-android.sh   # adb reverse tunnel
#
# The anon key is read from $SUPABASE_ANON_KEY or .env (ANON_KEY=...); the
# gateway port comes from $SUPABASE_PORT or .env API_GW_HTTP_PORT.
set -eu

MODE=${ANDROID_MODE:-lan}
SERIAL=${1:-$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}
[ -n "${SERIAL:-}" ] || { echo "No adb device found. Run: sh tool/android-doctor.sh" >&2; exit 1; }

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

HOST_IP=${SUPABASE_HOST:-$(ip route get 1.1.1.1 2>/dev/null | awk '{ print $7; exit }')}
HOST_IP=${HOST_IP:-192.168.0.17}

if [ "$MODE" = "localhost" ]; then
    adb -s "$SERIAL" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null
    BASE_URL="http://localhost:$PORT"
    echo "mode=localhost (adb reverse tcp:$PORT -> $SERIAL)"
else
    BASE_URL="http://$HOST_IP:$PORT"
    echo "mode=lan url=$BASE_URL"
    if ! curl -fsS -o /dev/null -H "apikey: $ANON_KEY" "$BASE_URL/auth/v1/health"; then
        echo "WARN: $BASE_URL is not healthy from this host (docker compose up -d?)." >&2
    fi
    if adb -s "$SERIAL" shell "toybox nc -w 2 -z $HOST_IP $PORT" >/dev/null 2>&1; then
        echo "device can reach $HOST_IP:$PORT"
    else
        echo "WARN: the device cannot reach $HOST_IP:$PORT." >&2
        echo "      Check the same Wi-Fi, UFW (Docker usually bypasses it) and" >&2
        echo "      that the gateway is published on 0.0.0.0:$PORT." >&2
    fi
fi

exec flutter run -d "$SERIAL" \
    --dart-define=SUPABASE_URL="$BASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"
