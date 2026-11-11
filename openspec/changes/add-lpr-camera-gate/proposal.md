## Why

Operators type or scan every plate by hand (`lib/features/plate_scanning`, `check_in`). At a staffed gate that is acceptable; at an unattended or busy entry it is the bottleneck, and the exit lane has no way to warn the desk that a car is leaving with an unpaid session. A fixed camera with plate recognition removes the typing, gives every entry a timestamped snapshot as evidence, and lets the desk be told about a blacklisted vehicle before it is inside.

The repo's rules make this non-trivial: `check_in` is bound to a signed-in operator (`require_app_user()`), evidence uploads must be owned by `auth.uid()` (`require_evidence_object`), the plate normalization exists twice (Dart `normalizePlate`, SQL in `check_in`) and must not drift, and an unpaid exit must never close by itself. This change specifies all of that on top of `add-device-gateway`.

## What Changes

- NEW per-lot LPR settings (`lpr_settings`): mode `assist` (default) or `auto`, confidence thresholds, vote count and window, cooldown, default category for unknown plates, and the system operator that auto check-ins are attributed to.
- NEW `lpr_camera_config` (direction `entry` or `exit` per camera device), `lpr_reads` (every accepted read) and `lpr_events` (the decisions: auto-done, pending operator confirmation, blocked, dismissed, expired).
- NEW service-role RPCs `device_ingest_lpr_read`, `device_lpr_attach_snapshot`, `device_lpr_config` and operator/admin RPCs `list_lpr_events`, `confirm_lpr_entry`, `dismiss_lpr_event`, `get_lpr_settings`, `set_lpr_settings`, `set_lpr_camera_direction`, plus `expire_lpr_events` / `purge_lpr_events` jobs.
- NEW gateway routes (files under the `device-gateway` function, kind `camera` only): `GET /v1/lpr/config`, `POST /v1/lpr/reads`, `PUT /v1/lpr/events/:id/snapshot`.
- Server-side debounce and voting over several reads, applying the plate normalization twin; entry decisions per mode and confidence; exit never closes a session, it raises an "exit pending" item that opens the check-out for that plate; blacklisted plates alert; unknown plates follow the existing auto-register rule of `check_in`.
- Snapshot stored in the existing private `evidence` bucket under `lpr/<lot>/<device>/<event>.jpg` and, once a session exists, attached as an `evidence_photos` row so the current evidence UI, retention and membership read policy apply.
- NEW Flutter feature `lib/features/lpr/`: operator inbox `/gate` (confirm / correct / dismiss; open check-out), admin settings `/gate-settings`, notification routing.
- NEW reference implementation of the Jetson Orin service under a NEW top-level `edge/lpr/` (Python, YOLO plate detector + OCR, TensorRT), with config schema, RTSP reconnection, local SQLite queue, systemd unit and hardware-free tests (recorded video fixtures + fake gateway).

## Capabilities

### New Capabilities

- `lpr-gate`: plate reads from a fixed camera, server-side voting and debounce, assist/auto decisions, pending confirmation, exit alerts, blacklist alerts, snapshot evidence, settings and the edge service contract.

### Modified Capabilities

- `check-in`: a check-in may be performed by the system operator on behalf of a recognised plate, with the snapshot attached as evidence.
- `notifications`: LPR pending, exit and blacklist alerts.

## Impact

- **Database** (numbers at implementation time, relative order): `<NEXT>_lpr_settings.sql`, `<NEXT>_lpr_ingest.sql`, `<NEXT>_lpr_operator_rpcs.sql`.
- **Edge Function**: new files in `supabase/volumes/functions/device-gateway/routes/lpr_*.ts`, one matcher extension in `routes.ts` for `:id` segments.
- **evidence-archive**: must also delete `lpr/` objects of purged events (see tasks 5.x).
- **Flutter**: `lib/features/lpr/**`, `lib/app/di/modules/lpr_module.dart`, `lib/app/router/deferred/gate_settings_entry.dart`, `lib/app/router/app_router.dart`, `lib/app/router/route_access.dart` (`/gate` added to `operatorRoutes`), `lib/app/shell/app_destinations.dart`, notification files, `lib/core/l10n/failure_messages.dart`, ARB files, `lib/core/network/supabase_error_mapper.dart`.
- **New top-level directory** `edge/lpr/` (not part of the Flutter build, excluded from `flutter analyze`).
- **Docs**: `docs/lpr-gate.md` (NEW), `docs/database.md`, `docs/architecture.md`, `docs/infrastructure.md`, `docs/project-overview.md`, `docs/agent-memory.md`, `CHANGELOG.md`.
- **Breaking**: none; lots without a camera are untouched; default mode is `assist`.
- **Depends on**: `add-device-gateway`. **Used by**: `add-barrier-control` (pass-holder recognition, paid-exit hook).

## Non-Goals

- Training or shipping plate-detector/OCR weights (the owner supplies a model; the spec fixes the interface, export steps and acceptance metrics).
- Vehicle make/colour recognition, driver face capture, liveness detection against a printed plate.
- Opening the barrier (that is `add-barrier-control`; this change only publishes the facts it needs: `lpr_events` rows of reason `exit_paid` and `pass_recognised`).
- Auto check-out or any change to billing: an exit never closes a session.
- Multi-camera fusion (two cameras on one lane) and parking-lot-wide vehicle tracking.
- Offline operation of the confirmation inbox (it lives on the server; no outbox entity).
