"""Check-out use case: close an open parking session and charge its fare."""

from datetime import UTC, datetime

from app.application.billing_service import FareCalculator
from app.domain.parking_session import ParkingSession, SessionStatus
from app.domain.repositories import (
    MonthlyPassRepository,
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
        monthly_passes: MonthlyPassRepository,
    ):
        self._sessions = sessions
        self._vehicles = vehicles
        self._tariffs = tariffs
        self._monthly_passes = monthly_passes

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

        active_pass = await self._monthly_passes.get_active_for_vehicle(
            vehicle.id, resolved_exit_time.date()
        )
        has_active_monthly_pass = active_pass is not None

        amount = await FareCalculator().calculate_fare_for_session(
            vehicle.category_id,
            session.entry_time,
            resolved_exit_time,
            self._tariffs,
            has_active_monthly_pass=has_active_monthly_pass,
        )

        session.status = SessionStatus.CLOSED
        session.exit_time = resolved_exit_time
        session.amount_charged = round(amount)
        session.ticket_number = f"TCK-{session_id:06d}"

        return await self._sessions.update(session)
