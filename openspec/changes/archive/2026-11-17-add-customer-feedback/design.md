## Context

The public surface already has a plate-keyed page (`/evidence`), an anonymous
booking page and a policy page. They share three rules: the link that the
customer holds is the key, the server never trusts the client for identity, and
the anonymous payload is a strict allow-list. Feedback follows the same shape.

The admin surface already has report pages with period chips, metric cards and
degradable sections. Feedback is smaller than a report, so it gets its own page
instead of becoming another block that can break `/reports`.

## Decisions

### D1. The session id plus the plate is the key

`public_feedback_session(p_session_id, p_plate)` and
`public_submit_feedback(p_session_id, p_plate, p_rating, p_comment)` require
both values. The id alone walks integers; the plate alone is guessable. Together
they match what the receipt already prints (`/evidence?session=…` plus the
printed plate) and need no new credential table. The plate is normalised with
the same rule as `public_cancel_reservation` (uppercase, blanks removed) before
comparison.

The public functions return **nothing** about the customer, the vehicle, the
amount or the operator. `public_feedback_session` returns the lot name (branding
the page is the point), `rateable`, `rated` and `rating` when it already exists.
Unknown session or wrong plate → `null`, which the page renders as the invalid
link state, never as an error (the same "not found is an answer" rule as the
reservation lookup).

### D2. Only closed sessions can be rated

Rating an ongoing visit invites a score for something that has not finished, and
a session id that is still open is a weaker key (the car may leave with someone
else). Both RPCs therefore require `exit_time is not null`. The public payload
carries `rateable = false` for an open session so the page can say "podrás
calificar al salir" instead of looking broken.

### D3. One row per session, no direct writes

`unique (session_id)` is the dedupe: a double tap, a refresh or a replayed
submit cannot create a second row. The table is read-only for clients (select
grant only, policy `lot_id = current_lot_id()`); inserts happen inside the
`security definer` function, which derives `lot_id` from the session — never
from the request. There is no update and no delete in v1.

Rating must be an integer 1..5 and the comment is trimmed; an empty comment is
stored as `''`. The column has a 500-character check as the last line of defence;
the RPC raises `InvalidDataError` first so the client gets a typed failure.

### D4. Errors

| Case | Error |
|---|---|
| Rating outside 1..5, comment > 500 characters | `InvalidDataError` |
| Session missing, wrong plate or still open | `SessionNotFoundError` |
| Session already rated | `FeedbackAlreadyError` |
| Caller of `feedback_summary` is not a platform admin | `AdminRequiredError` |

`FeedbackAlreadyError` is a new typed code; the page maps it to "ya calificaste
esta visita" and the failure mapper keeps it out of the generic server message.

### D5. `feedback_summary` is integer-only

```json
{
  "days": 30,
  "start_date": "2026-10-19",
  "end_date": "2026-11-17",
  "timezone": "America/Bogota",
  "total": 12,
  "average_x10": 43,
  "closed_sessions": 300,
  "response_rate_bp": 400,
  "low_count": 3,
  "distribution": {"1": 1, "2": 0, "3": 2, "4": 4, "5": 5},
  "recent": [
    {"id": 7, "session_id": 55, "plate": "MJS368", "rating": 5,
     "comment": "Muy rápido", "created_at": "2026-11-16T18:04:00Z"}
  ]
}
```

- `average_x10` is `round(avg(rating) * 10)` (43 = 4.3), so the client divides
  by 10 exactly once for display and never averages floats.
- `response_rate_bp` is basis points: `round(total * 10000 / closed_sessions)`,
  `0` when there are no closed sessions in the period.
- `closed_sessions` counts sessions of the lot whose `exit_time` falls in the
  period (business timezone), matching how reports count exits.
- `distribution` always carries keys `1`..`5` (zero included), because a missing
  bar would be read as "no such rating".
- `recent` is the newest 20 rows of the period, comments or not, newest first by
  `(created_at, id)` (`now()` is constant inside a transaction).
