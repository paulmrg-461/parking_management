## Why

`offline-sync` deliberately excluded check-in and check-out: check-in's evidence
photos are binary multipart uploads, and check-out's `exit_time` is generated
server-side at close time, so a naive queue-and-replay would silently charge the
wrong fare. Both are still remote-only today, so a brief connectivity drop at
the gate (the exact moment this app is meant to be used) fails the operator's
action outright. This change closes that gap for both flows, with fare
correctness intact.

## What Changes

- **Check-out**: `CheckOutRepositoryImpl.checkOut` captures the device's
  local time at the moment of the attempt. On `NetworkFailure` it queues a
  `checkOut` mutation carrying that captured `client_exit_time` (keyed by the
  session's real, already-existing id — no temp-id problem here) instead of
  failing. Replay sends `client_exit_time` through to the backend, which now
  accepts it, so the fare is computed against the original action time, not
  whenever the device happens to reconnect. The immediate on-screen receipt
  shows amount/ticket as **pending sync** (never a client-computed guess —
  billing math stays backend-only, see `design.md`).
- **Check-in**: `CheckInRepositoryImpl.createCheckIn` on `NetworkFailure`
  copies the evidence photos out of their transient picker location into
  app-persistent storage, queues a `checkIn` mutation (plate + persisted
  photo paths + captured entry time), and returns an optimistic
  `ParkingSession` with a synthetic negative id and a new `pendingSync`
  status. Replay re-submits the same multipart request once online; the
  temporary id is never referenced anywhere except that one rendered row, so
  it is simply replaced (not reconciled) the next time the open-sessions
  list is refreshed.
- Backend: `POST /check-outs/{session_id}` gains an optional JSON body field
  `client_exit_time`; `CheckOutService.close_session` already accepts an
  `exit_time` override (unused until now) — the route just wires it through.
- `PendingMutation`/`SyncService` extended with two new
  entity types (`checkIn` create, `checkOut` close) alongside the existing
  `update`/`delete` vehicle/tariff/category handling.

## Capabilities

### Modified Capabilities

- `check-in`: adds an offline-queued path for `POST /check-ins` (new ADDED
  scenario; existing online behavior unchanged).
- `check-out`: adds an optional `client_exit_time` override to
  `POST /check-outs/{session_id}` and an offline-queued path (new ADDED
  scenarios; existing online behavior unchanged since the field defaults to
  server time when omitted).
- `offline-sync`: extends the outbox/replay mechanism to two new mutation
  kinds (`checkIn` create, `checkOut` close), on top of the existing
  vehicle/tariff/category `update`/`delete` handling.

## Impact

- Backend: `check_outs.py` route + a small request-body schema;
  `check_out_service.py` unchanged (already takes `exit_time`).
- Flutter: `CheckInRepositoryImpl`, `CheckOutRepositoryImpl`,
  `ParkingSession` (new `pendingSync` status), `CheckOutReceipt` (amount/
  ticket become nullable + a `pendingSync` flag), `PendingMutation`
  (`entityId` becomes nullable to support check-in's temp-id-less create),
  `SyncService` (two new replay branches), new
  `lib/core/sync/pending_photo_storage.dart` (copies picker files into
  app-persistent storage, cleans up after successful replay), DI wiring.
- Non-goal (unchanged from `offline-sync`): no client-side fare
  calculation — an offline checkout's exact amount is only known once the
  device is back online and the replay completes; see `design.md` for why
  this is accepted rather than worked around.
