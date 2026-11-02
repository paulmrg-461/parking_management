-- The migration runner keeps its bookkeeping in public.schema_migrations.
-- It must never be reachable through PostgREST: lock it down and let the
-- RLS guard in tests require row level security on every public table.

do $$
begin
    if to_regclass('public.schema_migrations') is not null then
        execute 'alter table public.schema_migrations enable row level security';
        execute 'revoke all on public.schema_migrations from public, anon, authenticated';
    end if;
end $$;
