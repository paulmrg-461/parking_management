"""Check-in use cases."""

from datetime import UTC, datetime

from app.domain.evidence_photo import EvidencePhoto
from app.domain.parking_session import ParkingSession
from app.domain.repositories import (
    EvidencePhotoRepository,
    ParkingSessionRepository,
    VehicleRepository,
)
from app.domain.vehicle import normalize_plate


class VehicleNotFoundError(Exception):
    pass


class DuplicateOpenSessionError(Exception):
    pass


class CheckInService:
    def __init__(
        self,
        vehicles: VehicleRepository,
        sessions: ParkingSessionRepository,
        photos: EvidencePhotoRepository,
    ):
        self._vehicles = vehicles
        self._sessions = sessions
        self._photos = photos

    async def create_check_in(
        self, plate: str, operator_id: int, photo_paths: list[str]
    ) -> ParkingSession:
        vehicle = await self._vehicles.get_by_plate(normalize_plate(plate))
        if vehicle is None:
            raise VehicleNotFoundError(plate)

        existing = await self._sessions.get_open_by_vehicle_id(vehicle.id)
        if existing is not None:
            raise DuplicateOpenSessionError(vehicle.id)

        session = await self._sessions.create(
            ParkingSession(
                id=None,
                vehicle_id=vehicle.id,
                operator_id=operator_id,
                entry_time=datetime.now(UTC),
            )
        )

        for path in photo_paths:
            await self._photos.create(
                EvidencePhoto(
                    id=None,
                    session_id=session.id,
                    file_path=path,
                    taken_at=datetime.now(UTC),
                )
            )

        return session

    async def list_open_sessions(self) -> list[ParkingSession]:
        return await self._sessions.list_open()

    async def list_photos(self, session_id: int) -> list[EvidencePhoto]:
        return await self._photos.list_by_session_id(session_id)
