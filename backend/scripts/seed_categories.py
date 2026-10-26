"""Seed the default vehicle categories on a fresh database.

A brand-new database has no categories, which blocks the Flutter check-in
flow for unregistered vehicles (the category dropdown is disabled when empty).
Run this once after `alembic upgrade head` to create the standard set:

    uv run python scripts/seed_categories.py

Inside the `backend` container:

    docker compose exec backend python scripts/seed_categories.py

Idempotent: categories that already exist (by name) are left untouched.
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.application.category_service import CategoryService
from app.domain.errors import DuplicateCategoryNameError
from app.infrastructure.database import async_session_factory
from app.infrastructure.repositories.category_repository import SqlAlchemyCategoryRepository

DEFAULT_CATEGORIES = ("moto", "car", "camioneta", "camion", "bus")


async def _seed() -> None:
    async with async_session_factory() as session:
        service = CategoryService(SqlAlchemyCategoryRepository(session))
        created = 0
        for name in DEFAULT_CATEGORIES:
            try:
                await service.create(name)
                created += 1
            except DuplicateCategoryNameError:
                continue
        await session.commit()
    print(f"Categories seeded: {created} created, "
          f"{len(DEFAULT_CATEGORIES) - created} already present.")


def main() -> None:
    asyncio.run(_seed())


if __name__ == "__main__":
    main()
