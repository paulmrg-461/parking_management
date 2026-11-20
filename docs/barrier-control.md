# Barrier control

A boom barrier follows the system's state: it opens for a car that has just
checked in, for a session that has just been paid, for a recognised pass
holder (opt-in) and for a logged manual request. The barrier's own photocell,
safety edge and loop remain the safety authority; this system only issues
commands and records what happened.

## Who may open a barrier

Every path goes through `barrier_issue_command`; nothing else inserts
commands.

| Source | When | Rule |
|---|---|---|
| `checkin` | an LPR event becomes `done`/`confirmed` with a session, or any session opens | the barrier paired with the event's camera; `open_on_checkin = 'always'` also opens the single enabled entry barrier on any session |
| `paid_exit` | a session closes with a waiting `exit_unpaid` event (15 min), or an exit event is `exit_paid` | the paired exit barrier; `open_on_paid_exit = 'always'` also opens the single enabled exit barrier on any close |
| `pass_recognised` | an entry event with a pass, confidence ≥ 0.95, not blocked/duplicate, ≤ 20 s old | only when `open_for_pass_entry` is on for that barrier |
| `manual` | an operator confirms with a reason | any online, idle barrier; 10 per user per hour |
| `online_payment` | `barrier_request_exit_open(session)` from the payments hook | same pairing as `paid_exit` |

Never issued: an exit with an open session, a blacklisted vehicle, a session
closed more than 15 minutes ago, or a pass holder at the exit.

A command stays `queued` → `delivered` (at most three deliveries, at least
5 s apart) → `executed`/`rejected`, or ages out as `expired` (TTL 10–120 s,
default 30). The triggers that issue commands are wrapped: a broken barrier
never rolls back a check-in or a check-out.

## Signed commands

The database stores the facts; the gateway signs at delivery with an Ed25519
key (`BARRIER_COMMAND_SIGNING_KEY`, base64 PKCS#8) that exists only in the
functions environment. Without it `/v1/barrier/commands/next` answers `503`
(fail closed).

```
parking-barrier-v1|<command id>|<device id>|open|<issued s>|<expires s>|<nonce>|<hold_ms>|<max_open_s>
```

The timings are inside the signature, so a man-in-the-middle cannot lengthen
the opening. Generate a pair with
`sh edge/barrier/tools/gen_command_key.sh`; put the private half in `.env`
and the public half in the firmware. The firmware also rejects a command that
is expired, replayed (last 16 ids and a persisted monotonic `issued_at`),
addressed to another device or badly signed.

Rotation: ship firmware with the new public key first (the firmware accepts
two during the window), then switch the server key. `docker compose restart`
does **not** reload the environment — use `up -d functions`.

## Device protocol (kind `barrier`)

- `GET /v1/barrier/config` → `{direction, open_hold_ms, max_open_s,
  post_clear_delay_ms, max_reversals, command_ttl_s, poll_wait_s,
  heartbeat_interval_s}`.
- `GET /v1/barrier/commands/next?wait=20` → a signed command or `204`.
- `POST /v1/barrier/commands/:id/ack` (`Idempotency-Key` = id) with
  `{"result":"opened"|"refused", ...}`.
- `POST /v1/barrier/events` with `{client_ref, event, at, detail}`.
- `GET /v1/barrier/firmware?current=1.0.0` and
  `GET /v1/barrier/firmware/:version/image`.

All use the standard device headers; a non-barrier device gets `403`.

## Operator flow (`/barrier`)

Operators see each barrier, its direction and online status. **Abrir** asks
for a reason (3–200 characters), records who and why, notifies the admins and
tracks the command until it is executed or fails (live-region banner). An
offline barrier disables the button. The history sheet lists the commands with
their source, status and operator. Admins additionally get the configuration
sheet: direction, check-in and paid-exit rules (`never`/`camera only`/
`always`), the pass opt-in (with the spoofing warning) and the timings.

## Retention and operations

`expire_barrier_commands` runs in `jobs.sh` and the host cron; with barriers
installed set `JOBS_INTERVAL_SECONDS=30` so an undelivered command alerts
within half a minute. `purge_barrier_events(365)` deletes events and commands
older than a year: the audit trail of every opening is kept for 365 days.
The `firmware` bucket is private with no client policy; only the gateway
streams it.

Useful queries:

```sql
select device_name, source, status, issued_at, acked_at, result
  from public.barrier_commands order by issued_at desc limit 20;
select device_id, event, happened_at from public.barrier_events
 order by happened_at desc limit 20;
select public.list_barriers();
```

## Limits and threats

- The signing key in the functions host is the trust anchor; a full host
  compromise can forge commands. Rotate it if exposed.
- A stolen device key can poll (only its own commands), ack and post events
  (nuisance alerts); it cannot forge commands without the private key.
- Automatic pass opening is off by default: a printed plate with a valid pass
  could open the entry. The owner accepts that risk explicitly.
- Manual openings are audited (name, reason, time), notified to admins and
  limited to 10 per user per hour.
- There is no local trigger and no server socket on the device; the
  controller's own remote remains outside this system, as before.

## Rollback

Set the barrier's rules to `never` (or clear the camera pairing) and the
triggers stop issuing commands. Deleting the device cascades its config and
leaves existing commands with a null device; pending ones expire. Sessions,
payments and evidence are untouched.

## Firmware

The ESP32-S3 reference (`edge/barrier/`) is the remaining slice: pure-logic
host tests for the command validator and the state machine, TLS with a pinned
CA, encrypted NVS for the public keys and the last executed `issued_at`,
secure boot/OTA and the relay/loop/beam I/O. The command vector for the C++
test is `edge/barrier/test/vectors/command_v1.json`.
