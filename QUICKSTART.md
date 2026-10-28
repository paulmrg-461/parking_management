# Quickstart

One page, commands only. Full walkthrough:
[`docs/environment-guide.en.md`](docs/environment-guide.en.md) (English) ·
[`docs/environment-guide.md`](docs/environment-guide.md) (español).

## 1. Prerequisites

- Docker Engine + Compose v2, `git`, `curl`, `python3`.
- Flutter **beta** (`^3.14.0-95.1.beta`; CI pins `3.49.0-0.1.pre`).
- Android SDK / device only for the mobile app.

## 2. Start the stack

```bash
cp .env.example .env
sh supabase/generate-env.sh
chmod 600 .env

docker compose up -d
docker compose logs --tail=20 supabase-migrate   # wait for "migrations up to date"

sh supabase/create-operator.sh admin 123456 admin
```

The gateway port and public URLs live in `.env`:

```dotenv
API_GW_HTTP_PORT=8000          # this workspace uses 8017; change all four
SUPABASE_PUBLIC_URL=http://localhost:8000
API_EXTERNAL_URL=http://localhost:8000/auth/v1
SITE_URL=http://localhost:8000
```

After changing the port: `docker compose up -d --force-recreate api-gw auth`.

- Gateway/Studio: `http://localhost:$PORT` (Studio user `supabase`, password =
  `DASHBOARD_PASSWORD` in `.env`).
- Postgres (Supavisor): `localhost:5432`, database `parking`.

## 3. Run the app

```bash
flutter pub get

PORT=$(grep -E '^API_GW_HTTP_PORT=' .env | cut -d= -f2-)
ANON=$(grep -E '^ANON_KEY=' .env | cut -d= -f2-)

# Web
flutter run -d chrome \
  --dart-define=SUPABASE_URL="http://localhost:$PORT" \
  --dart-define=SUPABASE_ANON_KEY="$ANON"

# Physical phone over adb (USB or wireless): the script reverses the port
# and runs Flutter against localhost, so no firewall or LAN IP is involved.
sh tool/run-android.sh

# Emulator (the host is 10.0.2.2)
flutter run -d emulator-5554 \
  --dart-define=SUPABASE_URL="http://10.0.2.2:$PORT" \
  --dart-define=SUPABASE_ANON_KEY="$ANON"
```

Log in with `admin` / `123456` (or the PIN you chose).

## 4. Verify

```bash
flutter test
flutter analyze
sh supabase/healthcheck.sh
sh supabase/tests/e2e.sh
```

Manual: login → check-in (ticket with QR + Imprimir) → vehicles inside →
scan the QR / “Mark exit” → payment → `/reports` → `/audit` → `/diagnostics`.

## 5. Troubleshooting

| Symptom | Fix |
|---|---|
| Phone says it cannot reach the server | `adb reverse --list`; if empty run `adb reverse tcp:$PORT tcp:$PORT` (or `sh tool/run-android.sh`). Wireless adb drops it on every reconnect. |
| `curl http://localhost:$PORT/rest/v1/` returns 401 | Expected: the gateway is up and needs an API key. |
| Login fails with invalid credentials | Create the kiosk user (`sh supabase/create-operator.sh ...`) and check the app points at this stack. |
| Port changed | Update the four `.env` values, recreate `api-gw`/`auth` and rebuild the app. |
| Emulator cannot connect | Use `10.0.2.2:$PORT`, not `localhost`. |

## 6. Stop / reset

```bash
docker compose down       # stop, keep data
docker compose down -v    # stop and DELETE local data
```

## 7. More

- Full local guide: [`docs/setup-local.md`](docs/setup-local.md)
- Cloud/production: [`docs/setup-cloud.md`](docs/setup-cloud.md)
- Backups + restore drill: [`docs/runbook-restore.md`](docs/runbook-restore.md)
- Secrets/PIN rotation: [`docs/runbook-secrets.md`](docs/runbook-secrets.md)
- Data model and RPCs: [`docs/database.md`](docs/database.md)
