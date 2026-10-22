"""Security adapters: Argon2id password hasher and JWT token issuer."""

from dataclasses import dataclass
from datetime import timedelta

import jwt

from app.core import security
from app.domain.clock import Clock, system_clock
from app.domain.errors import InvalidTokenError
from app.domain.ports import PasswordHasher, TokenIssuer


class Argon2PasswordHasher(PasswordHasher):
    """Thread-offloaded Argon2id with timing-equalizing dummy verify."""

    async def hash(self, plain: str) -> str:
        return await security.hash_password_async(plain)

    async def verify(self, plain: str, hashed: str | None) -> bool:
        # Looked up at call time so tests can spy on the primitive.
        return await security.verify_password_async(plain, hashed)


@dataclass(frozen=True)
class JwtConfig:
    secret: str
    algorithm: str = "HS256"
    expires_minutes: int = 60

    @property
    def signing_key(self) -> security.SigningKey:
        return security.SigningKey(self.secret, self.algorithm)


class JwtTokenIssuer(TokenIssuer):
    def __init__(self, config: JwtConfig, clock: Clock = system_clock):
        self._config = config
        self._clock = clock

    def issue(self, subject: str) -> str:
        expires_at = self._clock() + timedelta(minutes=self._config.expires_minutes)
        claims = security.TokenClaims(subject, expires_at)
        return security.create_access_token(claims, self._config.signing_key)

    def subject_of(self, token: str) -> str:
        try:
            return security.decode_access_token(token, self._config.signing_key)
        except (jwt.PyJWTError, KeyError) as exc:
            raise InvalidTokenError() from exc


class SupabaseTokenIssuer(TokenIssuer):
    """Validates GoTrue access tokens and maps the email to a username.

    Self-hosted GoTrue signs HS256 tokens with the shared ``JWT_SECRET`` and
    puts the user's email in the payload. The app's local profile keeps the
    username as the email local-part (``operator@parking.local``).
    """

    def __init__(self, secret: str, audience: str = "authenticated"):
        self._secret = secret
        self._audience = audience

    def issue(self, subject: str) -> str:
        raise NotImplementedError("Supabase Auth issues its own tokens")

    def subject_of(self, token: str) -> str:
        try:
            payload = jwt.decode(
                token,
                self._secret,
                algorithms=["HS256"],
                audience=self._audience,
            )
        except jwt.PyJWTError as exc:
            raise InvalidTokenError() from exc
        email = payload.get("email")
        if not isinstance(email, str) or "@" not in email:
            raise InvalidTokenError()
        username = email.split("@", 1)[0].strip().lower()
        if not username:
            raise InvalidTokenError()
        return username


class CompositeTokenIssuer(TokenIssuer):
    """Accepts legacy PIN tokens and (optionally) Supabase Auth tokens."""

    def __init__(self, primary: TokenIssuer, fallback: TokenIssuer | None = None):
        self._primary = primary
        self._fallback = fallback

    def issue(self, subject: str) -> str:
        return self._primary.issue(subject)

    def subject_of(self, token: str) -> str:
        try:
            return self._primary.subject_of(token)
        except InvalidTokenError:
            if self._fallback is None:
                raise
            return self._fallback.subject_of(token)
