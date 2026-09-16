## Context

`offline-sync` (archived) added an outbox for `update`/`delete` on vehicles,
tariffs, categories, and explicitly excluded check-in and check-out for two
different reasons (see its `design.md` Non-Goals):

- **check-in**: evidence photos are binary multipart uploads; queuing bytes
  is bigger than queuing JSON.
- **check-out**: `exit_time` is generated server-side at close time
  (`datetime.now()`); replaying later would record the wrong exit time and
  mis-charge the fare.

Both are also, structurally, harder than the `update`/`delete` case already
solved: check-out's correctness bug is a real design problem (not just
"bigger"), and check-in is a **create**, which `offline-sync`'s design.md
separately flagged project-wide as needing "temporary-ID reconciliation... a
substantial feature on its own" — because a queued create's id isn't known
until the server assigns one, and other client state may reference that id.

This change solves both, but narrowly: it does not attempt a generic
create-with-reconciliation mechanism for the whole app (that remains a
non-goal, see below) — it exploits a property specific to check-in that makes
reconciliation unnecessary.

## Goals / Non-Goals

**Goals:**
- A check-out attempted while offline queues instead of failing, and its
  replay uses the *original* attempt time as `exit_time`, not the replay
  time — closing the correctness bug that kept check-out out of scope before.
- A check-in attempted while offline queues (plate + photos) instead of
  failing, survives an app restart before it syncs, and replays as the exact
  same multipart request that would have been sent online.
- Both flows degrade to a visible "pending sync" state in the UI rather than
  silently pretending to have succeeded with fabricated data.

