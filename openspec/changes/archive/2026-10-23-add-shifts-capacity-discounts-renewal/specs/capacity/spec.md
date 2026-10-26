## ADDED Requirements

### Requirement: Category capacity is enforced
The system SHALL reject a check-in that would exceed a category's configured
capacity (0 = unlimited), even under concurrent check-ins.

#### Scenario: Category full
- **WHEN** a category at capacity receives another check-in
- **THEN** the check-in is rejected with a localized "category full" error

#### Scenario: Capacity shown to the operator
- **WHEN** the dashboard loads
- **THEN** it shows used/total vehicles, a progress bar and the names of full
  categories
