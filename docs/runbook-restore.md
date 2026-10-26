# Restore runbook

How to prove a backup is good (drill) and how to bring a production instance
back after data loss or a bad deploy.

- **RPO** (data you can lose): up to the last successful `backup.sh`, nightly
  by default — schedule it more often if that is not acceptable.
- **RTO** (time to be back): ~15–30 min on the standard VM (restore + restart +
  smoke test), most of it waiting for services.
- A backup contains **the database and the Storage volume** and a `manifest.txt`.
  It does **not** contain `.env` (secrets). Keep that separate and backed up.

## 1. Monthly drill (safe, no downtime)

Restores the newest backup into a scratch database, compares schema, RPCs, RLS
policies, grants and row counts against the live database, checks the storage
archive, then drops the scratch database.

```bash
cd /opt/parking
sh supabase/restore-drill.sh                # takes a fresh backup first
sh supabase/restore-drill.sh backups/<stamp> # or an existing one
```

Expected output ends with `restore drill OK: … is restorable`. Record the date
and result; investigate any `FAIL:` line before the next release.

What it verifies:

| Check | Why |
|---|---|
| `pg_restore` exits cleanly | The dump is not corrupt and every extension exists. |
| `schema_migrations` matches | The backup has the schema the app expects. |
| Core RPCs exist | `check_in`, `check_out`, `dashboard_today`, `report_revenue`, `list_audit_log`, `current_lot_id`. |
| RLS policy count matches | Data isolation survived the dump. |
| `authenticated` table grants | The app can read its tables after the restore. |
| Row counts per table | Data is complete (users, lots, categories, sessions, shifts, …). |
| Storage archive entries | Photos/branding objects are present. |

## 2. Restore a production instance

> Destructive. Take a backup of the current state first, even if it is broken:
> `sh supabase/backup.sh`.

```bash
cd /opt/parking

# 1. Freeze writes: stop API/auth (keeps the DB up for the restore)
docker compose stop auth rest realtime storage functions supavisor

# 2. Restore (guarded by an explicit confirmation)
RESTORE_CONFIRM=yes sh supabase/restore.sh backups/<stamp>

# 3. Bring everything back
docker compose up -d
docker compose ps                    # wait for healthy
docker compose logs --tail=20 supabase-migrate
```

`restore.sh` terminates sessions, `pg_restore --clean --if-exists --no-owner`
as **`supabase_admin`** (the role that owns the app objects and granted the
original ACLs — restoring as `postgres` loses every grant), replaces
`supabase/volumes/storage`, and restarts the stack.

### Verification checklist

```bash
sh supabase/healthcheck.sh          # services, endpoints, backlog, no failures
sh supabase/diagnostics.sh          # counts and stuck work
sh supabase/tests/e2e.sh            # login → check-in → check-out → report
```

In the app: log in, check the dashboard occupancy, open `/reports`, `/audit`
and `/diagnostics`, and close one test plate end to end. Then tell operators
the system is back.

### On a new host

1. Install Docker and clone the repository at the same version.
2. Recreate `.env` with `generate-env.sh`. **Keep the same `JWT_SECRET`,
   `ANON_KEY` and `SERVICE_ROLE_KEY`** if restored clients (offline outbox) must
   keep working; rotating them forces every device to log in again.
3. `docker compose up -d`, then restore the DB + storage as above.
4. Recreate host cron jobs (`notifications-cron.sh`, `evidence-archive.sh`,
   `backup.sh`, `healthcheck.sh`).
5. Point DNS/proxy at the new host and run the checklist.

## 3. If the restore fails

- Keep the failed dump: `pg_restore` logs to `/tmp/parking-restore-drill.log`
  for the drill; for the real restore run it with the same `-v` output captured.
- Restore the pre-restore backup you took in step 0 to return to the previous
  state, then restore `supabase/volumes/storage` the same way.
- If `pg_restore` reports only ACL warnings (grantor/ownership), the data is
  usually intact: verify with the drill and the checklist, and re-run the
  migrations' grants by restoring as `supabase_admin`.
- Escalate with: `diagnostics.sh` output, `docker compose logs db`, the
  `manifest.txt` of both backups, and the failing `pg_restore` lines.

## 4. Cadence

| Task | Frequency | Owner |
|---|---|---|
| Nightly backup + offsite copy | daily 02:30 | cron |
| Restore drill | monthly | whoever is on call |
| Full disaster-recovery rehearsal on a scratch VM | before each major release | tech lead |
| Rotation of the bootstrap admin PIN and secrets review | quarterly | admin |
