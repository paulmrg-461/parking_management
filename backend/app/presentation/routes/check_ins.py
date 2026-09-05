"""Check-in endpoints."""

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status

from app.application.check_in_service import (
    CheckInService,
    DuplicateOpenSessionError,
    VehicleNotFoundError,
)
from app.domain.evidence_storage import EvidenceStoragePort
from app.domain.parking_session import ParkingSession
from app.domain.user import User
from app.infrastructure.repositories.evidence_photo_repository import (
    SqlAlchemyEvidencePhotoRepository,
)
from app.infrastructure.repositories.parking_session_repository import (
    SqlAlchemyParkingSessionRepository,
)
from app.infrastructure.repositories.vehicle_repository import (
    SqlAlchemyVehicleRepository,
)
from app.presentation.deps import (
    get_current_user,
    get_evidence_photo_repository,
    get_evidence_storage,
    get_parking_session_repository,
    get_vehicle_repository,
)
from app.presentation.schemas import CheckInRead, EvidencePhotoRead

router = APIRouter(tags=["check-ins"])


async def _to_check_in_read(
    service: CheckInService, session: ParkingSession
) -> CheckInRead:
    photos = await service.list_photos(session.id)
    return CheckInRead(
        id=session.id,
        vehicle_id=session.vehicle_id,
        operator_id=session.operator_id,
        entry_time=session.entry_time,
        status=session.status,
        photos=[EvidencePhotoRead.model_validate(photo) for photo in photos],
    )


@router.get(
    "/check-ins",
    response_model=list[CheckInRead],
    dependencies=[Depends(get_current_user)],
)
async def list_check_ins(
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
    sessions: SqlAlchemyParkingSessionRepository = Depends(
        get_parking_session_repository
    ),
    photos: SqlAlchemyEvidencePhotoRepository = Depends(
        get_evidence_photo_repository
    ),
) -> list[CheckInRead]:
    service = CheckInService(vehicles, sessions, photos)
    open_sessions = await service.list_open_sessions()
    return [await _to_check_in_read(service, session) for session in open_sessions]


@router.post(
    "/check-ins",
    response_model=CheckInRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_check_in(
    plate: str = Form(...),
    photos: list[UploadFile] = File(default=[]),
    current_user: User = Depends(get_current_user),
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
    sessions: SqlAlchemyParkingSessionRepository = Depends(
        get_parking_session_repository
    ),
    photo_repository: SqlAlchemyEvidencePhotoRepository = Depends(
        get_evidence_photo_repository
    ),
    storage: EvidenceStoragePort = Depends(get_evidence_storage),
) -> CheckInRead:
    photo_paths = []
    for upload in photos:
        content = await upload.read()
        photo_paths.append(await storage.save(upload.filename or "photo", content))

    service = CheckInService(vehicles, sessions, photo_repository)
    try:
        session = await service.create_check_in(
            plate=plate, operator_id=current_user.id, photo_paths=photo_paths
        )
    except VehicleNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found"
        ) from exc
    except DuplicateOpenSessionError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Vehicle already has an open session",
        ) from exc

    return await _to_check_in_read(service, session)
