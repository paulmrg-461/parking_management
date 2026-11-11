## ADDED Requirements

### Requirement: Loyalty program settings
The system SHALL store the loyalty program of a lot in `parking_settings` (`loyalty_enabled`, `loyalty_visits_required` 2..50, `loyalty_reward_kind` `free_stay` or `fixed_amount`, `loyalty_reward_max_amount`, `loyalty_reward_fixed_amount`, `loyalty_min_amount`, `loyalty_min_minutes` 0..1440, `loyalty_redeem_mode` `auto` or `operator`, `loyalty_stack_with_merchant`, `loyalty_reward_valid_days` 7..730). The program SHALL be disabled by default. Only an admin of the active lot SHALL read or change it, through `get_loyalty_settings` and `set_loyalty_settings`, which SHALL refuse invalid values with `InvalidLoyaltySettingsError`.

#### Scenario: Default is inert
- **WHEN** a lot has never configured loyalty
- **THEN** `loyalty_enabled` is false, no visit is recorded at check-out and every amount equals the previous behaviour

#### Scenario: Admin enables the program
- **WHEN** an admin calls `set_loyalty_settings` with `{"enabled": true, "visits_required": 5}`
- **THEN** the settings are stored, the audit log records the change and `get_loyalty_settings` returns the merged values

#### Scenario: Invalid values
- **WHEN** an admin sends `visits_required` 1, or a `fixed_amount` reward with value 0
- **THEN** the system raises `InvalidLoyaltySettingsError` and stores nothing

#### Scenario: Operator cannot read or change settings
- **WHEN** an operator calls `get_loyalty_settings` or `set_loyalty_settings`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Qualifying visits
WHEN a session of a lot with the program enabled changes from `open` to `closed`, the system SHALL record exactly one `loyalty_visits` row for it and SHALL count it only when the visit was paid: the payment method is not `monthly_pass` and not `exempt`, the ticket was not lost, `amount_charged` is greater than 0 and at least `loyalty_min_amount`, the stay lasted at least `loyalty_min_minutes`, no other counted visit of the same plate exists on the same business day of the lot timezone, and the session did not redeem a reward. A visit that does not count SHALL be stored as `skipped` with the reason `pass`, `lost_ticket`, `exempt`, `below_amount`, `below_minutes`, `same_day` or `reward_redeemed`. The account SHALL be created lazily, per lot and normalized plate.

#### Scenario: Paid visit counts
- **WHEN** a plate pays 9000 for a 2.5 hour stay with `loyalty_min_amount` 3000 and progress 2
- **THEN** the visit is `counted` and the progress becomes 3

#### Scenario: Second visit the same business day
- **WHEN** the same plate closes a second qualifying session on the same business day
- **THEN** the visit is `skipped` with reason `same_day` and the progress does not change

#### Scenario: Short stay or small payment
- **WHEN** a stay lasts 20 minutes with `loyalty_min_minutes` 30, or the charge is below `loyalty_min_amount`
- **THEN** the visit is `skipped` with reason `below_minutes` or `below_amount`

#### Scenario: Pass holder, lost ticket and exempt exits
- **WHEN** a session closes as `monthly_pass`, as a lost ticket, or as `exempt`
- **THEN** the visit is `skipped` with reason `pass`, `lost_ticket` or `exempt` and the progress does not change

#### Scenario: Zero charge never counts
- **WHEN** a merchant benefit makes `amount_charged` 0 and `loyalty_min_amount` is 0
- **THEN** the visit is `skipped` with reason `below_amount`

#### Scenario: Business day uses the lot timezone
- **WHEN** a visit closes at 23:30 and another at 00:10 local time, 40 minutes apart
- **THEN** both are counted on different business days

### Requirement: Earning rewards
WHEN a counted visit makes the plate's progress reach `loyalty_visits_required`, the system SHALL create one `loyalty_rewards` row (`available`) with a snapshot of the reward kind, cap and fixed value, `expires_at = now() + loyalty_reward_valid_days`, link it from the visit as `earned_reward_id`, and reset the progress to 0. Changing the program settings SHALL NOT change the value of rewards already earned.

