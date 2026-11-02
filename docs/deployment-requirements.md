# Deployment requirements — edge server or cloud

Minimum, recommended and capacity-planning guidance for running the parking
stack on a **Linux edge server on site** or on a **cloud VM**, plus the managed
cloud alternative. Everything here is in English on purpose; keep it that way.

> The whole stack is Docker Compose: PostgreSQL + GoTrue + PostgREST + Realtime +
> Storage + imgproxy + Edge Functions + Envoy (and optionally Studio/meta and the
> Supavisor pooler). The Flutter app talks only to the gateway over HTTPS.

---

## 1. Deployment shapes

| Shape | What runs | When to use |
| --- | --- | --- |
| **A. Edge server (recommended for one site)** | One Linux host on site running this Compose stack; cabinets/phones use the LAN; evidence uploads stay local | One parking lot, unreliable WAN, lowest latency, predictable cost |
| **B. Cloud VM** | The same Compose stack on a Linux VM with a public DNS name and TLS | Several sites, remote administration, no on-site hardware |
| **C. Managed cloud** | Supabase hosted (DB, Auth, Storage, Realtime, Functions) + the Flutter web/APK | Smallest ops burden; no VM to patch; watch storage egress and plan limits |

Shapes A and B are identical for the app: only `SUPABASE_PUBLIC_URL`,
`API_EXTERNAL_URL`, `SITE_URL` and the app URLs change. Shape C replaces the
Compose services with the hosted project; migrations and Edge Functions still
come from this repo.

---

## 2. Hardware baseline

The figures include the full Compose stack (idle footprint measured at
**~1.2 GB RAM**; plan headroom for image transforms, storage transfers,
Postgres cache and backups).

| Deployment | vCPU | RAM | Disk | Notes |
| --- | --- | --- | --- | --- |
| **Absolute minimum** — 1 site, ≤100 vehicles/day, photos only, 30-day retention | 2 | 4 GB | 40 GB SSD | Works, but tight during backups and video uploads. Disable Studio + postgres-meta in production. |
| **Recommended** — 1–3 sites, ≤300 vehicles/day, photos + some video | 4 | 8 GB | 80–160 GB SSD | The sweet spot. Separate the backup target (offsite). |
| **Busy / multi-site** — 4–10 sites, 300–1,000 vehicles/day, video evidence | 8 | 16 GB | 320 GB+ NVMe | Put the DB on the fastest disk; offsite backups mandatory. |
| **Edge mini-PC (shape A)** | 4 cores | 8 GB | 256 GB SSD (or 512 GB with video) | amd64 (the stack images are x86_64); avoid SD cards/eMMC, use an SSD with power-loss protection; add a UPS. |

Rules of thumb:

- **CPU**: bursts come from imgproxy, Postgres queries and Edge Functions. Two
  cores survive a single site; four make backups and check-ins coexist happily.
- **RAM**: 4 GB is the floor for the full stack; 8 GB is the practical
  recommendation; 16 GB for multi-site or hundreds of open Realtime clients.
- **Disk**: use SSD/NVMe, never network or SD storage. Keep **≥25 % free** for
  Postgres WAL, vacuum and Docker images. Alert at 80 %.
- **Swap**: 2–4 GB on a 4 GB host (safety valve only, not a sizing strategy).
- **arm64**: possible only if every image has an arm64 build; the supported path
  in this repo is amd64.

---

## 3. Capacity planning (disk is the real constraint)

Disk is dominated by **evidence** (photos + optional walk-around video), not by
the database.

| Item | Typical size |
| --- | --- |
| Evidence photo | 0.5–3 MB (client caps 5 MB; up to 5 photos per check-in) |
| Evidence video | 10–40 MB typical (bucket/client cap 50 MB, 60 s) |
| Database row (session, vehicle, notification, audit) | ~1–5 KB + indexes |
| Branding logo | < 1 MB per site |

**Formula**

```
evidence/GB ≈ vehicles_per_day × (photos_MB + video_adoption × video_MB)
              × retention_days ÷ 1024
```

Examples:

