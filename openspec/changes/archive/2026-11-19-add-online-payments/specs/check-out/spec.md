## ADDED Requirements

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
