# supabase-platform Specification

## Purpose
Self-hosted Supabase is the only backend: PostgreSQL 17 owns the data and
business rules, GoTrue owns credentials, PostgREST/Storage expose it, and the
Flutter client talks to them directly.

## Requirements
### Requirement: Self-hosted stack runs from the repository compose
The repository SHALL bring up the official self-hosted Supabase services
through `docker-compose.yml`, exposing the API gateway on port 8000.

#### Scenario: Stack is healthy
- **WHEN** `docker compose up -d` finishes pulling
- **THEN** Postgres, GoTrue, PostgREST, Storage, Studio and the gateway report
  healthy and Studio is reachable on port 8000

### Requirement: SQL migrations own the schema
The system SHALL apply `supabase/migrations/*.sql` exactly once, in filename
order, tracking them in `public.schema_migrations`.

#### Scenario: Re-running the migrator
- **WHEN** the `supabase-migrate` service runs again
- **THEN** already-applied files are skipped and no data is recreated

### Requirement: GoTrue owns credentials
The system SHALL authenticate operators through GoTrue using
`<username>@parking.local` and a 6-digit PIN as the password, and SHALL mirror
`auth.users` into `public.users` with the role from `app_metadata`.

#### Scenario: Operator signs in
- **WHEN** an active operator submits their username and PIN
- **THEN** GoTrue returns an access token and the profile exists in
  `public.users` with the same role

#### Scenario: Wrong PIN
- **WHEN** a wrong PIN is submitted
- **THEN** no token is issued and no profile is modified

### Requirement: Row level security is default-deny
`anon` SHALL have no table grants; `authenticated` access SHALL be limited by
RLS policies, and every session/evidence write SHALL go through a security
definer RPC or a Storage policy.

#### Scenario: Anonymous read
- **WHEN** a request uses only the anon key
- **THEN** reading application tables is denied

#### Scenario: Operator escalation
- **WHEN** an operator tries to write reference data or call an admin function
- **THEN** the request is rejected and the data is unchanged

### Requirement: Business rules live in SQL
Fare calculation, check-in/check-out, reports and branding SHALL be implemented
as PostgreSQL functions that derive the operator from `auth.uid()` and validate
timestamps server-side.

#### Scenario: Offline check-in replay
- **WHEN** the same idempotency key is replayed
- **THEN** the stored response is returned and no second session is created

#### Scenario: Fare parity
- **WHEN** a stay is priced
- **THEN** fractional hours ceil once per calendar day per rate type, the night
  window replaces the day rate, and the daily cap applies independently per day

### Requirement: Storage buckets
Evidence photos SHALL live in the private `evidence` bucket and branding in the
public `branding` bucket, enforced by Storage policies.

#### Scenario: Anonymous evidence access
- **WHEN** an unauthenticated client requests an evidence object
- **THEN** the request is denied

#### Scenario: Public branding
- **WHEN** the login screen requests the branding logo before authentication
- **THEN** the public branding object is served
