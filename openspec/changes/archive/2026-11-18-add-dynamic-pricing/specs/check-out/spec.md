## ADDED Requirements

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
