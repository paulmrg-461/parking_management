"""Fare quote use case: load a category's tariffs and price a stay."""

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

from app.domain.billing import FareCalculator, StayPeriod, select_category_tariffs
from app.domain.repositories import TariffRepository


@dataclass(frozen=True)
class StayQuery:
    """Parameter object: a category's stay to be priced."""

    category_id: int
    entry_time: datetime
    exit_time: datetime
    has_active_monthly_pass: bool = False

    @property
    def period(self) -> StayPeriod:
        return StayPeriod(self.entry_time, self.exit_time, self.has_active_monthly_pass)


class FareService:
    def __init__(self, tariffs: TariffRepository, calculator: FareCalculator):
        self._tariffs = tariffs
        self._calculator = calculator

    async def quote(self, query: StayQuery) -> Decimal:
        rows = await self._tariffs.list_by_category(query.category_id)
        tariffs = select_category_tariffs(query.category_id, rows)
        return self._calculator.calculate_fare(tariffs, query.period)
