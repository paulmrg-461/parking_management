## 1. Database

- [x] 1.1 Append the SQL cases to `supabase/tests/rpc_test.sql` before the final
  `rollback;` (one `do $$ ... $$` per case; the comment header is the name):
  `feedback: table defaults` (rating/comment/created_at),
  `feedback: constraints` (rating 0/6 and 501-character comment raise
  `check_violation`; two rows for one session break the unique key),
  `feedback: anon cannot read the table`,
  `feedback: operator reads own lot only`,
  `feedback: lookup normalises the plate`,
  `feedback: wrong plate returns null`,
  `feedback: open session is not rateable`,
  `feedback: submit stores one row`,
  `feedback: duplicate refused`,
  `feedback: invalid rating and comment`,
  `feedback: summary math` (backdated ratings, `average_x10`,
  `response_rate_bp`, `low_count`, distribution keys),
  `feedback: summary lot isolation` (Security),
  `feedback: operator cannot summarise` (`AdminRequiredError`),
  `feedback: summary rejects out-of-range days`,
  `feedback: public functions are the only anon entry points`.
- [x] 1.2 Create `supabase/migrations/0111_customer_feedback.sql`: the
  `session_feedback` table, index, RLS, revokes/grants and select policy;
  `public_feedback_session`, `public_submit_feedback` and `feedback_summary`
  per `design.md` D1–D5. Grants: the two public functions to `anon,
  authenticated`; the summary to `authenticated` (the `require_admin()` call
  inside is the real gate).
- [x] 1.3 Run `sh supabase/tests/run.sh` on a fresh scratch database; every new
  case green and every previous case untouched.

## 2. Flutter: domain, infrastructure and application

- [x] 2.1 Tests first: `test/features/feedback/domain/feedback_invite_test.dart`
  and `feedback_summary_test.dart` (parse the documented JSON, null rating,
  distribution keys, missing optionals, unknown extra keys ignored).
- [x] 2.2 Write `domain/entities/{feedback_invite,feedback_summary}.dart` and
  `domain/repositories/feedback_repository.dart` (Equatable, no Flutter import).
- [x] 2.3 Tests first in `test/features/feedback/infrastructure/`
  (`inspects rpc names, parameters and typed errors`): lookup null, lookup
  object, submit params, `FeedbackAlreadyError` code, `SessionNotFoundError`,
  network failure, summary parse and day parameter.
- [x] 2.4 Write the remote data source and repository implementation, mapping
  failures with the shared mapper.
- [x] 2.5 Cubit tests first: `PublicFeedbackCubit` (load ready, missing link,
  failure + retry, submit success, already-rated mapped to a state, failure
  keeps the form values) and `FeedbackSummaryCubit` (load, period switch
  without loading, empty, failure). Implement both as `ResilientCubit`.
- [x] 2.6 Add `feedback` to the failure mapper and the ARB keys (ES/EN),
  regenerate `flutter gen-l10n`; extend the mapper/l10n test.

## 3. Flutter: presentation

- [x] 3.1 Public page tests first (states, star a11y, 500-character counter,
  missing plate gate, retry keeps the answer, 360 dp + large text, tap target
  and label guidelines), then `public_feedback_page.dart` following the
  `PublicBookingPage` / `PublicEvidencePage` patterns.
- [x] 3.2 Admin page tests first (skeleton, empty, loaded metrics, distribution,
  recent comments, period chips, error + retry, a11y, 400 px), then
  `feedback_summary_page.dart` with `MetricCard`, `FilterBar`, `SectionHeader`,
  `SkeletonCardList`, `EmptyState` and `ErrorState`.
- [x] 3.3 DI module + `injection.dart`; router: public `/feedback` in
  `authRedirect` and the admin `/satisfaction` deferred entry; `AppDestination`
  under management. Extend the router, route-access and DI tests.

## 4. Receipt discovery

- [x] 4.1 Tests first for `publicFeedbackUri/Url` (null without base, query
  parameters, web origin fallback) and the WhatsApp receipt line (appended only
  with a base).
- [x] 4.2 Implement `lib/core/receipt/feedback_link.dart`, add the QR + caption
  to the PDF and thermal receipts when the link exists, and append the line to
  the WhatsApp receipt text.

## 5. Docs and gatekeeper

- [x] 5.1 `CHANGELOG.md`, `docs/project-overview.md` (module map + a short
  limitation note), `docs/database.md` (table, RPCs, RLS, ER diagram),
  `docs/agent-memory.md` (decisions, test count, schema range).
- [x] 5.2 `flutter analyze`, `flutter test --coverage` +
  `dart run tool/check_coverage.dart`, `sh supabase/tests/run.sh`,
  `flutter test -d linux integration_test/app_flow_test.dart`; commit and push.
