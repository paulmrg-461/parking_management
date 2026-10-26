## ADDED Requirements

### Requirement: Discounts are audited
The system SHALL let only admins apply a discount, require a reason, store the
actor/instant and report the total discounted amount.

#### Scenario: Admin discount
- **WHEN** an admin closes a session with a 1000 discount and a reason
- **THEN** the session stores the discount and the receipt shows it

#### Scenario: Operator discount
- **WHEN** an operator sends a discount
- **THEN** the check-out is rejected and the session stays open
