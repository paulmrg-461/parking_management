"""Report endpoints (revenue, occupancy) — admin only."""

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status

from app.application.report_service import InvalidReportRangeError, ReportService
from app.infrastructure.repositories.report_repository import (
    SqlAlchemyReportRepository,
)
from app.presentation.deps import get_report_repository, require_admin
from app.presentation.schemas import (
    CategoryOccupancyRead,
    CategoryRevenueRead,
    DailyRevenueRead,
    OccupancyReportRead,
    RevenueReportRead,
)

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get(
    "/revenue",
    response_model=RevenueReportRead,
    dependencies=[Depends(require_admin)],
)
async def get_revenue_report(
    start_date: date,
    end_date: date,
    reports: SqlAlchemyReportRepository = Depends(get_report_repository),
) -> RevenueReportRead:
    try:
        report = await ReportService(reports).get_revenue_report(
            start_date, end_date
        )
    except InvalidReportRangeError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    return RevenueReportRead(
        start_date=start_date,
        end_date=end_date,
        total=report.total,
        by_day=[
            DailyRevenueRead(date=day.date, amount=day.amount)
            for day in report.by_day
        ],
        by_category=[
            CategoryRevenueRead(
                category_id=category.category_id,
                category_name=category.category_name,
                amount=category.amount,
            )
            for category in report.by_category
        ],
    )


@router.get(
    "/occupancy",
    response_model=OccupancyReportRead,
    dependencies=[Depends(require_admin)],
)
async def get_occupancy_report(
    reports: SqlAlchemyReportRepository = Depends(get_report_repository),
) -> OccupancyReportRead:
    report = await ReportService(reports).get_occupancy_report()
    return OccupancyReportRead(
        total_open=report.total_open,
        by_category=[
            CategoryOccupancyRead(
                category_id=category.category_id,
                category_name=category.category_name,
                count=category.count,
            )
            for category in report.by_category
        ],
    )
