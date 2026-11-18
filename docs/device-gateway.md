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
