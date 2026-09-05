"""Tariff domain entity, type, and validation."""

from dataclasses import dataclass
from enum import Enum
import re


class TariffType(str, Enum):
    HOURLY = "hourly"
    DAILY = "daily"
    NIGHTLY = "nightly"
    MONTHLY = "monthly"


_TIME_PATTERN = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")


@dataclass
class Tariff:
    id: int | None
    category_id: int
    type: TariffType
    amount: int
    start_time: str | None
    end_time: str | None
    active: bool = True


def validate_amount(amount: int) -> int:
    if amount <= 0:
        raise ValueError("Amount must be a positive integer")
    return amount


def validate_time(value: str | None) -> str | None:
    if value is None:
        return None
    if not _TIME_PATTERN.match(value):
        raise ValueError("Time must be HH:MM in 24-hour format")
    return value


def validate_window(
    tariff_type: TariffType, start: str | None, end: str | None
) -> None:
    if tariff_type == TariffType.NIGHTLY:
        if start is None or end is None:
            raise ValueError("Nightly tariff requires a time window")
        if start == end:
            raise ValueError("Night window start and end must differ")
    elif start is not None or end is not None:
        raise ValueError("Only nightly tariffs carry a time window")
