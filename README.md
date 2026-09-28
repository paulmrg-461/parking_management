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

Brings up PostgreSQL and the backend API; runs migrations automatically.

```bash
docker compose up --build
```

The API is then live at `http://localhost:8000` (`/api/health` for a quick
check, `/docs` for the interactive OpenAPI UI).

Bootstrap the first admin user (auth is PIN-based and every other user is
created through an admin-only endpoint, so a fresh database needs this once):

```bash
docker compose exec backend python scripts/create_admin.py \
  --username admin --display-name "Admin" --pin 1234
```

Seed the default vehicle categories (a fresh database has none, which
disables the check-in category dropdown for new vehicles):

```bash
docker compose exec backend python scripts/seed_categories.py
```

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
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

- Android emulator talking to a backend on the host machine: use
  `http://10.0.2.2:8000` instead of `localhost`.
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
