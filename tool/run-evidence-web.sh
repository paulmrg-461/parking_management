#!/usr/bin/env sh
# (Re)creates the public evidence/policies host after a Docker or host restart.
# Binds to the LAN IP by default because another local project owns
# 127.0.0.1:8080 on this machine.
#
#   sh tool/run-evidence-web.sh
#   EVIDENCE_BIND=0.0.0.0 EVIDENCE_PORT=8080 sh tool/run-evidence-web.sh
set -eu

cd "$(dirname "$0")/.."
BIND=${EVIDENCE_BIND:-$(ip route get 1.1.1.1 2>/dev/null | awk '{ print $7; exit }')}
BIND=${BIND:-192.168.0.17}
PORT=${EVIDENCE_PORT:-8080}

[ -f build/web-public/index.html ] || {
  echo "build/web-public is missing: run 'flutter build web --release --output build/web-public ...' first." >&2
  exit 1
}

docker rm -f parking-evidence-web >/dev/null 2>&1 || true
docker run -d --name parking-evidence-web \
  -p "$BIND:$PORT:80" \
  --restart unless-stopped \
  -v "$PWD/build/web-public:/usr/share/nginx/html:ro" \
  -v "$PWD/tool/evidence-web.nginx.conf:/etc/nginx/conf.d/default.conf:ro" \
  nginx:alpine >/dev/null

sleep 2
code=$(curl -s -o /dev/null -w '%{http_code}' "http://$BIND:$PORT/" || true)
echo "evidence web on http://$BIND:$PORT (HTTP ${code:-no response})"
[ "$code" = "200" ] || exit 1
