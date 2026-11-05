# Host scheduling with systemd

The stack does not schedule work inside the app containers (except `pg_cron`
when the image ships it). These units run the same scripts the runbooks use:

| Unit | Cadence | Script |
|---|---|---|
| `parking-healthcheck.timer` | every 5 min | `supabase/healthcheck.sh` |
| `parking-cron.timer` | every minute | `supabase/notifications-cron.sh` (notifications, push, retention fallback) |
| `parking-backup.timer` | daily 03:15 | `supabase/backup.sh` (dump + storage + optional offsite) |

## Install (on the host, as root)

```bash
# 1. Put the repo at /opt/parking (or edit WorkingDirectory in every unit).
cd /opt/parking

# 2. Install the units.
cp tool/systemd/parking-*.service tool/systemd/parking-*.timer /etc/systemd/system/
systemctl daemon-reload

# 3. Alert webhook (optional): edit the unit instead of committing secrets.
systemctl edit parking-healthcheck.service
# [Service]
# Environment=HEALTHCHECK_WEBHOOK=https://hooks.example/parking

# 4. Enable and start.
systemctl enable --now parking-healthcheck.timer parking-cron.timer parking-backup.timer

# 5. Verify.
systemctl list-timers 'parking-*'
journalctl -u parking-healthcheck.service -n 50 --no-pager
journalctl -u parking-backup.service -n 50 --no-pager
```

## Backup retention and offsite

`supabase/backup.sh` writes `backups/<UTC timestamp>/` with the database dump,
storage archive, `SHA256SUMS` and a manifest, and validates the dump with
`pg_restore --list` before declaring success.

- `BACKUP_KEEP=14` keeps the newest 14 local archives (default in the unit).
- `BACKUP_REMOTE=rclone-remote:parking/backups` (set in `.env` or the unit) copies
  each archive offsite with `rclone copy --checksum`; the job fails if the copy
  fails. Install `rclone` and `rclone config` once on the host.
- `HEALTHCHECK_WEBHOOK` posts failures to Slack/Teams. The healthcheck also warns
  when the newest backup is older than 26 h or the disk is ≥ 90 % full.
- Restore procedure: [`runbook-restore.md`](runbook-restore.md). Drill monthly
  with `supabase/restore-drill.sh`.

## Notes

- The units assume Docker is installed and the stack starts on boot
  (`docker compose up -d` with `restart: unless-stopped`), or enable the
  compose service separately.
- Do not put secrets in the unit files; use `EnvironmentFile=/opt/parking/.env`
  (`chmod 600`) or `systemctl edit`.
- `idempotency_keys`, notifications, audit, WhatsApp and reservations already
  have SQL retention functions; `pg_cron` schedules them when available and
  `parking-cron` is the fallback.