**Non-Goals:**
- **No client-side fare calculation.** `FareCalculator` (backend,
  `app/application/billing_service.py`) has deliberately subtle rules —
  per-calendar-day splitting, midnight-wrapping night windows, per-day rate
  caps applied independently per day (see `PROGRESS.md`'s `billing` row).
  Porting that to Dart to show an instant offline receipt would create a
  second implementation of billing math that can drift from the backend's —
  exactly the kind of duplication this project avoids elsewhere (backend is
  documented as the system of record). An offline checkout's receipt shows
  **pending sync**, not an estimate. This is a real operational limitation
  (an operator can't quote the exact amount to a driver leaving during an
  outage) — accepted rather than worked around, because a *wrong* quoted
  amount is worse than none.
- **No generic create-with-reconciliation mechanism.** Check-in's queued
  create only works without id reconciliation because of a specific
  property (see Decisions below) — this does not generalize to, e.g.,
  queuing a new vehicle or tariff offline. That remains exactly as
  out-of-scope as `offline-sync`'s design.md already said.
- **No local cache of the open-sessions list.** Both `check-in`'s and
  `check-out`'s "list open sessions" stay remote-fetch-only, same as today.
  A queued-but-not-yet-replayed check-out will still show its session as
  open in that list until the replay completes and the list is refetched —
  a known, accepted staleness window, consistent with this app's existing
  "no version/conflict tracking" stance (see `offline-sync`'s design.md
  Risks).
- **No retry backoff / reordering** — same `flush()` semantics as
  `offline-sync` (one stuck entry doesn't block another; a non-`NetworkFailure`
  exception from a replay still propagates out of `flush()`, same accepted
  risk already documented there).

## Decisions

### Check-out: capture client time, don't trust replay time

`CheckOutRepositoryImpl.checkOut(sessionId)` keeps its existing signature.
Internally: try remote first (unchanged, still lets the backend use its own
`now()` when online — no client-clock trust introduced for the common case).
On `NetworkFailure`, capture `DateTime.now()` **immediately**, at the point
of the failed attempt (not at replay time), and enqueue a `PendingMutation`
carrying it as `client_exit_time`. Replay passes that exact value through.

- Backend: `CheckOutService.close_session` already accepts an optional
  `exit_time: datetime | None` override (added for `check-out`, never wired
  to the route). `POST /check-outs/{session_id}` gains an optional JSON body
  (`CheckOutRequest.client_exit_time: datetime | None = None`); the route
  passes it through unchanged when present, preserving today's
  server-clock behavior when absent (online path, unchanged).
- **Accepted risk (same shape as `offline-sync`'s existing "no version
  check" risk):** trusting a client-supplied timestamp for a value that
  drives billing is a real trust boundary weakening. Scope is deliberately
  narrow to limit blast radius: `client_exit_time` is only honored on the
  *offline* path (captured automatically by the app, not user-editable),
  and only affects the amount charged for that one session, not
  authentication/authorization. A malicious device clock could under/over
  charge one session — no worse than a broken device clock could already do
  to the app's own displayed timestamps elsewhere in the UI.
- The immediate on-screen result becomes a **pending receipt**:
  `CheckOutReceipt` gains `amountCharged`/`ticketNumber` as nullable plus a
  `pendingSync` flag; `CheckOutSuccess` UI shows "Queued — amount pending
  sync" instead of the numeric receipt when `pendingSync` is true.

### Check-in: queue the create, skip reconciliation entirely

The reason check-in's create doesn't need the "substantial" id-reconciliation
machinery `offline-sync`'s design.md worried about: **nothing on the client
holds a reference to a check-in session's id after creation.** The
open-sessions list is refetched from the server every time it's shown (no
local cache, no cross-feature foreign key to a session id stored anywhere in
Flutter state). So a synthetic id only has to be a valid, unique-enough
`Equatable` key for one rendered list row until the next refresh — it is
never persisted, never compared against a real id, never used to look
anything up.

- `ParkingSessionStatus` gains `pendingSync` (alongside `open`/`closed`).
- On `NetworkFailure`, `CheckInRepositoryImpl.createCheckIn`:
  1. Copies each photo file's bytes into app-persistent storage
     (`getApplicationSupportDirectory()/pending_check_ins/<clientRef>/`,
     via new `lib/core/sync/pending_photo_storage.dart`) — the picker's
     original file lives in a transient/cache location that the OS can
     reclaim before the queue drains, so this copy is required, not
     optional.
  2. Enqueues a `checkIn`-type `PendingMutation` (`entityId: null` — see
     below; payload: `plate`, persisted photo paths, captured
     `client_entry_time`, and a `clientRef` string used only as the photo
     subfolder name).
  3. Returns an optimistic `ParkingSession(id: -DateTime.now()
     .microsecondsSinceEpoch, status: pendingSync, ...)` so the submitting
     screen can show immediate feedback.
- Replay (`SyncService._replayCheckIn`) rebuilds the `File` list from the
  persisted paths and calls the same repository create path used online;
  on success it deletes the persisted photo directory (cleanup — otherwise
  local storage grows unboundedly across many offline check-ins).
- `PendingMutation.entityId` becomes `int?` (was `int`) to represent "no
  server id yet" for a `create` operation; `vehicle`/`tariff`/`category`
  `update`/`delete` entries are unaffected (`entityId` still always
  populated for those).

### Outbox/replay extension shape

`PendingMutation.entityType` gains two new values: `'checkIn'` (operation
`'create'`) and `'checkOut'` (operation `'close'`). `SyncService._replay`
dispatches on `entityType` exactly as it does today for the three existing
types — no restructuring of the existing vehicle/tariff/category branches.

## Risks / Trade-offs

- [Client-clock trust for `checkOut`'s `exit_time`] — see Decisions above;
  accepted, narrow blast radius.
- [No fare shown on offline checkout] — see Non-Goals; accepted, a wrong
  number is worse than no number.
- [Open-sessions list staleness for a queued-but-not-replayed checkout] —
  the session still shows as "open" until replay + refetch; accepted,
  consistent with the rest of this app's cache-staleness posture.
- [Synthetic negative id could theoretically collide across two check-ins
  queued in the same microsecond] — practically impossible on a
  single-operator device (one check-in flow at a time, human-paced); not
  guarded against.
- [Persisted photo storage grows if a replay never succeeds, e.g. the app
  is uninstalled/reinstalled mid-outage] — no orphan-cleanup sweep is added;
  same "no sophistication beyond what's needed" posture as `offline-sync`'s
  existing accepted risks. A follow-up could add a startup sweep that
  reconciles `pending_check_ins/` against current outbox entries if this
  proves an issue in practice.

## Migration Plan

- Backend: no schema migration — `close_session`'s `exit_time` parameter
  already exists; only the route gains an optional body field. Fully
  backward compatible (omitted body / no `client_exit_time` = today's
  behavior, server time).
- Flutter: `PendingMutation.entityId` widening from `int` to `int?` is
  backward-compatible with any already-queued JSON in
  `Hive.box<String>('sync_outbox')` (existing entries still decode; only
  new `checkIn` entries write `null`).

## Open Questions

- None. `monthly-passes` offline support remains a separate, explicitly
  deferred follow-up (noted in `offline-sync`'s design.md), unaffected by
  this change.
