"""Billing endpoints: optional live fare preview."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status

from app.application.billing_service import (
    FareCalculator,
    InvalidBillingPeriodError,
    MissingHourlyTariffError,
)
from app.infrastructure.repositories.tariff_repository import SqlAlchemyTariffRepository
from app.presentation.deps import get_current_user, get_tariff_repository

router = APIRouter(tags=["billing"])


@router.get(
    "/billing/quote",
    dependencies=[Depends(get_current_user)],
)
async def get_fare_quote(
    category_id: int,
    entry_time: datetime,
    exit_time: datetime,
    tariffs: SqlAlchemyTariffRepository = Depends(get_tariff_repository),
) -> dict[str, str]:
    try:
        amount = await FareCalculator().calculate_fare_for_session(
            category_id, entry_time, exit_time, tariffs
        )
    except InvalidBillingPeriodError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    except MissingHourlyTariffError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hourly tariff not configured for category",
        ) from exc
    return {"amount": str(amount)}
