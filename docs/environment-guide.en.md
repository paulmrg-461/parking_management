# Environment guide: Docker, Supabase, mobile and web

Practical guide to run the whole system on your machine. Spanish version:
[`environment-guide.md`](environment-guide.md) · Command cheat sheet:
[`../QUICKSTART.md`](../QUICKSTART.md). Short version: **yes,
everything runs locally for free**. You only pay when you publish it or when you
enable external integrations (automated WhatsApp, real push, app stores).

There is no application server: the Supabase stack (Docker) plus the Flutter app
is everything. Business rules live in PostgreSQL (SQL functions); Edge Functions
only cover admin users, evidence archival and message delivery.

---

## 1. What you are running

| Piece | What it is | Runs in |
|---|---|---|
| PostgreSQL 17 + RLS + RPCs | Database, permissions and business logic | Docker |
| GoTrue | Username + PIN login (JWT) | Docker |
| PostgREST | REST API and `rpc/*` | Docker |
| Storage | Evidence photos and logo | Docker |
| Realtime | Live in-app notifications | Docker |
| Edge Functions | `admin-users`, `push-dispatch`, `evidence-archive`, `whatsapp-dispatch` | Docker |
| Studio | Database web UI | Docker, same URL |
| Envoy | Single entry point (`:8000`) | Docker |
| Flutter app | Android + Web (same code) | Your machine / emulator / browser |

`docker compose` orchestrates everything; migrations in `supabase/migrations`
are applied automatically.

---

## 2. Requirements

### Machine

- 4 GB free RAM (8 GB if you also run an Android emulator).
- ~8 GB disk for images, database and builds.
- Linux, macOS, or Windows via WSL2. On Arch/Manjaro:

```bash
sudo pacman -S --needed docker docker-compose git curl python3 unzip
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"   # log out and back in
```

> On Linux you use **Docker Engine**, which is free. Docker Desktop is also free
> for personal use and small businesses; on Linux you do not need it.

### Flutter and Android

- Flutter on the **beta** channel (`pubspec.yaml` requires
  `^3.14.0-95.1.beta`; CI pins `3.49.0-0.1.pre`, 3.50 beta works locally).
- Android SDK + an emulator (or a USB-debugging phone) only for the mobile app.
  Not needed for web.

```bash
flutter channel beta
flutter upgrade
flutter doctor          # fix anything red (Android toolchain, etc.)
flutter emulators       # list; flutter emulators --launch <id>
```

---

## 3. Local setup (step by step)

### 3.1 Clone and generate secrets

```bash
git clone <repo> parking_management
cd parking_management

cp .env.example .env
sh supabase/generate-env.sh
```

`generate-env.sh` fills passwords and keys (Postgres, JWT, `ANON_KEY`,
`SERVICE_ROLE_KEY`, Storage, Studio password). It is safe to re-run: it keeps
values that already look real.

Protect `.env` (never committed):

```bash
chmod 600 .env
```

Values you will need from `.env`:

| Key | Used for |
|---|---|
| `ANON_KEY` | Building the app against your local Supabase |
| `SERVICE_ROLE_KEY` | Server/cron only; **never** in the app |
| `DASHBOARD_PASSWORD` | Studio login (`user: supabase`) |
| `SUPABASE_PUBLIC_URL` | `http://localhost:8000` by default |

### 3.2 Start the stack

```bash
docker compose up -d
docker compose ps            # wait until db/auth/rest/storage/realtime are healthy
```

The first run pulls images (several minutes). Once the database and GoTrue are
healthy, the one-shot `supabase-migrate` container applies the schema:

```bash
docker compose logs --tail=20 supabase-migrate
# ... "migrations up to date"
```

After adding migrations later:

```bash
docker compose up -d supabase-migrate && docker compose logs --tail=5 supabase-migrate
```

### 3.3 Create your administrator

```bash
sh supabase/create-operator.sh admin 123456 admin
```

- Stored as `admin@parking.local` in GoTrue; the PIN is the password (6 digits).
- Sign in with **user `admin`, PIN `123456`**.
- Change that PIN before using real data: `/users` in the app or
  `sh supabase/rotate-pin.sh admin <new-pin>`.

### 3.4 Studio (optional, to inspect the database)

Open <http://localhost:8000>:

- user: `supabase`
- password: the generated one (`DASHBOARD_PASSWORD` in `.env`).

