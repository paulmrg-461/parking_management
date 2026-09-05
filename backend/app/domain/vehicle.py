"""Vehicle domain entity and plate normalization."""

from dataclasses import dataclass


@dataclass
class Vehicle:
    id: int | None
    plate: str
    category_id: int
    color: str | None = None
    brand: str | None = None


def normalize_plate(plate: str) -> str:
    value = "".join(plate.split()).upper()
    if not value:
        raise ValueError("Plate must not be empty")
    return value
