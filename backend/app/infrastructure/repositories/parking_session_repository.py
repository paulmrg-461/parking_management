"""SQLAlchemy implementation of the parking session repository port."""

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.parking_session import ParkingSession, SessionStatus
from app.domain.repositories import ParkingSessionRepository
from app.infrastructure.models import ParkingSessionModel


def _as_utc(value: datetime | None) -> datetime | None:
    # SQLite (used by the test suite) does not persist tzinfo on
    # DateTime(timezone=True) columns, so values round-trip as naive even
    # though every timestamp in this codebase is written in UTC. Normalize
    # on read so callers can always compare/subtract these safely.
    if value is not None and value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value


class SqlAlchemyParkingSessionRepository(ParkingSessionRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    @staticmethod
    def _to_entity(model: ParkingSessionModel) -> ParkingSession:
        return ParkingSession(
            id=model.id,
            vehicle_id=model.vehicle_id,
            operator_id=model.operator_id,
            entry_time=_as_utc(model.entry_time),
            status=SessionStatus(model.status),
            exit_time=_as_utc(model.exit_time),
            amount_charged=model.amount_charged,
            ticket_number=model.ticket_number,
        )

    async def get_by_id(self, session_id: int) -> ParkingSession | None:
        model = await self._session.get(ParkingSessionModel, session_id)
        return self._to_entity(model) if model else None

    async def get_open_by_vehicle_id(
        self, vehicle_id: int
    ) -> ParkingSession | None:
        result = await self._session.execute(
            select(ParkingSessionModel).where(
                ParkingSessionModel.vehicle_id == vehicle_id,
                ParkingSessionModel.status == SessionStatus.OPEN.value,
            )
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def list_open(self) -> list[ParkingSession]:
        result = await self._session.execute(
            select(ParkingSessionModel)
            .where(ParkingSessionModel.status == SessionStatus.OPEN.value)
            .order_by(ParkingSessionModel.entry_time)
        )
        return [self._to_entity(model) for model in result.scalars()]

    async def create(self, session: ParkingSession) -> ParkingSession:
        model = ParkingSessionModel(
            vehicle_id=session.vehicle_id,
            operator_id=session.operator_id,
            entry_time=session.entry_time,
            status=session.status.value,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def update(self, session: ParkingSession) -> ParkingSession:
        model = await self._session.get(ParkingSessionModel, session.id)
        model.status = session.status.value
        model.exit_time = session.exit_time
        model.amount_charged = session.amount_charged
        model.ticket_number = session.ticket_number
        await self._session.flush()
        return self._to_entity(model)
