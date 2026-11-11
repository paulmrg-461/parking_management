## Why

The slot board shows what the system *believes*: a bay is "occupied" when an open session has `spot_id` set (`slot_board()` in `0072`, drawn by `lib/features/home/presentation/widgets/slot_board_card.dart`). Reality drifts: a car parks in a bay nobody checked in, a session is assigned to bay A3 while the car sits in A4, a car stays in a bay an admin took out of service, or a session lingers after the car left. Today nothing notices, and capacity, no-show holds and overstay alerts are all based on the same belief.

Per-bay occupancy sensors give the board a second, physical signal and let the system raise a notification when the two disagree, without changing how capacity, billing or check-in work.

## What Changes

- NEW sensor registry `bay_sensors` (hub device + channel mapped to a `parking_spots` row, type, threshold, last state, health inputs), `bay_sensor_events` (state transitions), `bay_mismatches` (open/resolved anomalies), `bay_sensor_settings` (per lot: debounce, stale minutes, flap limit, grace, cooldown).
- NEW service-role RPCs `device_bay_config`, `device_bay_report`; gateway routes (kind `sensor_hub`): `GET /v1/bays/config`, `POST /v1/bays/report`, `GET /v1/bays/firmware`, `GET /v1/bays/firmware/:version/image`.
- NEW server-side debounce (effective state computed at read time from the hub's report time), health (`unmapped`, `never_seen`, `stale`, `fault`, `flapping`, `ok`) and mismatch detection of three kinds: `occupied_unassigned`, `assigned_empty`, `occupied_out_of_service`.
- NEW RPCs `bay_occupancy`, `list_bay_sensors`, `map_bay_sensor`, `unmap_bay_sensor`, `set_bay_sensor_threshold`, `dismiss_bay_mismatch`, `get_bay_sensor_settings`, `set_bay_sensor_settings`; jobs `evaluate_bay_mismatches`, `purge_bay_sensor_events`.
- NEW notifications `bay_mismatch` (lot members) and `bay_sensor_unhealthy` (lot admins).
- Flutter: sensor state overlaid on the slot board cells (`SpotCellView`), a bay-alerts card on the dashboard, a sensor section in the bay editor (`/spots`) with health, raw reading, threshold and mapping, and a settings sheet. Lots with no sensors see no change.
- NEW ESP32-S3 hub firmware under a NEW top-level `edge/bay-hub/` (C++, PlatformIO/ESP-IDF): RS-485 ultrasonic and dry-contact drivers behind one interface, per-channel filtering, change-driven reports with a periodic snapshot, offline buffering, TLS with a pinned CA, signed OTA.

## Capabilities

### New Capabilities

- `bay-sensors`: mapping sensors to bays, receiving and debouncing reports, health, real occupancy on the board, mismatch detection and alerts, settings, hub behaviour.

### Modified Capabilities

- `notifications`: bay mismatch and sensor-unhealthy alerts.

## Impact

- **Database** (numbers at implementation time, order): `<NEXT>_bay_sensors.sql`, `<NEXT>_bay_sensor_ingest.sql`, `<NEXT>_bay_sensor_rpcs.sql`.
- **Edge Function**: `supabase/volumes/functions/device-gateway/routes/bays_*.ts`; the firmware routes share handlers with `add-barrier-control` (extract `routes/firmware_common.ts` if that change shipped first).
- **Scheduled jobs**: `supabase/jobs.sh`, `supabase/notifications-cron.sh`.
- **Flutter**: NEW `lib/features/bay_sensors/**`; modified `lib/features/home/application/dashboard_cubit.dart` (optional occupancy), `lib/features/home/presentation/widgets/slot_board_card.dart`, `lib/features/home/presentation/home_page.dart`, `lib/features/spots/presentation/spots_page.dart` and `widgets/spot_cell_view.dart`, DI, notification routing, error codes, ARB.
- **Firmware**: `edge/bay-hub/**` (NEW) and `edge/common/device_core/**` (NEW, shared with `edge/barrier`).
- **Docs**: `docs/bay-sensors.md` (NEW), `docs/slot-board.md` (new section), `docs/database.md`, `docs/architecture.md`, `docs/infrastructure.md`, `docs/project-overview.md`, `docs/agent-memory.md`, `CHANGELOG.md`.
- **Breaking**: none. `slot_board()`, `capacity_snapshot()`, `check_in`, `check_out` are not redefined.
- **Depends on**: `add-device-gateway`. Shares `device_firmware` with `add-barrier-control`.

## Non-Goals

- Sensors never change capacity, availability, billing, check-in or reservation logic; the session remains the source of truth. A sensor is advisory.
- Automatic correction (assigning a session to a bay, closing a session) from sensor data.
- Vehicle identification by sensor, per-bay cameras, guidance signs/LEDs, EV charging state.
- Several sensors per bay (one sensor per bay in this version) and sensors for lots with no mapped bays.
- Battery/LoRa wireless in-ground sensors (the hub reads wired sensors).
