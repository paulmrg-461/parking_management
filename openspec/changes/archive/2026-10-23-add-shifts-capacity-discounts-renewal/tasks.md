## 1. Shifts and cash

- [x] 1.1 Shift/cash tables, shift_id on sessions, RLS (own/admin reads)
- [x] 1.2 `open_shift`, `current_shift`, `close_shift`, `add_cash_movement`, `list_shifts`, `shift_totals`
- [x] 1.3 Check-out attaches the shift covering the exit time
- [x] 1.4 Flutter shift page (open, movement dialogs, close/arqueo, admin history) + route/home action
- [x] 1.5 Cubit/page tests and close notification

## 2. Capacity

- [x] 2.1 `categories.capacity` + constraint; serialized capacity trigger
- [x] 2.2 `occupancy_snapshot` (any user) with per-category capacity/is_full
- [x] 2.3 Flutter category capacity editor, dashboard used/capacity bar, full warning, localized `CategoryFullError`
- [x] 2.4 Cubit/trigger verification

## 3. Discounts

- [x] 3.1 Session discount columns (amount/reason/by/at) + check-out validation (admin + reason)
- [x] 3.2 Receipts show discount; report adds total/count
- [x] 3.3 Flutter checkout discount fields (admin only) and offline payload

## 4. Monthly pass auto-renewal

- [x] 4.1 `auto_renew` + `renewed_from_id`, idempotent renewal function + notifications
- [x] 4.2 Flutter pass form switch and list indicator
- [x] 4.3 Cron runs renewal
