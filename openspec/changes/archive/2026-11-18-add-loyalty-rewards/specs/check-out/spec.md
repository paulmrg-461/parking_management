## ADDED Requirements

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
