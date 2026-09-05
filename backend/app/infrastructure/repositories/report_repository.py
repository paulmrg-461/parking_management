"""SQLAlchemy implementation of the report repository port.

Read-only aggregation over existing tables (parking_sessions, vehicles,
categories) — no new tables, no domain aggregate persistence.
"""

from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.parking_session import SessionStatus
from app.domain.report import (
    CategoryOccupancy,
    CategoryRevenue,
    DailyRevenue,
    OccupancyReport,
    RevenueReport,
)
from app.domain.repositories import ReportRepository
from app.infrastructure.models import CategoryModel, ParkingSessionModel, VehicleModel


class SqlAlchemyReportRepository(ReportRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    async def revenue_by_range(
        self, start_date: date, end_date: date
    ) -> RevenueReport:
        range_start = datetime.combine(start_date, time.min, tzinfo=UTC)
        range_end = datetime.combine(end_date, time.min, tzinfo=UTC) + timedelta(
            days=1
        )
        amount_sum = func.coalesce(func.sum(ParkingSessionModel.amount_charged), 0)

        def _closed_in_range(query):
            return query.where(
                ParkingSessionModel.status == SessionStatus.CLOSED.value,
                ParkingSessionModel.exit_time >= range_start,
                ParkingSessionModel.exit_time < range_end,
            )

        total = await self._session.scalar(
            _closed_in_range(select(amount_sum))
        )

        day_column = func.date(ParkingSessionModel.exit_time)
        day_result = await self._session.execute(
            _closed_in_range(select(day_column, amount_sum))
            .group_by(day_column)
            .order_by(day_column)
        )
        by_day = [
            DailyRevenue(date=str(row[0]), amount=int(row[1]))
            for row in day_result.all()
        ]

        category_result = await self._session.execute(
            _closed_in_range(
                select(CategoryModel.id, CategoryModel.name, amount_sum)
                .join(VehicleModel, VehicleModel.id == ParkingSessionModel.vehicle_id)
                .join(CategoryModel, CategoryModel.id == VehicleModel.category_id)
            )
            .group_by(CategoryModel.id, CategoryModel.name)
            .order_by(CategoryModel.name)
        )
        by_category = [
            CategoryRevenue(category_id=row[0], category_name=row[1], amount=int(row[2]))
            for row in category_result.all()
        ]

        return RevenueReport(
            total=int(total or 0), by_day=by_day, by_category=by_category
        )

    async def current_occupancy(self) -> OccupancyReport:
        total_open = await self._session.scalar(
            select(func.count(ParkingSessionModel.id)).where(
                ParkingSessionModel.status == SessionStatus.OPEN.value
            )
        )

        category_result = await self._session.execute(
            select(
                CategoryModel.id,
                CategoryModel.name,
                func.count(ParkingSessionModel.id),
            )
            .join(VehicleModel, VehicleModel.id == ParkingSessionModel.vehicle_id)
            .join(CategoryModel, CategoryModel.id == VehicleModel.category_id)
            .where(ParkingSessionModel.status == SessionStatus.OPEN.value)
            .group_by(CategoryModel.id, CategoryModel.name)
            .order_by(CategoryModel.name)
        )
        by_category = [
            CategoryOccupancy(category_id=row[0], category_name=row[1], count=int(row[2]))
            for row in category_result.all()
        ]

        return OccupancyReport(total_open=int(total_open or 0), by_category=by_category)
