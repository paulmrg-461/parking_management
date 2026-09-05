"""FastAPI dependencies: user repository, current user, admin guard."""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import decode_access_token
from app.domain.evidence_storage import EvidenceStoragePort
from app.domain.user import User, UserRole
from app.infrastructure.database import get_session
from app.infrastructure.local_evidence_storage import LocalEvidenceStorage
from app.infrastructure.repositories.category_repository import (
    SqlAlchemyCategoryRepository,
)
from app.infrastructure.repositories.evidence_photo_repository import (
    SqlAlchemyEvidencePhotoRepository,
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

_bearer = HTTPBearer(auto_error=False)


async def get_user_repository(
    session: AsyncSession = Depends(get_session),
) -> SqlAlchemyUserRepository:
    return SqlAlchemyUserRepository(session)


async def get_category_repository(
    session: AsyncSession = Depends(get_session),
) -> SqlAlchemyCategoryRepository:
    return SqlAlchemyCategoryRepository(session)


async def get_tariff_repository(
    session: AsyncSession = Depends(get_session),
) -> SqlAlchemyTariffRepository:
    return SqlAlchemyTariffRepository(session)


async def get_vehicle_repository(
    session: AsyncSession = Depends(get_session),
) -> SqlAlchemyVehicleRepository:
    return SqlAlchemyVehicleRepository(session)


async def get_parking_session_repository(
    session: AsyncSession = Depends(get_session),
) -> SqlAlchemyParkingSessionRepository:
    return SqlAlchemyParkingSessionRepository(session)


async def get_evidence_photo_repository(
    session: AsyncSession = Depends(get_session),
) -> SqlAlchemyEvidencePhotoRepository:
    return SqlAlchemyEvidencePhotoRepository(session)


async def get_evidence_storage() -> EvidenceStoragePort:
    return LocalEvidenceStorage(settings.evidence_storage_path)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    users: SqlAlchemyUserRepository = Depends(get_user_repository),
) -> User:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated"
        )
    try:
        username = decode_access_token(
            credentials.credentials, settings.secret_key, settings.jwt_algorithm
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        ) from exc
    user = await users.get_by_username(username)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )
    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Admin required"
        )
    return user
