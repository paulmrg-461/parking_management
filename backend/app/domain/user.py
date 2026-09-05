"""User domain entity, role, and PIN validation."""

from dataclasses import dataclass
from enum import Enum
import re


class UserRole(str, Enum):
    ADMIN = "admin"
    OPERATOR = "operator"


@dataclass
class User:
    id: int | None
    username: str
    display_name: str
    role: UserRole
    pin_hash: str
    is_active: bool = True


_PIN_PATTERN = re.compile(r"^\d{4,6}$")


def validate_pin(pin: str) -> str:
    if not _PIN_PATTERN.match(pin):
        raise ValueError("PIN must be 4 to 6 digits")
    return pin
