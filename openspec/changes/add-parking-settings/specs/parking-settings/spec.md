## ADDED Requirements

### Requirement: Configure parking identity
The system SHALL store a singleton parking-settings record with the fields: name, address, schedule, phone, website and WhatsApp number, and SHALL expose it through `GET /api/settings` and `PATCH /api/settings`. Reads SHALL be available to any authenticated client and to unauthenticated clients (branding must render on the login screen before sign-in); writes MUST be restricted to admin users. Field values MUST be validated (name 1-80 chars; address ≤160; schedule ≤120; phone ≤32; WhatsApp ≤32 digits; website ≤200 and a valid URL) and MUST be rejected with 422 when invalid. The record SHALL default to name `Parqueadero` with empty contact fields when never configured.

#### Scenario: Admin updates the parking identity
- **WHEN** an admin sends `PATCH /api/settings` with `{"name": "Parqueadero Central", "address": "Cra 7 # 12-34", "phone": "+57 300 111 2233"}`
- **THEN** the server responds 200 with the merged record persisted in the `parking_settings` table

#### Scenario: Operator cannot modify settings
- **WHEN** an operator (non-admin) sends `PATCH /api/settings`
- **THEN** the server responds 403 and the stored record is unchanged

#### Scenario: Malformed settings are rejected
- **WHEN** any client sends `PATCH /api/settings` with an empty `name` or a `website` value of `not a url`
- **THEN** the server responds 422 with a field-level error and nothing is persisted

### Requirement: Logo upload and serving
The system SHALL let admins upload a single parking logo image via `POST /api/settings/logo` (multipart, JPEG/PNG, ≤5 MB, magic-byte validated) and SHALL serve the current logo bytes publicly at `GET /api/settings/logo`. Each successful upload MUST increment `logo_version` in the settings record so clients can detect a new logo. Uploading MUST be rejected with 413/422 for oversized or non-image files and with 403 for non-admin users.

#### Scenario: Admin uploads a logo
- **WHEN** an admin posts a valid PNG to `POST /api/settings/logo`
- **THEN** the server stores the file, responds 200 with the incremented `logo_version`, and `GET /api/settings/logo` returns the image bytes with the matching content type

#### Scenario: Non-image upload is rejected
- **WHEN** any client posts a text file (no image magic bytes) to `POST /api/settings/logo`
- **THEN** the server responds 422 and the previous logo remains available

#### Scenario: Operator cannot upload a logo
- **WHEN** an operator posts a valid image to `POST /api/settings/logo`
- **THEN** the server responds 403 and `logo_version` is unchanged

### Requirement: Offline access and outbox sync
The Flutter app SHALL cache the settings record and logo bytes in Hive so branding renders with no network. Admin edits MUST be applied optimistically to the local cache and queued as an outbox mutation (`MutationEntity.settings`) that replays via `PATCH /api/settings` when connectivity returns; a missing replayer MUST NOT be possible (registration in `sync_module.dart` is part of this capability). Logo upload SHALL require connectivity (bytes are not queued) and MUST surface a failure message when offline.

#### Scenario: Settings load offline
- **WHEN** the app loads settings while offline and the Hive cache holds a previous record
- **THEN** the form and all branding surfaces render the cached values with no error

#### Scenario: Offline edit replays later
- **WHEN** an admin saves a name change with no connectivity and connectivity later returns
- **THEN** the outbox replays the change with `PATCH /api/settings` and the server record ends up equal to the locally saved values

#### Scenario: Logo upload while offline fails visibly
- **WHEN** an admin picks a logo while offline
- **THEN** the upload is not queued, an error message is shown, and the cached logo is untouched

### Requirement: Receipts display parking identity
The thermal (ESC/POS) and PDF receipts SHALL use the configured parking name as their header instead of the hardcoded `PARQUEADERO` literal, and SHALL append a footer with address, schedule and phone when configured. The PDF receipt SHALL include the logo image when one exists. When settings are unset or unavailable, receipts MUST fall back to the current default (`PARQUEADERO`, no contact footer) so printing never fails.

#### Scenario: Thermal receipt uses the configured name
- **WHEN** a receipt is printed while settings hold name `Parqueadero Central` with address and phone
- **THEN** the ESC/POS output contains `Parqueadero Central` in the header and the address/phone lines in the footer, and contains no `PARQUEADERO` literal

#### Scenario: Printing works with no cached settings
- **WHEN** a receipt is printed before any settings were ever loaded
- **THEN** the receipt still prints using the `PARQUEADERO` fallback header

### Requirement: App chrome branding
The app title shown in the home AppBar, the login header and the task-switcher title SHALL use the configured parking name, and the login screen SHALL show the configured logo image (falling back to the generic parking icon when no logo exists). Values SHALL come from the root-level branding state populated at startup from the local cache and refreshed from the backend.

#### Scenario: Login screen shows the parking brand
- **WHEN** the app opens the login page after settings (name and logo) were synced
- **THEN** the header displays `Parqueadero Central` and the uploaded logo instead of the generic icon

#### Scenario: Branding falls back before first sync
- **WHEN** the app opens with an empty settings cache
- **THEN** the title shows the localized default (`Parqueadero`/`Parking`) and the generic icon, with no error

### Requirement: WhatsApp quick action
The app SHALL expose a floating WhatsApp action that opens `https://wa.me/<digits>` (international digits only, country code preserved) for the configured WhatsApp number. The action MUST be hidden when no WhatsApp number is configured, and MUST be available to both admin and operator roles.

#### Scenario: WhatsApp action opens the chat
- **WHEN** WhatsApp is configured as `+57 300 111 2233` and the user taps the floating action
- **THEN** the system browser/WhatsApp opens `https://wa.me/573001112233`

#### Scenario: Action hidden when unconfigured
- **WHEN** the WhatsApp field is empty
- **THEN** no floating WhatsApp action is rendered

### Requirement: Contact page
The system SHALL provide a read-only contact page (accessible to admin and operator) showing the configured name, logo, address, schedule, phone, website and WhatsApp, with tap actions that dial the phone, open the website and open WhatsApp. A separate admin-only settings page SHALL provide the edit form for all fields plus logo upload.

#### Scenario: Contact page renders configured data
- **WHEN** an operator opens the contact page with fully configured settings
- **THEN** address, schedule, phone, website and WhatsApp are displayed and each action targets the configured value

#### Scenario: Settings form is admin-only
- **WHEN** an operator navigates to the settings route
- **THEN** the router redirects them away (route is admin-only by default) and no settings form is shown
