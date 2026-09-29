"""SQLAlchemy implementation of the parking settings repository port."""

from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.parking_settings import ParkingSettings
from app.domain.repositories import ParkingSettingsRepository
from app.infrastructure.models import ParkingSettingsModel

SINGLETON_ID = 1


class SqlAlchemyParkingSettingsRepository(ParkingSettingsRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    @staticmethod
    def _to_entity(model: ParkingSettingsModel) -> ParkingSettings:
        return ParkingSettings(
            id=model.id,
            name=model.name,
            address=model.address,
            schedule=model.schedule,
            phone=model.phone,
            website=model.website,
            whatsapp=model.whatsapp,
            logo_version=model.logo_version,
            logo_path=model.logo_path,
            updated_at=model.updated_at,
        )

    async def get(self) -> ParkingSettings | None:
        model = await self._session.get(ParkingSettingsModel, SINGLETON_ID)
        return self._to_entity(model) if model else None

    async def save(self, settings: ParkingSettings) -> ParkingSettings:
        model = await self._session.get(ParkingSettingsModel, SINGLETON_ID)
        if model is None:
            model = ParkingSettingsModel(id=SINGLETON_ID)
            self._session.add(model)
        self._apply(model, settings)
        await self._session.flush()
        # Server-managed updated_at is expired on flush; reload it here,
        # inside the async context (a later sync read would raise
        # MissingGreenlet).
        await self._session.refresh(model, ["updated_at"])
        return self._to_entity(model)

    @staticmethod
    def _apply(model: ParkingSettingsModel, settings: ParkingSettings) -> None:
        model.name = settings.name
        model.address = settings.address
        model.schedule = settings.schedule
        model.phone = settings.phone
        model.website = settings.website
        model.whatsapp = settings.whatsapp
        model.logo_version = settings.logo_version
        model.logo_path = settings.logo_path
