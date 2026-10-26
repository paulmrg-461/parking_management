-- Housekeeping: idempotency responses are only useful for 48 hours (the
-- client retry window). Without a purge the table grows forever.

create or replace function public.purge_expired_idempotency()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    deleted integer;
begin
    delete from public.idempotency_keys
     where created_at < now() - interval '48 hours';
    get diagnostics deleted = row_count;
    return deleted;
end;
$$;

grant execute on function public.purge_expired_idempotency() to authenticated;
