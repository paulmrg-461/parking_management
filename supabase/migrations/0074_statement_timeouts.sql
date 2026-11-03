-- Protect the database from runaway requests: bound how long a PostgREST
-- request may run and how long it may sit idle inside a transaction.
-- Service/edge-function traffic is unaffected (it uses the service role).
-- 15 s is generous for reports; the app's lists/pages are bounded and paged.

do $$
begin
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
        execute 'alter role authenticated set statement_timeout = ''15000''';
        execute 'alter role authenticated set idle_in_transaction_session_timeout = ''30000''';
    end if;
    if exists (select 1 from pg_roles where rolname = 'anon') then
        execute 'alter role anon set statement_timeout = ''5000''';
        execute 'alter role anon set idle_in_transaction_session_timeout = ''15000''';
    end if;
end $$;
