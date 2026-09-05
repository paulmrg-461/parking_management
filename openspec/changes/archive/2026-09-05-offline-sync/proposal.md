## Why

Vehicles, tariffs, and categories are admin-facing reference-data CRUD screens
used on-site, where wifi/mobile connectivity can drop briefly. Today every
mutation is remote-only: an `update`/`delete` on a spotty connection fails
outright and the operator must retry once the network returns, even though
nothing about editing a vehicle's color or deactivating a tariff requires the
request to happen at that exact instant. This change lets those two mutation
kinds survive a brief offline window instead of failing.

## What Changes

- Add an outbox (`lib/core/sync/`): a Hive-backed queue of pending
  `update`/`delete` mutations, replayed automatically once connectivity is
  restored (`lib/core/network/connectivity_service.dart` wraps
  `connectivity_plus`).
- `VehicleRepositoryImpl`/`TariffRepositoryImpl`/`CategoryRepositoryImpl`:
  on a `NetworkFailure` from `update`/`delete`, apply the change to the local
  Hive cache (optimistic, merged client-side) and enqueue it instead of
  rethrowing; `SyncService.flush()` replays each queued entry through the
  same repository's own `update`/`delete` method once online.
- **Deliberately narrow scope** — only `update`/`delete` on vehicles,
  tariffs, categories. Everything else (check-in, check-out, monthly-passes,
  and all `create` mutations across the app) is explicitly out of scope; see
  `design.md`'s Non-Goals for the correctness reasons.

## Capabilities

### New Capabilities

- `offline-sync`: outbox-queued `update`/`delete` for vehicles, tariffs, and
  categories, replayed automatically on reconnect.

### Modified Capabilities

(none — `vehicles`, `tariffs`, `categories` specs are unchanged; their
`update`/`delete` behavior when online is identical. This change only adds
behavior for the previously-unspecified offline case.)

## Impact

- Flutter: `pubspec.yaml` (+`connectivity_plus`), new `lib/core/sync/`
  (`pending_mutation.dart`, `sync_outbox.dart`, `sync_service.dart`), new
  `lib/core/network/connectivity_service.dart`, extended
  `Vehicle/Tariff/CategoryLocalDataSource` (+`upsert`/`remove`), extended
  `Vehicle/Tariff/CategoryRepositoryImpl` (`update`/`delete` no longer
  rethrow `NetworkFailure`), `lib/app/di/injection.dart` (new
  `ConnectivityService`/`SyncOutbox`/`SyncService` registrations, repository
  constructors gain a `SyncOutbox` param), `lib/main.dart` (starts
  `SyncService` after DI configuration).
- Backend: none — this is a Flutter-only, client-side resilience change.
- Non-goal: check-in, check-out, monthly-passes, and any `create` mutation
  remain remote-only/unchanged — see `design.md`.
