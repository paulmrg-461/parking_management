## 1. Dependencies

- [x] 1.1 Add `connectivity_plus` to `pubspec.yaml`, `flutter pub get`

## 2. Core sync primitives

- [x] 2.1 `lib/core/sync/pending_mutation.dart`: `PendingMutation` (entityType,
  operation, entityId, payloadJson, enqueuedAt) with `toJson`/`fromJson`
- [x] 2.2 `lib/core/sync/sync_outbox.dart`: abstract `SyncOutbox`
  (`enqueue`/`listPending`/`remove`) + `HiveSyncOutbox` (JSON-in-`Box<String>`,
  no Hive adapter/typeId needed)
- [x] 2.3 `lib/core/network/connectivity_service.dart`: abstract
  `ConnectivityService` (`isOnline`/`onConnectivityChanged`) +
  `ConnectivityPlusService` wrapping `connectivity_plus`
- [x] 2.4 `lib/core/sync/sync_service.dart`: `SyncService(outbox,
  connectivity, vehicles, tariffs, categories)` with `start()` (subscribe +
  eager flush) and `flush()` (replay each pending entry via the repository's
  own `update`/`delete`, remove on success, leave queued on `NetworkFailure`,
  never let one entry block another)

## 3. Local data sources (generic single-entity write)

- [x] 3.1 `VehicleLocalDataSource`/`HiveVehicleLocalDataSource`: add
  `upsert(Vehicle)`/`remove(int id)`
- [x] 3.2 `TariffLocalDataSource`/`HiveTariffLocalDataSource`: add
  `upsert(Tariff)`/`remove(int id)`
- [x] 3.3 `CategoryLocalDataSource`/`HiveCategoryLocalDataSource`: add
  `upsert(Category)`/`remove(int id)`

## 4. Repository impls (update/delete gain an offline branch)

- [x] 4.1 `VehicleRepositoryImpl`: constructor gains `SyncOutbox`; `update`
  merges the patch client-side and enqueues on `NetworkFailure` instead of
  rethrowing; `delete` removes from cache and enqueues on `NetworkFailure`
- [x] 4.2 `TariffRepositoryImpl`: same pattern (merge mirrors
  `UpdateTariffCommand`'s patch fields)
- [x] 4.3 `CategoryRepositoryImpl`: same pattern (category's `update(id,
  name)` has no separate command type — the merged record is just
  `Category(id, name)`)

## 5. Wiring

- [x] 5.1 `lib/app/di/injection.dart`: register `ConnectivityService` and
  `SyncOutbox` early (alongside `KeyValueStore`); pass `SyncOutbox` into the
  three repository registrations; register `SyncService` after all three
  repositories
- [x] 5.2 `lib/main.dart`: `serviceLocator<SyncService>().start()` right
  after `configureDependencies()`

## 6. Tests

- [x] 6.1 `test/core/sync/sync_outbox_test.dart`: enqueue/listPending/remove
  round-trip, multiple independent entries
- [x] 6.2 `test/core/sync/sync_service_test.dart`: Success (replay + remove
  on reconnect), Failure (still-`NetworkFailure` replay stays queued, no
  throw), Security/robustness (one poison entry does not block a second,
  independent entry in the same `flush()`), offline no-op case
- [x] 6.3 Update `vehicle_repository_test.dart`/`tariff_repository_test.dart`/
  `category_repository_test.dart`: pass a fake `SyncOutbox`, keep all
  pre-existing cases green, add update/delete-offline cases asserting no
  rethrow + optimistic merged result + correct `enqueue` call

## 7. Verification

- [x] 7.1 `flutter analyze` (0 issues)
- [x] 7.2 `flutter test` (all green, pre-existing 96 + new = 108)
- [x] 7.3 `openspec validate offline-sync --strict`
- [x] 7.4 `openspec archive offline-sync -y`
- [x] 7.5 Update `PROGRESS.md` (archived table, empty remaining-changes
  section, test counts, key decisions note)
