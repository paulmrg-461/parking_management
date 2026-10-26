# Quickstart

One page, commands only. Full walkthroughs:
[`docs/environment-guide.en.md`](docs/environment-guide.en.md) (English) ·
[`docs/environment-guide.md`](docs/environment-guide.md) (español).

## 1. Prerequisites

- Docker Engine + Compose v2, `git`, `curl`, `python3`.
- Flutter **beta** (`^3.14.0-95.1.beta`; CI pins `3.49.0-0.1.pre`).
- Android SDK/emulator only for the mobile app.

## 2. Start the stack

```bash
cp .env.example .env
sh supabase/generate-env.sh
chmod 600 .env

docker compose up -d
docker compose logs --tail=20 supabase-migrate   # wait for "migrations up to date"

sh supabase/create-operator.sh admin 123456 admin
```

- App/Studio: <http://localhost:8000> (Studio user `supabase`, password =
  `DASHBOARD_PASSWORD` in `.env`).
- Read `ANON_KEY` from `.env` for the app build.

## 3. Run the app

```bash
flutter pub get

# Web
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>

# Android emulator (host is 10.0.2.2)
flutter run -d emulator-5554 \
  --dart-define=SUPABASE_URL=http://10.0.2.2:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>

# Physical phone over adb (USB or wireless): reverse the port and use localhost
adb reverse tcp:8000 tcp:8000
flutter run -d <serial> \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>
```

Log in with `admin` / `123456`.

## 4. Verify

```bash
flutter test
flutter analyze
sh supabase/healthcheck.sh
sh supabase/tests/e2e.sh
```

Manual: login → check-in → check-out → receipt → `/reports` → `/audit` → `/diagnostics`.

## 5. Integrations

Nothing is mandatory. In-app notifications work out of the box (Realtime).

| Want | Set |
|---|---|
| Android push | Firebase project, `FCM_SERVICE_ACCOUNT_JSON`, build with `FCM_ENABLED=true` + `FIREBASE_*` (free) |
| Browser push | `VAPID_*` in `.env`, build with `WEB_PUSH_VAPID_PUBLIC_KEY` (free, needs HTTPS or localhost) |
| Automated WhatsApp | Meta token + approved templates (`WHATSAPP_*`); billed per message |
| Manual WhatsApp | Nothing (`wa.me` from the app) |

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
