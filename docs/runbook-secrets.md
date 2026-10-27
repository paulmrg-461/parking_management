# Secrets and PIN runbook

Everything lives in `.env` on the host (never in git) plus per-user PINs in
GoTrue. This runbook covers the quarterly review, how to rotate each secret,
and what to do if one leaks.

## 1. Inventory

| Secret | Consumed by | Rotating it… |
|---|---|---|
| `POSTGRES_PASSWORD` | db, auth, rest, realtime, storage, meta, functions, supavisor | Requires `ALTER USER` for each role + restart. No client rebuild. |
| `JWT_SECRET` | GoTrue (signing), PostgREST/Storage/Realtime (verification) | Invalidates every session. `ANON_KEY`/`SERVICE_ROLE_KEY` are derived from it, so they change too. App builds need the new anon key. |
| `ANON_KEY` / `SERVICE_ROLE_KEY` | Flutter build, storage, studio, cron, functions | Same rotation as `JWT_SECRET` (they are signed by it). The service key must stay server-side. |
| `DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD` | Studio basic auth at the proxy | Restart the proxy; nothing else changes. |
| Operator/admin PINs | One per user in GoTrue | Per user, no downtime. |
| `FCM_SERVICE_ACCOUNT_JSON` | `push-dispatch` | Replace the JSON, restart `functions`. |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | `push-dispatch`, web build | Browser subscriptions become invalid: users must re-enable notifications; rebuild the web app with the new public key. |
| `WHATSAPP_TOKEN` / `WHATSAPP_PHONE_NUMBER_ID` | `whatsapp-dispatch` | Replace in `.env`, restart `functions`. Queued messages keep retrying. |

`.env` must be `chmod 600` and excluded from git. Keep an encrypted copy
sealed somewhere safe (it is intentionally not part of `backup.sh`).

## 2. Quarterly review

```bash
cd /opt/parking
sh supabase/check-secrets.sh      # permissions, placeholders, tracked .env, signup flag
sh supabase/healthcheck.sh
sh supabase/tests/e2e.sh
```

Then, in the app:

1. `/users` — confirm every active account is needed, exactly one known
   administrator per site (the last-admin guard blocks removing the final one).
2. `/audit` — filter by actor and review user/role/membership changes.
3. `/diagnostics` — no failed pushes/WhatsApp messages, no stale sessions.
4. Rotate the bootstrap admin PIN (next section) if it has not changed this
   quarter.
5. Confirm the nightly backup exists and the monthly restore drill ran
   (`docs/runbook-restore.md`).

## 3. Rotate an operator PIN

From the app: `/users` → actions → **Reset PIN** (audited).

From the host (bootstrap admin, or when nobody can sign in):

```bash
sh supabase/rotate-pin.sh <username> <new-6-digit-pin>
```

It uses the GoTrue admin API with the service key, so it works without a
signed-in admin. It does not write an audit row (there is no human actor);
note the change in your ops log. Verify: sign in with the new PIN, the old one
must fail.

## 4. Rotate the JWT secret (and API keys)

Blast radius: every device is logged out; the app keeps its offline outbox and
session data, but must be rebuilt with the new `ANON_KEY` (or the deployment
must inject it through your distribution channel).

```bash
cd /opt/parking
sh supabase/backup.sh /var/backups/parking/pre-jwt-rotation

# 1. Blank the three values so generate-env.sh regenerates them together
sed -i 's/^JWT_SECRET=.*/JWT_SECRET=/' .env
sed -i 's/^ANON_KEY=.*/ANON_KEY=/' .env
sed -i 's/^SERVICE_ROLE_KEY=.*/SERVICE_ROLE_KEY=/' .env
sh supabase/generate-env.sh

# 2. Restart everything that verifies tokens
docker compose up -d --force-recreate auth rest storage realtime functions studio api-gw
docker compose ps
sh supabase/healthcheck.sh
```

3. Rebuild the clients with the new `--dart-define=SUPABASE_ANON_KEY=…` and
   distribute them. Until they update, old builds fail to authenticate (safe:
   they show the login screen, not data).
4. Host cron reads `.env` on every run, so `notifications-cron.sh`,
   `evidence-archive.sh` and the backup scripts pick up the new service key
   automatically.

## 5. Rotate the database password

No client rebuild; the stack restarts.

```bash
cd /opt/parking
new=$(openssl rand -hex 24)
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$new/" .env

# Every role that authenticates with that password (see docker-compose.yml):
for role in postgres supabase_admin supabase_auth_admin supabase_storage_admin authenticator; do
  docker compose exec -T db psql -U postgres -v ON_ERROR_STOP=1 \
    -c "alter user \"$role\" with password '$new';"
done

docker compose up -d --force-recreate db auth rest realtime storage meta functions supavisor
sh supabase/healthcheck.sh
```

If a service still fails to connect, check its `DATABASE_URL`/`PGRST_DB_URI`
in `docker-compose.yml` and repeat the `alter user` for that role.

## 6. Rotate push / WhatsApp credentials

- **FCM**: new service-account JSON → `.env` → `docker compose restart functions`.
- **VAPID**: new key pair → `.env` → restart `functions` → rebuild the web app
  with the new public key → users re-enable notifications in the inbox.
- **WhatsApp**: new system-user token → `.env` → `restart functions`. Failed
  queue rows retry; check `/diagnostics` afterwards.

## 7. Suspected leak

Order matters: stop the bleeding, then invalidate, then verify.

1. Remove public exposure if any (firewall/proxy), rotate the leaked secret.
2. If JWT or DB credentials leaked: rotate both (sections 4 and 5) — a JWT
   leak lets anyone sign tokens; a DB leak bypasses RLS.
3. Rotate the service-role consumers (`functions`, cron, `admin-users`).
4. Review `/audit` (admin actions), `client_error_reports` and the PostgreSQL
   logs for unexpected access.
5. Review users: disable anything unknown (`/users`), rotate all PINs.
6. Write down the incident: what leaked, window, actions, verification.
