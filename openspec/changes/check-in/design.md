## Context

`vehicles` and `tariffs` completed the reference-data layer; `plate-scanning`
(Flutter-only) speeds up plate entry. This change delivers the backend half of
check-in: opening a `parking_sessions` record for a resolved vehicle and
persisting evidence photos captured at entry. The Flutter half (capture UI,
multipart upload call, offline queueing) is being built in parallel against this
API contract.

## Goals / Non-Goals

**Goals:**
- Resolve the vehicle by normalized plate (reusing `VehicleRepository.get_by_plate`).
- Open a `parking_sessions` row (status `open`, `entry_time`, `operator_id`)
  and reject a second open session for the same vehicle.
- Accept zero or more evidence photos per check-in, store their bytes via a
  storage port, and persist one `evidence_photos` row per photo referencing the
  session.
- Expose `POST /check-ins` (multipart) and `GET /check-ins` (list open sessions)
  for any authenticated user (day-to-day operator use, same as vehicle search).
- Keep photo storage behind a port (`EvidenceStoragePort`) so local disk storage
  can be swapped for S3/object storage later without touching the service.

**Non-Goals:**
- Billing/checkout: this change does not compute fares or close sessions. A
  session just tracks `entry_time` / `status` until a later `check-out` change
  closes it and hands off to billing.
- Photo review/annotation UI, image resizing/compression, or virus scanning.
- Multiple concurrent sessions per vehicle (rejected as a conflict, not queued).

## Decisions

- **Vehicle resolution reuses `VehicleRepository.get_by_plate`.** No new lookup
  logic; unknown plate raises `VehicleNotFoundError` -> 404, matching how
  `vehicles` already normalizes and searches plates.
- **One open session per vehicle, enforced in the service.** `CheckInService`
  checks for an existing open session via a repository query before creating a
  new one; violation raises `DuplicateOpenSessionError` -> 409. Alternative: a
  partial unique index on `(vehicle_id) WHERE status = 'open'` — deferred; the
  service-level check keeps this SQLite-test-friendly (SQLite lacks partial
  unique index support), matching the existing test suite's in-memory SQLite
  approach.
- **`status` is a plain string enum (`open`/`closed`)** stored as `String`,
  matching how `TariffType`/`UserRole` are modeled (`str, Enum` domain type,
  `String` column) rather than a native Postgres enum, for migration simplicity
  and SQLite test compatibility.
- **Evidence storage behind `EvidenceStoragePort`** (`async def save(filename,
  content) -> str`). `LocalEvidenceStorage` writes under a configurable root
  directory (`settings.evidence_storage_path`, default `./data/evidence`),
  creating it if missing, and returns a path relative to that root (so a future
  `S3EvidenceStorage` can implement the same port without any caller change).
  Filenames are namespaced by a generated UUID to avoid collisions across
  concurrent uploads.
- **`POST /check-ins` accepts `multipart/form-data`** (`plate: str`,
  `photos: list[UploadFile]`), requiring `python-multipart`. Any authenticated
  user (admin or operator) may check in a vehicle — mirroring `GET /vehicles`
  (read, any authenticated role) rather than the admin-only vehicle *mutation*
  gate, because check-in is a day-to-day operator action, not reference-data
  management (confirmed against `openspec/specs/vehicles/spec.md`, where only
  vehicle create/update/delete is admin-gated and lookups are open to any
  authenticated user).
- **Repositories `flush()`, never `commit()`** — the session-scoped commit
  happens in `get_session()` at the request boundary, matching every existing
  repository (`vehicle_repository.py`, etc.).

## Risks / Trade-offs

- [No partial unique index for "one open session per vehicle"] → a race between
  two concurrent check-ins for the same plate could both pass the service check
  before either commits. Acceptable for v1 (single-operator-at-a-time kiosk
  flow); a DB-level constraint is a follow-up once running on Postgres only.
- [Local disk storage] → not durable across multiple app instances/replicas;
  acceptable for the current single-instance deployment. The port boundary means
  swapping to S3 later touches only `infrastructure/`.
- [No image validation (type/size)] → deferred; a future hardening pass can add
  content-type/size checks at the route layer.

## Migration Plan

1. Add `parking_sessions` table (FK to `vehicles.id`, `users.id`) via Alembic
   migration `0005`.
2. Add `evidence_photos` table (FK to `parking_sessions.id`) via Alembic
   migration `0006`.
3. Both additive only; rollback drops the tables in reverse order.

## Open Questions

- None blocking. Whether `check-out` reuses `EvidenceStoragePort` for exit
  photos is deferred to that change.
