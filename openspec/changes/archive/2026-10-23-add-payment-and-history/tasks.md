## 1. Payments

- [x] 1.1 `payment_method` column + check constraint; `overstay_hours` setting
- [x] 1.2 Check-out RPC accepts/validates the method and forces monthly pass
- [x] 1.3 Report revenue returns `by_payment`
- [x] 1.4 Flutter payment dialog, receipt row and report section
- [x] 1.5 Tests for method forwarding, offline payload and invalid method

## 2. Vehicle history

- [x] 2.1 `vehicle_history(plate)` RPC with visits/total/open flag/sessions
- [x] 2.2 Flutter feature (entity/port/Supabase+Hive repository/cubit/page)
- [x] 2.3 `/history` route for both roles + home shortcut
- [x] 2.4 Cubit/page tests (success/failure/empty plate)

## 3. Overstay alerts

- [x] 3.1 `notify_overstays()` (daily dedupe, configurable hours)
- [x] 3.2 Cron script runs the sweep
