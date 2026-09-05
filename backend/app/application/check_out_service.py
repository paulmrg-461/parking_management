"""Check-out use case: close an open parking session and charge its fare."""

from datetime import UTC, datetime

from app.application.billing_service import FareCalculator
from app.domain.parking_session import ParkingSession, SessionStatus
from app.domain.repositories import (
    ParkingSessionRepository,
    TariffRepository,
    VehicleRepository,
)


class SessionNotFoundError(Exception):
    pass


class SessionAlreadyClosedError(Exception):
    pass


class CheckOutService:
    def __init__(
        self,
        sessions: ParkingSessionRepository,
        vehicles: VehicleRepository,
        tariffs: TariffRepository,
    ):
        self._sessions = sessions
        self._vehicles = vehicles
        self._tariffs = tariffs

    async def close_session(
        self, session_id: int, exit_time: datetime | None = None
    ) -> ParkingSession:
        session = await self._sessions.get_by_id(session_id)
        if session is None:
            raise SessionNotFoundError(session_id)
        if session.status == SessionStatus.CLOSED:
            raise SessionAlreadyClosedError(session_id)

        vehicle = await self._vehicles.get_by_id(session.vehicle_id)
        resolved_exit_time = exit_time or datetime.now(UTC)

        # TODO(monthly-passes): look up an active pass for this vehicle once
        # that capability exists.
        amount = await FareCalculator().calculate_fare_for_session(
            vehicle.category_id,
            session.entry_time,
            resolved_exit_time,
            self._tariffs,
            has_active_monthly_pass=False,
        )

        session.status = SessionStatus.CLOSED
        session.exit_time = resolved_exit_time
        session.amount_charged = round(amount)
        session.ticket_number = f"TCK-{session_id:06d}"

        return await self._sessions.update(session)
