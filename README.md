# Parking Management

Offline-first parking management system: vehicle check-in/check-out, time-based
billing (hourly/daily/nightly rates, per-day caps), vehicle categories, monthly
passes, evidence photos, license-plate OCR scanning, and admin revenue/occupancy
reports.

- `backend/` — FastAPI + PostgreSQL (source of truth)
- `lib/` — Flutter app (Android + Web), Hive-backed offline cache + sync outbox
- `openspec/` — specs and change history (spec-driven development via
  [OpenSpec](https://github.com/openspec-org/openspec)); see `PROGRESS.md` for
  a capability-by-capability changelog

Architecture: Hexagonal (Ports & Adapters) + Clean Architecture, organized by
feature, on both sides of the stack. See `AGENTS.md` for the full conventions.

## Quickstart with Docker Compose

Brings up **self-hosted Supabase** (Postgres, Auth, PostgREST, Storage,
Studio), the FastAPI backend and Redis. Supabase migrations run automatically
via the `supabase-migrate` service.

```bash
cp .env.example .env
sh supabase/generate-env.sh   # generates the stack secrets (never printed)
docker compose up --build
```

| Service | URL |
|---|---|
| FastAPI (transitional app API) | `http://localhost:8000` (`/docs`, `/api/health`) |
| Supabase Studio | `http://localhost:8001` |
| Supabase REST/Auth | `http://localhost:8001/rest/v1`, `http://localhost:8001/auth/v1` |
| Postgres (Supavisor) | `localhost:5432`, database `parking` |

Supabase Auth is the target identity provider. Create the first admin in GoTrue
(the `auth.users` trigger mirrors the profile into `public.users`):

```bash
sh supabase/create-operator.sh admin 123456 admin
```

The PIN is the GoTrue password for `admin@parking.local`; the kiosk keeps
asking for username + PIN, but in Supabase mode it must be **6 digits**
(GoTrue clamps the minimum to 6). The legacy PIN endpoint still works during
the transition. Default categories are seeded by `supabase/migrations`.

> The migration is phased (see `openspec/changes/migrate-to-supabase/`):
> Supabase runs alongside FastAPI today; billing/check-in/check-out and
> evidence uploads move to RPC/Storage next, then FastAPI is removed. A fresh
> database uses `supabase/migrations`, not Alembic.

Then run the Flutter app against it — see [Flutter](#flutter) below.

## Backend (without Docker)

Requires Python 3.12+ and [`uv`](https://docs.astral.sh/uv/), plus a running
PostgreSQL instance.

```bash
cd backend
cp .env.example .env        # edit DATABASE_URL/SECRET_KEY for your setup
uv sync
uv run alembic upgrade head
uv run python scripts/create_admin.py --username admin --display-name "Admin" --pin 1234
uv run python scripts/seed_categories.py
uv run uvicorn app.main:app --reload
```

Tests: `uv run pytest`.

## Flutter

Requires the Flutter SDK (stable channel). The API base URL is injected at
build/run time via `--dart-define` (defaults to `http://localhost:8000`):

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_URL=http://localhost:8001 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY from .env>
```

When both Supabase defines are present, login goes through GoTrue; without
them the app falls back to the legacy FastAPI PIN endpoint.

- Android emulator talking to services on the host machine: use
  `http://10.0.2.2:8000` (API) and `http://10.0.2.2:8001` (Supabase).
- Web (`flutter run -d chrome ...`) needs `CORS_ORIGINS` on the backend to
  include the origin Flutter serves from (see `backend/.env.example`).

Tests: `flutter test`. Static analysis: `flutter analyze`.

### Android release builds

`flutter build apk --release` is debug-signed today (no keystore is checked
into this repo, by design). To produce a real, distributable release build:
copy `android/key.properties.example` to `android/key.properties`, point it
at your keystore, and fill in the passwords/alias — `android/key.properties`
is gitignored and picked up automatically once present.

## OpenSpec workflow

New capabilities go through `openspec/changes/<name>/` (`proposal.md` +
`design.md` + `tasks.md`) before implementation; `openspec archive` folds an
approved, implemented change into `openspec/specs/`. `PROGRESS.md` tracks the
resulting capability history and key technical decisions.

## License

MIT — see `LICENSE`.
