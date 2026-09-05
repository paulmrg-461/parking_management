"""Repository ports for the parking domain."""

from abc import ABC, abstractmethod

from app.domain.category import Category
from app.domain.evidence_photo import EvidencePhoto
from app.domain.parking_session import ParkingSession
from app.domain.tariff import Tariff
from app.domain.user import User
from app.domain.vehicle import Vehicle


class UserRepository(ABC):
    @abstractmethod
    async def get_by_username(self, username: str) -> User | None:
        raise NotImplementedError

    @abstractmethod
    async def get_by_id(self, user_id: int) -> User | None:
        raise NotImplementedError

    @abstractmethod
    async def list_all(self) -> list[User]:
        raise NotImplementedError

    @abstractmethod
    async def create(self, user: User) -> User:
        raise NotImplementedError

    @abstractmethod
    async def update(self, user: User) -> User:
        raise NotImplementedError


class CategoryRepository(ABC):
    @abstractmethod
    async def get_by_name(self, name: str) -> Category | None:
        raise NotImplementedError

    @abstractmethod
    async def get_by_id(self, category_id: int) -> Category | None:
        raise NotImplementedError

    @abstractmethod
    async def list_all(self) -> list[Category]:
        raise NotImplementedError

    @abstractmethod
    async def create(self, category: Category) -> Category:
        raise NotImplementedError

    @abstractmethod
    async def update(self, category: Category) -> Category:
        raise NotImplementedError

    @abstractmethod
    async def delete(self, category_id: int) -> None:
        raise NotImplementedError


class TariffRepository(ABC):
    @abstractmethod
    async def get_by_id(self, tariff_id: int) -> Tariff | None:
        raise NotImplementedError

    @abstractmethod
    async def list_all(self) -> list[Tariff]:
        raise NotImplementedError

    @abstractmethod
    async def list_by_category(self, category_id: int) -> list[Tariff]:
        raise NotImplementedError

    @abstractmethod
    async def create(self, tariff: Tariff) -> Tariff:
        raise NotImplementedError

    @abstractmethod
    async def update(self, tariff: Tariff) -> Tariff:
        raise NotImplementedError

    @abstractmethod
    async def delete(self, tariff_id: int) -> None:
        raise NotImplementedError


class VehicleRepository(ABC):
    @abstractmethod
    async def get_by_id(self, vehicle_id: int) -> Vehicle | None:
        raise NotImplementedError

    @abstractmethod
    async def get_by_plate(self, plate: str) -> Vehicle | None:
        raise NotImplementedError

    @abstractmethod
    async def list_all(self) -> list[Vehicle]:
        raise NotImplementedError

    @abstractmethod
    async def create(self, vehicle: Vehicle) -> Vehicle:
        raise NotImplementedError

    @abstractmethod
    async def update(self, vehicle: Vehicle) -> Vehicle:
        raise NotImplementedError

    @abstractmethod
    async def delete(self, vehicle_id: int) -> None:
        raise NotImplementedError


class ParkingSessionRepository(ABC):
    @abstractmethod
    async def get_by_id(self, session_id: int) -> ParkingSession | None:
        raise NotImplementedError

    @abstractmethod
    async def get_open_by_vehicle_id(
        self, vehicle_id: int
    ) -> ParkingSession | None:
        raise NotImplementedError

    @abstractmethod
    async def list_open(self) -> list[ParkingSession]:
        raise NotImplementedError

    @abstractmethod
    async def create(self, session: ParkingSession) -> ParkingSession:
        raise NotImplementedError

    @abstractmethod
    async def update(self, session: ParkingSession) -> ParkingSession:
        raise NotImplementedError


class EvidencePhotoRepository(ABC):
    @abstractmethod
    async def list_by_session_id(self, session_id: int) -> list[EvidencePhoto]:
        raise NotImplementedError

    @abstractmethod
    async def create(self, photo: EvidencePhoto) -> EvidencePhoto:
        raise NotImplementedError
