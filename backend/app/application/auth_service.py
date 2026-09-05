"""Authentication use cases."""

from app.core.config import settings
from app.core.security import create_access_token, verify_password
from app.domain.repositories import UserRepository
from app.domain.user import User


class AuthService:
    def __init__(self, users: UserRepository):
        self._users = users

    async def login(self, username: str, pin: str) -> User | None:
        user = await self._users.get_by_username(username)
        if user is None or not user.is_active:
            return None
        if not verify_password(pin, user.pin_hash):
            return None
        return user

    def issue_token(self, user: User) -> str:
        return create_access_token(
            subject=user.username,
            secret=settings.secret_key,
            algorithm=settings.jwt_algorithm,
            expires_minutes=settings.access_token_expire_minutes,
        )
