## Why

The parking operation needs to reconcile money (how each stay was paid), answer
customer questions about past visits, and act on vehicles that stay far longer
than expected. Today check-out only stores an amount and the app has no vehicle
timeline or overstay alert.

## What Changes

- Check-out records a payment method (`cash`, `card`, `transfer`,
  `monthly_pass`, `exempt`); a monthly pass forces `monthly_pass`.
- Revenue reports add a `by_payment` breakdown; receipts show the method.
- `vehicle_history(plate)` returns the vehicle profile, visits, total spent and
  the latest 100 sessions; Flutter adds a searchable `/history` page with an
  offline cache.
- `notify_overstays()` creates one admin notification per open vehicle per day
  after the configurable `parking_settings.overstay_hours` (default 24).
- The notifications cron runs the overstay sweep alongside pass-expiry alerts.

## Impact

- **Database**: migrations `0009`/`0010` (payment column + constraints, check-out
  RPC, report field, overstay alert, history RPC).
- **Flutter**: payment dialog + receipt/payment labels, report section, new
  vehicle-history feature and route; overstay notifications are automatic.
- **Ops**: `supabase/notifications-cron.sh` now calls `notify_overstays()`.
