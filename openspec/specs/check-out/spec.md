# check-out Specification

## Purpose
TBD - created by archiving change check-out. Update Purpose after archive.
## Requirements
### Requirement: Close an open session and compute its fare
An authenticated user SHALL be able to check out an open parking session by its id, closing it with the current time as exit time and charging the fare computed by the `billing` capability. The amount owed SHALL be composed by `fare_quote` as the gross fare, minus the automatic adjustments of the session in the normative order, minus the manual admin discount, never below zero. The session SHALL store the gross amount, the ordered adjustment lines and the final charge, and the response SHALL list them.

#### Scenario: Check out an open session
- **WHEN** an authenticated user checks out a session that is currently open
- **THEN** the system stamps the session's exit time as the current time, computes the fare for the elapsed stay via the category's tariffs, sets the session's status to closed, records the gross amount, the adjustments, the charged amount and a generated ticket number, and returns the updated session

#### Scenario: Check-out with a merchant validation
- **WHEN** the session has a pending merchant validation when it is closed
- **THEN** the validation is applied, the response lists the adjustment line and the charged amount is the amount due after the benefit

#### Scenario: Manual discount stays manual
- **WHEN** an admin closes a session with a manual discount and a merchant validation
- **THEN** `discount_amount` stores only the manual discount and the merchant line is stored in the adjustments

#### Scenario: No merchants configured
- **WHEN** the lot has no merchants
- **THEN** the gross amount equals the charged amount plus the discount and the adjustment list is empty, exactly as before this change

### Requirement: Unknown session is rejected
The system SHALL reject a check-out for a session id that does not exist.

#### Scenario: Unknown session id
- **WHEN** a user checks out a session id that has no matching parking
  session
- **THEN** the system rejects the request with a not-found error

### Requirement: Already-closed session is rejected
The system SHALL reject a check-out for a session that is already closed.

#### Scenario: Session already checked out
- **WHEN** a user checks out a session whose status is already closed
- **THEN** the system rejects the request with a conflict error

### Requirement: Unauthenticated check-out is rejected
The system SHALL reject a check-out request from an unauthenticated caller.

#### Scenario: Missing credentials
- **WHEN** an unauthenticated caller attempts to check out a session
- **THEN** the system rejects the request with an unauthorized error

### Requirement: Check-out accepts a client-supplied exit time
The system SHALL accept an optional client-supplied exit time for a
check-out and use it instead of the server's current time when present.

#### Scenario: Client exit time supplied
- **WHEN** a check-out request includes a `client_exit_time`
- **THEN** the system uses that time (not the current server time) as the
  session's `exit_time` for fare calculation and storage

#### Scenario: Client exit time omitted
- **WHEN** a check-out request omits `client_exit_time`
- **THEN** the system uses the current server time, unchanged from today's
  behavior

### Requirement: Offline check-out queues instead of failing
When a check-out attempt fails due to a network failure (not a
business-rule rejection), the system SHALL capture the device's local time
at that moment and queue the check-out for automatic replay using that
captured time, instead of failing the operator's action.

#### Scenario: Check out while offline
- **WHEN** an authenticated user checks out an open session while the
  device has no connectivity
- **THEN** the app captures the current device time, queues the check-out
  for replay with that time, and shows a pending-sync result with no
  amount or ticket number yet

#### Scenario: Queued check-out replays with the original attempt time
- **WHEN** connectivity is restored after a check-out was queued
- **THEN** the app resubmits the check-out with the originally captured
  exit time, so the fare reflects the moment the operator acted, not the
  moment connectivity returned

#### Scenario: Business-rule rejection still fails immediately
- **WHEN** a check-out is attempted for a session that does not exist or is
  already closed, regardless of connectivity
- **THEN** the system rejects it immediately and does NOT queue it for
  replay

### Requirement: Locked pricing rule in the fare
The gross fare used by check-out, the check-out preview, the public session page and the history reprint SHALL include the session's locked pricing rule (through `fare_pricing_step`), and the breakdown and every receipt SHALL list the applied rule and its delta. A session without lock SHALL be charged the tariff fare exactly as before.

#### Scenario: Receipt lists the rule
- **WHEN** a locked session closes
- **THEN** the receipt shows "Tarifa: Alta ocupacion" and the gross includes its delta