#### Scenario: Fifth visit earns a reward
- **WHEN** progress is 4 of 5 and a qualifying visit closes
- **THEN** one `available` reward exists for the plate, progress is 0 and `earned_total` increased by 1

#### Scenario: Settings change after earning
- **WHEN** an admin raises `loyalty_reward_fixed_amount` after a reward was earned
- **THEN** the earned reward keeps its snapshot value

#### Scenario: Another lot is independent
- **WHEN** the same plate has progress 4 in lot 1
- **THEN** its progress in lot 2 is unaffected

### Requirement: Reward as a fare line
The system SHALL apply at most one `available`, non-expired reward per session as a `reward` line in the fare composition, through `fare_reward_step` called by `fare_quote`, after the merchant lines and before the manual discount, following the normative composition block of the design. The value SHALL be `min(R, loyalty_reward_max_amount)` for `free_stay` (`R` when no cap) or `min(R, fixed amount)` for `fixed_amount`, SHALL never exceed the running amount, SHALL NOT lower the charge below an amount already paid online, and SHALL be skipped, leaving the reward `available`, when its value is 0 or when `loyalty_stack_with_merchant` is false and a merchant line with a positive amount was applied. The oldest reward SHALL be used first. The preview SHALL be free of side effects.

#### Scenario: Free stay on a midnight-crossing stay
- **WHEN** a 23:00 to 02:00 stay costs 6000 and a no-cap free-stay reward is available in `auto` mode
- **THEN** the reward line is 6000, the amount due is 0 and the line is stored in `fare_adjustments`

#### Scenario: Fixed discount on a capped day
- **WHEN** a day stay is capped at 20000 and a fixed 5000 reward applies
- **THEN** the amount due is 15000

#### Scenario: Cap on a free stay
- **WHEN** the fare is 10000 and the reward is a free stay capped at 8000
- **THEN** the reward line is 8000 and the amount due is 2000

#### Scenario: Stacking with a merchant benefit and pricing
- **WHEN** the base is 9000, pricing makes the gross 10800, a 50 percent merchant benefit gives 5400, a fixed 2000 reward applies and the admin discount is 400
- **THEN** the amount due is 3000

#### Scenario: Exclusive with merchants
- **WHEN** `loyalty_stack_with_merchant` is false and a merchant line with amount 5400 applied
- **THEN** no reward line is added and the reward stays `available`

#### Scenario: Nothing left to discount
- **WHEN** a merchant benefit already reduced the running amount to 0
- **THEN** the reward is skipped with reason `zero` and stays `available`

#### Scenario: Online payment already made
- **WHEN** the customer paid the whole fare online before leaving
- **THEN** the reward is skipped, stays `available` and the charge is unchanged

#### Scenario: Pass holder and lost ticket
- **WHEN** the session is a pass holder's or a lost ticket
- **THEN** no reward line is produced and the reward stays `available`

### Requirement: Redemption bookkeeping at close
WHEN a session closes carrying a `reward` line in `fare_adjustments`, the system SHALL mark that reward `redeemed` with the session, the instant and the amount, inside the closing transaction, without re-declaring `check_out`, and SHALL NOT count that visit.

#### Scenario: Reward redeemed
- **WHEN** a session closes with a reward line of 2000
- **THEN** the reward is `redeemed`, `redeemed_amount` is 2000, the account `redeemed_total` increased by 1 and the visit is `skipped(reward_redeemed)`

#### Scenario: A failure never blocks the exit
- **WHEN** the loyalty bookkeeping raises an unexpected error while a session closes
- **THEN** the session still closes, a `skipped(error)` visit is stored and a warning is logged

