## Why

A boom barrier is the only physical enforcement a parking lot has: today a car can leave without the desk ever touching the system, and the desk must walk to the gate (or use a remote) to let a paying customer out. Once cameras (`add-lpr-camera-gate`) tell the system who is at the gate and the desk tells it who has paid, the barrier can follow the system's state: open for a car that has just checked in, open for a session that has just been paid, open for a recognised pass holder, and open on a logged, reasoned manual request.

A barrier is also the most dangerous thing in this stack: a forged "open" lets a car leave unpaid, and a wrong "close" can hit a vehicle. This change therefore specifies a server that issues signed, single-use, 30-second commands; a firmware that accepts nothing else, no local trigger, and keeps the controller's own safety devices authoritative; and the failure behaviour for power and network loss.

## What Changes

- NEW per-barrier configuration (`barrier_config`): direction, paired LPR camera, which events open it, hold and safety timings.
- NEW `barrier_commands` (the audit trail and the queue), `barrier_events` (device-reported: opened, closed, obstruction, tamper, power restored), `device_firmware` (signed OTA manifests).
- NEW issuers, all server-side: LPR-created check-in, check-out (paid exit), recognised monthly-pass holder at an entry (opt-in), operator manual open with a mandatory reason (audited, admins notified, rate-limited), and an optional hook function for `add-online-payments`.
- NEW Ed25519 command signing in the Edge Function (`BARRIER_COMMAND_SIGNING_KEY`, new env var); the firmware holds only the public key.
- NEW gateway routes (kind `barrier`): `GET /v1/barrier/config`, `GET /v1/barrier/commands/next` (long poll), `POST /v1/barrier/commands/:id/ack`, `POST /v1/barrier/events`, `GET /v1/barrier/firmware`, `GET /v1/barrier/firmware/:version/image`.
- NEW RPCs for operators/admins: `list_barriers`, `request_manual_barrier_open`, `get_barrier_command`, `list_barrier_commands`, `set_barrier_config`, `release_device_firmware`; jobs `expire_barrier_commands`, `purge_barrier_events`.
- NEW Flutter feature `lib/features/barrier/` with `/barrier` (operators and admins): barrier status, manual open with reason, history, admin configuration.
- NEW ESP32-S3 firmware under a NEW top-level `edge/barrier/` (C++, PlatformIO/ESP-IDF): pure-logic library unit-tested on the host, relay/loop/beam I/O, TLS with a pinned CA, encrypted NVS key storage, secure boot + signed OTA with rollback.

## Capabilities

### New Capabilities

- `barrier-control`: configuring barriers, issuing and delivering signed commands, device behaviour and safety, manual open, events, firmware releases.

### Modified Capabilities

- `check-out`: a closed (paid) session may trigger the exit barrier.
- `notifications`: manual-open, command-failed and barrier-fault alerts.

## Impact

- **Database** (numbers at implementation time, order): `<NEXT>_barrier_config.sql`, `<NEXT>_barrier_commands.sql`, `<NEXT>_barrier_triggers.sql`, `<NEXT>_barrier_operator_rpcs.sql`.
- **Edge Function**: `supabase/volumes/functions/device-gateway/routes/barrier_*.ts`, `signing.ts`; `supabase/docker-compose.yml` (`functions` service gets `BARRIER_COMMAND_SIGNING_KEY`), `.env.example`, `supabase/.env.example`.
- **Scheduled jobs**: `supabase/jobs.sh`, `supabase/notifications-cron.sh` (`expire_barrier_commands`, `purge_barrier_events`).
- **Storage**: private bucket `firmware` (created by the migration, service role only).
- **Flutter**: `lib/features/barrier/**`, DI module, route, destination, notification routing, error codes, ARB.
- **Firmware**: `edge/barrier/**` (NEW), not built by Flutter CI.
- **Docs**: `docs/barrier-control.md` (NEW, includes wiring and commissioning), `docs/database.md`, `docs/architecture.md`, `docs/infrastructure.md`, `docs/project-overview.md`, `docs/runbook-secrets.md` (signing key rotation), `docs/agent-memory.md`, `CHANGELOG.md`.
- **Breaking**: none; with no barrier device registered nothing changes.
- **Depends on**: `add-device-gateway`, `add-lpr-camera-gate`. **Optional hook for**: `add-online-payments`.

## Non-Goals

- Being a safety system: the barrier controller's own photocell, safety edge and loop remain the safety authority; this change adds signals, it does not replace them or claim any safety rating.
- Offline authorisation (a whitelist cached on the ESP32 that opens without the server): rejected, see design.
- Opening for exit on LPR alone while the session is unpaid, or for a pass holder at an exit with an open session.
- Gate arms with several lanes per device, turnstiles, sliding gates (the relay model fits them, but only a boom barrier is specified and tested).
- Remote close from the app (closing is automatic on the device).
- MQTT, BLE, Wi-Fi provisioning portals, local web UI on the device.
