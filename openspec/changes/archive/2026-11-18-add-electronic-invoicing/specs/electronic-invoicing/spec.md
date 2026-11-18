## ADDED Requirements

### Requirement: Invoicing is off by default and inert without credentials
The system SHALL keep electronic invoicing off for every lot (`fiscal_settings.mode = 'off'`) until a lot admin saves complete issuer data and chooses `on_request` or `always`. WHILE the mode is `off`, THE SYSTEM SHALL create no fiscal document. WHEN the provider credentials are not configured, THE SYSTEM SHALL leave documents `pending` and the dispatcher SHALL answer `configured: false` without calling the database or any provider.

#### Scenario: Default off
- **WHEN** a lot has never saved fiscal settings
- **THEN** `issue_fiscal_document` raises `FiscalNotEnabledError`

#### Scenario: Incomplete issuer data
- **WHEN** an admin sets the mode to `always` without NIT, legal name or municipality code
- **THEN** the system raises `FiscalSettingsIncompleteError` and the mode stays `off`

#### Scenario: No provider credentials
- **WHEN** `fiscal-dispatch` runs without `FISCAL_PROVIDER_URL` or `FISCAL_PROVIDER_TOKEN`
- **THEN** it answers `{"configured": false, "claimed": 0}` and documents stay `pending`

#### Scenario: Lot isolation of settings
- **WHEN** lot 1 turns invoicing on
- **THEN** lot 2 remains `off`

### Requirement: Numbering resolutions per lot
The system SHALL keep, per lot and document type (`pos`, `invoice`, `credit_note`), at most one active numbering resolution with prefix, authorized range, validity dates and the next number. WHEN a document is issued, THE SYSTEM SHALL allocate the next number under a row lock inside the issuing transaction so that numbers are consecutive without gaps. IF no active resolution exists, THEN the system SHALL raise `FiscalResolutionMissingError`. IF the resolution is outside its validity dates in the lot's business timezone, THEN the system SHALL raise `FiscalResolutionExpiredError`. IF the range is exhausted, THEN the system SHALL raise `FiscalResolutionExhaustedError` and leave the sequence unchanged. The system SHALL notify lot admins with `fiscal_resolution_low` when fewer than 50 numbers remain or the resolution ends within 30 days, at most once per day.

#### Scenario: Consecutive numbers
- **WHEN** two documents of the same type are issued in a lot
- **THEN** their numbers differ by exactly 1

#### Scenario: Rolled back issuance releases the number
- **WHEN** an issuance transaction fails after allocating a number
- **THEN** the next successful document receives that same number

#### Scenario: Exhausted range
- **WHEN** the next number is beyond the range
- **THEN** the system raises `FiscalResolutionExhaustedError` and creates no document

#### Scenario: New resolution replaces the active one
- **WHEN** an admin saves a resolution for a type that already has an active one
- **THEN** the previous one becomes inactive and the new one starts at its range start

#### Scenario: Operator cannot manage resolutions
- **WHEN** an operator calls `save_fiscal_resolution`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Issue a document for a paid session or pass charge
WHEN an authenticated user of the lot calls `issue_fiscal_document` for a closed session with an amount charged greater than zero and a payment method other than `exempt`, or for a paid pass charge with an amount greater than zero, THE SYSTEM SHALL create one document of type `pos` (no customer data) or `invoice` (customer data given) numbered from the lot's resolution, with amounts computed from the charge by the tax rule. The system SHALL return the existing document when one already exists for the source. IF the source is open, exempt, zero-valued, closed before invoicing started, or unknown, THEN the system SHALL raise `FiscalSourceNotBillableError` or `FiscalSourceNotFoundError` and create nothing. IF the source belongs to another lot, THEN the system SHALL raise `FiscalSourceNotFoundError`.

#### Scenario: POS equivalent document
- **WHEN** an operator issues for a closed 11900 session without customer data
- **THEN** a `pos` document with total 11900, tax base 10000 and tax 1900 is created in status `pending`

#### Scenario: Invoice with customer data
- **WHEN** the call includes document type NIT, number and name
- **THEN** an `invoice` document is created with that customer

#### Scenario: Idempotent
- **WHEN** the same source is issued twice
- **THEN** the second call returns the same document with `created = false`

#### Scenario: Payment split
- **WHEN** a session was paid 6000 online and 5900 in cash
- **THEN** the document payload lists an `online` payment of 6000 and a `cash` payment of 5900

