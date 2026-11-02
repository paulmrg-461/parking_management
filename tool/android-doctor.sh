#!/usr/bin/env sh
# Prints everything needed to diagnose "the phone cannot reach the app".
# Read-only: it never changes adb, firewall or network settings.
set -eu

cd "$(dirname "$0")/.."
ANON=$(grep -E '^ANON_KEY=' .env 2>/dev/null | cut -d= -f2- || true)
PORT=$(grep -E '^API_GW_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || true)
PORT=${PORT:-8000}
HOST_IP=${SUPABASE_HOST:-$(ip route get 1.1.1.1 2>/dev/null | awk '{ print $7; exit }')}
HOST_IP=${HOST_IP:-192.168.0.17}

echo "== host"
echo "ip=$HOST_IP gateway=$(ip route | awk '/default/ { print $3; exit }')"
ping -c 1 -W 1 "$(ip route | awk '/default/ { print $3; exit }')" >/dev/null 2>&1 \
  && echo "gateway: reachable" || echo "gateway: UNREACHABLE"
curl -fsS -o /dev/null -H "apikey: $ANON" "http://localhost:$PORT/auth/v1/health" \
  && echo "api localhost:$PORT: ok" || echo "api localhost:$PORT: FAIL"
curl -fsS -o /dev/null -H "apikey: $ANON" "http://$HOST_IP:$PORT/auth/v1/health" \
  && echo "api $HOST_IP:$PORT: ok" || echo "api $HOST_IP:$PORT: FAIL"

echo "== adb"
adb devices
adb mdns services 2>/dev/null | sed -n '2,6p' || true
SERIAL=$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')
if [ -z "${SERIAL:-}" ]; then
  echo "no device: enable Wireless debugging (or plug USB) and retry."
  exit 0
fi
echo "serial=$SERIAL"
echo "device ip: $(adb -s "$SERIAL" shell "ip -4 addr show wlan0 2>/dev/null | grep -o 'inet [0-9.]*' | head -1" 2>/dev/null | tr -d '\r')"
adb -s "$SERIAL" shell "dumpsys wifi | grep -m1 -i 'Wi-Fi is'" 2>/dev/null | tr -d '\r' || true
adb -s "$SERIAL" reverse --list 2>/dev/null || true
adb -s "$SERIAL" shell "ping -c 1 -W 1 $HOST_IP >/dev/null 2>&1" \
  && echo "device -> host ping: ok" || echo "device -> host ping: FAIL"
adb -s "$SERIAL" shell "toybox nc -w 2 -z $HOST_IP $PORT" >/dev/null 2>&1 \
  && echo "device -> $HOST_IP:$PORT: ok" || echo "device -> $HOST_IP:$PORT: FAIL"
echo
echo "Common fixes:"
echo "  * LAN mode: sh tool/run-android.sh (no adb reverse needed)."
echo "  * Wireless adb: it changes port/IP on every reconnect; use the mDNS"
echo "    entry from 'adb devices' or reconnect from the phone's dialog."
echo "  * localhost mode only works while 'adb reverse' is applied."
