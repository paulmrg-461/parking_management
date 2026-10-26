-- Existing active passes predate 0016 and therefore have no charge row.
-- Create the pending charge once so admins can collect them from the UI.
insert into public.monthly_pass_payments (
    monthly_pass_id, amount, payment_method, due_date
)
select mp.id,
       mp.amount,
       mp.auto_renew_payment_method,
       mp.start_date
  from public.monthly_passes mp
 where mp.active
   and mp.end_date >= current_date
   and not exists (
       select 1 from public.monthly_pass_payments p
        where p.monthly_pass_id = mp.id
   )
on conflict (monthly_pass_id) do nothing;
