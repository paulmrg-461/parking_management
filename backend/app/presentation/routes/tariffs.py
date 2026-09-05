"""Tariff endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.application.tariff_service import TariffNotFoundError, TariffPatch, TariffService
from app.domain.tariff import Tariff
from app.infrastructure.repositories.tariff_repository import SqlAlchemyTariffRepository
from app.presentation.deps import get_current_user, get_tariff_repository, require_admin
from app.presentation.schemas import TariffCreate, TariffRead, TariffUpdate

router = APIRouter(tags=["tariffs"])


@router.get(
    "/tariffs",
    response_model=list[TariffRead],
    dependencies=[Depends(get_current_user)],
)
async def list_tariffs(
    category_id: int | None = None,
    tariffs: SqlAlchemyTariffRepository = Depends(get_tariff_repository),
) -> list[TariffRead]:
    service = TariffService(tariffs)
    result = (
        await service.list_by_category(category_id)
        if category_id is not None
        else await service.list_all()
    )
    return [TariffRead.model_validate(tariff) for tariff in result]


@router.post(
    "/tariffs",
    response_model=TariffRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_admin)],
)
async def create_tariff(
    body: TariffCreate,
    tariffs: SqlAlchemyTariffRepository = Depends(get_tariff_repository),
) -> TariffRead:
    try:
        tariff = await TariffService(tariffs).create(
            Tariff(
                id=None,
                category_id=body.category_id,
                type=body.type,
                amount=body.amount,
                start_time=body.start_time,
                end_time=body.end_time,
            )
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    return TariffRead.model_validate(tariff)


@router.patch(
    "/tariffs/{tariff_id}",
    response_model=TariffRead,
    dependencies=[Depends(require_admin)],
)
async def update_tariff(
    tariff_id: int,
    body: TariffUpdate,
    tariffs: SqlAlchemyTariffRepository = Depends(get_tariff_repository),
) -> TariffRead:
    try:
        tariff = await TariffService(tariffs).update(
            tariff_id,
            TariffPatch(
                type=body.type,
                amount=body.amount,
                start_time=body.start_time,
                end_time=body.end_time,
                active=body.active,
            ),
        )
    except TariffNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Tariff not found"
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    return TariffRead.model_validate(tariff)


@router.delete(
    "/tariffs/{tariff_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_admin)],
)
async def delete_tariff(
    tariff_id: int,
    tariffs: SqlAlchemyTariffRepository = Depends(get_tariff_repository),
) -> None:
    try:
        await TariffService(tariffs).delete(tariff_id)
    except TariffNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Tariff not found"
        ) from exc