- `p_days` is clamped to 1..365; anything else raises
  `InvalidReportRangeError`, matching the other report ranges.

### D6. Admin page composition

- `MetricCard`s: average (one decimal, `4,3`), answers (+ response rate caption),
  low ratings (≤ 3, warning tone, "Revisar comentarios" caption).
- Distribution: five horizontal bars scaled to the largest bucket, with the
  count and the percentage; semantic colours are success for 4..5, neutral for
  3 and warning for 1..2 (the existing `StatusColors`/`ColorScheme` tokens, no
  literals).
- Recent list: rating chip, plate (`PlateText`), date (`Formatters`), comment as
  plain text (no markdown/HTML rendering). Empty comments show "Sin comentario".
- Period chips 7 / 30 / 90 inside a `FilterBar` with the count as summary.
- Four states; a failed summary keeps the page with `ErrorState` + retry, it is
  not a section that can hide the rest (there is nothing else on the page).
- Admin-only route; operators are redirected home and the SQL function refuses
  them independently.

### D7. Discovery without breaking receipts

`core/receipt/feedback_link.dart` mirrors `evidence_link.dart`:
`publicFeedbackUri(sessionId, plate, {base})` uses `APP_URL` (web origin
fallback) and returns `null` when there is no base. With no base the receipt is
unchanged (no dangling QR/URL). The thermal/PDF receipt adds a compact QR plus
the caption "Califica tu visita"; the WhatsApp receipt text appends one line
with the link. The plate travels in the QR because the customer already holds
the receipt — same exposure as `/evidence`, which the printed receipt already
shows.

### D8. Online-only, no outbox

Submitting needs the server to verify the session and the duplicate. Nothing is
queued: a network failure shows the localized message with a retry, and the
rating/comment stay in the form. The feature never touches `SyncService` or
`PendingMutation`.

## Data model

```sql
create table if not exists public.session_feedback (
    id          bigint generated always as identity primary key,
    lot_id      integer not null references public.parking_lots(id),
    session_id  bigint  not null references public.parking_sessions(id),
    rating      smallint not null check (rating between 1 and 5),
    comment     text not null default '' check (char_length(comment) <= 500),
    created_at  timestamptz not null default now(),
    unique (session_id)
);
create index if not exists ix_feedback_lot_created
    on public.session_feedback(lot_id, created_at desc);
```

RLS on, `revoke all` from `public, anon, authenticated`, `grant select` to
`authenticated`, policy `feedback_read_lot` for select using
`lot_id = public.current_lot_id()`.

## Flutter shape

```
lib/features/feedback/
├── domain/entities/{feedback_invite,feedback_summary}.dart
├── domain/repositories/feedback_repository.dart
├── infrastructure/{feedback_remote_data_source,feedback_repository_impl}.dart
├── application/{public_feedback_cubit,feedback_summary_cubit}.dart
└── presentation/{public_feedback_page,feedback_summary_page}.dart
```

`PublicFeedbackCubit`: `FeedbackLoading`, `FeedbackReady(invite)`,
`FeedbackSubmitted(rating)`, `FeedbackMissingLink`, `FeedbackFailure(message)`;
`submit()` keeps the typed failure. `FeedbackSummaryCubit`:
`FeedbackSummaryLoading`, `FeedbackSummaryLoaded(summary)`,
`FeedbackSummaryFailure(message)`; `load(days)` never emits loading on a period
switch (chips keep the content while the new window arrives).

## Verification

- SQL: defaults/constraints, one row per session, wrong plate, open session,
  unknown session, invalid rating/comment, already rated, anon cannot read the
  table, operator cannot call the summary, lot isolation, average/response-rate
  math with backdated rows, distribution keys, `recent` ordering.
- Dart: entity parsing, remote data source params and typed errors, cubits
  (success/failure/edge), public page states and a11y guidelines, admin page
  states/period switch, route access (public vs admin), link builder.
- Manual: open `/feedback?session=…&plate=…` on a phone-sized viewport, rate,
  reload (already-rated), and check the admin page counts.
