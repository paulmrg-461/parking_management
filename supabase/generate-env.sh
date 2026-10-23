#!/bin/sh
# Generates/updates the secrets required by the self-hosted Supabase stack in
# the repository root `.env`. Safe to re-run: keeps existing values.
#
#   cp .env.example .env
#   sh supabase/generate-env.sh
set -eu

cd "$(dirname "$0")/.."

python3 - <<'PY'
import base64
import hashlib
import hmac
import json
import re
import secrets
import time
import uuid
from pathlib import Path

env_path = Path(".env")
if not env_path.exists():
    raise SystemExit("missing .env: run `cp .env.example .env` first")

lines = env_path.read_text().splitlines()
pattern = re.compile(r"^([A-Z0-9_]+)=(.*)$")

PLACEHOLDERS = {
    "",
    "postgres",
    "your-super-secret-and-long-postgres-password",
    "your-super-secret-jwt-token-with-at-least-32-characters-long",
    "this_password_is_insecure_and_should_be_updated",
    "your-32-character-encryption-key",
    "your-encryption-key-32-chars-min",
    "your-super-secret-and-long-logflare-key-public",
    "your-super-secret-and-long-logflare-key-private",
    "625729a08b95bf1b7ff351a663f3a23c",
    "850181e4652dd023b7a98c58ae0d2d34bd487ee0cc3254aed6eda37307425907",
    "supabase",
}


def current() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in lines:
        match = pattern.match(line)
        if match:
            values[match.group(1)] = match.group(2)
    return values


def put(key: str, value: str) -> None:
    global lines
    for index, line in enumerate(lines):
        match = pattern.match(line)
        if match and match.group(1) == key:
            lines[index] = f"{key}={value}"
            return
    lines.append(f"{key}={value}")


def ensure(key: str, value: str) -> None:
    existing = current().get(key, "")
    if existing in PLACEHOLDERS or (key in {"JWT_SECRET", "SECRET_KEY"} and len(existing) < 32):
        put(key, value)


def b64(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def jwt(secret: str, role: str) -> str:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "role": role,
        "iss": "supabase",
        "iat": now,
        "exp": now + 10 * 365 * 24 * 3600,
    }
    signing_input = (
        b64(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + b64(json.dumps(payload, separators=(",", ":")).encode())
    )
    signature = hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
    return signing_input + "." + b64(signature)


ensure("JWT_SECRET", secrets.token_urlsafe(48))
ensure("POSTGRES_PASSWORD", secrets.token_urlsafe(24))
ensure("SECRET_KEY_BASE", secrets.token_urlsafe(48))
ensure("DASHBOARD_PASSWORD", secrets.token_urlsafe(18))
ensure("PG_META_CRYPTO_KEY", secrets.token_hex(32))

# Fixed-length keys required by the services.
put("REALTIME_DB_ENC_KEY", secrets.token_hex(8))       # 16 chars
put("VAULT_ENC_KEY", secrets.token_hex(16))            # 32 chars
put("POOLER_TENANT_ID", str(uuid.uuid4()))
put("S3_PROTOCOL_ACCESS_KEY_ID", secrets.token_hex(16))
put("S3_PROTOCOL_ACCESS_KEY_SECRET", secrets.token_hex(32))

# Stack wiring (idempotent: only set when missing/placeholder).
put("POSTGRES_DB", current().get("POSTGRES_DB") or "parking")
put("POSTGRES_HOST", "db")
put("POSTGRES_PORT", current().get("POSTGRES_PORT") or "5432")
put("API_GW_HTTP_PORT", current().get("API_GW_HTTP_PORT") or "8000")
put("SUPABASE_PUBLIC_URL", f"http://localhost:{current().get('API_GW_HTTP_PORT', '8000')}")
put(
    "API_EXTERNAL_URL",
    f"{current().get('SUPABASE_PUBLIC_URL')}/auth/v1",
)
put("SITE_URL", current().get("SUPABASE_PUBLIC_URL"))
put("PASSWORD_MIN_LENGTH", "6")
put("DISABLE_SIGNUP", "true")
put("ENABLE_EMAIL_AUTOCONFIRM", "true")
put("ENABLE_PHONE_SIGNUP", "false")
put("ENABLE_PHONE_AUTOCONFIRM", "false")
put("PGRST_DB_SCHEMAS", "public")
put("PGRST_DB_EXTRA_SEARCH_PATH", "public")

# API keys are HS256 JWTs signed with the current JWT_SECRET.
JWT_SECRET = current()["JWT_SECRET"]
put("ANON_KEY", jwt(JWT_SECRET, "anon"))
put("SERVICE_ROLE_KEY", jwt(JWT_SECRET, "service_role"))
put("JWT_KEYS", "")
put("JWT_JWKS", "")
put("SUPABASE_PUBLISHABLE_KEY", "")
put("SUPABASE_SECRET_KEY", "")

# Fill any optional key the stack expects but this .env predates, using the
# example defaults (existing values are never overwritten).
example = Path(".env.example").read_text().splitlines()
known = current()
for line in example:
    match = pattern.match(line)
    if match and match.group(1) not in known:
        lines.append(line)
        known[match.group(1)] = match.group(2)

env_path.write_text("\n".join(lines) + "\n")
print(f"updated {env_path} ({len(current())} variables); secrets were not printed")
PY
