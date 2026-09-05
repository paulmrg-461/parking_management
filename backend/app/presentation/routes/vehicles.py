"""Vehicle endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.application.vehicle_service import (
    DuplicatePlateError,
    VehicleNotFoundError,
    VehiclePatch,
    VehicleService,
)
from app.domain.vehicle import Vehicle
from app.infrastructure.repositories.vehicle_repository import SqlAlchemyVehicleRepository
from app.presentation.deps import get_current_user, get_vehicle_repository, require_admin
from app.presentation.schemas import VehicleCreate, VehicleRead, VehicleUpdate

router = APIRouter(tags=["vehicles"])


@router.get(
    "/vehicles",
    response_model=list[VehicleRead],
    dependencies=[Depends(get_current_user)],
)
async def list_vehicles(
    plate: str | None = None,
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
) -> list[VehicleRead]:
    service = VehicleService(vehicles)
    if plate is not None:
        vehicle = await service.find_by_plate(plate)
        return [VehicleRead.model_validate(vehicle)] if vehicle else []
    result = await service.list_all()
    return [VehicleRead.model_validate(vehicle) for vehicle in result]


@router.post(
    "/vehicles",
    response_model=VehicleRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_admin)],
)
async def create_vehicle(
    body: VehicleCreate,
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
) -> VehicleRead:
    try:
        vehicle = await VehicleService(vehicles).create(
            Vehicle(
                id=None,
                plate=body.plate,
                category_id=body.category_id,
                color=body.color,
                brand=body.brand,
            )
        )
    except DuplicatePlateError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Plate already exists"
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    return VehicleRead.model_validate(vehicle)


@router.patch(
    "/vehicles/{vehicle_id}",
    response_model=VehicleRead,
    dependencies=[Depends(require_admin)],
)
async def update_vehicle(
    vehicle_id: int,
    body: VehicleUpdate,
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
) -> VehicleRead:
    try:
        vehicle = await VehicleService(vehicles).update(
            vehicle_id,
            VehiclePatch(
                category_id=body.category_id,
                color=body.color,
                brand=body.brand,
            ),
        )
    except VehicleNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found"
        ) from exc
    return VehicleRead.model_validate(vehicle)


@router.delete(
    "/vehicles/{vehicle_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_admin)],
)
async def delete_vehicle(
    vehicle_id: int,
    vehicles: SqlAlchemyVehicleRepository = Depends(get_vehicle_repository),
) -> None:
    try:
        await VehicleService(vehicles).delete(vehicle_id)
    except VehicleNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found"
        ) from exc
