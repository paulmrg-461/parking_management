## Decisions

1. **Payment is part of the session, not a separate payments table.** One
   check-out has exactly one method; a table would add joins without benefit
   until split payments are supported.
2. **Monthly passes win.** If an active pass covers the exit date the RPC
   forces `monthly_pass`, regardless of the UI selection, so the audit trail
   matches the zero charge.
3. **History is an RPC, not a raw PostgREST embed.** It aggregates visits/total
   in one round trip and keeps the client from depending on join syntax; it
   returns the last 100 sessions for a plate.
4. **Overstay alerts dedupe per vehicle per day** (`overstay:<session>:<date>`)
   so the cron can run every minute without spamming admins.
5. **Offline history cache** keeps the last lookup per plate in Hive; it is
   cleared on logout like the other reference caches.

## Risks

- The report JSON grows with `by_payment`; older clients ignore unknown fields.
- Overstay threshold is configurable only via SQL for now (no settings UI).
- Payment method is not printed on the thermal/PDF receipt yet; it appears on
  the on-screen receipt and in reports.
