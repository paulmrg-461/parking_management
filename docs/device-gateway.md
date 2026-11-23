# Device gateway protocol

Hardware devices never use a user account. Register one in `/devices` (next
batch) or with `register_lot_device` and keep the `pkd_…` key it returns: it is
shown once.

## Request headers

| Header | Required | Notes |
|---|---|---|
| `X-Device-Key` | except `/v1/time` | `pkd_<12 hex>_<64 hex>` |
| `X-Device-Seq` | except `/v1/time` | strictly increasing per device; build it as `(boot_counter << 32) | request_counter` |
| `X-Device-Timestamp` | except `/v1/time` | Unix seconds; ±5 minutes |
| `X-Device-Firmware` | no | free text, ≤ 40 chars |

## Endpoints

- `GET /functions/v1/device-gateway/v1/time` → `{server_time, max_skew_s}`.
- `POST /functions/v1/device-gateway/v1/heartbeat` with `{"status": {...}}` →
  `{server_time, heartbeat_interval_s, offline_minutes, device}`. `status` is a
  JSON object up to 2 KB.

Errors are JSON `{message}` with `401` (unauthorized/disabled), `409` (replay),
`400` (clock skew) or `429` (rate limit, see `retry_after_s`). Retry with a new
sequence and timestamp and the same idempotency key on network errors, 429 or
5xx.

The API key is stored as a SHA-256 hash; rotate it from the admin screen if it
leaks. The gateway derives the lot from the registry, never from a header.

## Automated protocol smoke (no hardware)

`test/integration/device_gateway_test.dart` exercises the real path against a
running stack: it signs in as a lot admin, registers a `camera` device, calls
`/v1/time`, sends a heartbeat, then asserts the branches that firmware relies on
— replay (`409`), clock skew (`400`), a tampered key (`401`) and recovery with
the right key (`200`) — and finally checks the audit events. The wrapper
`integration_test/app_flow_test.dart` runs it next to the check-in flow:

```bash
SUPABASE_URL=http://localhost:8017 \
SUPABASE_ANON_KEY=$(grep '^ANON_KEY=' .env | cut -d= -f2-) \
flutter test -d linux integration_test/app_flow_test.dart
```

It skips when the environment is not configured. What still needs real
hardware: boot behaviour, retry/backoff on a physical network and firmware
updates.

## LPR routes (cameras only)

- `GET /v1/lpr/config` → `{direction, min_confidence, vote_window_seconds,
  heartbeat_interval_s}`; `400 LprDirectionNotSetError` until an admin assigns
  the direction.
- `POST /v1/lpr/reads` → the read outcome. Body ≤ 4 KiB and the
  `Idempotency-Key` header **must** equal `client_ref` (400 otherwise).
- `PUT /v1/lpr/events/:id/snapshot` → `{event_id, session_id}`. Body: JPEG
  (magic `FF D8 FF`) ≤ 256 KiB; `409 SnapshotAlreadyAttachedError` is success
  for the device. The object path is built from the authenticated device, never
  from the request.

All three use the standard headers (key, sequence, timestamp, firmware) and
answer `403 InvalidDeviceKindError` for a non-camera device. The full path is
covered by the automated smoke: it registers a camera, assigns the direction,
posts three reads (one `assist` event) and uploads a small JPEG.

## Bay sensor routes (kind `sensor_hub`)

- `GET /v1/bays/config` → `{report_interval_s, stable_ms, channels:[{ch,
  type, threshold, hysteresis, mapped}]}`.
- `POST /v1/bays/report` with `{"channels":[{"ch":1,"state":"occupied",
  "raw":900,"at":"..."}],"full":true}` (body ≤ 16 KiB) →
  `{accepted, ignored, created_channels}`. Feed the channels in order; the
  server ignores an `at` that is not newer than the last report.
- `GET /v1/bays/firmware?current=1.0.0` and
  `GET /v1/bays/firmware/:version/image` (released `sensor_hub` images only).

A non-`sensor_hub` device gets `403`. The whole path is covered by the
automated smoke: register a hub, read the config and report two channels.
