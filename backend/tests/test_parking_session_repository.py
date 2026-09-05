"""Parking session repository tests (Success / Failure / Security)."""

from datetime import UTC, datetime

import pytest

from app.domain.category import Category
from app.domain.parking_session import ParkingSession, SessionStatus
from app.domain.user import User, UserRole
from app.domain.vehicle import Vehicle
from app.infrastructure.repositories.category_repository import (
    SqlAlchemyCategoryRepository,
)
from app.infrastructure.repositories.parking_session_repository import (
    SqlAlchemyParkingSessionRepository,
)
from app.infrastructure.repositories.user_repository import SqlAlchemyUserRepository
from app.infrastructure.repositories.vehicle_repository import (
    SqlAlchemyVehicleRepository,
)


@pytest.fixture
async def vehicle_id(session_factory):
    async with session_factory() as session:
        category_repository = SqlAlchemyCategoryRepository(session)
        category = await category_repository.create(Category(id=None, name="carro"))
        vehicle_repository = SqlAlchemyVehicleRepository(session)
        vehicle = await vehicle_repository.create(
            Vehicle(id=None, plate="ABC123", category_id=category.id)
        )
        await session.commit()
        return vehicle.id


@pytest.fixture
async def operator_id(session_factory):
    async with session_factory() as session:
        user_repository = SqlAlchemyUserRepository(session)
        user = await user_repository.create(
            User(
                id=None,
                username="operator",
                display_name="Operator",
                role=UserRole.OPERATOR,
                pin_hash="hash",
            )
        )
        await session.commit()
        return user.id


@pytest.fixture
async def repository(session_factory):
    async with session_factory() as session:
        yield SqlAlchemyParkingSessionRepository(session)


async def test_create_and_get_open_by_vehicle_id(repository, vehicle_id, operator_id):
    session = await repository.create(
        ParkingSession(
            id=None,
            vehicle_id=vehicle_id,
            operator_id=operator_id,
            entry_time=datetime.now(UTC),
        )
    )

    fetched = await repository.get_open_by_vehicle_id(vehicle_id)

    assert fetched is not None
    assert fetched.id == session.id
    assert fetched.status == SessionStatus.OPEN


async def test_get_open_by_vehicle_id_returns_none_when_none_open(
    repository, vehicle_id
):
    assert await repository.get_open_by_vehicle_id(vehicle_id) is None


async def test_closed_session_is_excluded_from_open_list(
    repository, vehicle_id, operator_id
):
    session = await repository.create(
        ParkingSession(
            id=None,
            vehicle_id=vehicle_id,
            operator_id=operator_id,
            entry_time=datetime.now(UTC),
        )
    )
    session.status = SessionStatus.CLOSED
    await repository.update(session)

    assert await repository.get_open_by_vehicle_id(vehicle_id) is None
    assert session.id not in [s.id for s in await repository.list_open()]


async def test_update_round_trips_checkout_fields(
    repository, vehicle_id, operator_id
):
    entry_time = datetime.now(UTC)
    session = await repository.create(
        ParkingSession(
            id=None,
            vehicle_id=vehicle_id,
            operator_id=operator_id,
            entry_time=entry_time,
        )
    )
    exit_time = datetime.now(UTC)
    session.status = SessionStatus.CLOSED
    session.exit_time = exit_time
    session.amount_charged = 6000
    session.ticket_number = f"TCK-{session.id:06d}"

    updated = await repository.update(session)

    assert updated.status == SessionStatus.CLOSED
    assert updated.exit_time == exit_time
    assert updated.amount_charged == 6000
    assert updated.ticket_number == f"TCK-{session.id:06d}"

    refetched = await repository.get_by_id(session.id)
    assert refetched.exit_time == exit_time
    assert refetched.amount_charged == 6000
    assert refetched.ticket_number == f"TCK-{session.id:06d}"


async def test_new_session_has_no_checkout_fields(
    repository, vehicle_id, operator_id
):
    session = await repository.create(
        ParkingSession(
            id=None,
            vehicle_id=vehicle_id,
            operator_id=operator_id,
            entry_time=datetime.now(UTC),
        )
    )

    assert session.exit_time is None
    assert session.amount_charged is None
    assert session.ticket_number is None
