"""Check-in endpoint tests (Success / Failure / Security)."""

import os

from app.core.security import hash_password
from app.domain.user import User, UserRole
from app.infrastructure.local_evidence_storage import LocalEvidenceStorage
from app.infrastructure.repositories.user_repository import SqlAlchemyUserRepository
from app.main import app
from app.presentation.deps import get_evidence_storage


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


async def _operator_headers(client, session_factory):
    await _seed_user(session_factory, "operator", UserRole.OPERATOR)
    token = (await _login(client, "operator")).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def _create_vehicle(client, headers, plate="ABC123"):
    category = await client.post(
        "/api/categories", json={"name": "carro"}, headers=headers
    )
    if category.status_code != 201:
        # non-admin cannot create categories/vehicles; use admin instead.
        raise AssertionError("expected admin headers for setup")
    vehicle = await client.post(
        "/api/vehicles",
        json={"plate": plate, "category_id": category.json()["id"]},
        headers=headers,
    )
    return vehicle.json()


async def _admin_headers(client, session_factory):
    await _seed_user(session_factory, "admin", UserRole.ADMIN)
    token = (await _login(client, "admin")).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _use_tmp_storage(tmp_path):
    storage = LocalEvidenceStorage(str(tmp_path))
    app.dependency_overrides[get_evidence_storage] = lambda: storage


async def test_check_in_existing_vehicle_with_photos(
    client, session_factory, tmp_path
):
    admin_headers = await _admin_headers(client, session_factory)
    await _create_vehicle(client, admin_headers)
    operator_headers = await _operator_headers(client, session_factory)
    _use_tmp_storage(tmp_path)

    response = await client.post(
        "/api/check-ins",
        data={"plate": "abc123"},
        files=[("photos", ("dent.jpg", b"fake-bytes", "image/jpeg"))],
        headers=operator_headers,
    )

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "open"
    assert len(body["photos"]) == 1
    stored_path = os.path.join(str(tmp_path), body["photos"][0]["file_path"])
    assert os.path.isfile(stored_path)
    with open(stored_path, "rb") as f:
        assert f.read() == b"fake-bytes"


async def test_check_in_without_photos(client, session_factory, tmp_path):
    admin_headers = await _admin_headers(client, session_factory)
    await _create_vehicle(client, admin_headers, plate="NOPHOTO1")
    operator_headers = await _operator_headers(client, session_factory)
    _use_tmp_storage(tmp_path)

    response = await client.post(
        "/api/check-ins",
        data={"plate": "NOPHOTO1"},
        headers=operator_headers,
    )

    assert response.status_code == 201
    assert response.json()["photos"] == []


async def test_check_in_unknown_plate_is_not_found(client, session_factory, tmp_path):
    operator_headers = await _operator_headers(client, session_factory)
    _use_tmp_storage(tmp_path)

    response = await client.post(
        "/api/check-ins",
        data={"plate": "ZZZ999"},
        headers=operator_headers,
    )

    assert response.status_code == 404


async def test_duplicate_open_session_is_conflict(client, session_factory, tmp_path):
    admin_headers = await _admin_headers(client, session_factory)
    await _create_vehicle(client, admin_headers, plate="DUP123")
    operator_headers = await _operator_headers(client, session_factory)
    _use_tmp_storage(tmp_path)
    await client.post(
        "/api/check-ins", data={"plate": "DUP123"}, headers=operator_headers
    )

    response = await client.post(
        "/api/check-ins", data={"plate": "DUP123"}, headers=operator_headers
    )

    assert response.status_code == 409


async def test_unauthenticated_check_in_is_rejected(client, tmp_path):
    _use_tmp_storage(tmp_path)

    response = await client.post("/api/check-ins", data={"plate": "ABC123"})

    assert response.status_code == 401


async def test_list_open_sessions(client, session_factory, tmp_path):
    admin_headers = await _admin_headers(client, session_factory)
    await _create_vehicle(client, admin_headers, plate="LIST123")
    operator_headers = await _operator_headers(client, session_factory)
    _use_tmp_storage(tmp_path)
    await client.post(
        "/api/check-ins", data={"plate": "LIST123"}, headers=operator_headers
    )

    response = await client.get("/api/check-ins", headers=operator_headers)

    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["status"] == "open"
