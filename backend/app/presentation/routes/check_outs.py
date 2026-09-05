"""Check-out endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.application.billing_service import (
    InvalidBillingPeriodError,
    MissingHourlyTariffError,
)
from app.application.check_out_service import (
    CheckOutService,
    SessionAlreadyClosedError,
    SessionNotFoundError,
)
from app.domain.user import User
from app.infrastructure.repositories.monthly_pass_repository import (
    SqlAlchemyMonthlyPassRepository,
)
from app.infrastructure.repositories.parking_session_repository import (
    SqlAlchemyParkingSessionRepository,
)
from app.infrastructure.repositories.tariff_repository import (
    SqlAlchemyTariffRepository,
)
from app.infrastructure.repositories.vehicle_repository import (
    SqlAlchemyVehicleRepository,
)
from app.presentation.deps import (
    get_current_user,
    get_monthly_pass_repository,
    get_parking_session_repository,
    get_tariff_repository,
    get_vehicle_repository,
)
from app.presentation.schemas import CheckOutRead

router = APIRouter(tags=["check-outs"])


@router.post(
    "/check-outs/{session_id}",
    response_model=CheckOutRead,
)
async def create_check_out(
    session_id: int,
    current_user: User = Depends(get_current_user),
    sessions: SqlAlchemyParkingSessionRepository = Depends(
        get_parking_session_repository
    ),
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
    tariffs: SqlAlchemyTariffRepository = Depends(get_tariff_repository),
    monthly_passes: SqlAlchemyMonthlyPassRepository = Depends(
        get_monthly_pass_repository
    ),
) -> CheckOutRead:
    service = CheckOutService(sessions, vehicles, tariffs, monthly_passes)
    try:
        session = await service.close_session(session_id)
    except SessionNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
        ) from exc
    except SessionAlreadyClosedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Session already closed",
        ) from exc
    except MissingHourlyTariffError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hourly tariff not configured for category",
        ) from exc
    except InvalidBillingPeriodError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc

    vehicle = await vehicles.get_by_id(session.vehicle_id)
    return CheckOutRead(
        id=session.id,
        plate=vehicle.plate,
        entry_time=session.entry_time,
        exit_time=session.exit_time,
        status=session.status,
        amount_charged=session.amount_charged,
        ticket_number=session.ticket_number,
    )