#### Scenario: Exempt session
- **WHEN** the session was closed with payment method `exempt`
- **THEN** the system raises `FiscalSourceNotBillableError`

#### Scenario: Other lot
- **WHEN** an operator of lot 1 issues for a session of lot 2
- **THEN** the system raises `FiscalSourceNotFoundError`

### Requirement: Customer fiscal data is optional and validated
The system SHALL accept optional customer data (document type in CC, NIT, CE, PP, TI, RC, TE, DIE; document number of 3 to 20 letters or digits; name of 2 to 120 characters; optional email) at check-out and when issuing from the history. IF any value is invalid, THEN the system SHALL raise `InvalidFiscalCustomerError`. The system SHALL NOT expose customer data to operators and SHALL NOT require it to close a session. WHILE the device is offline, THE SYSTEM SHALL hide the fiscal section and SHALL NOT queue fiscal data.

#### Scenario: Invalid number
- **WHEN** the document number has two characters
- **THEN** the system raises `InvalidFiscalCustomerError`

#### Scenario: Check-out without fiscal data
- **WHEN** an operator closes a session and leaves the section empty
- **THEN** the check-out succeeds and, in `always` mode, a `pos` document is created

#### Scenario: Offline
- **WHEN** the operator opens the check-out dialog offline
- **THEN** the "Datos para factura" section is not shown and the check-out is queued as today

#### Scenario: Operators do not read customers
- **WHEN** an operator selects from `fiscal_documents`
- **THEN** no rows are returned

### Requirement: Asynchronous outbox with retries and states
The system SHALL submit documents to the provider through the `fiscal-dispatch` Edge Function, which claims due documents, submits `pending` ones, queries `sent` ones and reports every result through `record_fiscal_result`. A document SHALL move `pending -> sent -> accepted` or end `rejected` when the provider or the tax authority rejects it. WHEN a transient error occurs (network error, timeout, 408, 429, 5xx), THE SYSTEM SHALL keep the document and retry after 1, 5, 15, 60 and then 240 minutes. WHEN the eighth attempt fails, THE SYSTEM SHALL set the status to `failed` and notify lot admins. WHEN a document is accepted, THE SYSTEM SHALL store the CUFE (or CUDE) and the QR data. Only the service role SHALL execute `claim_fiscal_documents` and `record_fiscal_result`.

#### Scenario: Accepted
- **WHEN** the provider answers accepted with a CUFE and a QR
- **THEN** the document is `accepted` with both stored and `accepted_at` set

#### Scenario: Asynchronous provider
- **WHEN** the provider answers processing
- **THEN** the document becomes `sent` and is queried again after one minute

#### Scenario: Transient error
- **WHEN** the provider answers 503
- **THEN** the document stays pending with the next attempt scheduled and `attempts` increased

#### Scenario: Retry budget exhausted
- **WHEN** the eighth attempt fails transiently
- **THEN** the status is `failed` and each active lot admin receives one `fiscal_document_failed` notification

#### Scenario: Rejection
- **WHEN** the provider rejects the document with a reason
- **THEN** the status is `rejected`, the reason is stored and admins are notified once

#### Scenario: Wrong caller
- **WHEN** a request to `fiscal-dispatch` carries the anon key, or an authenticated user calls `claim_fiscal_documents`
- **THEN** the function answers 403 and Postgres denies the RPC

#### Scenario: Provider outage does not block sales
- **WHEN** the provider is unreachable
- **THEN** check-out and issuance still succeed and documents wait in `pending`

### Requirement: Admins retry rejected or failed documents
WHEN a lot admin calls `retry_fiscal_document` for a `rejected` or `failed` document, THE SYSTEM SHALL return it to `pending` with its attempts reset and SHALL allow replacing the customer data. IF the document is in another status, THEN the system SHALL raise `InvalidFiscalStatusError`. IF the document is unknown or belongs to another lot, THEN the system SHALL raise `FiscalDocumentNotFoundError`.

#### Scenario: Retry with corrected customer
- **WHEN** an admin retries a rejected invoice with a corrected document number
- **THEN** the document is `pending` with the new number data and the same fiscal number

#### Scenario: Accepted document cannot be retried
- **WHEN** an admin retries an accepted document
- **THEN** the system raises `InvalidFiscalStatusError`

