## 1. Backend domain

- [x] 1.1 Add `ParkingSession` entity (`id`, `vehicle_id`, `operator_id`,
  `entry_time`, `status`) and `SessionStatus` enum (`open`/`closed`) in
  `app/domain/parking_session.py`
- [x] 1.2 Add `EvidencePhoto` entity (`id`, `session_id`, `file_path`,
  `taken_at`) in `app/domain/evidence_photo.py`
- [x] 1.3 Add `ParkingSessionRepository` and `EvidencePhotoRepository`
  abstract ports (async, `abstractmethod`-only) to `app/domain/repositories.py`
- [x] 1.4 Add `EvidenceStoragePort` abstract port (`async def save(filename,
  content) -> str`) in `app/domain/evidence_storage.py`

## 2. Backend infrastructure (DB + storage)

- [x] 2.1 Add `ParkingSessionModel` and `EvidencePhotoModel` SQLAlchemy models
  to `app/infrastructure/models.py`
- [x] 2.2 Add Alembic migration `0005_create_parking_sessions.py`
- [x] 2.3 Add Alembic migration `0006_create_evidence_photos.py`
- [x] 2.4 Add `SqlAlchemyParkingSessionRepository` in
  `app/infrastructure/repositories/parking_session_repository.py`
- [x] 2.5 Add `SqlAlchemyEvidencePhotoRepository` in
  `app/infrastructure/repositories/evidence_photo_repository.py`
- [x] 2.6 Add `LocalEvidenceStorage` adapter in
  `app/infrastructure/local_evidence_storage.py`; add `evidence_storage_path`
  to `Settings`
- [x] 2.7 Write 3 tests (Success / Failure / Security) for the parking session
  repository

## 3. Backend application

- [x] 3.1 Add `CheckInService` (`app/application/check_in_service.py`) with
  `create_check_in(plate, operator_id, photo_paths) -> ParkingSession` and
  `list_open_sessions()`
- [x] 3.2 Raise `VehicleNotFoundError` for an unknown plate and
  `DuplicateOpenSessionError` for a vehicle with an already-open session

## 4. Backend presentation (routes)

- [x] 4.1 Add `CheckInCreate`/`CheckInRead`/`EvidencePhotoRead` schemas to
  `app/presentation/schemas.py`
- [x] 4.2 Add `POST /check-ins` (multipart: `plate` + `photos`, authenticated)
  and `GET /check-ins` (list open sessions, authenticated) in
  `app/presentation/routes/check_ins.py`
- [x] 4.3 Add `get_parking_session_repository`, `get_evidence_photo_repository`,
  `get_evidence_storage` factories to `app/presentation/deps.py`
- [x] 4.4 Mount the `check_ins` router in `app/main.py`
- [x] 4.5 Add `python-multipart` to `backend/pyproject.toml`
- [x] 4.6 Write 3 tests (Success / Failure / Security) for the check-in
  endpoints, including that uploaded photo bytes land on disk at the returned
  path

## 5. Verification

- [x] 5.1 Run `alembic upgrade head` (or verify migration syntax if no DB is
  reachable in this environment)
- [x] 5.2 Confirm `pytest` passes (all pre-existing tests + new ones)
- [x] 5.3 Confirm `openspec validate check-in` passes

## 6. Flutter (parallel implementation against the API contract above)

- [x] 6.1 Add `lib/features/check_in/domain/` (`ParkingSession` entity +
  `ParkingSessionStatus` enum, `CheckInRepository` port)
- [x] 6.2 Add `CheckInCubit` (`application/`) orchestrating scan/manual plate
  entry + photo capture + submit, client-side plate validation via
  `normalizePlate`
- [x] 6.3 Add `DioCheckInRemoteDataSource` (multipart upload) +
  `ParkingSessionDto` + `CheckInRepositoryImpl` (remote-only, no local cache)
- [x] 6.4 Add `CheckInPage` (scan-plate button reusing `/scan`, manual
  fallback, photo capture reusing `plate_scanning`'s image-capture
  abstraction, open-sessions list) + `/check-in` route + home-page entry point
- [x] 6.5 Register in DI (`injection.dart`)
- [x] 6.6 Write 3 tests (Success / Failure / Security) per layer
- [x] 6.7 Confirm `flutter analyze` (0 issues) and `flutter test` (all green)
  pass with both the backend and Flutter halves merged
