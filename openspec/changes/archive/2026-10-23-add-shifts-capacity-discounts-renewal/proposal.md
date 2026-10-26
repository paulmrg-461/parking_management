## Why

The operation needs cash accountability per operator, a hard capacity limit per
category, a controlled way to grant discounts with an audit trail, and monthly
passes that do not silently expire when they are meant to continue.

## What Changes

- New shifts + cash movements: operators open a shift with an opening float,
  record withdrawals/deposits, and close with a counted-cash reconciliation
  (expected vs counted, difference). Check-outs attach to the shift open at the
  exit time; admins see recent shifts and get a close notification.
- Categories gain `capacity` (0 = unlimited); a serialized trigger rejects
  check-ins when a category is full. The occupancy snapshot and dashboard show
  used/available and full categories.
- Check-out accepts an admin-only discount (`amount` + mandatory reason),
  stores who/when/why, and reports total discounts.
- Monthly passes gain `auto_renew`: the cron creates a linked new pass for the
  same duration/amount when the old one expires, notifies admins, and manual
  passes keep the 3-day reminder.
- The notification cron runs pass renewal and overstay sweeps.

## Impact

- Migrations `0011` (capacity, discounts, shift tables), `0012` (shift RPCs),
  `0013` (auto-renewal).
- Flutter: category capacity editor, occupancy capacity/full warnings, shift
  page/route/home action, checkout discount fields, monthly pass auto-renew
  switch, report discount totals.