#### Scenario: Unchanged without lock
- **WHEN** a session has no lock
- **THEN** the gross equals the tariff fare

#### Scenario: Offline check-out replay
- **WHEN** a queued check-out replays with `client_exit_time`
- **THEN** the pricing line comes from the stored lock and the base fare up to that exit time, never from current occupancy or rules

### Requirement: Loyalty reward at check-out
WHEN the session being closed has an available loyalty reward and the program rules allow it, the system SHALL include one `reward` line in the fare composition after the merchant lines and before the manual discount, store it in `fare_adjustments`, and show it in the check-out preview, the receipt and the public session summary. The system SHALL NOT add a parameter to `check_out`: the operator's choice SHALL be recorded beforehand with `choose_loyalty_redemption`.

#### Scenario: Reward line at check-out
- **WHEN** an operator closes a session whose plate has an available reward in `auto` mode
- **THEN** the receipt lists the loyalty reward line and the charge is the amount due after it

#### Scenario: Operator mode without a choice
- **WHEN** the lot is in `operator` mode and no choice was recorded
- **THEN** the session closes without the reward and the reward stays available

#### Scenario: Loyalty disabled
- **WHEN** the lot has the program disabled
- **THEN** the preview and the closing amount equal the previous behaviour

### Requirement: Loyalty progress after check-out
The system SHALL count the closed session toward the plate's loyalty progress inside the closing transaction when it qualifies, and the check-out receipt SHALL show the new progress or "reward earned" when the device is online.

#### Scenario: Visit counted when the session closes
- **WHEN** a qualifying paid session closes
- **THEN** the plate's progress increases by one in the same transaction

#### Scenario: Offline replay
- **WHEN** a queued check-out is replayed with its `client_exit_time`
- **THEN** the business day of the visit is computed from that exit time in the lot timezone

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

### Requirement: Check-out of a session paid online
WHEN an operator closes a session whose `online_paid_amount` is greater than zero, THE SYSTEM SHALL apply the exit grace window to the exit instant that the check-out uses, charge `online_paid_amount` inside the window or the recomputed fare outside it, and compute the cash or card due at the desk as the charge minus `online_paid_amount`. WHEN the amount due at the desk is zero, THE SYSTEM SHALL store the method `online` regardless of the method the caller sent and SHALL ignore any cash received. IF cash received is lower than the amount due at the desk, THEN the system SHALL raise `InvalidCashReceivedError`. IF a discount exceeds the amount due at the desk, THEN the system SHALL raise `InvalidDiscountError`.

#### Scenario: Close without collecting
- **WHEN** a session paid online 5 minutes ago is closed
- **THEN** the session is closed as `online`, no cash is recorded and the operator collects nothing

#### Scenario: Collect only the difference
- **WHEN** the grace window is over and the fare rose by 3000 after a 6000 online payment
- **THEN** the operator selects cash, the change is computed against 3000 and the session stores `amount_charged = 9000`

#### Scenario: Offline replay uses the captured exit time
- **WHEN** a queued check-out is replayed with a `client_exit_time` inside the window
- **THEN** the grace rule is evaluated at that exit time, not at the replay time

#### Scenario: Paid session that also has a pass
- **WHEN** a session paid online is closed and the vehicle also has an active monthly pass
- **THEN** the session is stored as `online` with the amount paid and lot admins receive an `online_payment_review` notification

#### Scenario: Other lot
- **WHEN** an operator closes a paid session of a lot they are not a member of
- **THEN** the system raises `LotRequiredError`

### Requirement: Operators see which sessions were paid online
The system SHALL show the paid-online amount and its grace deadline in the open-sessions list and in the check-out preview, and the check-out dialog SHALL show the amount paid, the balance and no payment choice when the balance is zero. WHILE the device is offline and the cached session shows no online payment, THE SYSTEM SHALL warn that the online payment state cannot be confirmed.

#### Scenario: Chip in the list
- **WHEN** an open session has `online_paid_amount > 0`
- **THEN** its tile shows "Pagado en línea"

#### Scenario: Dialog without payment choice
- **WHEN** the preview reports `amount_due = 0`
- **THEN** the dialog hides the payment method and cash fields and its confirm action reads "Confirm exit"

#### Scenario: Offline warning
- **WHEN** the operator starts a check-out while offline
- **THEN** the dialog shows that online payment cannot be verified offline

