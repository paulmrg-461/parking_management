## 1. Backend: check-out accepts client-supplied exit time

- [x] 1.1 `app/presentation/schemas.py`: add `CheckOutRequest` (optional
  `client_exit_time: datetime | None = None`)
- [x] 1.2 `app/presentation/routes/check_outs.py`: `create_check_out` accepts
  an optional JSON body (`CheckOutRequest`), passes `client_exit_time`
  through to `CheckOutService.close_session(session_id, exit_time=...)`
- [x] 1.3 `backend/tests/test_check_out_endpoints.py`: add a case asserting
  a supplied `client_exit_time` is used for the fare calc / stored
  `exit_time` (not server "now"), and a case confirming omitting it keeps
  today's server-time behavior

## 2. Flutter: domain/entity changes

- [x] 2.1 `ParkingSession` (`check_in/domain/entities/parking_session.dart`):
  add `ParkingSessionStatus.pendingSync`
- [x] 2.2 `CheckOutReceipt`: `amountCharged`/`ticketNumber` become nullable,
  add `pendingSync` (bool)
- [x] 2.3 `PendingMutation`: `entityId` becomes `int?`; update
  `toJson`/`fromJson` accordingly

## 3. Flutter: persisted photo storage for queued check-ins

- [x] 3.1 `lib/core/sync/pending_photo_storage.dart`: copy a list of `File`s
  into `getApplicationSupportDirectory()/pending_check_ins/<clientRef>/`,
  return the persisted paths; a `deleteFor(clientRef)` to clean up after
  a successful replay

## 4. Flutter: check-out offline path

- [x] 4.1 `CheckOutRepositoryImpl.checkOut`: on `NetworkFailure`, capture
  `DateTime.now()`, enqueue a `checkOut`/`close` `PendingMutation`
  (`entityId: sessionId`, payload `client_exit_time`), return a pending
  `CheckOutReceipt` (`pendingSync: true`, `amountCharged`/`ticketNumber`
  null) instead of rethrowing
- [x] 4.2 `CheckOutRemoteDataSource.checkOut`: accept an optional
  `clientExitTime` param, include it in the POST body when present (used by
  replay; online path still omits it, unchanged behavior)
- [x] 4.3 `check_out_page.dart`: when `CheckOutSuccess.receipt.pendingSync`
  is true, show "Queued — amount pending sync" instead of the numeric
  receipt/ticket

## 5. Flutter: check-in offline path

- [x] 5.1 `CheckInRepositoryImpl.createCheckIn`: on `NetworkFailure`,
  persist photos via `PendingPhotoStorage`, capture `DateTime.now()` as
  `client_entry_time`, enqueue a `checkIn`/`create` `PendingMutation`
  (`entityId: null`, payload: plate, persisted photo paths,
  `client_entry_time`, `clientRef`), return an optimistic `ParkingSession`
  (synthetic negative id, `status: pendingSync`) instead of rethrowing
- [x] 5.2 `check_in_page.dart`: render `pendingSync` sessions with a
  "pending sync" badge instead of treating them as a normal open session

## 6. Flutter: SyncService replay

- [x] 6.1 `SyncService._replay`: dispatch `'checkOut'` ->
  `_replayCheckOut`, `'checkIn'` -> `_replayCheckIn`
- [x] 6.2 `_replayCheckOut`: decode `client_exit_time`, call
  `CheckOutRepository.checkOut(sessionId, clientExitTime: ...)` (repository
  interface gains this optional param, forwarded to the remote data source)
- [x] 6.3 `_replayCheckIn`: rebuild `File` list from persisted paths, call
  `CheckInRepository.createCheckIn(plate: ..., photos: ...)`; on success,
  delete the persisted photo directory via `PendingPhotoStorage.deleteFor`

## 7. Wiring

- [x] 7.1 `lib/app/di/injection.dart`: register `PendingPhotoStorage`; pass
  `SyncOutbox` into `CheckInRepositoryImpl`/`CheckOutRepositoryImpl`
  constructors; `SyncService` registration gains `CheckInRepository`/
  `CheckOutRepository` dependencies

## 8. Tests

- [x] 8.1 `check_out_repository_impl_test.dart`: Success (online, unchanged),
  Failure (`NetworkFailure` -> pending receipt + correct enqueue payload,
  no rethrow), Security/robustness (captured time is the *attempt* time,
  not a later time)
- [x] 8.2 `check_in_repository_impl_test.dart`: Success (unchanged),
  Failure (`NetworkFailure` -> photos persisted + optimistic pending
  session + correct enqueue payload), Security/robustness (photo bytes
  actually survive deletion of the original transient file)
- [x] 8.3 `pending_photo_storage_test.dart`: copy round-trip, `deleteFor`
  removes exactly that `clientRef`'s files and no others
- [x] 8.4 `sync_service_test.dart`: extend with `checkIn`/`checkOut` replay
  cases (success removes from outbox + cleans up photos; `NetworkFailure`
  leaves queued, same as existing entity types)
- [x] 8.5 Update any test currently asserting check-in/check-out rethrow
  `NetworkFailure` unconditionally (this is now only true for genuinely
  non-network failures, e.g. `VehicleNotFoundError`/`ValidationFailure`,
  which must still propagate un-queued)

## 9. Verification

- [x] 9.1 `cd backend && uv run pytest` (all green)
- [x] 9.2 `flutter analyze` (0 issues)
- [x] 9.3 `flutter test` (all green)
- [x] 9.4 `openspec validate offline-check-in-out --strict`
- [x] 9.5 `openspec archive offline-check-in-out -y`
- [x] 9.6 Update `PROGRESS.md` (archived table row, test counts, key
  decisions note re: pending-sync receipts)
