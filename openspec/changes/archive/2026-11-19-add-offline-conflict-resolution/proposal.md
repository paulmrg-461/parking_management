## Why

Offline edits to reference data replay as last-write-wins (`docs/project-overview.md` §8 "Conflict resolution for offline reference-data edits (last-write-wins today)"; `PROGRESS.md` row `offline-sync`). Two admins editing the same tariff, one of them without connectivity, silently overwrite each other when the offline one reconnects: a price, a capacity or a lot setting changes with nobody told. Capacity, tariffs and settings drive billing and bookings, so a silent overwrite is a money and availability bug.

## What Changes

- **Row version (NEW column `version integer not null default 1`)** on the four tables the outbox replays by PATCH/DELETE: `vehicles`, `tariffs`, `categories`, `parking_settings`. A `BEFORE UPDATE` trigger increments it only when the row really changes; existing rows backfill to `1`. None of the four has a usable version today (`updated_at` exists only on `parking_settings` and is not maintained by direct patches).
- **If-Match style writes**: the client sends the base version it edited from as a PostgREST filter (`PATCH /vehicles?id=eq.5&version=eq.7`, `DELETE` likewise). Zero rows updated is a conflict (typed `VersionConflictFailure`, code `VersionConflictError`, carrying the current server row), never a silent success.
- **Outbox**: `PendingMutation` stores `baseVersion` and a `baseSnapshotJson`; a new state "needs resolution" is distinct from retryable and from dead-letter; `SyncService` auto-merges non-overlapping field changes with a three-way merge and parks real conflicts; nothing is ever dropped.
- **Resolution UI**: from the `SyncBadge` sheet, a field-by-field "mine / theirs" dialog with keep-mine, keep-theirs and per-field merge; explicit delete-vs-edit handling.
- **Transition**: old clients send no version filter and keep last-write-wins; a per-lot policy `parking_settings.row_version_required` (turned on by lot admins only when `min_app_version`, `0076`, is set) makes the database refuse table writes from clients that do not declare version awareness.
- **Flutter**: `Vehicle`, `Tariff`, `Category`, `ParkingSettings` gain `version`; the four remote data sources use two shared helpers (`updateVersioned`, `deleteVersioned`); settings edits queue only the changed fields.
- Check-in and check-out replays are analysed one by one and stay version-free (already idempotent).

## Capabilities

### New Capabilities

- `row-versioning`: per-row version column, bump trigger, stale-base refusal on direct table writes, transition policy.
- `sync-conflict-resolution`: detection, three-way auto-merge, the needs-resolution outbox state, resolution choices, delete-vs-edit rules, badge and dialog.

### Modified Capabilities

- `offline-sync`: queued mutations carry their base version; consecutive edits of one row coalesce; settings edits queue only changed fields; persisted outbox JSON gains fields (backward compatible).

## Impact

- **Database**: one migration `<NEXT>_row_versions.sql` (columns, check, trigger function `row_version_guard()` + 4 triggers, `parking_settings.row_version_required`, `set_row_version_policy(p_required boolean)`), tests in `supabase/tests/rpc_test.sql`. Migration head is `0102` today and `add-public-booking-captcha` takes `0103+`; use the next free number at implementation time.
- **Flutter core**: `lib/core/sync/{pending_mutation,sync_outbox,notifying_sync_outbox,sync_service,sync_status_cubit,mutation_replayer}.dart`, NEW `lib/core/sync/conflict/*`, NEW `lib/core/network/versioned_write.dart`, `lib/core/error/failure.dart`, `lib/core/widgets/sync_badge.dart`, NEW `lib/core/widgets/conflict_resolution_dialog.dart`, `lib/core/l10n/failure_messages.dart`.
- **Flutter features**: vehicles, tariffs, categories, settings (entities, DTOs + generated code, local/remote data sources, repository impls, replayers, commands, edit dialogs), check-in and check-out replayers (signature only), `lib/app/di/hive_adapters.g.yaml` + generated adapters, `lib/app/di/modules/sync_module.dart`, `lib/app/di/injection.dart` (one header).
- **Docs**: `CHANGELOG.md`, `docs/project-overview.md` (§8 limitation removed), `docs/database.md`, `docs/agent-memory.md`, `PROGRESS.md` offline row.
- **Dependencies**: none.
- **Breaking**: none for clients that do not send a version (policy off by default). Stored outbox entries from older builds load unchanged and replay as last-write-wins (documented legacy path).
- **Depends on**: nothing in the change list functionally; ordered after `add-booking-waitlist` only by the global schedule. If `add-public-booking-captcha` or later changes touch `parking_settings`, the trigger below keeps working (it is column agnostic).

## Non-Goals

- CRDTs or operational transforms (design §Trade-offs).
- Versioning `monthly_passes`, `users`, `parking_lots`, `parking_spots` or any table the outbox does not replay.
- Online-only RPC edits of a vehicle's owner data (`update_vehicle_flags`): they are never queued and the RPC already serializes on `for update`.
- Recreating a record another user deleted (a new id would break references); the user may only accept the deletion.
- Queuing creates, shifts or cash actions (AGENTS §5 forbids it; unchanged).
- Real-time presence or locking of records while someone edits.