### Requirement: Numbered documents are immutable
The system SHALL reject any change to the type, number, prefix, lot, source, amounts, issue time or related document of a fiscal document after creation, SHALL allow customer data to change only while the document is `rejected` or `failed`, and SHALL grant no delete privilege on fiscal documents. The system SHALL NOT purge fiscal documents.

#### Scenario: Amount change
- **WHEN** a statement changes the total of an existing document
- **THEN** the system raises `FiscalDocumentImmutableError`

#### Scenario: Customer change on an accepted document
- **WHEN** a statement changes the customer name of an accepted document
- **THEN** the system raises `FiscalDocumentImmutableError`

### Requirement: Credit notes correct accepted documents
WHEN a lot admin calls `request_credit_note` with a reason of 3 to 200 characters for an accepted, non-voided document without a live credit note, THE SYSTEM SHALL create a `credit_note` document with its own number, the same amounts and customer, and a reference to the original. WHEN the credit note is accepted, THE SYSTEM SHALL mark the original voided and SHALL allow a new document for the same source. IF the original is not accepted, THEN the system SHALL raise `FiscalDocumentNotAcceptedError`. IF a live credit note exists, THEN the system SHALL raise `FiscalDocumentAlreadyCreditedError`.

#### Scenario: Credit and reissue
- **WHEN** an admin credits an accepted invoice and the credit note is accepted
- **THEN** the original is voided and an `invoice` with the correct customer can be issued for the same session

#### Scenario: Pending original
- **WHEN** an admin requests a credit note for a pending document
- **THEN** the system raises `FiscalDocumentNotAcceptedError`

#### Scenario: Second credit note
- **WHEN** an admin requests a second credit note for the same document
- **THEN** the system raises `FiscalDocumentAlreadyCreditedError`

#### Scenario: Operator
- **WHEN** an operator calls `request_credit_note`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Receipts show the electronic document
WHEN a session has an accepted document, THE SYSTEM SHALL print its type title, full number, CUFE and QR on the receipt (screen, PDF and thermal, ASCII-only on thermal). WHEN the document is not yet accepted, THE SYSTEM SHALL print "Documento electronico en proceso". WHEN the session has no document, THE SYSTEM SHALL print no fiscal block.

#### Scenario: Accepted document on the reprint
- **WHEN** an operator reprints the receipt of a session whose invoice was accepted
- **THEN** the receipt shows "FACTURA ELECTRONICA DE VENTA", the number, the CUFE and the QR

#### Scenario: Pending document
- **WHEN** the receipt is printed right after check-out
- **THEN** it shows the pending label and no CUFE

#### Scenario: Operator sees no customer data
- **WHEN** `fiscal_document_for_session` is called by an operator
- **THEN** the response contains no customer name, number or email

### Requirement: Only admins review documents
The system SHALL let only lot admins list fiscal documents, settings and resolutions of the active lot, with status filter and paging ordered by id descending, and the `/invoicing` route SHALL be reachable by admins only. The screen SHALL handle loading, empty, loaded and error-with-retry states.

#### Scenario: Filter by status
- **WHEN** an admin filters by `rejected`
- **THEN** only rejected documents of the lot are listed

#### Scenario: Operator route
- **WHEN** an operator navigates to `/invoicing`
- **THEN** the router redirects to home

#### Scenario: Other lot
- **WHEN** an admin of lot 1 lists documents
- **THEN** documents of lot 2 never appear

#### Scenario: Empty lot
- **WHEN** the lot has no documents
- **THEN** the screen shows the empty state with a call to action to configure a resolution

### Requirement: Scheduled issuance for always mode
WHILE a lot is in `always` mode with an active resolution, THE SYSTEM SHALL issue a `pos` document through `enqueue_pending_fiscal_documents` for every paid session and paid pass charge that has no live document 10 minutes after it was closed or paid and that happened after invoicing started. The job SHALL skip lots without an active resolution and SHALL NOT use another lot's settings.

#### Scenario: Offline check-out
- **WHEN** an offline check-out replays and 10 minutes pass
- **THEN** the job creates its `pos` document

#### Scenario: Online-paid pass charge
- **WHEN** a pass renewal is paid online
- **THEN** the job creates a document for the charge

#### Scenario: No resolution
- **WHEN** the lot has no active resolution
- **THEN** the job creates nothing for it
