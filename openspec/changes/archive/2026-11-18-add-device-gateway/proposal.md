## Why

The system only knows people: every write goes through a `security definer` RPC that derives the actor from `auth.uid()` (`require_app_user()`) and the lot from the `x-lot-id` header (`current_lot_id()`). A plate camera, a boom barrier or a bay-sensor hub has no GoTrue user and must never hold one (a PIN login on a device would be an operator credential in a box at the gate). Three hardware changes are planned (`add-lpr-camera-gate`, `add-barrier-control`, `add-bay-sensors`); each needs the same thing first: a way to register a device for a lot, authenticate it with a credential that is useless for anything else, bound what it can call, know when it goes silent and keep a trail of what it did.

## What Changes

- NEW per-lot **device registry** `public.lot_devices` (kind `camera` / `barrier` / `sensor_hub`, name, API key stored as a SHA-256 hash and shown once, enabled flag, last seen, firmware version, monotonic request sequence, rate window).
- NEW **audited event log** `public.device_events` (registration, key rotation, enable/disable, rename, delete, online/offline transitions, rejected requests, invalid-key attempts).
- NEW admin RPCs for lot admins: `register_lot_device`, `rotate_lot_device_key`, `update_lot_device`, `delete_lot_device`, `list_lot_devices`, `list_device_events`, `set_device_offline_minutes`.
- NEW service-role-only RPCs (the privilege a device cannot obtain): `device_lookup`, `device_accept_request`, `device_record_auth_failure`, `device_heartbeat`.
- NEW Edge Function `device-gateway` (`supabase/volumes/functions/device-gateway/`): authenticates by `X-Device-Key` (constant-time compare of the SHA-256 hash, never a user JWT), resolves the lot from the registry (never from a header the device sends), enforces replay protection (`X-Device-Seq` strictly increasing) and the clock-skew bound (`X-Device-Timestamp` within 5 minutes, the repo's `MAX_CLIENT_CLOCK_SKEW`), rate-limits per device, and dispatches to a route table that later changes extend. This change ships `GET /v1/time` and `POST /v1/heartbeat`.
- NEW **offline alert**: `notify_offline_devices()` (run by `supabase/jobs.sh` and `supabase/notifications-cron.sh`) creates `device_offline` notifications for the lot's admins through the existing `public.notifications` table; the first accepted request afterwards creates `device_online`.
- NEW Flutter feature `lib/features/devices/` and admin-only deferred route `/devices`: list with status, register, show-key-once dialog, rotate key, enable/disable, rename, delete, event history, offline threshold.

## Capabilities

### New Capabilities

- `device-gateway`: registering hardware devices per lot, issuing and rotating their API keys, authenticating device requests, replay/clock/rate protection, heartbeat, the device event log and the admin screen.

### Modified Capabilities

- `notifications`: adds device offline/online alerts for lot admins.

## Impact

- **Database** (new migrations, numbers assigned at implementation time, in this order): `<NEXT>_device_registry.sql`, `<NEXT>_device_gateway_rpcs.sql`, `<NEXT>_device_offline_alerts.sql`. One additive column on `public.parking_settings` (`device_offline_minutes`). No existing function is redefined.
- **Edge Functions**: new `supabase/volumes/functions/device-gateway/`; `supabase/.gitignore` allowlist; no new env var (uses `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, already passed to the `functions` service).
- **Scheduled jobs**: `supabase/jobs.sh` and `supabase/notifications-cron.sh` gain `notify_offline_devices` and `purge_device_events`.
- **Flutter**: new `lib/features/devices/`, `lib/app/di/modules/devices_module.dart`, `lib/app/router/deferred/devices_entry.dart`, one route in `lib/app/router/app_router.dart`, one destination in `lib/app/shell/app_destinations.dart`, two notification types in `lib/features/notifications/presentation/notification_routes.dart` and `notifications_page.dart`, error codes in `lib/core/l10n/failure_messages.dart`, strings in `lib/l10n/app_es.arb` / `app_en.arb`.
- **Tests**: `supabase/tests/rpc_test.sql`, new Deno tests beside the function, new `test/features/devices/**`, `test/helpers/fake_device_repository.dart`.
- **Docs**: `docs/database.md`, `docs/architecture.md`, `docs/infrastructure.md`, `docs/project-overview.md`, `docs/agent-memory.md`, `CHANGELOG.md`, NEW `docs/device-gateway.md` (protocol reference for firmware authors).
- **Breaking**: none. A lot with no devices behaves exactly as today.
- **Depends on**: nothing. **Required by**: `add-lpr-camera-gate`, `add-barrier-control`, `add-bay-sensors`.

## Non-Goals

- Any device behaviour (plate reads, barrier commands, bay states): those are the three follow-up changes; this one ships only the registry, the authenticated transport and heartbeat.
- An MQTT broker, WebSocket/long-lived device connections, or device-to-device messaging.
- Device provisioning over BLE/Wi-Fi AP, a fleet OTA server, or remote configuration push (firmware reads its config locally; OTA is specified per firmware in the follow-up changes).
- Per-IP rate limiting (the gateway does not hand Postgres a trustworthy client address; the limit is per device).
- Giving operators access to device management (admin of the lot only).
- Mutual TLS / client certificates, and asymmetric per-device keys (see design, rejected alternatives).