- 100 vehicles/day, 5 photos × 2 MB, 30 % videos × 25 MB, 30 days:
  `100 × (10 + 0.3×25) × 30 ÷ 1024 ≈ 51 GB` → plan **80–100 GB** with headroom.
- 300 vehicles/day, same mix, 90 days: `≈ 460 GB` → 512 GB NVMe or shorter
  `evidence_retention_days`.
- Photos only, 100/day, 30 days: `≈ 29 GB` → 40 GB works, 80 GB recommended.

Database growth is modest (tens of MB to a few GB per year at hundreds of
sessions/day). Budget 10 GB for the DB volume + WAL, plus 2× the DB size for a
local dump before it is copied offsite.

**Backups**: `supabase/backup.sh` writes a compressed `pg_dump` plus a tarball
of `supabase/volumes/storage`. Size the backup target as **≥1.5×** the live
data and keep it **off the server**. A 30-day retention with nightly dumps
needs roughly `30 × (DB + new evidence/day)`.

---

## 4. Operating system and software

| Item | Minimum | Recommended |
| --- | --- | --- |
| OS | Debian 12 or Ubuntu 22.04 LTS (64-bit) | **Ubuntu 24.04 LTS** |
| Kernel | 5.15+ | distribution default (with security updates) |
| Docker Engine | 24.x | latest stable |
| Docker Compose | v2 (`docker compose`) | latest v2 |
| Tools | `git`, `curl`, `jq`, `tar`, `openssl` | + `chrony`, `fail2ban`, `unattended-upgrades` |
| Time sync | systemd-timesyncd | chrony against a nearby pool |
| Locale/timezone | UTF-8; site timezone in `parking_settings.business_timezone` | same; keep the host UTC and the site timezone in settings |
| Access | sudo user + SSH keys | SSH keys only, no root login, management over VPN/allowlist |

The host must run the Docker daemon (systemd) and start at boot
(`restart: unless-stopped` is set on the services).

---

## 5. Network and exposure

| Port | Scope | Purpose |
| --- | --- | --- |
| **443/tcp** | public | TLS reverse proxy → gateway (the only public port) |
| 80/tcp | public | ACME challenge / redirect to HTTPS |
| 22/tcp | restricted | SSH (allowlist/VPN, key auth) |
| 8000 (gateway) | **loopback only** in production | `API_GW_HTTP_PORT=127.0.0.1:8000` |
| 5432 / 6543 | **loopback only** | Postgres / pooler, only for admin tooling |
| 8080 (optional) | LAN only | static public evidence page (see `docs/slot-board.md` / nginx helper) |

Requirements:

