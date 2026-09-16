"""Check-out endpoint tests (Success / Failure / Security)."""

from datetime import UTC, datetime, timedelta

from app.application.check_out_service import CheckOutService
from app.core.security import hash_password
from app.domain.category import Category
from app.domain.parking_session import ParkingSession
from app.domain.tariff import Tariff, TariffType
from app.domain.user import User, UserRole
from app.domain.vehicle import Vehicle
from app.infrastructure.repositories.category_repository import (
    SqlAlchemyCategoryRepository,
)
from app.infrastructure.repositories.monthly_pass_repository import (
    SqlAlchemyMonthlyPassRepository,
)
from app.infrastructure.repositories.parking_session_repository import (
    SqlAlchemyParkingSessionRepository,
)
from app.infrastructure.repositories.tariff_repository import (
    SqlAlchemyTariffRepository,
)
from app.infrastructure.repositories.user_repository import SqlAlchemyUserRepository
from app.infrastructure.repositories.vehicle_repository import (
    SqlAlchemyVehicleRepository,
)


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


async def _admin_headers(client, session_factory):
    await _seed_user(session_factory, "admin", UserRole.ADMIN)
    token = (await _login(client, "admin")).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def _create_vehicle_with_hourly_tariff(
    client, headers, plate="ABC123", amount=3000
):
    category = await client.post(
        "/api/categories", json={"name": f"carro-{plate}"}, headers=headers
    )
    category_id = category.json()["id"]
    await client.post(
        "/api/tariffs",
        json={"category_id": category_id, "type": "hourly", "amount": amount},
        headers=headers,
    )
    vehicle = await client.post(
        "/api/vehicles",
        json={"plate": plate, "category_id": category_id},
        headers=headers,
    )
    return vehicle.json()


async def _check_in(client, headers, plate):
    response = await client.post(
        "/api/check-ins", data={"plate": plate}, headers=headers
    )
    return response.json()


async def test_check_out_open_session_charges_fare(client, session_factory):
    admin_headers = await _admin_headers(client, session_factory)
    await _create_vehicle_with_hourly_tariff(client, admin_headers, plate="OUT001")
    operator_headers = await _operator_headers(client, session_factory)
    check_in = await _check_in(client, operator_headers, "OUT001")
    session_id = check_in["id"]

    response = await client.post(
        f"/api/check-outs/{session_id}", headers=operator_headers
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "closed"
    assert body["amount_charged"] >= 0
    assert body["ticket_number"] == f"TCK-{session_id:06d}"
    assert body["plate"] == "OUT001"
    assert body["exit_time"] is not None


async def test_check_out_service_computes_exact_amount_for_injected_exit_time(
    session_factory,
):
    """Service-level determinism check: fixed entry/exit -> exact fare."""
    async with session_factory() as session:
        category_repository = SqlAlchemyCategoryRepository(session)
        category = await category_repository.create(Category(id=None, name="carro"))
        tariff_repository = SqlAlchemyTariffRepository(session)
        await tariff_repository.create(
            Tariff(
                id=None,
                category_id=category.id,
                type=TariffType.HOURLY,
                amount=3000,
                start_time=None,
                end_time=None,
            )
        )
        vehicle_repository = SqlAlchemyVehicleRepository(session)
        vehicle = await vehicle_repository.create(
            Vehicle(id=None, plate="EXACT01", category_id=category.id)
        )
        user_repository = SqlAlchemyUserRepository(session)
        operator = await user_repository.create(
            User(
                id=None,
                username="op-exact",
                display_name="Operator",
                role=UserRole.OPERATOR,
                pin_hash="hash",
            )
        )
        session_repository = SqlAlchemyParkingSessionRepository(session)
        entry_time = datetime(2026, 1, 1, 8, 0, tzinfo=UTC)
        parking_session = await session_repository.create(
            ParkingSession(
                id=None,
                vehicle_id=vehicle.id,
                operator_id=operator.id,
                entry_time=entry_time,
            )
        )
        await session.commit()

        monthly_pass_repository = SqlAlchemyMonthlyPassRepository(session)
        service = CheckOutService(
            session_repository, vehicle_repository, tariff_repository, monthly_pass_repository
        )
        exit_time = entry_time + timedelta(hours=1, minutes=5)

        closed = await service.close_session(parking_session.id, exit_time=exit_time)

        assert closed.amount_charged == 6000  # 2h ceil * 3000
        assert closed.exit_time == exit_time
        assert closed.ticket_number == f"TCK-{parking_session.id:06d}"


async def test_check_out_uses_client_supplied_exit_time(client, session_factory):
    admin_headers = await _admin_headers(client, session_factory)
    await _create_vehicle_with_hourly_tariff(client, admin_headers, plate="OUT005")
    operator_headers = await _operator_headers(client, session_factory)
    check_in = await _check_in(client, operator_headers, "OUT005")
    session_id = check_in["id"]
    entry_time = datetime.fromisoformat(check_in["entry_time"])
    client_exit_time = entry_time + timedelta(hours=2)

    response = await client.post(
        f"/api/check-outs/{session_id}",
        json={"client_exit_time": client_exit_time.isoformat()},
        headers=operator_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert datetime.fromisoformat(body["exit_time"]) == client_exit_time
    assert body["amount_charged"] == 6000  # 2h ceil * 3000


async def test_check_out_unknown_session_is_not_found(client, session_factory):
    operator_headers = await _operator_headers(client, session_factory)

    response = await client.post("/api/check-outs/999999", headers=operator_headers)

    assert response.status_code == 404


async def test_check_out_already_closed_session_is_conflict(
    client, session_factory
):
    admin_headers = await _admin_headers(client, session_factory)
    await _create_vehicle_with_hourly_tariff(client, admin_headers, plate="OUT002")
    operator_headers = await _operator_headers(client, session_factory)
    check_in = await _check_in(client, operator_headers, "OUT002")
    session_id = check_in["id"]
    await client.post(f"/api/check-outs/{session_id}", headers=operator_headers)

    response = await client.post(
        f"/api/check-outs/{session_id}", headers=operator_headers
    )

    assert response.status_code == 409


async def test_unauthenticated_check_out_is_rejected(client, session_factory):
    admin_headers = await _admin_headers(client, session_factory)
    await _create_vehicle_with_hourly_tariff(client, admin_headers, plate="OUT003")
    operator_headers = await _operator_headers(client, session_factory)
    check_in = await _check_in(client, operator_headers, "OUT003")
    session_id = check_in["id"]

    response = await client.post(f"/api/check-outs/{session_id}")

    assert response.status_code == 401


async def test_check_out_with_active_monthly_pass_charges_zero(
    client, session_factory
):
    admin_headers = await _admin_headers(client, session_factory)
    vehicle = await _create_vehicle_with_hourly_tariff(
        client, admin_headers, plate="OUT004"
    )
    today = datetime.now(UTC).date()
    await client.post(
        "/api/monthly-passes",
        json={
            "vehicle_id": vehicle["id"],
            "start_date": (today - timedelta(days=1)).isoformat(),
            "end_date": (today + timedelta(days=30)).isoformat(),
            "amount": 100000,
        },
        headers=admin_headers,
    )
    operator_headers = await _operator_headers(client, session_factory)
    check_in = await _check_in(client, operator_headers, "OUT004")
    session_id = check_in["id"]

    response = await client.post(
        f"/api/check-outs/{session_id}", headers=operator_headers
    )

    assert response.status_code == 200
    assert response.json()["amount_charged"] == 0
