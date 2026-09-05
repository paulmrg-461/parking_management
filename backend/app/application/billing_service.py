"""Fare calculation for a parking stay.

Pure, synchronous algorithm (`FareCalculator.calculate_fare`) plus a thin
async wrapper that loads a category's tariff rows. See
`openspec/changes/billing/design.md` (or, once archived,
`openspec/specs/billing/spec.md` + the archived design) for the full
rationale behind the rounding/cap granularity chosen below.
"""

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from decimal import Decimal

from app.domain.category_tariffs import CategoryTariffs
from app.domain.repositories import TariffRepository
from app.domain.tariff import Tariff, TariffType

_SECONDS_PER_HOUR = 3600


class InvalidBillingPeriodError(Exception):
    """Raised when exit_time is not strictly after entry_time."""


class MissingHourlyTariffError(Exception):
    """Raised when a category has no active hourly tariff configured."""


@dataclass(frozen=True)
class _DaySegment:
    day: date
    start: datetime
    end: datetime


class FareCalculator:
    """Computes the charge for a parking stay from a category's tariffs."""

    def calculate_fare(
        self,
        tariffs: CategoryTariffs,
        entry_time: datetime,
        exit_time: datetime,
        has_active_monthly_pass: bool = False,
    ) -> Decimal:
        if exit_time <= entry_time:
            raise InvalidBillingPeriodError("exit_time must be after entry_time")

        if has_active_monthly_pass:
            return Decimal("0")

        total = Decimal("0")
        for segment in _split_by_calendar_day(entry_time, exit_time):
            total += _charge_for_day(segment, tariffs)

        # Defense in depth: never return a negative charge, even if a
        # malformed tariff amount slipped past `tariffs` validation.
        return max(total, Decimal("0"))

    async def calculate_fare_for_session(
        self,
        category_id: int,
        entry_time: datetime,
        exit_time: datetime,
        tariff_repository: TariffRepository,
        has_active_monthly_pass: bool = False,
    ) -> Decimal:
        rows = await tariff_repository.list_by_category(category_id)
        hourly = _first_active(rows, TariffType.HOURLY)
        if hourly is None:
            raise MissingHourlyTariffError(category_id)

        tariffs = CategoryTariffs(
            category_id=category_id,
            hourly=hourly,
            daily=_first_active(rows, TariffType.DAILY),
            nightly=_first_active(rows, TariffType.NIGHTLY),
        )
        return self.calculate_fare(
            tariffs, entry_time, exit_time, has_active_monthly_pass
        )


def _first_active(rows: list[Tariff], tariff_type: TariffType) -> Tariff | None:
    for row in rows:
        if row.type == tariff_type and row.active:
            return row
    return None


def _split_by_calendar_day(entry_time: datetime, exit_time: datetime) -> list[_DaySegment]:
    """Split [entry_time, exit_time) into one sub-interval per calendar day.

    Calendar day = midnight-to-midnight in the datetimes' own tzinfo; this
    function does not convert timezones, it trusts whatever entry_time /
    exit_time already carry.
    """
    segments: list[_DaySegment] = []
    cursor = entry_time
    while cursor < exit_time:
        day = cursor.date()
        next_midnight = datetime.combine(day, time.min, tzinfo=cursor.tzinfo) + timedelta(
            days=1
        )
        segment_end = min(exit_time, next_midnight)
        segments.append(_DaySegment(day=day, start=cursor, end=segment_end))
        cursor = segment_end
    return segments


def _charge_for_day(segment: _DaySegment, tariffs: CategoryTariffs) -> Decimal:
    night_seconds, day_seconds = _split_seconds(segment, tariffs.nightly)

    hourly_rate = _clamped_amount(tariffs.hourly.amount)
    night_rate = (
        _clamped_amount(tariffs.nightly.amount) if tariffs.nightly is not None else Decimal("0")
    )

    # Rounding/cap granularity decision: ceil is applied ONCE PER CALENDAR
    # DAY, PER RATE TYPE — total night-window minutes for the day are summed
    # first and ceiled once, and total day-rate minutes for the day are
    # summed first and ceiled once. It is NOT ceiled per disjoint physical
    # sub-interval (a night window that wraps midnight can appear as two
    # separate pieces within one calendar day; ceiling each piece
    # independently would double-round, e.g. 5 min + 5 min of night time
    # would wrongly bill 2 rounded hours instead of 1). It is also NOT
    # pooled into a single ceil for the whole multi-day stay (that would let
    # fractional remainders across days cancel out and would break the
    # per-day cap, which must apply independently to every day touched,
    # partial first/last day included).
    day_hours = _ceil_hours(day_seconds)
    night_hours = _ceil_hours(night_seconds)

    charge = Decimal(day_hours) * hourly_rate + Decimal(night_hours) * night_rate

    if tariffs.daily is not None:
        daily_rate = _clamped_amount(tariffs.daily.amount)
        charge = min(charge, daily_rate)

    return charge


def _split_seconds(segment: _DaySegment, nightly: Tariff | None) -> tuple[int, int]:
    """Return (night_seconds, day_seconds) for this calendar-day segment."""
    total_seconds = _to_seconds(segment.end - segment.start)

    if nightly is None:
        return 0, total_seconds

    night_seconds = 0
    for window_start, window_end in _night_windows_for_day(segment, nightly):
        overlap_start = max(segment.start, window_start)
        overlap_end = min(segment.end, window_end)
        if overlap_end > overlap_start:
            night_seconds += _to_seconds(overlap_end - overlap_start)

    return night_seconds, total_seconds - night_seconds


def _night_windows_for_day(
    segment: _DaySegment, nightly: Tariff
) -> list[tuple[datetime, datetime]]:
    """Absolute datetime ranges of the night window inside this calendar day.

    A window that crosses midnight (e.g. "22:00"-"06:00") shows up as two
    disjoint ranges within a single calendar day: the tail of the previous
    night (00:00 -> end_time) and the head of the next night
    (start_time -> 24:00). A window that does not cross midnight is a single
    range. (`start_time == end_time` is rejected by `tariffs` validation, so
    it is not handled here.)
    """
    tzinfo = segment.start.tzinfo
    day_start = datetime.combine(segment.day, time.min, tzinfo=tzinfo)
    day_end = day_start + timedelta(days=1)

    start_dt = day_start + _time_offset(nightly.start_time)
    end_dt = day_start + _time_offset(nightly.end_time)

    if start_dt < end_dt:
        return [(start_dt, end_dt)]
    return [(day_start, end_dt), (start_dt, day_end)]


def _time_offset(hhmm: str) -> timedelta:
    hours, minutes = (int(part) for part in hhmm.split(":"))
    return timedelta(hours=hours, minutes=minutes)


def _to_seconds(delta: timedelta) -> int:
    return round(delta.total_seconds())


def _ceil_hours(seconds: int) -> int:
    if seconds <= 0:
        return 0
    return (seconds + _SECONDS_PER_HOUR - 1) // _SECONDS_PER_HOUR


def _clamped_amount(amount: int) -> Decimal:
    # Defense in depth: `tariffs` validation already rejects amount <= 0 at
    # creation time; clamp again here so a raw/malformed Tariff can never
    # push a charge negative.
    return Decimal(max(amount, 0))
