"""Report repository tests: direct aggregation math (Success / Failure)."""

from datetime import UTC, date, datetime

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
from app.infrastructure.repositories.report_repository import (
    SqlAlchemyReportRepository,
)
from app.infrastructure.repositories.user_repository import SqlAlchemyUserRepository
from app.infrastructure.repositories.vehicle_repository import (
    SqlAlchemyVehicleRepository,
)


async def _seed(session_factory):
    """Seed 2 categories, 2 vehicles, an operator, and a mix of sessions.

    - moto/PLATE-M: closed inside range (2026-01-02), closed outside range
      (2026-01-10), one open session.
    - carro/PLATE-C: closed inside range (2026-01-01).
    """
    async with session_factory() as session:
        categories = SqlAlchemyCategoryRepository(session)
        moto = await categories.create(Category(id=None, name="moto"))
        carro = await categories.create(Category(id=None, name="carro"))

        vehicles = SqlAlchemyVehicleRepository(session)
        moto_vehicle = await vehicles.create(
            Vehicle(id=None, plate="PLATE-M", category_id=moto.id)
        )
        carro_vehicle = await vehicles.create(
            Vehicle(id=None, plate="PLATE-C", category_id=carro.id)
        )

        users = SqlAlchemyUserRepository(session)
        operator = await users.create(
            User(
                id=None,
                username="operator-report",
                display_name="Operator",
                role=UserRole.OPERATOR,
                pin_hash="hash",
            )
        )

        sessions = SqlAlchemyParkingSessionRepository(session)
        in_range_moto = await sessions.create(
            ParkingSession(
                id=None,
                vehicle_id=moto_vehicle.id,
                operator_id=operator.id,
                entry_time=datetime(2026, 1, 2, 8, 0, tzinfo=UTC),
            )
        )
        in_range_moto.status = SessionStatus.CLOSED
        in_range_moto.exit_time = datetime(2026, 1, 2, 10, 0, tzinfo=UTC)
        in_range_moto.amount_charged = 2000
        in_range_moto.ticket_number = "TCK-000001"
        await sessions.update(in_range_moto)

        out_of_range_moto = await sessions.create(
            ParkingSession(
                id=None,
                vehicle_id=moto_vehicle.id,
                operator_id=operator.id,
                entry_time=datetime(2026, 1, 10, 8, 0, tzinfo=UTC),
            )
        )
        out_of_range_moto.status = SessionStatus.CLOSED
        out_of_range_moto.exit_time = datetime(2026, 1, 10, 9, 0, tzinfo=UTC)
        out_of_range_moto.amount_charged = 9999
        out_of_range_moto.ticket_number = "TCK-000002"
        await sessions.update(out_of_range_moto)

        in_range_carro = await sessions.create(
            ParkingSession(
                id=None,
                vehicle_id=carro_vehicle.id,
                operator_id=operator.id,
                entry_time=datetime(2026, 1, 1, 7, 0, tzinfo=UTC),
            )
        )
        in_range_carro.status = SessionStatus.CLOSED
        in_range_carro.exit_time = datetime(2026, 1, 1, 23, 30, tzinfo=UTC)
        in_range_carro.amount_charged = 5000
        in_range_carro.ticket_number = "TCK-000003"
        await sessions.update(in_range_carro)

        await sessions.create(
            ParkingSession(
                id=None,
                vehicle_id=moto_vehicle.id,
                operator_id=operator.id,
                entry_time=datetime(2026, 1, 3, 8, 0, tzinfo=UTC),
            )
        )

        await session.commit()


@pytest.fixture
async def seeded(session_factory):
    await _seed(session_factory)
    return session_factory


async def test_revenue_by_range_sums_by_day_and_category(seeded):
    async with seeded() as session:
        repository = SqlAlchemyReportRepository(session)

        report = await repository.revenue_by_range(
            date(2026, 1, 1), date(2026, 1, 2)
        )

        assert report.total == 7000  # 2000 (moto) + 5000 (carro); excludes 9999
        by_day = {entry.date: entry.amount for entry in report.by_day}
        assert by_day == {"2026-01-01": 5000, "2026-01-02": 2000}
        by_category = {
            entry.category_name: entry.amount for entry in report.by_category
        }
        assert by_category == {"moto": 2000, "carro": 5000}


async def test_revenue_by_range_excludes_sessions_outside_range(seeded):
    async with seeded() as session:
        repository = SqlAlchemyReportRepository(session)

        report = await repository.revenue_by_range(
            date(2026, 1, 1), date(2026, 1, 2)
        )

        amounts = [entry.amount for entry in report.by_day]
        assert 9999 not in amounts


async def test_current_occupancy_counts_only_open_sessions_by_category(seeded):
    async with seeded() as session:
        repository = SqlAlchemyReportRepository(session)

        report = await repository.current_occupancy()

        assert report.total_open == 1
        by_category = {entry.category_name: entry.count for entry in report.by_category}
        assert by_category == {"moto": 1}
        assert "carro" not in by_category
