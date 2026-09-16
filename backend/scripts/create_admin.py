"""Bootstrap the first admin user on a fresh database.

Auth is PIN-based and every user is created via an admin-only endpoint, so a
brand-new database has no way to create its first admin through the API.
Run this once after `alembic upgrade head`:

    uv run python scripts/create_admin.py --username admin --display-name "Admin" --pin 1234

Inside the `backend` container (dependencies already installed, no need for
`uv run`'s sync check):

    docker compose exec backend python scripts/create_admin.py --username admin --display-name "Admin" --pin 1234

Refuses (without modifying anything) if a user with that username already
exists.
"""

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.application.user_service import DuplicateUsernameError, UserService
from app.domain.user import UserRole
from app.infrastructure.database import async_session_factory
from app.infrastructure.repositories.user_repository import SqlAlchemyUserRepository


async def _create_admin(username: str, display_name: str, pin: str) -> None:
    async with async_session_factory() as session:
        service = UserService(SqlAlchemyUserRepository(session))
        try:
            await service.create(
                username=username,
                display_name=display_name,
                role=UserRole.ADMIN,
                pin=pin,
            )
            await session.commit()
        except DuplicateUsernameError:
            print(f"User '{username}' already exists — nothing to do.")
            return
        except ValueError as exc:
            print(f"Invalid PIN: {exc}")
            return

    print(f"Admin user '{username}' created.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--username", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--pin", required=True, help="4 to 6 digits")
    args = parser.parse_args()

    asyncio.run(_create_admin(args.username, args.display_name, args.pin))


if __name__ == "__main__":
    main()