- A **DNS name** (e.g. `parking.example.com`) pointing to the host and a
  **valid TLS certificate** (Caddy/Nginx/Traefik + Let's Encrypt). Android
  release builds **require HTTPS**; the app and the printed evidence QR use
  public URLs.
- The reverse proxy must support **WebSockets/HTTP Upgrade** for Realtime
  (`/realtime/v1`), long read timeouts (≥ 1 h) and a body limit **≥ 60 MB**
  (video evidence; photos are ≤ 5 MB each).
- Set `SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL`, `SITE_URL` and (for printed
  receipts) `APP_URL` to the public HTTPS URL; a mismatch breaks auth redirects,
  signed Storage URLs and QR links.
- Egress must allow HTTPS to the services you enable: FCM (push), Meta Graph
  (WhatsApp templates) and your SMTP/backup target. Nothing else is required.
- Bandwidth: ~1 Mbps per active device for normal use; budget **≥ 5 Mbps
  upload** at the cabin if video evidence is used (a 40 MB clip takes ~1 min at
  5 Mbps; photos upload in seconds). Realtime is lightweight (a few KB/s).
- Latency to the server: keep it under ~150 ms for a comfortable app; on-site
  edge (shape A) is ideal.

---

## 6. Security baseline

- Firewall (`ufw`/`nftables`): allow 22/80/443 only; bind 8000/5432/6543 to
  loopback; never expose Postgres or Studio publicly.
- `fail2ban` for SSH; key-only auth; automatic security updates; reboot window.
- Secrets only in `.env` (`chmod 600`), never in git or dart-defines:
  `supabase/check-secrets.sh`; rotate PINs with `supabase/rotate-pin.sh`;
  JWT/DB rotation and leak response in `docs/runbook-secrets.md`.
- Disable Studio (`studio`) and `meta` in production unless you need them, or
  reach them only through a VPN. They add attack surface and memory.
- Keep `DISABLE_SIGNUP=true` and a 6-digit PIN policy; admins create users
  through the `admin-users` Edge Function (service key stays server-side).
- Backups: nightly `supabase/backup.sh`, copied **offsite and encrypted**
  (3-2-1); test a restore monthly with `supabase/restore-drill.sh`; document
  RPO/RTO (default: RPO 24 h, RTO 1–2 h).
- Monitoring: run `supabase/healthcheck.sh` from cron (with its webhook),
  export container/disk alerts (Docker or node_exporter), and watch disk,
  memory and failed logins.
- Log rotation for Docker (`max-size`/`max-file`); keep the reverse-proxy
  access log for incident review.

---

## 7. Managed cloud (shape C) sizing

If you use Supabase hosted instead of a VM:

| Component | Sizing guidance |
| --- | --- |
| Postgres | Start at the **8 GB RAM** tier for one site; 16 GB for multi-site. The DB itself is small — RAM is for connections/cache. |
| Storage | Same evidence formula; video dominates. Choose enough included storage and watch egress (customers open evidence links). |
| Realtime | One connection per signed-in device; keep the plan's concurrent-connection limit above `devices × 2`. |
| Edge Functions | `admin-users`, `push-dispatch`, `evidence-archive`, `whatsapp-dispatch`, `public-evidence`; invocation volume is low (one per check-in/out plus retention jobs). |
| Scheduled work | Hosted Supabase does not give you `pg_cron` in the app DB in this setup: run retention/push jobs from an external scheduler (cron/GitHub Actions) against the functions, as documented. |
| Backups | Enable provider backups/PITR; still export a `pg_dump` + Storage copy offsite. |

For a cloud VM (shape B), use the same hardware table in section 2 and the same
TLS/port rules; only the machine is rented.

---

## 8. Minimum acceptance checklist

Before going live, confirm:

- [ ] Linux LTS, Docker Engine + Compose v2, time sync enabled.
- [ ] DNS resolves, TLS certificate valid, HTTP redirects to HTTPS.
- [ ] Only 22/80/443 public; gateway/Postgres/pooler on loopback.
- [ ] WebSockets work (Realtime) and the proxy body limit is ≥ 60 MB.
- [ ] `.env` filled, `chmod 600`, `check-secrets.sh` passes; admin user created
      with a non-default PIN.
- [ ] `docker compose up -d` healthy; `supabase/healthcheck.sh` reports 0
      failures (includes migrations).
- [ ] `evidence_retention_days` set; disk alert at 80 %; backups offsite and a
      restore drill completed.
- [ ] Public URLs (`SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL`, `SITE_URL`,
      `APP_URL`) point to the HTTPS host.
- [ ] Optional integrations decided: FCM, VAPID, Meta WhatsApp.
- [ ] A real e2e pass against the deployment
      (`SUPABASE_URL=… SUPABASE_ANON_KEY=… flutter test test/integration` or
      `sh supabase/tests/e2e.sh`).

---

## 9. Reference commands

```bash
# first boot
cp .env.example .env && sh supabase/generate-env.sh   # or fill the secrets
docker compose up -d
sh supabase/healthcheck.sh

# admin + demo data
sh supabase/create-operator.sh admin 123456 admin

# nightly (cron)
sh supabase/backup.sh
sh supabase/healthcheck.sh
```

Related: [`setup-cloud.md`](setup-cloud.md) (VM + TLS proxy walkthrough),
[`infrastructure.md`](infrastructure.md) (services, ports, volumes),
[`runbook-restore.md`](runbook-restore.md),
[`runbook-secrets.md`](runbook-secrets.md).