### 3.5 Run the web app

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY from .env>
```

The `ANON_KEY` is public (it ships in the binary); `SERVICE_ROLE_KEY` is a
secret and must never be in the app.

### 3.6 Run the Android app

**Emulator** (the host is `10.0.2.2`, not `localhost`):

```bash
flutter emulators --launch <emulator-id>
flutter run -d emulator-5554 \
  --dart-define=SUPABASE_URL=http://10.0.2.2:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>
```

**Physical phone on the same Wi-Fi:**

1. `ip addr` (or `ipconfig`) to find your machine IP, e.g. `192.168.1.50`.
2. `flutter run -d <device> --dart-define=SUPABASE_URL=http://192.168.1.50:8000 --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>`.
3. If it cannot connect, allow port 8000 in the machine firewall.

**Debug** builds allow cleartext HTTP (the debug `AndroidManifest` enables it).
**Release** builds require HTTPS.

### 3.7 Production builds

```bash
# Static web (any host; use HTTPS in production)
flutter build web --release \
  --dart-define=SUPABASE_URL=https://your-domain.com \
  --dart-define=SUPABASE_ANON_KEY=<production ANON_KEY>

# Android (needs your keystore, see android/key.properties)
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://your-domain.com \
  --dart-define=SUPABASE_ANON_KEY=<production ANON_KEY>
```

---

## 4. Verify it works

```bash
flutter test                 # 571 tests
flutter analyze              # only SDK deprecation infos from the beta channel
sh supabase/healthcheck.sh   # services, endpoints, backlog (exit 1 on failure)
sh supabase/tests/e2e.sh     # login → check-in → check-out → report → history
```

Minimal manual pass: log in → check a plate in → check it out with a payment →
open the receipt → `/reports` → `/audit` → `/diagnostics`.

SQL/RLS tests against a scratch database (optional):

```bash
PW=$(grep -E '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
docker exec supabase-db psql -U supabase_admin -d postgres -c "drop database if exists sql_test;"
docker exec supabase-db psql -U supabase_admin -d postgres -c "create database sql_test owner supabase_admin;"
docker run --rm --network parking_management_default -v "$PWD/supabase:/work" \
  -e PGHOST=supabase-db -e PGUSER=supabase_admin -e PGPASSWORD="$PW" \
  -e PGDATABASE=sql_test postgres:17-alpine sh -c "cd /work && sh tests/run.sh"
docker exec supabase-db psql -U supabase_admin -d postgres -c "drop database if exists sql_test;"
```

---

## 5. Integrations: what is mandatory and what is not

**Mandatory: nothing.** Without any integration the app is complete: login,
check-in/out, billing, shifts, reports, passes, reservations, audit.

| Integration | Needed? | Free | Requires |
|---|---|---|---|
| **In-app** notifications (bell + inbox) | No, already works | Yes | Nothing: local Realtime |
| **Android push** (FCM, app closed) | No | Yes (free tier) | Firebase project + credentials + build with `FCM_ENABLED=true` |
| **Browser push** (VAPID, tab closed) | No | Yes | VAPID key pair and build-time public key; HTTPS or localhost |
| **Manual WhatsApp** (`wa.me`) | No | Yes | Nothing; opens WhatsApp on the operator's phone |
| **Automated WhatsApp** (Meta Cloud API) | No | **No** | Meta account, token, sender number, approved templates; per-message billing |
| Bluetooth thermal printing | No | Yes | Bluetooth printer + Android permission |
| Plate OCR | No | Yes | Android only (on-device ML Kit) |

### "I do not want notifications yet"

Configure no push at all:

- Leave `FCM_SERVICE_ACCOUNT_JSON` and `VAPID_*` empty in `.env`.
- Do not build with `FCM_ENABLED=true` or `WEB_PUSH_VAPID_PUBLIC_KEY`.
- `push-dispatch` and `whatsapp-dispatch` return `{configured:false}` and do
  nothing; the cron can keep running harmlessly.

The bell and `/notifications` inbox still work through **Realtime**, with no
cost or configuration. Pass-expiry, overstay and shift-close alerts are still
generated and visible in the app.

> If you later want push, Android/FCM is the cheapest path (free). Browser push
> needs HTTPS (or `localhost`) because service workers require a secure origin;
> it will not work on a LAN IP over HTTP.

---

## 6. Is all of this free locally?

**Yes.** Locally there are no licenses or service fees:

