# Local setup (from zero)

Target: a laptop with the full stack (database, auth, API, storage, functions)
and the Flutter app talking to it. Everything runs in Docker; the app runs on
the host.

Tested on Linux. Windows users should run the shell scripts under WSL2.

## 1. Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Docker Engine + Compose v2 | 24+ / v2.20+ | `docker compose version` must work. |
| Flutter | the SDK pinned in `.github/workflows/ci.yml` (`3.49.0-0.1.pre`, beta channel) | Dart `^3.14.0-95.1.beta` per `pubspec.yaml`. |
| Android SDK | API 34+ | Only for running on a device/emulator. |
| `python3`, `openssl`, `curl`, `sh` | any recent | Used by the helper scripts. |

Disk: ~6 GB for images, plus DB/storage growth. Memory: 4 GB free is
comfortable (8 GB if you also run an Android emulator).

## 2. Clone and generate secrets

```bash
git clone <repo> parking_management
cd parking_management

cp .env.example .env
sh supabase/generate-env.sh
```

`generate-env.sh` fills every placeholder secret (Postgres password, JWT
secret, anon/service keys, storage keys, …) and is safe to re-run: it keeps
values that already look real. The resulting `.env` is **never committed**.

Required values it sets for the app:

- `SUPABASE_PUBLIC_URL` (used by the helper scripts, normally
  `http://localhost:8000`; the port comes from `API_GW_HTTP_PORT` and must
  match `API_EXTERNAL_URL`/`SITE_URL`. This workspace uses **8017**.)
- `ANON_KEY`, `SERVICE_ROLE_KEY`
- `POSTGRES_PASSWORD`, `POSTGRES_DB` (default `parking`)

Optional integrations (leave empty to disable):

- `FCM_SERVICE_ACCOUNT_JSON` (Android background push)
- `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (browser push)

## 3. Start the stack

```bash
docker compose up -d
docker compose ps          # wait until db/auth/rest/storage/realtime are healthy
```

What comes up (details in [`infrastructure.md`](infrastructure.md)):

- **Envoy gateway** on `http://localhost:8000` — the only entry point the app needs.
- **Studio** at the same address (open it in a browser).
- **PostgreSQL 17** on `localhost:5432` (and the pooler on `6543`).
- **Edge Functions** container with `admin-users` and `push-dispatch`.

The one-shot `supabase-migrate` container applies `supabase/migrations/*.sql`
in order after the database and GoTrue are healthy:

```bash
docker compose logs --tail=20 supabase-migrate
# ... "migrations up to date"
```

To re-apply after adding a migration:

```bash
docker compose up -d supabase-migrate && docker compose logs --tail=5 supabase-migrate
```

`supabase/migrate.sh` records applied files in `public.schema_migrations`, so
each migration runs exactly once (they are **not** idempotent by design; write
new files instead of editing old ones).

## 4. Create the first admin

```bash
sh supabase/create-operator.sh admin 123456 admin
```

- PINs are 6 digits (GoTrue treats them as passwords).
- The username becomes `admin@parking.local` in GoTrue; `public.users` is
  filled by the `auth.users` trigger, and the user joins the `default` lot.
- Additional users can be created from the app (`/users`) once you are in.

Log in with `admin` / `123456`. The app forces a 6-digit PIN everywhere.

## 5. Run the Flutter app

Read the configured port and key once per terminal:

```bash
PORT=$(grep -E '^API_GW_HTTP_PORT=' .env | cut -d= -f2-)
ANON=$(grep -E '^ANON_KEY=' .env | cut -d= -f2-)
```

**Web (fastest loop):**

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL="http://localhost:$PORT" \
  --dart-define=SUPABASE_ANON_KEY="$ANON"
```

**Android emulator** (the host is `10.0.2.2`, not `localhost`):

```bash
flutter run -d emulator-5554 \
  --dart-define=SUPABASE_URL="http://10.0.2.2:$PORT" \
  --dart-define=SUPABASE_ANON_KEY="$ANON"
