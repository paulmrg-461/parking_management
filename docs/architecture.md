# Architecture

Hexagonal (Ports & Adapters) + Clean Architecture on the client, and a
database-centric backend: **there is no application server**. PostgreSQL owns
the business rules (SQL RPCs), and PostgREST/GoTrue/Storage/Realtime expose it
to the Flutter app under Row Level Security.

## 1. System context

```mermaid
flowchart LR
  subgraph people
    operator[Operator<br/>check-in / check-out / cash]
    admin[Admin<br/>reports / users / settings]
  end

  app["Flutter app<br/>(Android + Web)"]

  subgraph supabase["Self-hosted Supabase (Docker)"]
    gw[Envoy gateway]
    auth[GoTrue<br/>PIN → JWT]
    rest[PostgREST<br/>tables + RPCs]
    storage[Storage<br/>evidence / branding]
    rt[Realtime<br/>notifications]
    fn["Edge Functions<br/>admin-users / push-dispatch"]
    db[("PostgreSQL 17<br/>schema + RLS + RPCs")]
  end

  fcm[[Firebase Cloud Messaging]]
  push[[Web Push / VAPID]]

  operator --> app
  admin --> app
  app -->|HTTPS + JWT| gw
  gw --> auth & rest & storage & rt & fn
  auth & rest & storage & rt & fn --> db
  fn -.->|background push| fcm & push
```

| Layer | Responsibility |
|---|---|
| Flutter app | UI, state (Cubits), offline cache and outbox. Talks only to the gateway. |
| Envoy | Single entry point: routes `/auth/v1`, `/rest/v1`, `/storage/v1`, `/realtime/v1`, `/functions/v1` and Studio. |
| GoTrue | Authentication. Usernames map to `<user>@parking.local`, the PIN is the password. |
| PostgREST | REST over tables (RLS-scoped) and `rpc/*` (business operations). |
| Storage | Private `evidence` bucket, public `branding` bucket. |
| Realtime | Streams `public.notifications` rows to the signed-in user. |
| Edge Functions | `admin-users` (GoTrue admin API with the service key) and `push-dispatch` (FCM + Web Push). |
| PostgreSQL | Tables, constraints, RLS policies, `security definer` RPCs, triggers (capacity, notifications, auth mirror). |

## 2. Flutter architecture (by feature)

```mermaid
flowchart TB
  subgraph presentation
    pages[pages + widgets<br/>context.l10n, no business rules]
  end
  subgraph application
    cubits[Cubits + use cases<br/>ResilientCubit, Submission]
  end
  subgraph domain
    entities[entities + repository ports<br/>depends on nothing]
  end
  subgraph infrastructure
    adapters[Supabase adapters<br/>Hive caches, DTOs, outbox]
  end

  pages --> cubits --> entities
  cubits --> entities
  adapters -.implements.-> entities
  pages -->|reads state| cubits
```

```
lib/
├── app/                 # composition root: get_it modules, router, shell
│   ├── di/              #   one module per feature + injection.dart
│   ├── router/          #   go_router config, route access policy
│   └── shell/           #   bottom bar / collapsible sidebar, offline banner
├── core/                # cross-cutting: error/failure, sync outbox,
│                        #   l10n, theme, widgets, lot context, receipts
└── features/<feature>/
    ├── domain/          #   entities + repository ports (+ commands)
    ├── application/     #   cubits and use cases
    ├── infrastructure/  #   Supabase + Hive adapters, DTOs/mappers
    └── presentation/    #   pages and widgets
```

Rules enforced by review and tests:

- `domain/` imports nothing from Flutter or Supabase.
- Cubits extend `ResilientCubit` so a future resolving after `close()` cannot
  throw; action outcomes are modelled as `Submission`.
- Every user-facing string comes from `context.l10n` (es/en, 390 keys at
  parity); printed receipts use `ReceiptLabels`.
- Repositories hide the network/cache split: `load()` = remote → cache, with
  `NetworkFailure` falling back to the cache.

## 3. Login and session

```mermaid
sequenceDiagram
  participant U as Operator
  participant A as App (AuthCubit)
  participant G as GoTrue
  participant DB as PostgreSQL
  participant L as LotsCubit

  U->>A: username + 6-digit PIN
  A->>G: POST /auth/v1/token (email = user@parking.local)
  G->>DB: verify password hash
  DB-->>G: ok
  G-->>A: access_token (JWT) + refresh_token
  A->>A: store JWT (secure storage) + profile (Hive)
  A->>L: load memberships (my_lots)
  L->>L: restore persisted lot, apply x-lot-id header
  A->>A: flush outbox, start push, reload branding
```

- The JWT lives in `flutter_secure_storage`; Hive only keeps the profile.
- GoTrue rotates tokens; the auth-state listener rewrites the Hive snapshot.
- Logout clears reference-data caches and signs out locally; the outbox is
  **never** cleared (work done offline must still reach the server).

## 4. Check-in (online and offline)

