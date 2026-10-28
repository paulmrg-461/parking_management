# UI kit and screen states

One visual language for every module. Feature code composes these widgets
instead of re-implementing headers, empty states or skeletons, so a change here
reaches the dashboard, the lists, the forms and the public pages at once.

## The four states

Every data screen maps its cubit state to one of four explicit views:

| State | Widget | Rule |
|---|---|---|
| Loading | `SkeletonList`, `SkeletonCardList`, `SkeletonTable` | Placeholders mimic the real geometry (row, card or table). One shared pulse controller; static when the OS asks to reduce motion. |
| Success | the screen's own builder | Responsive, no layout shifts between data refreshes. |
| Empty | `EmptyState` | Tonal circle icon + `title` + guidance `message` + an explicit `action` (first record, clear filters, register check-in...). |
| Error | `ErrorState` | Localized `message` from the cubit, `title` ("Algo salió mal"), and a `Reintentar` button. Raw exceptions never reach the widget. |

`AsyncView<T>` (with `AsyncLoading` / `AsyncEmpty` / `AsyncFailed` /
`AsyncReady`) implements the switch for cubit pages; list pages add
`RefreshIndicator` around the body.

## Building blocks

| Widget | Use |
|---|---|
| `SectionHeader` | Group title inside a page body: icon chip, title, optional subtitle and trailing action. |
| `MetricCard` | KPI tile: label, tabular value, optional caption/chip and tonal icon. Tappable when `onTap` is set (≥ 48 dp). |
| `FilterBar` | Card that groups search + filters, shows a result `summary` and an optional "clear filters" action. |
| `ListPageScaffold` | App bar + `SyncBadge` + add FAB + pull-to-refresh for CRUD lists. |
| `EmptyState` / `ErrorState` | The empty and error states above. |
| `StatusChip` | Semantic state label (success / warning / pending / neutral). |
| `SearchField` | List search with desktop autofocus, `Esc` to clear and optional plate keypad. |
| `MoneyText` | Money in the site currency (see `docs/database.md`, `0068`). |

## Tokens and accessibility

- Spacing, radii, widths and the minimum touch target come from
  `core/theme/tokens.dart` (`Space`, `Radii`, `Layout`, `Motion`). No literal
  padding or color in feature code.
- Semantic colors come from `ColorScheme` or `StatusColors` (success, warning,
  pending) — never a hex literal.
- Every interactive element is at least `Layout.minTouch` (48 dp). Icon
  buttons, chips, slot cells and keypad keys all satisfy it; widget tests run
  `androidTapTargetGuideline`, `labeledTapTargetGuideline` and
  `textContrastGuideline`.
- Text is always `context.l10n`; money is always `Money`/`MoneyText`.
- Loading, empty and error states are localized too (`loading`, `errorTitle`,
  `actionRetry`, each module's empty hint).

## Module conventions

- **Lists** (records, audit, users, notifications, passes, reservations,
  vehicles, tariffs, categories, lots): `ListPageScaffold`/`Scaffold` +
  `FilterBar` + skeleton + empty CTA + pull-to-refresh.
- **Dashboards** (home, reports, shifts): `SectionHeader` sections and
  `MetricCard` KPIs; the primary operator actions stay above the fold.
- **Forms** (check-in, settings, dialogs): `SectionHeader` groups, helper text,
  sticky save bar when the form scrolls, and inline validation.
- **Inbox**: notifications are grouped by day (today / yesterday / earlier),
  with an unread filter and an empty state that links to records.

When a new screen needs a new pattern, add it here and in `core/widgets`
instead of copying a private widget into a feature.