### Requirement: Operator redemption choice
The system SHALL let an authenticated user of the lot choose, before check-out and through `choose_loyalty_redemption`, to `redeem`, to `skip` or to clear (`auto`) the redemption of an open session. In `auto` mode the reward SHALL apply unless the choice is `skip`; in `operator` mode it SHALL apply only when the choice is `redeem`, and the preview SHALL report `reason = 'operator_choice_pending'` until the operator chooses.

#### Scenario: Operator mode waits for a choice
- **WHEN** the lot is in `operator` mode, a reward is available and no choice was made
- **THEN** the preview shows the reward as available but not applied

#### Scenario: Operator redeems
- **WHEN** the operator chooses `redeem` and then closes the session
- **THEN** the reward line is applied and the reward is `redeemed`

#### Scenario: Skip in auto mode
- **WHEN** the operator chooses `skip` in `auto` mode
- **THEN** no reward line is applied and the reward stays `available`

#### Scenario: Redeem without a reward
- **WHEN** the plate has no available reward and the choice is `redeem`
- **THEN** the system raises `NoRewardAvailableError`

#### Scenario: Closed session or other lot
- **WHEN** the session is closed, or belongs to another lot
- **THEN** the system raises `SessionAlreadyClosedError` or `LotRequiredError`

#### Scenario: Anonymous cannot choose
- **WHEN** an anonymous client calls `choose_loyalty_redemption`
- **THEN** Postgres denies the call with insufficient privilege

### Requirement: Reward expiry
The system SHALL expire an `available` reward whose `expires_at` has passed, through the job `loyalty_expire_rewards` (executable by `service_role` only), and SHALL NOT apply an expired reward even before the job runs.

#### Scenario: Job expires rewards
- **WHEN** a reward's `expires_at` is in the past and the job runs
- **THEN** the reward becomes `expired` and the job returns the count

#### Scenario: Expired reward is not applied
- **WHEN** a reward is past `expires_at` but still `available`
- **THEN** the fare composition does not apply it

#### Scenario: Job is service-role only
- **WHEN** an authenticated user calls `loyalty_expire_rewards`
- **THEN** Postgres denies the call with insufficient privilege

### Requirement: Reversal of a visit
The system SHALL provide an internal function `loyalty_reverse_visit(p_session_id)`, not executable by API roles, for a future void feature. It SHALL mark the visit `reversed`; when the visit earned a reward still `available` it SHALL reverse that reward and set the progress to `visits_required - 1`; when the earned reward was already redeemed it SHALL keep it and leave the progress unchanged; for a visit that earned nothing it SHALL set the progress to `greatest(progress - 1, 0)`; when the voided session had redeemed a reward that is not yet expired it SHALL restore that reward to `available`. It SHALL never create a reward and SHALL be idempotent.

#### Scenario: Reverse the visit that earned a reward
- **WHEN** the fifth visit that earned an available reward is reversed
- **THEN** the reward is `reversed`, progress is 4 and `earned_total` decreased by 1

#### Scenario: Reward already redeemed
- **WHEN** the earning visit is reversed after its reward was redeemed
- **THEN** the reward stays `redeemed` and the progress is unchanged

#### Scenario: Plain visit
- **WHEN** a counted visit that earned nothing is reversed at progress 3
- **THEN** progress becomes 2, and at progress 0 it stays 0

#### Scenario: Restore a redeemed reward
- **WHEN** the session that redeemed a reward is reversed before the reward expires
- **THEN** the reward becomes `available` again and `redeemed_total` decreases by 1

#### Scenario: Idempotent and private
- **WHEN** the same session is reversed twice, or an authenticated user calls the function
- **THEN** the second call returns `reversed: false`, and the API call is denied with insufficient privilege

### Requirement: Manual progress adjustment
An admin of the active lot SHALL be able to correct a plate's progress with `adjust_loyalty_progress(p_plate, p_delta, p_reason)`, with a mandatory reason of 3 to 200 characters, a delta between -50 and 50 excluding 0, and a resulting progress between 0 and `visits_required - 1`. The adjustment SHALL be stored in `loyalty_adjustments` with the actor and audited, and SHALL never create a reward.

