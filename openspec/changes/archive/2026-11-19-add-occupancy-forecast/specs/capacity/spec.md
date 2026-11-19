## ADDED Requirements

### Requirement: Public availability exposes an aggregate forecast
The public availability payload SHALL include a `forecast` object for the lot, keeping every existing key, the function signature and the `anon` grant. The object SHALL contain only a status, the timezone and, per group with capacity, the confidence, `full_now`, `full_at` (`HH:mm` or null) and 12 hourly levels (`free`, `busy`, `full`). It SHALL NOT contain vehicle counts, capacities, sample counts, plates, session data or timestamps of individual vehicles. WHERE the lot disabled public visibility the status SHALL be `hidden` with no groups, and any internal error SHALL yield status `unavailable` without failing the availability call.

#### Scenario: Aggregates only
- **WHEN** an anonymous client calls `public_availability(1)` for a lot with enough history
- **THEN** `forecast.groups[0]` has `group`, `confidence`, `full_now`, `full_at` and `hours` with `hour` and `level`, and no `capacity`, `current`, `samples` or `expected` field

#### Scenario: Existing payload unchanged
- **WHEN** the same call is made
- **THEN** `lot`, `max_reservation_hours` and `categories` are identical to the previous contract

#### Scenario: Hidden by the lot
- **WHEN** a lot admin sets `public_enabled` to false
- **THEN** `forecast.status` is `hidden` and `forecast.groups` is empty

#### Scenario: Not enough history
- **WHEN** the lot has too little history
- **THEN** `forecast.status` is `insufficient_history` and no group is returned

#### Scenario: Failure never breaks booking
- **WHEN** the forecast computation raises an error
- **THEN** `public_availability` still returns its categories and `forecast.status` is `unavailable`

#### Scenario: Unknown lot
- **WHEN** an anonymous client asks for a lot that does not exist or is inactive
- **THEN** the function returns null as before

#### Scenario: Internals are not callable
- **WHEN** an anonymous client calls `public_forecast_block`, `forecast_compute` or `public_availability_base`
- **THEN** Postgres denies execution

#### Scenario: Lot isolation
- **WHEN** lot 1 and lot 2 have different histories
- **THEN** each lot's payload reflects only its own sessions

### Requirement: Public booking page shows when the lot fills
The public booking page SHALL show a "¿Cuándo se llena?" card when the forecast is visible, with a sentence per group ("Suele llenarse cerca de las 17:30", "Ahora está lleno" or "No suele llenarse en las próximas horas"), twelve hourly cells that carry an icon and a text label in addition to colour, a semantic label per cell, and a disclaimer that it is an estimate. The card SHALL be hidden when the status is not `ok` or no group is present.

#### Scenario: Visible forecast
- **WHEN** the availability contains a car group with `full_at` 17:30
- **THEN** the page shows "Suele llenarse cerca de las 17:30" and 12 cells

#### Scenario: Hidden forecast
- **WHEN** the status is `hidden`, `insufficient_history` or `unavailable`
- **THEN** no forecast card is rendered and the rest of the page is unchanged

#### Scenario: Colour is not the only signal
- **WHEN** a cell is `full`
- **THEN** it shows a distinct icon and its semantic label says "Lleno"

#### Scenario: Old backend
- **WHEN** the payload has no `forecast` key
- **THEN** the page renders as before without a card

#### Scenario: Narrow screen
- **WHEN** the page renders at 400 px with 1.6 text scale
- **THEN** no overflow occurs
