## ADDED Requirements

### Requirement: Optional exit photos at check-out
The check-out dialog SHALL offer an optional "Exit photos" section (0 to 5 photos) when the device is online, captured with the same image capture and compression as check-in photos (JPEG, quality 80, at most 1920 px) and subject to the same 5 MB per-photo limit. After a check-out that completed online (a receipt that is not `pendingSync`), the app MUST upload the photos with insert-only uploads to the `evidence` bucket under `exit-<sessionId>-<clientRef>/<index>.<ext>` and register them with `add_exit_evidence`. The `clientRef` MUST be generated before the first attempt and reused on retries. A failure to store exit photos MUST NOT undo or block the check-out and MUST offer a retry. The `check_out` RPC signature MUST NOT change.

#### Scenario: Exit photos saved after check-out
- **WHEN** an online operator captures two exit photos in the check-out dialog and confirms payment
- **THEN** the session is closed first and then both photos are uploaded and registered as exit evidence, and the app confirms "Exit photos saved"

#### Scenario: Upload failure does not undo the check-out
- **WHEN** the check-out succeeds but the exit photo upload fails with a network error
- **THEN** the session stays closed, the app shows "Exit photos could not be saved" with a retry that reuses the same `clientRef`

#### Scenario: Offline check-out
- **WHEN** the device is offline or the receipt is `pendingSync`
- **THEN** the exit photo section shows that exit photos need a connection (or, if the receipt turned out pending, the photos are discarded and the operator is told) and the queued check-out is unaffected

#### Scenario: Photo too large
- **WHEN** a captured exit photo exceeds 5 MB
- **THEN** it is rejected with the existing photo-too-large message and not added

#### Scenario: Offer the comparison
- **WHEN** exit photos were saved and the session has entry photos and the AI feature is configured
- **THEN** the confirmation offers "Compare with entry photos", which only navigates and never starts a comparison by itself

### Requirement: Entry and exit evidence are shown separately
The in-app evidence sheet SHALL group a session's photos under "Entry photos" and "Exit photos" using `evidence_photos.phase` and SHALL offer a "Compare" action when both groups contain photos. The photo counts shown by existing screens (`photo_count`) MUST continue to count every evidence file of the session.

#### Scenario: Two sections
- **WHEN** a session has 3 entry photos and 2 exit photos
- **THEN** the sheet shows two sections with 3 and 2 photos and a Compare action

#### Scenario: Entry only
- **WHEN** a session has only entry photos
- **THEN** the sheet shows the existing single gallery without a Compare action
