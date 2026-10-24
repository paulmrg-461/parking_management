-- Minimal Supabase stubs for running the migrations against the
-- supabase/postgres image in CI (no GoTrue/Storage/Realtime containers).
create schema if not exists auth;
-- Created by supabase/migrate.sh in production; the diagnostics RPC reads it.
create table if not exists public.schema_migrations (
    name       text        primary key,
    applied_at timestamptz not null default now()
);

create schema if not exists storage;

create table if not exists auth.users (
    id uuid primary key,
    email text,
    raw_user_meta_data jsonb not null default '{}'::jsonb,
    raw_app_meta_data jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create table if not exists storage.buckets (
    id text primary key,
    name text,
    public boolean not null default false,
    file_size_limit bigint,
    allowed_mime_types text[]
);

create table if not exists storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text not null,
    name text not null,
    owner uuid,
    -- Mirrors the production column the diagnostics snapshot reads.
    metadata jsonb not null default '{}'::jsonb
);

-- Realtime publication is created by the Realtime service in production.
do $$
begin
    if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        create publication supabase_realtime;
    end if;
end $$;

-- The Supabase image revokes CREATE on public from postgres.
grant create, usage on schema public to postgres;
