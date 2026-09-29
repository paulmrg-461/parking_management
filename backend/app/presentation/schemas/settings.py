"""Parking settings DTOs (public read + validated partial update)."""

import re
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.domain.parking_settings import ParkingSettingsPatch

# Bare domains (parqueadero.co, sub.example.co) or full URLs; spaces rejected.
_WEBSITE_PATTERN = re.compile(
    r"^(https?://)?[\w-]+(\.[\w-]+)+(:\d+)?(/.*)?$", re.IGNORECASE
)
_PHONE_PATTERN = re.compile(r"^[+()\d][\d\s()-]{6,31}$")
_WHATSAPP_PATTERN = re.compile(r"^\+?[\d\s()-]{7,31}$")


class ParkingSettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str
    address: str
    schedule: str
    phone: str
    website: str
    whatsapp: str
    logo_version: int
    updated_at: datetime | None = None


class ParkingSettingsUpdate(BaseModel):
    """Partial update: omitted/None fields keep their current value."""

    name: str | None = Field(default=None, max_length=80)
    address: str | None = Field(default=None, max_length=160)
    schedule: str | None = Field(default=None, max_length=120)
    phone: str | None = Field(default=None, max_length=32)
    website: str | None = Field(default=None, max_length=200)
    whatsapp: str | None = Field(default=None, max_length=32)

    @field_validator("name")
    @classmethod
    def _name_must_not_be_blank(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        if not stripped:
            raise ValueError("name must not be empty")
        return stripped

    @field_validator("phone")
    @classmethod
    def _phone_format(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return value
        stripped = value.strip()
        if not _PHONE_PATTERN.fullmatch(stripped):
            raise ValueError("phone must contain only digits, spaces and +()-")
        return stripped

    @field_validator("whatsapp")
    @classmethod
    def _whatsapp_format(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return value
        stripped = value.strip()
        digits = re.sub(r"\D", "", stripped)
        if not _WHATSAPP_PATTERN.fullmatch(stripped) or len(digits) < 8:
            raise ValueError("whatsapp must be a phone number with at least 8 digits")
        return stripped

    @field_validator("website")
    @classmethod
    def _website_format(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return value
        stripped = value.strip()
        if not _WEBSITE_PATTERN.fullmatch(stripped):
            raise ValueError("website must be a valid URL")
        return stripped

    def to_patch(self) -> ParkingSettingsPatch:
        return ParkingSettingsPatch(
            name=self.name,
            address=self.address,
            schedule=self.schedule,
            phone=self.phone,
            website=self.website,
            whatsapp=self.whatsapp,
        )
