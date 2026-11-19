## ADDED Requirements

### Requirement: Joining the waitlist
WHILE a lot has `parking_settings.waitlist_enabled = true`, the system SHALL let an anonymous customer join the waitlist of a category by giving a plate, a name, a Colombian mobile, how long they can wait (10 minutes to 24 hours from now) and how long to hold the space once offered (10 to 1440 minutes). The system SHALL refuse the join with `WaitlistNotNeededError` WHEN the capacity check would currently accept a hold for that plate and category. The system SHALL return the entry code, the position in the group queue and the notification channel (`whatsapp` iff `parking_settings.whatsapp_auto`, else `screen`).

#### Scenario: Join while the group is full
- **WHEN** the car group of lot 1 is full and an anonymous customer joins for a car category with a valid plate, name, mobile and windows
- **THEN** an entry with status `waiting` is stored with the group `car`, and the answer carries its id, position 1 and `notify_channel`

#### Scenario: Space is available
- **WHEN** the category still has capacity and a customer tries to join
- **THEN** the system raises `WaitlistNotNeededError` and stores nothing

#### Scenario: Waitlist disabled
- **WHEN** the lot has `waitlist_enabled = false` and a customer tries to join
- **THEN** the system raises `WaitlistDisabledError`

#### Scenario: Invalid wait window
- **WHEN** `p_wait_until` is less than 10 minutes or more than 24 hours ahead, or `p_hold_minutes` is outside 10..1440
- **THEN** the system raises `InvalidWaitWindowError`

#### Scenario: Invalid contact data
- **WHEN** the plate, name or mobile is invalid
- **THEN** the system raises `InvalidPlateError`, `InvalidNameError` or `InvalidPhoneError` respectively

### Requirement: Waitlist limits
The system SHALL allow one active (`waiting` or `offered`) entry per plate and lot (`WaitlistExistsError`), at most two active entries per mobile and lot (`WaitlistLimitError`) and at most `parking_settings.waitlist_max_entries` active entries per lot (`WaitlistFullError`). The system SHALL refuse a join with `ReservationExistsError` WHEN the plate already holds an active reservation.

#### Scenario: Second entry for the same plate
- **WHEN** a plate is already `waiting` in the lot and the same plate joins again
- **THEN** the system raises `WaitlistExistsError`

#### Scenario: Third entry for one mobile
- **WHEN** a mobile has two active entries and joins with a third plate
- **THEN** the system raises `WaitlistLimitError`

#### Scenario: Lot cap reached
- **WHEN** the lot has `waitlist_max_entries` active entries and another customer joins
- **THEN** the system raises `WaitlistFullError`

#### Scenario: Another lot is unaffected
- **WHEN** lot 1 reached its cap and a customer joins lot 2
- **THEN** the entry is created in lot 2

### Requirement: Waitlist is behind the public booking protection
The system SHALL expose the join to anonymous callers only through a gate that refuses with `CaptchaRequiredError` WHILE `parking_settings.public_booking_captcha` is on for the lot, and SHALL perform entry creation in a function executable by the service role alone. The system SHALL refuse a join with `BookingThrottledError` WHEN `parking_settings.public_booking_hourly_limit` entries were created in the lot in the last hour, whatever their status, counted under the advisory lock `hashtext('public_booking_throttle')` for the lot.

#### Scenario: Captcha required
- **WHEN** a lot demands a captcha and an anonymous client calls `public_join_waitlist` directly
- **THEN** the system raises `CaptchaRequiredError` and stores nothing

#### Scenario: Verified function is not reachable by anon
- **WHEN** the `anon` or `authenticated` role calls `public_join_waitlist_verified`
- **THEN** Postgres denies the call with insufficient privilege

#### Scenario: Hourly ceiling
- **WHEN** the ceiling is 2 and two entries were created in the last hour, one of them already left
- **THEN** a third join raises `BookingThrottledError`

#### Scenario: Staff reservations unaffected
- **WHEN** the waitlist ceiling is reached
- **THEN** an operator can still create a reservation from the app

### Requirement: Offers are real holds that cannot overbook
WHEN capacity frees in a group, the system SHALL offer the space to the oldest `waiting` entry of that group by inserting an active reservation (`source = 'waitlist'`, `reserved_until = now() + waitlist_claim_minutes`) after `reservation_capacity_check` accepted it under the group and category locks, and SHALL set the entry `offered` with its `offer_until` and `reservation_id`. The system SHALL NOT create an offer WHEN the group is full, SHALL skip an entry whose category is full without blocking later entries of other categories, and SHALL order entries by creation time and id. Capacity SHALL be freed by a check-out, a hold becoming `cancelled` or `expired`, a bay returning to `active`, or an increase of capacity or decrease of out-of-service spaces.

#### Scenario: Check-out frees a space
- **WHEN** the group is full with one entry waiting and a vehicle of that group checks out
- **THEN** the entry becomes `offered`, an active hold with `source = 'waitlist'` exists, and `public_availability` reports the group full again

#### Scenario: FIFO order
- **WHEN** two entries wait in the same group and one space frees
- **THEN** the entry created first is offered and the second stays `waiting`

