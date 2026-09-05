## Context

Today `VehicleRepositoryImpl`/`TariffRepositoryImpl`/`CategoryRepositoryImpl`
already cache `list()` reads in Hive and fall back to that cache on
`NetworkFailure` (see each repo's `list()`). `update`/`delete` have no such
fallback — they call the remote data source directly and let `NetworkFailure`
propagate. `Vehicle/Tariff/CategoryLocalDataSource` today only expose
`cacheAll`/`readAll` (bulk replace, used by `list()`); there is no
single-entity write. No `connectivity_plus` (or similar) dependency exists
yet in `pubspec.yaml`.

## Goals / Non-Goals

**Goals:**
- `update`/`delete` on vehicles, tariffs, categories survive a `NetworkFailure`
  by applying the change to the local cache and queuing it for replay,
  instead of failing the operator's action outright.
- Replay automatically once connectivity is restored, without operator
  intervention.
- One replay entry that keeps failing must not block any other queued entry
  in the same flush pass.

**Non-Goals (deliberately excluded from this change):**
- **`check-in`**: evidence photos are uploaded via multipart binary payload.
  Queuing binary payloads for later replay means persisting file bytes and
  handling partial uploads — a materially bigger undertaking than the
  JSON-payload queuing this change implements. Out of scope.
- **`check-out`**: `exit_time` is generated server-side at the moment of
  closing (`datetime.now()` in `CheckOutService.close_session`). Queuing a
  check-out while offline and replaying it hours later would silently
  record the WRONG exit time and overcharge/undercharge the fare — a
  correctness bug, not an inconvenience. Check-out stays remote-only.
- **`monthly-passes`**: structurally identical reference-data CRUD to
  vehicles/tariffs/categories and WOULD be a reasonable candidate for the
  exact same outbox pattern — but is explicitly left out of THIS change to
  keep the diff reviewable. Natural follow-up change.
- **All `create` mutations** (vehicles, tariffs, categories, and everywhere
  else): a create needs a server-assigned id. Queuing a create and showing
  an optimistic local entity would require temporary-ID reconciliation
  (allocate a placeholder id, later swap it for the real one across every
  place that id is referenced) — a substantial feature in its own right.
  Creates remain remote-only/fail-immediately-offline, unchanged.
- **`reports`**: read-only, no mutations to queue.

## Decisions

- **Outbox storage: JSON-in-a-`Box<String>`, not a Hive-adapter type.**
  `PendingMutation` is a plain class with `toJson`/`fromJson`, stored as
  `jsonEncode(...)` values in `Hive.openBox<String>('sync_outbox')`, keyed by
  Hive's auto-incrementing int key (`box.add`). This avoids adding a typeId
  to `lib/app/di/hive_adapters.dart`'s `@GenerateAdapters` list (which would
  otherwise become typeId 9) for a record that is purely an internal queue
  entry, never synced or displayed directly.
- **Optimistic local update is merged in the repository, not the local data
  source.** `VehicleLocalDataSource`/etc. gain only generic `upsert`/`remove`
  methods. Each repository impl reads its own cached entity (via existing
  `readAll()` + find-by-id), merges the command's patch fields onto it
  client-side (mirroring the backend's own patch-merge shape, e.g.
  `TariffService._merge`), and calls `upsert` with the merged result. This
  keeps each entity's merge-shape knowledge in one place (the repository)
  instead of duplicating it into the local data source too.
- **Replay goes through each repository's own public `update`/`delete`
  method.** `SyncService` depends on the `VehicleRepository`/
  `TariffRepository`/`CategoryRepository` ports (not a separate "raw remote"
  path) — those methods already succeed via remote when actually online, so
  replay needs no parallel code path.
- **One stuck entry does not block the rest of the flush.** `SyncService.
  flush()` iterates every pending entry independently: a `NetworkFailure` on
  one entry is caught and that entry is left queued, but the loop continues
  to the next entry. This is a deliberate trade-off — no per-entry retry
  backoff, no reordering, no dependency tracking between entries — matching
  this app's existing preference (see `list()`'s simple cache-fallback) for
  simple, predictable semantics over a more sophisticated conflict-resolution
  scheme. A vehicle stuck behind a stale category reference, for example,
  will keep retrying every flush without affecting an unrelated tariff edit.
- **`connectivity_plus` reports `List<ConnectivityResult>`** (a device can
  have more than one active interface); "online" is defined as "at least one
  reported result is not `ConnectivityResult.none`" (`ConnectivityService.
  isOnline`/`onConnectivityChanged`).
- **`SyncService.start()` flushes once eagerly** in addition to subscribing
  to `onConnectivityChanged`, so a mutation queued in a previous app session
  (already online at next launch) doesn't wait for a connectivity change
  event that may never fire.

## Risks / Trade-offs

- [Last-write-wins, no conflict detection] If the record was also edited
  server-side (by another operator) while this device was offline, the
  queued replay will overwrite that edit with the stale-context patch. No
  version/etag check is introduced — matches this app's existing (documented)
  preference for simple last-write-wins semantics elsewhere.
- [No exponential backoff] A permanently-failing entry (e.g. the record was
  deleted server-side by someone else in the meantime, so the replay 404s
  as something other than `NetworkFailure`) is NOT caught by the
  `NetworkFailure`-only catch and would propagate out of `flush()` today only
  if such an error reaches `SyncService` directly — but since replay always
  goes through the repository's own `update`/`delete`, and those methods only
  special-case `NetworkFailure`, any other failure type (e.g.
  `ValidationFailure`) would still propagate. This is accepted: `flush()`
  itself does not currently guard against a non-`NetworkFailure` exception
  from one entry stopping the loop for the rest — a follow-up could wrap the
  whole per-entry replay in a broader catch if this proves an issue in
  practice.
- [Optimistic UI can display slightly-stale merged data] Fields not covered
  by an `Update*Command` (e.g. a vehicle's `plate`, which has no update path)
  come from whatever was last cached from `list()`/remote — acceptable since
  those fields are immutable via `update` in the first place.

## Migration Plan

No backend changes, no schema migration. Additive Flutter-only change:
existing `list()`/`create()` behavior is untouched; `update()`/`delete()`
gain a new offline branch that did not exist before (previously: rethrow).
`lib/app/di/hive_adapters.g.yaml` is untouched (`nextTypeId` stays `9`) since
the outbox is not a Hive-adapter type.

## Open Questions

- None for this change. `monthly-passes` offline support (noted above as a
  reasonable, explicitly-deferred follow-up) would reuse this exact pattern
  with a fourth `entityType`.
