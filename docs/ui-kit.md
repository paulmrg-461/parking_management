# UI kit and screen states

One visual language for every module. Feature code composes these widgets
instead of re-implementing headers, empty states or skeletons, so a change here
reaches the dashboard, the lists, the forms and the public pages at once.

## The four states

Every data screen maps its cubit state to one of four explicit views:

| State | Widget | Rule |
|---|---|---|
| Loading | `SkeletonList`, `SkeletonCardList`, `SkeletonTable`, plus the `SkeletonPulse`/`SkeletonCard`/`SkeletonBox` primitives for custom layouts (the home KPI grid) | Placeholders mimic the real geometry (row, card or table). One shared pulse controller; static when the OS asks to reduce motion. |
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
| `AppIconButton` | Icon action with a required tooltip and a 48 dp target. Use it instead of `IconButton(visualDensity: compact)` in rows (check-out reprint, history actions). |
| `PlateText` / `PlateText.styleFor` | The only plate typography (monospace, tabular). Dense places (slot cells, list rows) copy `styleFor` at a smaller size; never set `fontFamily: 'monospace'` by hand. |
| `ReceiptSummaryDialog` | Post-action summary. With `onPrint` the primary is a filled **Imprimir** (closes, then prints post-frame) and the full receipt is a secondary **Ver recibo** text button; without a printer **Generar recibo** stays primary. `nextActionLabel` renders as a tonal button. |

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
  sticky save bar when the form scrolls (check-in uses
  `Scaffold.bottomNavigationBar` + `SafeArea` + `Space.md`), and inline
  validation: errors go on the offending field through
  `InputDecoration.errorText`; a banner is only for errors without a field.
  Every `DropdownButtonFormField` sets `isExpanded: true`: without it the
  selected label (a category or user name, or large text) overflows a phone
  width. Rows that put a primary action next to a title and text (the logo
  card) stack the action under the header instead of squeezing the `Row`.
  Long forms get a 360 dp + 1.6x text test that scrolls the whole page
  (`settings_page_test.dart`, "the whole form fits 360 dp").
- **Choice inputs**: up to five options render as a `Wrap` of `ChoiceChip`s
  (payment method, check-in category with availability; unavailable options
  disabled), more fall back to a dropdown.
- **Charge flows**: the row that started a server call shows a 20×20
  `CircularProgressIndicator` in its button and ignores re-entrant taps/scans;
  the primary action names the amount (`Cobrar $X`). Cash input offers
  `Exacto` plus the smallest covering bills as `ActionChip`s, autofocuses and
  confirms on keyboard *done*.
- **Bottom sheets / dialogs with fields**: add
  `MediaQuery.viewInsetsOf(context).bottom` to sheet padding, use
  `AlertDialog(scrollable: true)`, `textInputAction` next/done, and
  `textCapitalization.sentences` on free-text reasons.
- **Slot cells**: text from `textTheme.labelSmall`, wrapped in
  `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` + `FittedBox`;
  every non-maintenance cell is a semantic button (a free bay opens
  `/check-in?spot=<id>`).
- **Inbox**: notifications are grouped by day (today / yesterday / earlier),
  with an unread filter and an empty state that links to records.

When a new screen needs a new pattern, add it here and in `core/widgets`
instead of copying a private widget into a feature.