#### Scenario: Two spaces free
- **WHEN** two spaces free at once and two entries wait
- **THEN** both entries are offered and the group is full again

#### Scenario: Full category does not block another category
- **WHEN** the first entry's category is full but the second entry's category (same group) has room and the group has room
- **THEN** the second entry is offered and the first stays `waiting`

#### Scenario: Walk-in takes the space first
- **WHEN** a walk-in check-in fills the freed space before the dispatch can offer it
- **THEN** no offer is created and the entry stays `waiting`

#### Scenario: Never exceeds capacity
- **WHEN** a space frees and one entry waits, and a regular public booking and the dispatch compete for it
- **THEN** exactly one of them gets it and open sessions plus active holds never exceed the capacity

#### Scenario: Bay back in service
- **WHEN** a bay returns from `out_of_service` to `active` and an entry of its group waits
- **THEN** the entry is offered

### Requirement: Claiming an offer
WHEN the customer presents the entry code and the mobile (or the desk claims for them) before `offer_until`, the system SHALL extend the offer's reservation to `now() + hold_minutes`, change its source to `public`, set the entry `claimed` and return the reservation in the booking answer shape. WHEN `whatsapp_auto` is on the system SHALL queue the existing `reservation_confirmed` message. The system SHALL refuse a claim with `WaitlistNotOfferedError` on a `waiting` entry and with `OfferNoLongerAvailableError` after the offer lapsed, was cancelled or the entry ended.

#### Scenario: Claim in time
- **WHEN** the customer claims an offered entry before `offer_until`
- **THEN** the hold now ends `hold_minutes` from now, appears as a web reservation (cancellable by code, plate and mobile), and the entry is `claimed`

#### Scenario: Claim after expiry
- **WHEN** the customer claims after `offer_until`
- **THEN** the system raises `OfferNoLongerAvailableError`

#### Scenario: Claim while waiting
- **WHEN** the entry is still `waiting`
- **THEN** the system raises `WaitlistNotOfferedError`

#### Scenario: Wrong mobile
- **WHEN** the code is right but the mobile is not the entry's
- **THEN** the system raises `WaitlistEntryNotFoundError` and changes nothing

#### Scenario: Claim and expiry race
- **WHEN** the expiry job and a claim run at the same moment on one offer
- **THEN** exactly one wins: either the entry is `claimed` or it is `expired`, never both

### Requirement: Expiry and cascade
The system SHALL expire an offer at `offer_until` by setting its reservation `expired` (without grace) and the entry `expired`, and SHALL then offer the freed space to the next entry. The system SHALL expire `waiting` entries whose `wait_until` passed. The jobs service (`supabase/jobs.sh`) and `supabase/notifications-cron.sh` SHALL run `waitlist_expire`, `waitlist_dispatch_all` and `purge_waitlist`, which are executable by the service role only.

#### Scenario: Unclaimed offer cascades
- **WHEN** an offer lapses and a second entry waits in the group
- **THEN** the first entry is `expired`, its hold is `expired`, and the second entry is `offered`

#### Scenario: Waiting entry lapses
- **WHEN** a `waiting` entry passes its `wait_until`
- **THEN** the job marks it `expired`

#### Scenario: Customer arrives before the job runs
- **WHEN** the offered customer checks in with the plate before the job expires the offer
- **THEN** the hold becomes `used` and the next job run marks the entry `claimed`

#### Scenario: Job functions are closed
- **WHEN** an authenticated or anonymous caller executes `waitlist_expire`
- **THEN** Postgres denies the call with insufficient privilege

### Requirement: Leaving the waitlist
The system SHALL let the customer leave with the entry code and the mobile, setting the entry `left`; WHEN the entry was `offered` the system SHALL also cancel its reservation so the space is offered to the next entry.

#### Scenario: Leave while waiting
- **WHEN** a customer leaves a `waiting` entry with the right code and mobile
- **THEN** the entry is `left` and the position of later entries improves

#### Scenario: Leave an offer
- **WHEN** a customer leaves an `offered` entry and another entry waits
- **THEN** the offer's hold is cancelled and the next entry is offered

#### Scenario: Wrong pair
- **WHEN** the mobile does not match the code
- **THEN** the system raises `WaitlistEntryNotFoundError` and nothing changes

### Requirement: Lookup by code and mobile
The system SHALL return an entry created in the last 48 hours for the code and mobile pair, including its status, position, `offer_until` and `reservation_id`, and SHALL return `null` (not an error) WHEN nothing matches. The system SHALL never return an entry for a different mobile or lot.

#### Scenario: Entry found
- **WHEN** the code and mobile match an offered entry
- **THEN** the answer carries status `offered` and `offer_until`

#### Scenario: Nothing matches
- **WHEN** the mobile or the lot differs
- **THEN** the answer is `null`

