"""Monthly pass endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.application.monthly_pass_service import (
    MonthlyPassNotFoundError,
    MonthlyPassPatch,
    MonthlyPassService,
    VehicleNotFoundError,
)
from app.domain.monthly_pass import MonthlyPass
from app.infrastructure.repositories.monthly_pass_repository import (
    SqlAlchemyMonthlyPassRepository,
)
from app.infrastructure.repositories.vehicle_repository import (
    SqlAlchemyVehicleRepository,
)
from app.presentation.deps import (
    get_current_user,
    get_monthly_pass_repository,
    get_vehicle_repository,
    require_admin,
)
from app.presentation.schemas import (
    MonthlyPassCreate,
    MonthlyPassRead,
    MonthlyPassUpdate,
)

router = APIRouter(tags=["monthly-passes"])


@router.get(
    "/monthly-passes",
    response_model=list[MonthlyPassRead],
    dependencies=[Depends(get_current_user)],
)
async def list_monthly_passes(
    vehicle_id: int | None = None,
    passes: SqlAlchemyMonthlyPassRepository = Depends(get_monthly_pass_repository),
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
) -> list[MonthlyPassRead]:
    service = MonthlyPassService(passes, vehicles)
    result = (
        await service.list_by_vehicle(vehicle_id)
        if vehicle_id is not None
        else await service.list_all()
    )
    return [MonthlyPassRead.model_validate(item) for item in result]


@router.post(
    "/monthly-passes",
    response_model=MonthlyPassRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_admin)],
)
async def create_monthly_pass(
    body: MonthlyPassCreate,
    passes: SqlAlchemyMonthlyPassRepository = Depends(get_monthly_pass_repository),
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
) -> MonthlyPassRead:
    try:
        monthly_pass = await MonthlyPassService(passes, vehicles).create(
            MonthlyPass(
                id=None,
                vehicle_id=body.vehicle_id,
                start_date=body.start_date,
                end_date=body.end_date,
                amount=body.amount,
            )
        )
    except VehicleNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found"
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    return MonthlyPassRead.model_validate(monthly_pass)


@router.patch(
    "/monthly-passes/{pass_id}",
    response_model=MonthlyPassRead,
    dependencies=[Depends(require_admin)],
)
async def update_monthly_pass(
    pass_id: int,
    body: MonthlyPassUpdate,
    passes: SqlAlchemyMonthlyPassRepository = Depends(get_monthly_pass_repository),
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
) -> MonthlyPassRead:
    try:
        monthly_pass = await MonthlyPassService(passes, vehicles).update(
            pass_id,
            MonthlyPassPatch(
                start_date=body.start_date,
                end_date=body.end_date,
                amount=body.amount,
                active=body.active,
            ),
        )
    except MonthlyPassNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Monthly pass not found"
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    return MonthlyPassRead.model_validate(monthly_pass)


@router.delete(
    "/monthly-passes/{pass_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_admin)],
)
async def delete_monthly_pass(
    pass_id: int,
    passes: SqlAlchemyMonthlyPassRepository = Depends(get_monthly_pass_repository),
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
) -> None:
    try:
        await MonthlyPassService(passes, vehicles).delete(pass_id)
    except MonthlyPassNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Monthly pass not found"
        ) from exc
