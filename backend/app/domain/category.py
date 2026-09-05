"""Vehicle category domain entity and validation."""

from dataclasses import dataclass


@dataclass
class Category:
    id: int | None
    name: str


def validate_name(name: str) -> str:
    value = name.strip()
    if not value:
        raise ValueError("Category name must not be empty")
    return value