```

**Physical Android device over adb (USB or wireless):**

```bash
sh tool/run-android.sh        # reverses API_GW_HTTP_PORT and runs Flutter
```

No LAN IP or firewall rule is involved; the app uses `http://localhost:<port>`
through the reverse tunnel. Wireless adb reconnects drop the tunnel: rerun the
script (or `adb reverse tcp:$PORT tcp:$PORT`). If you prefer the LAN, pass
`http://<laptop-ip>:$PORT` and add it to `API_EXTERNAL_URL`/`SITE_URL` in
`.env` for Studio redirects. Android release builds require HTTPS (see
[`setup-cloud.md`](setup-cloud.md)).

Optional dart-defines: `APP_NAME`, `FCM_ENABLED` + `FIREBASE_*`,
`FCM_VAPID_KEY`, `WEB_PUSH_VAPID_PUBLIC_KEY`.

Without `SUPABASE_URL`/`SUPABASE_ANON_KEY` the app fails fast at startup by
design (`configureDependencies()` throws).

## 6. Run the tests

```bash
flutter test
flutter analyze          # only SDK deprecation infos are expected on beta
flutter build web --release
```

SQL/RLS/RPC suite (real Postgres, applies every migration):

```bash
PW=$(grep -E '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
docker exec supabase-db psql -U supabase_admin -d postgres -c "drop database if exists sql_test;"
docker exec supabase-db psql -U supabase_admin -d postgres -c "create database sql_test owner supabase_admin;"
docker run --rm --network parking_management_default -v "$PWD/supabase:/work" \
  -e PGHOST=supabase-db -e PGUSER=supabase_admin -e PGPASSWORD="$PW" \
  -e PGDATABASE=sql_test postgres:17-alpine sh -c "cd /work && sh tests/run.sh"
```

The suite runs inside one transaction and rolls back, so it is safe to point at
a scratch database. CI does exactly this against `supabase/postgres`.

End-to-end against the running stack (login → check-in → check-out → report →
history), both at the API level and through the Dart client the app uses:

```bash
sh supabase/tests/e2e.sh

SUPABASE_URL=http://localhost:8000 \
SUPABASE_ANON_KEY=$(grep '^ANON_KEY=' .env | cut -d= -f2-) \
flutter test test/integration
```

Both create a unique `E2E…` plate per run; delete test rows from the database
if you care about a clean local dataset.

## 7. Day-to-day commands

```bash
# rebuild/restart one service after editing it
docker compose restart functions        # Edge Functions
docker compose restart                  # everything

# follow logs
docker compose logs -f rest auth

# open a psql shell
docker exec -it supabase-db psql -U supabase_admin -d parking

# stop but keep data
docker compose down
# stop and DELETE local data/images volumes
docker compose down -v
```

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| App throws `Supabase is required` | Missing `--dart-define=SUPABASE_URL` / `SUPABASE_ANON_KEY`. |
| `PGRST202` “function not found” | The migration was applied after PostgREST cached the schema; wait a few seconds or `docker compose restart rest`. |
| `migrations up to date` but a table is missing | The file name was already recorded in `schema_migrations`; add a **new** migration instead of editing an old one. |
| Android emulator cannot reach the API | Use `10.0.2.2` instead of `localhost`. |
| 401 from the app after login | `.env` keys changed after the app was built; rebuild with the current `ANON_KEY`. |
| `docker compose up` fails on `.env` | `cp .env.example .env && sh supabase/generate-env.sh`. |
| Studio loads but the app does not | Studio goes through the gateway too; the app only needs the gateway port (`API_GW_HTTP_PORT`, e.g. `:8017`). |
| Push never arrives | In-app notifications work through Realtime; background push needs FCM/VAPID credentials. |
| PIN rejected on create | PINs must be exactly 6 digits (`PASSWORD_MIN_LENGTH=6`). |

## 9. Resetting the local system

```bash
docker compose down -v          # drops containers, volumes and local data
rm .env && cp .env.example .env && sh supabase/generate-env.sh
docker compose up -d
sh supabase/create-operator.sh admin 123456 admin
```

Storage objects live under `supabase/volumes/storage`; the database under the
Docker volume. Both are removed by `down -v`.
