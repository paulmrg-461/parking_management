## Why

The system collects money and evidence but never asks the customer how the visit
went. The owner has revenue, occupancy and cash-anomaly reports, yet no signal
about service quality, cleanliness or waiting time at the desk, and a complaint
only reaches them if the customer happens to call. Every closed session already
has an id and a plate, and the receipt already prints a QR that carries the
plate as the access key (`/evidence`), so the missing piece is a **two-tap
survey** on the same public surface plus an admin report that turns the answers
into a figure the owner can act on.

## What Changes

- **New table `session_feedback`** (one row per closed session, lot-scoped):
  rating 1..5, optional comment up to 500 characters, created at. RLS lets lot
  members read their own lot; nobody writes the table directly — only the
  `security definer` RPCs do.
- **Public, plate-keyed API**: `public_feedback_session(session, plate)` returns
  the lot name and whether the visit can be rated (closed, not rated yet);
  `public_submit_feedback(session, plate, rating, comment)` records it. Both are
  granted to `anon`; a wrong plate, an open session or a second submission is
  refused. The public payload never includes the plate, the owner or the amount
  charged.
- **Public page `/feedback?session=…&plate=…`**: branded hero with the lot name,
  a 48 dp star selector, an optional comment, submit, and explicit
  loading / form / already-rated / submitted / invalid-link / error states. If
  the link has no plate, the page asks for it (same gate as `/evidence`).
- **Admin page `/satisfaction`**: average rating, number of answers, response
  rate against closed sessions in the period and the count of low ratings
  (≤ 3), a 1..5 distribution, and the latest comments with their date and
  plate. Period chips 7 / 30 / 90 days. Loading skeleton, empty, error + retry.
- **RPC `feedback_summary(p_days)`**: admin-only, lot-scoped, business timezone;
  integer-friendly money-free payload (`average_x10`, `response_rate_bp`) so the
  client never does float arithmetic.
- **Discovery**: the receipt printing pipeline adds the survey QR (PDF and
  thermal) when `APP_URL` is configured, and the automated/manual WhatsApp
  receipt text appends a "Califica tu visita" line with the same link. No
  configuration means no extra line, never a broken one.
- **No offline queue**: feedback is online-only (it needs the server to verify
  the session). A failed submit shows a localized retry, nothing is written to
  the outbox.

## Capabilities

### New Capabilities

- `customer-feedback`: the survey table and its public capture API, the public
  page, the admin satisfaction report and the discovery links on the receipt.

### Modified Capabilities

- `check-out`: the printed/WhatsApp receipt can carry the survey link. The
  amount, the fare and every existing receipt line are unchanged.

## Impact

- **Database:** one migration, next free number (`0111_customer_feedback.sql`),
  applied by `supabase-migrate`: the table, its index, RLS, and the three
  functions. No existing table, policy or RPC changes. Tests appended to
  `supabase/tests/rpc_test.sql`.
- **Flutter:** new feature `lib/features/feedback/` (domain / application /
  infrastructure / presentation), DI module, public route, admin deferred route
  and destination, `core/receipt/feedback_link.dart`, receipt text helpers,
  ARB strings (ES/EN), failure-message mapping.
- **Docs:** `CHANGELOG.md`, `docs/project-overview.md`, `docs/database.md`,
  `docs/agent-memory.md`, `docs/ui-kit.md` if a new shared widget appears.
- **Dependencies:** none added (`qr_flutter` and the existing `functions` client
  cover everything).
- **Breaking:** none. Without a feedback row the admin page shows its empty
  state; without `APP_URL` the receipts are exactly as today.

## Non-Goals

- Merchant / operator replies to a comment, moderation or deletion.
- Low-rating push or WhatsApp alerts (a natural follow-up; the admin page is the
  first surface).
- Customer identity, cross-visit history or a loyalty score.
- Email/SMS invitations or a public listing of comments.
- Editing a submitted rating (a second submission is refused on purpose).
- Reports CSV/PDF export of the survey (the page copies nothing yet).
