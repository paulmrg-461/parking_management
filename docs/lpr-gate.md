# LPR gate (plate camera)

A fixed camera reads plates and the server decides what to do with each read.
The camera never decides and never opens a session. The feature is per lot and
inert until an admin registers a camera as `camera`, assigns it a direction and
optionally switches the mode to `auto`.

## What the server does with a read

Reads arrive through the device gateway (device key + strictly increasing
sequence, same protocol as the heartbeat). The server serialises reads per
camera, normalises the plate (`upper(regexp_replace(…, '\s', '', 'g'))`),
ignores reads older than 15 minutes, drops reads under the minimum confidence,
debounces a plate read again within the cooldown, and only decides after the
configured number of votes inside the window.

| Direction | Condition (first match wins) | Event | Side effects |
|---|---|---|---|
| entry | blacklisted vehicle | `blocked / blacklisted` | `lpr_blacklisted` alert |
| entry | open session already exists | `pending / duplicate_session` | `lpr_pending` |
| entry | mode `assist` | `pending / assist_mode` | `lpr_pending` |
| entry | mean confidence below the auto threshold | `pending / low_confidence` | `lpr_pending` |
| entry | unknown plate, no default category | `pending / unknown_plate` | `lpr_pending` |
| entry | system operator missing/inactive | `pending / no_system_operator` | `lpr_pending` |
| entry | mode `auto`, checks pass | `done` + session | normal check-in notice |
| entry | `check_in` says full | `pending / lot_full` | `lpr_pending` |
| entry | `check_in` failed otherwise | `pending / error` (name in `detail`) | `lpr_pending` |
| exit | blacklisted vehicle | `blocked / blacklisted` | `lpr_blacklisted` |
| exit | open session in this lot | `pending / exit_unpaid` + session | `lpr_exit`, **no write** |
| exit | session closed within the window | `done / exit_paid` | none |
| exit | anything else | `pending / no_open_session` | `lpr_pending` |

An exit event never closes, charges or edits a session. `has_pass` records
whether the vehicle had an active monthly pass at decision time.

## Operator flow (`/gate`)

Operators (and admins) see the pending reads, newest first, and can:

- **Confirm entry**: opens the plate dialog (correction allowed), runs the
  normal `check_in` as the signed-in operator and attaches the snapshot as
  evidence. A double tap replays the same session (`lpr-confirm:<event>`).
- **Dismiss**: closes the read with an optional note (stored in `detail.note`).
- **Open check-out**: for `exit_unpaid`, jumps to `/check-out?scan=<plate>`.

Confirming needs connectivity and the action is disabled offline. Alerts
(`lpr_pending`, `lpr_exit`, `lpr_blacklisted`) open the gate. The inbox polls
every 10 seconds while open.

## Settings (`/gate-settings`, admin)

Mode (`assist`/`auto`), minimum confidence (0.50–0.99), automatic confidence
(0.50–0.999, never below the minimum), minimum votes (1–10), vote window
(2–60 s), cooldown (10–3600 s), default category for new plates, the system
operator and each camera's direction. Switching to `auto` asks for
confirmation because a spoofed plate could open a session unattended.

The system operator is an ordinary active operator/admin member of the lot
(create it with the users admin, e.g. `gate-bot`, display name
"Cámara de entrada"). Automatic check-ins are attributed to it, so reports and
audits show who the session belongs to.

## Device protocol

All routes are camera-only and use the standard device headers.

- `GET /functions/v1/device-gateway/v1/lpr/config` →
  `{direction, min_confidence, vote_window_seconds, heartbeat_interval_s}`;
  `400 LprDirectionNotSetError` until an admin assigns the direction.
- `POST …/v1/lpr/reads` — body ≤ 4 KiB, `Idempotency-Key` must equal
  `client_ref`:
  ```json
  {"client_ref":"<uuid>","plate":"ABC123","confidence":0.947,
   "captured_at":"2026-11-10T14:03:21.512Z","track_id":"t-1731247"}
  ```
  → `{read_id, outcome, event, snapshot_wanted}` (`recorded`, `decided`,
  `debounced`, `replayed`, `stale`, `ignored_low_confidence`).
- `PUT …/v1/lpr/events/:id/snapshot` — JPEG (magic `FF D8 FF`) ≤ 256 KiB →
  `{event_id, session_id}`; `409 SnapshotAlreadyAttachedError` is success. The
  gateway builds the path from the authenticated device.

Reads retried after a network error must reuse the same `client_ref` and a new
sequence; the server answers `replayed` without a second event.

## Storage and retention

Snapshots live in the existing private `evidence` bucket under
`lpr/<lot>/<device>/<event>.jpg`. While no `evidence_photos` row references
them, members of the lot can read them through `can_read_lpr_snapshot()`
(the policy never uses `current_lot_id()`, which Storage cannot send). Once an
entry is confirmed the snapshot is an ordinary evidence photo. The expiry job
marks stale pending reads `expired` and confirms unpaid exits whose session was
closed; `evidence-archive` calls `purge_lpr_events(30)` and deletes the orphan
objects.

## Rollback

Switch the mode to `assist` (or clear the camera direction, which makes the
device answer `LprDirectionNotSetError` and stop posting reads). Pending events
expire on their own; existing sessions and evidence are untouched. Deleting the
camera device cascades its direction and leaves the events with a null device.

## Limits

Assist mode is the default and the safe choice: a fixed camera can misread a
plate and a printed copy can spoof it. Auto mode is an owner decision. Night,
rain, dirt and unusual plates lower the accuracy; the UI shows the confidence
and the number of votes so the operator can judge. Nothing here changes billing
except through the normal `check_in`/`check_out` paths.
