"""User management use cases."""

from app.core.security import hash_password
from app.domain.repositories import UserRepository
from app.domain.user import User, UserRole, validate_pin


class DuplicateUsernameError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class UserService:
    def __init__(self, users: UserRepository):
        self._users = users

    async def create(
        self, username: str, display_name: str, role: UserRole, pin: str
    ) -> User:
        validate_pin(pin)
        if await self._users.get_by_username(username) is not None:
            raise DuplicateUsernameError(username)
        user = User(
            id=None,
            username=username,
            display_name=display_name,
            role=role,
            pin_hash=hash_password(pin),
        )
        return await self._users.create(user)

    async def list_all(self) -> list[User]:
        return await self._users.list_all()

    async def update(
        self,
        user_id: int,
        display_name: str | None,
        role: UserRole | None,
        is_active: bool | None,
    ) -> User:
        user = await self._users.get_by_id(user_id)
        if user is None:
            raise UserNotFoundError(user_id)
        if display_name is not None:
            user.display_name = display_name
        if role is not None:
            user.role = role
        if is_active is not None:
            user.is_active = is_active
        return await self._users.update(user)
