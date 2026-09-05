## Context

`tariffs` stores one row per `(category_id, type)` — `Tariff.type` is exactly
one of `hourly`/`daily`/`nightly`/`monthly`, with `amount: int` (COP) and, for
`nightly`, a `start_time`/`end_time` `"HH:MM"` window (validated to differ,
required only for `nightly`). `check-in` opens a `ParkingSession` with
`entry_time` only; `exit_time` and `check-out` do not exist yet. This change
adds the fare math both future changes need, as a pure, heavily-tested unit —
no repository writes, no new tables.

## Goals / Non-Goals

**Goals:**
- A pure, synchronous `FareCalculator.calculate_fare(...)` that is a
  deterministic function of (tariffs, entry_time, exit_time,
  has_active_monthly_pass) — trivially unit-testable without a DB or event loop.
- Correct handling of: ceil-to-hour, night-window-replaces-day (including
  midnight wraparound), per-calendar-day daily-rate cap, multi-day stays,
  and a monthly-pass short-circuit to `0`.
- A thin async wrapper for the one real dependency this needs in practice:
  loading a category's tariff rows via `TariffRepository`.

**Non-Goals:**
- Persisting a session's charged amount, or closing a session — that is
  `check-out`'s job. This change only computes an amount.
- Real monthly-pass storage/lookup — `has_active_monthly_pass` is a plain
  boolean parameter the caller supplies; the actual subscription concept
  (table, active/expired lookup) is a separate future `monthly-passes` change.
- Any HTTP surface beyond an optional, minimal read-only quote endpoint.
- Currency formatting/rounding-to-cents — COP has no decimals; `Tariff.amount`
  is already a whole-COP `int`, and every operation in the calculator
  (multiplication by an integer hour count, `min()` for the cap, addition) on
  whole-COP inputs stays whole, so no cents-level rounding exists to define.

## Decisions

- **New `CategoryTariffs` domain aggregate** (`app/domain/category_tariffs.py`):
  a dataclass bundling `category_id`, a required `hourly: Tariff`, and optional
  `daily: Tariff | None` / `nightly: Tariff | None`. The task's suggested
  calculator signature (`calculate_fare(tariff: Tariff, ...)`) assumes one
  `Tariff` carries all four rates; the real `Tariff` entity does not (verified
  by reading `app/domain/tariff.py` and `app/application/tariff_service.py`
  before writing any code). Rather than bolt hourly/daily/nightly fields onto
  `Tariff` (which would break its "one row = one rate type" shape used by the
  `tariffs` CRUD/validation already shipped), this change adds the smallest
  possible aggregate that reuses `Tariff` as-is. `__post_init__` asserts each
  slot holds a `Tariff` of the matching `TariffType` (defense in depth; the
  `tariffs` capability already enforces this at creation time).
- **`FareCalculator` is a plain class in `app/application/billing_service.py`**
  with:
  - `calculate_fare(self, tariffs: CategoryTariffs, entry_time: datetime,
    exit_time: datetime, has_active_monthly_pass: bool = False) -> Decimal`
    — pure, sync, the entire algorithm.
  - `async def calculate_fare_for_session(self, category_id: int, entry_time,
    exit_time, tariff_repository: TariffRepository, has_active_monthly_pass=
    False) -> Decimal` — thin wrapper: loads the category's active hourly
    (required — raises `MissingHourlyTariffError` if absent), daily, and
    nightly rows, builds a `CategoryTariffs`, and delegates to the sync method.
    Takes `category_id` + explicit `entry_time`/`exit_time` rather than a
    `ParkingSession` because a session only carries `entry_time` today (no
    `exit_time`, no `category_id` — that's on `Vehicle`); `check-out` (not yet
    built) is the natural caller once it resolves vehicle -> category and has
    both timestamps.
  - `raise InvalidBillingPeriodError` (module-level exception) when
    `exit_time <= entry_time`.
