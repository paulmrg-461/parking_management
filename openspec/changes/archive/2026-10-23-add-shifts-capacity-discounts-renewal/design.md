## Decisions

1. **Shift attaches by exit time.** Check-out looks up the operator's shift
   covering `exit_at`, so an offline replay lands in the shift where the
   operator acted, not the one open at reconnect time.
2. **Expected cash is derived, not duplicated.** Cash sales come from closed
   sessions linked to the shift; withdrawals/deposits are explicit
   `cash_movements`. No sale rows are duplicated in the cash ledger.
3. **Capacity is enforced in a trigger with a per-category advisory lock.**
   This covers every insert path (RPC or future direct writes) and serializes
   concurrent check-ins so the limit cannot be exceeded.
4. **Discounts are admin-only and audited in the session row.** The gross fare
   remains derivable (`amount_charged + discount_amount`); the reason, actor
   and instant are stored with the session.
5. **Auto-renew creates a linked pass.** `renewed_from_id` is unique, making
   the daily job idempotent while preserving pass history; the old pass becomes
   inactive once its end date passes.
6. **Overstay/discount scope.** Overstay uses the existing notification center;
   no new push channel.

## Risks

- Cash reconciliation assumes a single cash drawer per operator shift.
- Capacity 0 means unlimited; a partially configured set of categories makes
  the dashboard's total capacity partial (per-category flags remain exact).
- Discounts are limited to admins; operators must escalate.