```mermaid
sequenceDiagram
  participant U as Operator
  participant P as CheckInPage/Cubit
  participant R as CheckInRepository
  participant S as Storage
  participant F as rpc/check_in
  participant DB as PostgreSQL
  participant O as Outbox

  U->>P: plate + evidence photos
  P->>R: createCheckIn(...)
  R->>R: client_ref = new UUID, entry time captured now
  R->>S: upload photos (path = <client_ref>/<file>)
  R->>F: check_in(plate, photos, Idempotency-Key=client_ref)
  F->>DB: capacity (lot, category) + reservation + blacklist checks
  DB-->>F: session row
  F->>DB: trigger → admin notifications
  F-->>R: 201 session (id, lot_id, ticket)
  R-->>P: ParkingSession

  Note over R,O: On NetworkFailure instead
  R->>O: enqueue {client_ref, client_entry_time, lot_id, photos}
  R-->>P: optimistic session (status pendingSync)

  Note over O,DB: SyncService drains the queue when online
  O->>F: check_in(..., Idempotency-Key=same client_ref, p_lot_id=captured)
  F-->>O: original session (replay) or new one
```

Key invariants:

- `client_ref` is generated **before** the first attempt and reused for every
  replay, so a lost response never creates a duplicate or a dead letter.
- The entry time is captured on the device (validated server-side with a 5
  minute skew tolerance), so billing starts when the operator acted.
- The lot is captured at enqueue time and validated by `resolve_lot()`, so a
  queued entry lands in the site where it happened even after a lot switch.

## 5. Check-out and billing

```mermaid
sequenceDiagram
  participant U as Operator
  participant P as CheckOutPage/Cubit
  participant F as rpc/check_out
  participant DB as PostgreSQL

  U->>P: choose payment method (+ discount, lost ticket)
  P->>F: check_out(session, method, discount?, lost_ticket?)
  F->>DB: validate session/lot, payment method, discount guard
  F->>DB: calculate_fare(category, entry, exit, has_pass)
  alt lost ticket
    F->>DB: ignore pass, charge full daily tariff + reason
  end
  F->>DB: attach open shift of (operator, lot), write amount/ticket
  F->>DB: trigger → check-out notification
  F-->>P: receipt (amount, method, ticket, discount)
```

Billing rules live in `calculate_fare()`: fractional hours ceil per day,
daily cap per day touched, night window replaces the day tariff, monthly pass
→ 0. Discounts are admin-only with a required reason and an audit trail; lost
tickets require a reason and charge the full daily tariff. Ticket numbers carry
the site code (`TCK-<LOT>-000123`).

## 6. Shifts and cash

An operator opens one shift per site (`unique (operator_id, lot_id)`), records
withdrawals/deposits, and closes by counting the drawer. `shift_totals()`
recomputes expected cash from the sessions attached to that shift plus the
pass payments collected in cash, so it is always derived, never stored stale.
Closed shifts can be corrected by an admin with a mandatory reason; the
previous/new reconciliation stays in `shift_adjustments`.

## 7. Notifications

```mermaid
flowchart LR
  db[(notifications table)] -->|Realtime row| app[In-app bell + inbox]
  db -->|trigger: check-in/out, shift close| db
  cron[cron: passes, overstay, renewal] --> db
  fn[push-dispatch] -->|reads pending rows| db
  fn --> fcm[FCM]
  fn --> webpush[Web Push]
  fcm --> android[Android notification]
  webpush --> browser[Browser notification]
```

- In-app notifications need no configuration.
- Background delivery is opt-in: FCM service account for Android, VAPID keys
  for browsers. `push-dispatch` is service-role-only and also prunes dead
  endpoints.
- Tapping a notification deep-links by type (`/shift`, `/monthly-passes`,
  `/history?plate=…`).

## 8. Multiple parking sites

```mermaid
sequenceDiagram
  participant App
  participant L as LotContext
  participant GW as Envoy → PostgREST
  participant DB as PostgreSQL

  App->>L: login / user picks a site
  L->>L: persist lot id (Hive)
  L->>GW: header x-lot-id: 2 on every request (mandatory)
  GW->>DB: current_lot_id() validates membership
  alt member
    DB-->>App: lot 2 rows only
  else missing / forged / not a member
    DB-->>App: LotRequiredError
  end
```

Every site-owned table carries `lot_id`. RLS filters reads, and every
`security definer` RPC stamps/filters the active lot explicitly (definer
functions bypass RLS). `parking_settings`, branding and the logo are per lot;
capacity is per `(lot, category)`; reports default to the active lot and
platform admins can request the consolidated view.

## 9. Security model

| Control | Implementation |
|---|---|
| Authentication | GoTrue only; 6-digit PIN (min length 6), signup disabled, `/token` rate-limited by client header. |
| Authorization | `public.users.role` (platform admin/operator) + `lot_members.role` per site; `is_admin()` / `is_lot_admin()`. |
| Data isolation | RLS on every table (`lot_id = current_lot_id()` for site data, ownership for notifications/tokens). |
| Writes | Only through `security definer` RPCs that derive the actor from `auth.uid()` and enforce idempotency. |
| Storage | `evidence` private and readable only through a session of the active lot; `branding` public read, admin write. |
| Service key | Never in the client; only inside `admin-users` / `push-dispatch` (server-side env). |
| Auditing | Discounts (actor/reason/instant), shift corrections, pass payments; WhatsApp/contact data is branding-only. |

## 10. Deliberate trade-offs

| Decision | Why |
|---|---|
| No application server | One deployable, no duplicated business rules, RLS is the boundary. |
| SQL RPCs own logic | Billing/capacity must be atomic; the client cannot be trusted. |
| Hive + outbox instead of live-sync | A parking lot loses connectivity; operators must keep working. |
| Header-selected lot (mandatory) | No re-login to switch sites; validated server-side, so it is only a selector. Missing header fails closed. |
| PDF/thermal receipts, no e-invoicing | Product scope: internal receipt only. |
| Separate `admin-users` function | GoTrue admin API needs the service key; it must never reach the app. |
