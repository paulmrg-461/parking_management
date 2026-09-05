"""Security primitives tests (Success / Failure / Security)."""

import pytest

from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)


def test_password_hashes_and_verifies():
    hashed = hash_password("s3cret-password")

    assert hashed != "s3cret-password"
    assert verify_password("s3cret-password", hashed) is True


def test_wrong_password_is_rejected():
    hashed = hash_password("s3cret-password")

    assert verify_password("wrong-password", hashed) is False


def test_invalid_hash_is_rejected_gracefully():
    assert verify_password("s3cret-password", "not-a-valid-hash") is False


def test_access_token_roundtrip():
    token = create_access_token("user-1", "a-very-long-secret-key-for-testing-only-1234567890", "HS256", 60)

    assert decode_access_token(token, "a-very-long-secret-key-for-testing-only-1234567890", "HS256") == "user-1"


def test_invalid_token_raises():
    with pytest.raises(Exception):
        decode_access_token("not-a-token", "a-very-long-secret-key-for-testing-only-1234567890", "HS256")


def test_token_with_wrong_secret_raises():
    token = create_access_token("user-1", "a-very-long-secret-key-for-testing-only-1234567890", "HS256", 60)

    with pytest.raises(Exception):
        decode_access_token(token, "another-long-secret-key-for-testing-only-0987654321", "HS256")