| Resource | Local cost |
|---|---|
| Docker Engine + images (Postgres, GoTrue, PostgREST, Storage, Realtime, Envoy, Studio) | $0 (open source) |
| Flutter + Android SDK | $0 |
| Database, Storage, Functions | $0 (your machine) |
| In-app push | $0 |
| Manual WhatsApp (`wa.me`) | $0 |

You spend hardware, disk and time. Real costs appear when publishing:

### Approximate production costs (USD; check current prices)

| Item | Range | Notes |
|---|---|---|
| VM for the stack (2 vCPU / 4 GB / 40 GB) | **$5–20 / month** | Hetzner/DigitalOcean/Vultr; the full stack fits in 4 GB |
| Domain | **$10–15 / year** | Needed for HTTPS with Let's Encrypt |
| Off-site backups | **$1–5 / month** | Extra object storage or `rclone` to another provider |
| Google Play (Android release) | **$25 one-time** | Optional if you sideload via MDM |
| Firebase (FCM) | **$0** | Spark plan is enough for notifications |
| VAPID (web push) | **$0** | You only generate keys |
| WhatsApp Cloud API (automated) | **Variable** | Meta bills per message/template by country and category; can start at cents. Requires a business account and approved templates |
| Supabase Cloud (instead of a VM) | **$0 free / ~$25+ per month pro** | This repo targets self-hosting; Cloud needs migration/function adaptation |
| Static web hosting (without the VM) | **$0** on Netlify/Cloudflare Pages | The API must still be HTTPS |

For **one site, internal use**, the realistic minimum is: $5–10/month VM +
domain + backups = **~$10–15/month**, with $0 in integrations if you skip
automated WhatsApp.

---

## 7. Common problems

| Symptom | Cause / fix |
|---|---|
| `Supabase is required` at startup | Missing `--dart-define=SUPABASE_URL` / `SUPABASE_ANON_KEY`. |
| Android emulator cannot connect | Use `10.0.2.2`, not `localhost`. |
| Physical phone cannot connect | Same Wi-Fi, your machine IP, port 8000 open in the firewall. |
| `PGRST202` function not found | Migration applied after PostgREST cached the schema: wait a few seconds or `docker compose restart rest`. |
| `migrations up to date` but a table is missing | That file is already recorded; add a **new** migration instead of editing an applied one. |
| 401 after changing `.env` | Rebuild the app with the current `ANON_KEY`. |
| Studio asks for a password | It is `DASHBOARD_PASSWORD` in `.env`. |
| Web push never appears | Needs HTTPS (or `localhost`) and a build with `WEB_PUSH_VAPID_PUBLIC_KEY`. |
| Everything broken after experimenting | `docker compose down -v` drops local data; repeat 3.1–3.3. |

---

## 8. Command cheat sheet

```bash
# Stack
docker compose up -d                     # start
docker compose ps                        # status
docker compose logs -f rest auth         # logs
docker compose restart functions         # after editing an Edge Function
docker compose up -d supabase-migrate    # apply new migrations
docker compose down                      # stop (keeps data)
docker compose down -v                   # stop and DELETE local data

# Data
docker exec -it supabase-db psql -U supabase_admin -d parking
sh supabase/backup.sh
RESTORE_CONFIRM=yes sh supabase/restore.sh backups/<stamp>
sh supabase/restore-drill.sh             # prove the backup restores

# Users
sh supabase/create-operator.sh <user> <pin> [admin|operator]
sh supabase/rotate-pin.sh <user> <new-pin>

# App
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=http://localhost:8000 --dart-define=SUPABASE_ANON_KEY=<ANON>
flutter run -d emulator-5554 --dart-define=SUPABASE_URL=http://10.0.2.2:8000 --dart-define=SUPABASE_ANON_KEY=<ANON>

# Quality and operations
flutter test
flutter analyze
sh supabase/healthcheck.sh
sh supabase/diagnostics.sh
sh supabase/tests/e2e.sh
sh supabase/check-secrets.sh
```

---

## 9. When to move to the cloud

When you need access outside your network, several operators, or serious
backups:

1. Follow [`setup-cloud.md`](setup-cloud.md): VM + Docker + Caddy/Nginx with TLS.
2. Set up backups and the monthly drill ([`runbook-restore.md`](runbook-restore.md)).
3. Review secrets and PINs ([`runbook-secrets.md`](runbook-secrets.md)).
4. Only if you want automated notices, add FCM (free) and/or Meta WhatsApp
   (billed per message).

Technical details: [`architecture.md`](architecture.md),
[`infrastructure.md`](infrastructure.md), [`database.md`](database.md).