- **Algorithm — split by calendar day, then by night window, in that order:**
  1. `has_active_monthly_pass=True` short-circuits to `Decimal("0")` before any
     other computation.
  2. Split `[entry_time, exit_time)` into one sub-interval per calendar date
     (in the datetimes' own tzinfo — the calculator does not convert timezones,
     it trusts whatever `entry_time`/`exit_time` carry, matching `check-in`'s
     `datetime.now(UTC)`).
  3. Within each calendar-day sub-interval, if a nightly tariff is configured,
     further split by the recurring `start_time`..`end_time` window (handling
     the case where the window wraps midnight, e.g. `"22:00"`-`"06:00"`, which
     can appear as *two* disjoint night pieces inside a single calendar day —
     e.g. `00:00`-`06:00` tail of the previous night, and `22:00`-`24:00` head
     of the next). Sum all night-piece minutes and all remaining (day) minutes
     for that calendar day separately.
  4. **Daily-cap/rounding granularity decision (the non-obvious part):** ceil
     is applied **once per calendar day, per rate type** — i.e. total night
     minutes for that calendar day are summed first, then ceiled to hours
     once; total day (hourly-rate) minutes for that calendar day are summed
     first, then ceiled once. It is *not* ceiled per disjoint sub-interval
     (which would double-round a night window that appears as two pieces in
     one day, e.g. 5 min + 5 min of night time would wrongly bill 2 rounded
     hours instead of 1), and it is *not* pooled across the whole multi-day
     stay into one final ceil (which would let a multi-day stay's fractional
     remainders cancel out unrealistically and would defeat the per-day cap —
     a 3-day stay must be capped 3 times, not once). Concretely: for a stay
     that spans days 1..N, day 1 and day N are partial calendar-day
     sub-intervals (from `entry_time`/to `exit_time`), and every day (partial
     or full) is rounded and capped exactly once, independently.
  5. Each calendar day's charge = `ceil(day_minutes/60) * hourly_rate +
     ceil(night_minutes/60) * night_rate`, then capped at
     `min(that, daily_rate)` when a daily tariff is configured for the
     category (uncapped otherwise).
  6. Total = sum of every calendar day's (possibly capped) charge.
  - **Security/defense in depth:** any tariff `amount` is clamped to `>= 0`
    before use (`max(amount, 0)`), even though `tariffs` validation already
    rejects non-positive amounts at creation time — a calculator that is
    handed a raw `Tariff`/`CategoryTariffs` directly (e.g. in a unit test, or
    by a future caller that skips the service layer) must never be able to
    produce a negative charge. The final total is also clamped to `>= 0`.
- **Ceil-to-hour uses integer-second arithmetic**, not floating point:
  `hours = (total_seconds + 3599) // 3600`, avoiding float rounding error
  near exact-hour boundaries.
- **Optional `GET /billing/quote`** (`category_id`, `entry_time`, `exit_time`
  ISO-8601 query params, `Depends(get_current_user)`) returning
  `{"amount": "<decimal-string>"}` for a live UI fare preview. Read-only, any
  authenticated user (matches how `GET /vehicles`/`GET /tariffs` are gated) —
  added because it is genuinely useful for a fare preview and costs three
  small tests; kept optional/minimal per the change brief.

## Risks / Trade-offs

- [Independent per-rate-type ceiling per day] -> a stay that crosses the
  night/day boundary twice in one calendar day could round up slightly more
  than a "single continuous ceil" model would. Accepted: it is the simpler,
  more predictable, and harder-to-game rule (a partial hour in either regime
  always rounds in the operator's favor, consistently), and matches how the
  worked examples in the change brief expect day and night portions billed
  "not blended."
- [Calendar-day cap, not rolling 24h from entry] -> a stay starting at 23:00
  and ending 23:00 the next day touches two calendar-day cap buckets (each
  capped at the full daily rate) rather than being capped once as a single
  "24h period." Accepted per the change brief's own algorithm description
  ("split... by day boundary", "cap each 24h/calendar-day segment"); the
  `tariffs` spec does not define finer semantics to contradict this.
- [No monthly-pass storage] -> `has_active_monthly_pass` is caller-supplied;
  until `monthly-passes` exists, every caller must pass `False` (or omit it),
  which is the only checked-in caller behavior today (no caller wired yet).

## Migration Plan

None — no new tables/columns. No Alembic migration.

## Open Questions

- Whether `check-out` will call `calculate_fare_for_session` at close time or
  re-derive `CategoryTariffs` itself is deferred to that change.