### Requirement: Desk manages the waitlist
The system SHALL let any member of the lot (operator or admin) list the active entries (`waiting`, `offered`) in order, claim an offer for a customer (`desk_claim_waitlist`) and remove an entry (`desk_remove_waitlist`, which cancels an offered hold). The system SHALL restrict `set_waitlist_settings` to lot admins. The system SHALL refuse a desk call on another lot's entry with `LotRequiredError`. The system SHALL raise to every active lot member a `waitlist_joined` notification per join and a `waitlist_offer` notification per offer, deduplicated per entry and user.

#### Scenario: Operator lists and removes
- **WHEN** an operator opens the board
- **THEN** the active entries of the lot appear with position, contact and offer deadline, and removing one cancels it

#### Scenario: Operator cannot change settings
- **WHEN** an operator calls `set_waitlist_settings`
- **THEN** the system raises `AdminRequiredError` and the settings are unchanged

#### Scenario: Other lot
- **WHEN** an operator of lot 1 acts on an entry of lot 2
- **THEN** the system raises `LotRequiredError`

#### Scenario: Notifications on join and offer
- **WHEN** an entry joins and later receives an offer
- **THEN** each active member of the lot has exactly one `waitlist_joined` and one `waitlist_offer` row for that entry

#### Scenario: Desk told to call without WhatsApp
- **WHEN** an offer is created in a lot with `whatsapp_auto = false`
- **THEN** the `waitlist_offer` notification asks the desk to call the customer

### Requirement: WhatsApp notification with graceful fallback
WHEN an offer is created and `parking_settings.whatsapp_auto` is true, the system SHALL queue one `whatsapp_messages` row with template `waitlist_offer` and parameters `[name, plate, deadline HH24:MI, lot name, code]`, and `whatsapp-dispatch` SHALL map that template. WHILE `whatsapp_auto` is false or the dispatcher has no credentials, the system SHALL keep working: the join answer reports `notify_channel = 'screen'`, the page polls the lookup, and the desk is told to call.

#### Scenario: Offer queues a message
- **WHEN** an offer is created in a lot with `whatsapp_auto = true`
- **THEN** a pending `waitlist_offer` row for the customer's mobile with the five parameters exists

#### Scenario: WhatsApp off
- **WHEN** the lot has `whatsapp_auto = false`
- **THEN** no `whatsapp_messages` row is created and the join answer has `notify_channel = 'screen'`

#### Scenario: Dispatcher knows the template
- **WHEN** a queued `waitlist_offer` row is drained by `whatsapp-dispatch` with credentials
- **THEN** it is sent with the template name from `WHATSAPP_TEMPLATE_WAITLIST_OFFER` (default `waitlist_offer`)

### Requirement: Waitlist data is private and lot-scoped
The system SHALL enable row level security on `reservation_waitlist` and `waitlist_kicks`, grant `select` on the entry table only to `authenticated` with the policy `lot_id = current_lot_id()`, and grant no table privilege to `anon`. The system SHALL delete entries in a terminal status (`claimed`, `expired`, `left`, `cancelled`) older than 30 days through `purge_waitlist`.

#### Scenario: Anon cannot read
- **WHEN** the `anon` role selects from `reservation_waitlist`
- **THEN** Postgres denies the statement

#### Scenario: Member sees only own lot
- **WHEN** an operator of lot 1 selects entries
- **THEN** only lot 1 rows are visible

#### Scenario: Purge
- **WHEN** `purge_waitlist(30)` runs with a `left` entry older than 30 days and a `waiting` one
- **THEN** only the old terminal entry is deleted

### Requirement: Reservation report counts the waitlist
The system SHALL add to `report_reservations` a `waitlist` object with `joined`, `offered`, `claimed`, `expired`, `left`, `cancelled` and `waiting` counts of entries created in the window, and SHALL exclude unclaimed waitlist-source holds from the existing counts.

#### Scenario: Counts
- **WHEN** an entry joined, was offered and claimed inside the window
- **THEN** `waitlist.joined = 1`, `waitlist.offered = 1`, `waitlist.claimed = 1` and the claimed hold counts as a `public` reservation

#### Scenario: Admin only
- **WHEN** an operator calls `report_reservations`
- **THEN** the system raises `AdminRequiredError` as before

### Requirement: Public page offers the waitlist when full
WHEN `PublicBookingAvailability.hasAvailability` is false or a category `isFull`, and the lot reports the waitlist enabled, the booking page SHALL show a join form (same captcha field as the booking form), then the entry status with position and code, the claim and leave actions when offered, and a lookup by code and mobile. The page SHALL show the four states (loading skeleton, content, empty = card hidden when disabled, error with retry) and SHALL never queue waitlist calls offline.

#### Scenario: Full lot shows the form
- **WHEN** every category is full and the waitlist is enabled
- **THEN** the page shows the join form below the no-space notice

#### Scenario: Offer shown and claimed
- **WHEN** the customer's entry becomes offered
- **THEN** the card shows the deadline and a claim button, and claiming shows the normal confirmation with the hold

#### Scenario: Disabled
- **WHEN** the lot has the waitlist disabled
- **THEN** the page looks as it does today

#### Scenario: Offline
- **WHEN** the device is offline and the customer joins
- **THEN** the card shows a retryable error and nothing is stored locally
