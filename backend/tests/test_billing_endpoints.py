"""Billing quote endpoint tests (Success / Failure / Security)."""

from app.core.security import hash_password
from app.domain.user import User, UserRole
from app.infrastructure.repositories.user_repository import SqlAlchemyUserRepository


async def _seed_user(session_factory, username, role, pin="1234"):
    async with session_factory() as session:
        repository = SqlAlchemyUserRepository(session)
        await repository.create(
            User(
                id=None,
                username=username,
                display_name=username.title(),
                role=role,
                pin_hash=hash_password(pin),
            )
        )
        await session.commit()


async def _login(client, username, pin="1234"):
    return await client.post(
        "/api/auth/login", json={"username": username, "pin": pin}
    )


async def _auth_headers(client, session_factory):
    await _seed_user(session_factory, "admin", UserRole.ADMIN)
    token = (await _login(client, "admin")).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def _create_category_with_hourly_tariff(client, headers, amount=3000):
    category = await client.post(
        "/api/categories", json={"name": "carro"}, headers=headers
    )
    category_id = category.json()["id"]
    await client.post(
        "/api/tariffs",
        json={"category_id": category_id, "type": "hourly", "amount": amount},
        headers=headers,
    )
    return category_id


async def test_quote_returns_computed_amount(client, session_factory):
    headers = await _auth_headers(client, session_factory)
    category_id = await _create_category_with_hourly_tariff(client, headers, 3000)

    response = await client.get(
        "/api/billing/quote",
        params={
            "category_id": category_id,
            "entry_time": "2026-01-01T08:00:00Z",
            "exit_time": "2026-01-01T09:05:00Z",
        },
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json() == {"amount": "6000"}


async def test_quote_rejects_exit_before_entry(client, session_factory):
    headers = await _auth_headers(client, session_factory)
    category_id = await _create_category_with_hourly_tariff(client, headers)

    response = await client.get(
        "/api/billing/quote",
        params={
            "category_id": category_id,
            "entry_time": "2026-01-01T09:00:00Z",
            "exit_time": "2026-01-01T08:00:00Z",
        },
        headers=headers,
    )

    assert response.status_code == 422


async def test_quote_requires_authentication(client, session_factory):
    headers = await _auth_headers(client, session_factory)
    category_id = await _create_category_with_hourly_tariff(client, headers)

    response = await client.get(
        "/api/billing/quote",
        params={
            "category_id": category_id,
            "entry_time": "2026-01-01T08:00:00Z",
            "exit_time": "2026-01-01T09:00:00Z",
        },
    )

    assert response.status_code == 401
