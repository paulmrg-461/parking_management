# Parking Management — Agent Conventions & System Blueprint

## 1. Session Memory & Governance

Read `docs/agent-memory.md` at the start of a session: current branch state, commands, invariants, and known gotchas. Update it when a batch lands.
Deployment and design docs live in `docs/` (`README.md` indexes them): `environment-guide.en.md` / `environment-guide.md` (onboarding, EN/ES), `setup-local.md`, `setup-cloud.md`, `deployment-requirements.md`, `architecture.md`, `infrastructure.md` and `database.md`; `QUICKSTART.md` at the root is the one-page command sheet.
`docs/project-overview.md` is the executive summary (module status, limitations) and `CHANGELOG.md` tracks notable changes. Keep the changelog, the overview, and the Mermaid diagrams in sync with code changes.

---

## 2. Overview & Architectural Mandates (MANDATORY)

Parking management system: vehicle registration/control, time-based billing, vehicle categories, night rates, damage evidence photos, and automatic license plate detection.

Monorepo:
* `lib/` — Flutter app (targets: `android`, `web`, and `linux` for head-of-line integration/desktop POS)
* `supabase/` — self-hosted Supabase (Postgres schema, RPCs, RLS, Storage, Edge Functions) — single source of truth
* `openspec/` — specs and changes (spec-driven development via OpenSpec)

### Hexagonal + Clean Architecture (by feature)

```text
lib/features/<feature>/
├── domain/           # Pure entities + repository interfaces (ports). Zero external dependencies.
├── application/      # Use cases + Cubits (orchestration, business rules, state).
├── infrastructure/   # Adapters (Supabase RPCs, Hive CE), DTOs, mappers.
└── presentation/     # Screens, atomic widgets, theme-aware layouts.
```

* Outer layers depend on inner layers; `domain/` depends on pure Dart only.
* Clean Code rules: functions $\le 20$ lines, max 2 parameters, self-documenting identifiers.
* Patterns: Repository, UseCase, Adapter, Factory, DI Singleton (`get_it`), Observer (`Cubit`).
* All identifiers, code, comments, and OpenSpec artifacts MUST be in English.

---

## 3. UI/UX Design System & Accessibility Mandates

Every operator screen and dashboard view must adhere to strict enterprise usability standards:

### A. The 4 UI States Rule

Every screen or interactive widget must handle four explicit states via sealed `Equatable` states:

1. **Loading State:** Shimmer skeletons replicating the exact geometry of cards, tables, or slot grids (no raw, unaligned progress indicators).
2. **Success State:** High-contrast, responsive layout reflecting real-time updates without layout shifts.
3. **Empty State:** Informative visual icon, friendly guidance text, and an explicit Call to Action (e.g., "No active vehicles in this category. Register Check-In").
4. **Error State:** User-friendly localized message with an explicit "Retry" action; raw exceptions must never reach the view layer.

### B. Tokens, Ergonomics & Accessibility (WCAG 2.1 AA)

* **Design Tokens Exclusivity:** Consume `Theme.of(context)` tokens exclusively. Zero hardcoded color literals (`Color(0xFF...)`) or absolute font stylings in widgets.
* **Touch Target Integrity:** All interactive buttons, slot cards, and keyboard actions must meet the $\ge 48 \times 48\text{ dp}$ touch target threshold for touch-screen POS/cabin terminals.
* **Semantic Colors:**
* Free/Available slots: Emerald green (`#10B981` / semantic success).
* Occupied/Active: Slate / Zinc neutral with clear vehicle plate badges.
* Overstay / High Risk / Negative Cash: Rose/Red alert (`#F43F5E`) used *strictly* for actionable anomalies.
* **Typography & Localization:** Formatting via `Money` (`core/money`) and localized labels via `context.l10n` exclusively.

---

## 4. Testing Mandates & Linux Native Verification (Strict TDD)

Testing follows the **Red $\rightarrow$ Green $\rightarrow$ Refactor** discipline. Tests are written **BEFORE** implementation code.

### A. Unit & Feature Testing

* **Coverage Target:** $\ge 90\%$ coverage on `domain/`, `application/`, and `infrastructure/` mappers.
* **Isolation:** Use `mocktail` for dependency isolation and `bloc_test` for Cubit state emissions.
* **Test Structure:** Strict Arrange $\rightarrow$ Act $\rightarrow$ Assert. Every test case must verify:
1. *Success Case* (nominal execution path).
2. *Failure / Edge Case* (network drop, validation error, out-of-capacity).
3. *Security / RLS Invariant* (unauthorized role, wrong lot ID, expired token).

### B. Linux Integration & E2E Testing

Critical operator workflows (Check-in, Check-out calculation, Cash shift reconciliation, Pass renewal) must be covered by integration tests runnable directly on Linux headless CI:

```bash
# 1. Static and Unit Analysis
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart

# 2. Native Linux E2E & Flow Verification
flutter test -d linux integration_test/parking_workflow_test.dart
```
* Integration tests exercise real Hive local storage, mock/fake network boundaries, and assert that UI state transitions and receipts render within acceptable time budgets ($< 250\text{ ms}$).
* Zero skipped tests or deleted assertions are permitted to force a green build.

---

## 5. Implementation Invariants & Business Logic

* **Retryable Writes & Idempotency:** Generate `client_ref` BEFORE the first attempt, send it as `Idempotency-Key`, and persist the SAME ref if queued in Hive outbox. Never generate idempotency keys inside failure catch blocks.
* **Offline Timestamps:** Capture `client_entry_time` and `client_exit_time` at the moment of operator confirmation (not at sync time); validate server-side against `MAX_CLIENT_CLOCK_SKEW`.
* **Resilient Cubits:** All Cubits must extend `ResilientCubit` to prevent unhandled post-close emissions.
* **Shift & Cash Actions:** Cash intake, shift opening, closing, and reconciliation are strictly disabled while offline; they must never be queued in the outbox.
* **Multi-Lot Isolation:** Every table carries `lot_id`. RLS policies must read `current_lot_id()` from the mandatory `x-lot-id` header. Storage and Realtime must use membership checks (`can_read_evidence()`, `can_read_lot()`) because headers are stripped.
* **Money Handling:** Amounts are strictly integers in minor units (COP pesos, USD cents) formatted only through `Money` (`core/money`). Never divide by 100 or hardcode `$` in widgets.

---

## 6. Gatekeeper Checklist

Before closing any task or pushing to Git:

1. **Static Analysis & Linting:**
```bash
flutter analyze
```

*Must report 0 errors, 0 warnings (only pinned SDK deprecation infos allowed).*

2. **Full Test Suite & Coverage:**
```bash
flutter test --coverage
```

*All unit tests must pass in green.*

3. **Backend & Integration Verification:**
```bash
sh supabase/tests/run.sh
flutter test -d linux integration_test/app_flow_test.dart
```

4. **Delivery & Commit:**
* Commit with Conventional Commits (`feat:`, `fix:`, `test:`, `refactor:`).

* Push immediately to the remote branch; never leave completed tasks unpushed.