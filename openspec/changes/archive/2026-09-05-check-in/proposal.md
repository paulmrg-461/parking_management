## Why

Operators need to register a vehicle entry (check-in) and capture damage evidence
photos (dents/scratches) at that moment, before the vehicle enters the lot. Today
there is no way to open a parking session for a vehicle or attach entry-time
evidence photos to it. This is the operational entry point that `check-out` and
billing will later close and settle.

## What Changes

- Add a `parking_sessions` concept: an open/closed session tied to a vehicle and
  the operator who checked it in, with an `entry_time`.
- Add an `evidence_photos` concept: one or more photos attached to a session at
  check-in, stored on disk (or a future object store) behind a storage port.
- Add backend endpoints: `POST /check-ins` (multipart: plate + photo files,
  authenticated) and `GET /check-ins` (list open sessions, authenticated).
- Reject check-in for an unknown plate (404) or for a vehicle that already has an
  open session (409).

## Capabilities

### New Capabilities

- `check-in`: register a vehicle entry (parking session) with optional damage
  evidence photos, for an authenticated operator or admin, rejecting unknown
  plates and duplicate open sessions.

### Modified Capabilities

(none)

## Impact

- Backend: `ParkingSession` + `EvidencePhoto` domain entities; `ParkingSessionModel`
  + `EvidencePhotoModel` and Alembic migrations; `ParkingSessionRepository` +
  `EvidencePhotoRepository` ports and SQLAlchemy impls; `EvidenceStoragePort` +
  `LocalEvidenceStorage` adapter; `CheckInService`; `check_ins` router; schemas.
- Flutter: handled by a parallel change (not in scope here).
- `openspec/specs/` gains `check-in` after archive.