#### Scenario: Correct a missing visit
- **WHEN** an admin adds 1 to a plate at progress 2 with the reason "visit paid in cash, not recorded"
- **THEN** progress is 3 and an adjustment row with the actor exists

#### Scenario: Out of range
- **WHEN** the adjustment would give progress 5 with `visits_required` 5, or below 0
- **THEN** the system raises `LoyaltyAdjustRangeError`

#### Scenario: Reason required
- **WHEN** the reason is empty or shorter than 3 characters
- **THEN** the system raises `LoyaltyReasonRequiredError`

#### Scenario: Operator cannot adjust
- **WHEN** an operator calls `adjust_loyalty_progress`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Privacy and lot isolation
The system SHALL expose no loyalty object to anonymous callers, SHALL let operators read only the counts of `loyalty_plate_status` for the active lot, SHALL let only admins of the active lot select the loyalty tables, and SHALL keep accounts, visits and rewards per lot. Every table SHALL carry `lot_id` and row level security.

#### Scenario: Anonymous access
- **WHEN** an anonymous client selects a loyalty table or calls a loyalty function
- **THEN** Postgres denies it with insufficient privilege

#### Scenario: Operator reads counts only
- **WHEN** an operator selects from `loyalty_visits` directly
- **THEN** no rows are returned, while `loyalty_plate_status` answers with counts

#### Scenario: Other lot
- **WHEN** an admin of lot 2 selects the rows of lot 1
- **THEN** no rows are returned

#### Scenario: Plate normalisation
- **WHEN** the plate is typed as "abc 123"
- **THEN** it is looked up and stored as `ABC123`

### Requirement: Check-in progress and receipts
The system SHALL answer `loyalty_plate_status(p_plate)` for the active lot with the visits, the required number, the next visit number, the count and soonest expiry of available rewards and whether a visit was already counted today, answering `{"enabled": false}` when the program is off and never creating an account. The app SHALL show it at check-in as "Visit n of N", with a reward badge when a reward is available, and SHALL print the progress and the reward line on the entry and exit receipts when known; with no connection nothing SHALL be shown and no check-in or check-out SHALL be blocked.

#### Scenario: Progress for a returning plate
- **WHEN** a plate has progress 3 of 5 and the operator types it at check-in
- **THEN** the screen shows "Visita 4 de 5"

#### Scenario: Reward badge
- **WHEN** the plate has an available reward
- **THEN** the chip shows "Recompensa disponible"

#### Scenario: Program off or offline
- **WHEN** the program is disabled, or the device is offline
- **THEN** no chip is shown and check-in works as before

#### Scenario: Status does not create accounts
- **WHEN** the status of a never-seen plate is requested
- **THEN** it answers zero visits and no account row exists

#### Scenario: Pending-sync receipt
- **WHEN** a receipt is printed for a check-out still pending sync
- **THEN** it prints no loyalty line

### Requirement: Loyalty report
An admin SHALL be able to request `report_loyalty(p_start_date, p_end_date)` for a range of at most 366 days in the lot timezone, returning members, active members, visits counted, skipped (by reason) and reversed, rewards earned, redeemed, expired, reversed and available, the discount given and the ten most frequent plates. The app SHALL offer the report on `/loyalty` with a CSV copy and a PDF share, using raw integers in the CSV.

#### Scenario: Monthly report
- **WHEN** an admin requests November
- **THEN** the counts and the discount given cover only rows created or redeemed in that range

#### Scenario: Invalid range
- **WHEN** the start is after the end, or the span exceeds 366 days
- **THEN** the system raises `InvalidReportRangeError`

#### Scenario: Role and lot isolation
- **WHEN** an operator or an admin of another lot requests the report
- **THEN** the system raises `AdminRequiredError`, or returns only that lot's own figures

#### Scenario: Export
- **WHEN** an admin copies the CSV
- **THEN** it holds `section,label,value` rows with raw integers and no currency symbols
