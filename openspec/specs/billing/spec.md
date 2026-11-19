# billing Specification

## Purpose
TBD - created by archiving change billing. Update Purpose after archive.
## Requirements
### Requirement: Hourly billing with ceil-to-hour rounding
The system SHALL bill a parking stay's day-rate portion at the category's
hourly rate, rounding any fractional hour up to the next whole hour.

#### Scenario: Exact one hour
- **WHEN** a stay's day-rate portion lasts exactly one hour
- **THEN** the system charges exactly one hour at the hourly rate

#### Scenario: Fractional hour rounds up
- **WHEN** a stay's day-rate portion lasts one hour and five minutes
- **THEN** the system charges two hours at the hourly rate

### Requirement: Night tariff replaces the day tariff during its window
The system SHALL bill the portion of a stay that falls inside the category's
configured night window (`start_time`..`end_time`, which may cross midnight)
at the night rate instead of the hourly rate, never both.

#### Scenario: Stay entirely inside the night window
- **WHEN** a stay's entry and exit both fall inside the night window
- **THEN** the system bills the entire stay at the night rate, not the
  hourly rate

#### Scenario: Stay crosses from day into the night window
- **WHEN** a stay starts before the night window and ends inside it
- **THEN** the system bills the portion before the window at the hourly
  rate and the portion inside the window at the night rate, as separate
  amounts, not a blended rate

#### Scenario: Night window crosses midnight
- **WHEN** the night window is configured as, for example, `22:00` to
  `06:00`, and a stay starts inside the window before midnight and ends
  inside the window after midnight
- **THEN** the system treats the entire stay as inside the night window with
  no false rate switch at midnight

### Requirement: Daily rate caps each calendar day's charge
The system SHALL cap the charge for each calendar day a stay overlaps at the
category's daily rate, applied independently per calendar day, when a daily
rate is configured for the category.

#### Scenario: Multi-day stay is capped per day, not unbounded
- **WHEN** a stay spans multiple calendar days
- **THEN** the system charges, for each calendar day overlapped, the lower
  of that day's computed hourly/nightly charge or the daily rate, and sums
  those per-day amounts — never `total hours * hourly rate` unbounded

### Requirement: Active monthly pass overrides the charge to zero
The system SHALL charge zero for a stay when the caller indicates the
vehicle has an active monthly pass, regardless of the stay's duration or any
tariff amount.

#### Scenario: Monthly pass active
- **WHEN** a fare is calculated with an active monthly pass indicated
- **THEN** the system returns a charge of zero

### Requirement: Invalid billing period is rejected
The system SHALL reject a fare calculation whose exit time is not strictly
after its entry time.

#### Scenario: Exit at or before entry
- **WHEN** a fare is calculated with an exit time that is equal to or
  earlier than the entry time
- **THEN** the system rejects the request with a validation error

### Requirement: Charge is never negative
The system SHALL never return a negative charge, even when given a
malformed or non-positive tariff amount.

#### Scenario: Non-positive tariff amount
- **WHEN** a fare is calculated using a tariff whose amount is zero or
  negative
- **THEN** the system returns a charge of zero for that portion, never a
  negative amount

### Requirement: Charged amounts are tax-inclusive
The system SHALL treat every stored charge (`amount_charged`, pass charge amounts) as the total the customer pays, tax included, and SHALL derive the tax for fiscal documents from that total with the lot's configured rate, never altering the fare calculation or the amount charged. The tax base SHALL equal the total times 10000 divided by (10000 plus the rate in basis points), rounded to the nearest peso, and the tax SHALL equal the total minus the tax base.

#### Scenario: Tax extracted from the charge
- **WHEN** a session was charged 11900 and the lot rate is 1900 basis points
- **THEN** the fiscal document shows tax base 10000, tax 1900 and total 11900

#### Scenario: Fare unchanged
- **WHEN** invoicing is switched on for a lot
- **THEN** `calculate_fare` and `check_out` return the same amounts as before

#### Scenario: Zero rate
- **WHEN** the lot rate is 0
- **THEN** the tax base equals the total and the tax is 0

