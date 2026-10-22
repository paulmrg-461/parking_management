"""Supabase (GoTrue) token validation during the migration."""

from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.domain.errors import InvalidTokenError
from app.infrastructure.security import (
    CompositeTokenIssuer,
    JwtConfig,
    JwtTokenIssuer,
    SupabaseTokenIssuer,
)

SUPABASE_SECRET = "supabase-test-secret-at-least-32-bytes-long"
LEGACY_SECRET = "legacy-test-secret-at-least-32-bytes-long"


def _supabase_token(
    *,
    secret: str = SUPABASE_SECRET,
    email: str | None = "operator@parking.local",
    audience: str = "authenticated",
) -> str:
    now = datetime.now(UTC)
    payload: dict[str, object] = {
        "sub": "8a1d5a8e-0000-0000-0000-000000000001",
        "aud": audience,
        "role": "authenticated",
        "iat": now,
        "exp": now + timedelta(hours=1),
    }
    if email is not None:
        payload["email"] = email
    return jwt.encode(payload, secret, algorithm="HS256")


def test_supabase_token_maps_email_to_username():
    issuer = SupabaseTokenIssuer(SUPABASE_SECRET)

    assert issuer.subject_of(_supabase_token()) == "operator"


def test_supabase_token_with_another_secret_is_rejected():
    issuer = SupabaseTokenIssuer(SUPABASE_SECRET)

    with pytest.raises(InvalidTokenError):
        issuer.subject_of(_supabase_token(secret="wrong-secret"))


def test_supabase_token_without_email_is_rejected():
    issuer = SupabaseTokenIssuer(SUPABASE_SECRET)

    with pytest.raises(InvalidTokenError):
        issuer.subject_of(_supabase_token(email=None))


def test_supabase_token_with_wrong_audience_is_rejected():
    issuer = SupabaseTokenIssuer(SUPABASE_SECRET)

    with pytest.raises(InvalidTokenError):
        issuer.subject_of(_supabase_token(audience="service_role"))


def test_unsigned_token_is_rejected():
    """Security: alg=none must never authenticate a request."""
    token = jwt.encode(
        {"aud": "authenticated", "email": "admin@parking.local"},
        key="",
        algorithm="none",
    )
    issuer = SupabaseTokenIssuer(SUPABASE_SECRET)

    with pytest.raises(InvalidTokenError):
        issuer.subject_of(token)


def test_composite_accepts_legacy_and_supabase_tokens():
    legacy = JwtTokenIssuer(JwtConfig(LEGACY_SECRET))
    issuer = CompositeTokenIssuer(legacy, SupabaseTokenIssuer(SUPABASE_SECRET))

    assert issuer.subject_of(legacy.issue("admin")) == "admin"
    assert issuer.subject_of(_supabase_token()) == "operator"


def test_composite_rejects_a_token_signed_by_neither():
    legacy = JwtTokenIssuer(JwtConfig(LEGACY_SECRET))
    issuer = CompositeTokenIssuer(legacy, SupabaseTokenIssuer(SUPABASE_SECRET))

    with pytest.raises(InvalidTokenError):
        issuer.subject_of(_supabase_token(secret="unknown-secret"))
