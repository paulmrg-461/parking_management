#!/usr/bin/env sh
# One command for the local demo: database + API, public web host, Chrome dev
# app and (when a phone is connected) the LAN APK.
#
#   sh tool/dev-up.sh
#   ANDROID=0 sh tool/dev-up.sh          # web only
#   ANDROID_BUILD=1 sh tool/dev-up.sh    # rebuild the APK first
#
# The phone build points at http://<host-ip>:8017 (LAN), so it keeps working
# after adb drops; adb is only needed to install it.
set -eu

cd "$(dirname "$0")/.."
ANON=$(grep -E '^ANON_KEY=' .env | cut -d= -f2-)
PORT=$(grep -E '^API_GW_HTTP_PORT=' .env | cut -d= -f2-)
PORT=${PORT:-8000}
HOST_IP=${SUPABASE_HOST:-$(ip route get 1.1.1.1 2>/dev/null | awk '{ print $7; exit }')}
HOST_IP=${HOST_IP:-192.168.0.17}
API="http://$HOST_IP:$PORT"
LOG=${WEB_LOG:-/tmp/opencode/flutter-web.log}

echo "== stack"
docker compose up -d >/dev/null
docker compose up -d supabase-migrate >/dev/null 2>&1 || true

echo "== waiting for the API at $API"
i=0
until curl -fsS -o /dev/null -H "apikey: $ANON" "$API/auth/v1/health"; do
  i=$((i + 1))
  [ "$i" -lt 60 ] || { echo "API did not become healthy; see docker compose logs" >&2; exit 1; }
  sleep 2
done
echo "api: ok"

echo "== public web host"
sh tool/run-evidence-web.sh

if ps aux | grep "flutter_tools.snapshot run -d chr[o]me" | grep -v grep >/dev/null; then
  echo "chrome dev app: already running (log: $LOG)"
else
  mkdir -p "$(dirname "$LOG")"
  setsid nohup flutter run -d chrome \
    --dart-define=SUPABASE_URL="http://localhost:$PORT" \
    --dart-define=SUPABASE_ANON_KEY="$ANON" \
    --dart-define=APP_URL="$API" >"$LOG" 2>&1 </dev/null &
  echo "chrome dev app: starting (log: $LOG)"
fi

SERIAL=$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')
if [ "${ANDROID:-1}" = "1" ] && [ -n "${SERIAL:-}" ]; then
  APK=build/app/outputs/flutter-apk/app-release.apk
  [ -f "$APK" ] || APK=build/app/outputs/flutter-apk/app-debug.apk
  if [ "${ANDROID_BUILD:-0}" = "1" ] || [ ! -f "$APK" ]; then
    echo "== building the Android APK"
    flutter build apk --debug \
      --dart-define=SUPABASE_URL="$API" \
      --dart-define=SUPABASE_ANON_KEY="$ANON" \
      --dart-define=APP_URL="$API" | tail -1
    APK=build/app/outputs/flutter-apk/app-debug.apk
  fi
  echo "== installing $APK on $SERIAL"
  adb -s "$SERIAL" install -r "$APK" >/dev/null
  adb -s "$SERIAL" shell am force-stop pro.devpaul.parking_management
  adb -s "$SERIAL" shell am start -n pro.devpaul.parking_management/.MainActivity >/dev/null
  echo "android: running on $SERIAL (LAN $API)"
elif [ "${ANDROID:-1}" = "1" ]; then
  echo "android: no adb device; enable Wireless debugging and rerun" >&2
fi

echo
echo "web (LAN):   http://$HOST_IP:8080"
echo "api:         $API"
echo "login:       admin / 123456"
