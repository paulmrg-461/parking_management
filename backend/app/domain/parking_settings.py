"""Parking lot identity settings (singleton record) and its partial update."""

from dataclasses import dataclass, replace
from datetime import datetime

DEFAULT_NAME = "Parqueadero"


@dataclass(frozen=True)
class ParkingSettings:
    id: int | None
    name: str
    address: str
    schedule: str
    phone: str
    website: str
    whatsapp: str
    logo_version: int
    logo_path: str | None
    updated_at: datetime | None = None

    @classmethod
    def defaults(cls) -> "ParkingSettings":
        """Unconfigured record: what the app renders before any admin edit."""
        return cls(
            id=None,
            name=DEFAULT_NAME,
            address="",
            schedule="",
            phone="",
            website="",
            whatsapp="",
            logo_version=0,
            logo_path=None,
        )


@dataclass(frozen=True)
class LogoAsset:
    """Serving payload: current logo bytes plus its cache version."""

    version: int
    content: bytes
    extension: str

    @property
    def media_type(self) -> str:
        return "image/jpeg" if self.extension in (".jpg", ".jpeg") else "image/png"


@dataclass(frozen=True)
class ParkingSettingsPatch:
    """Fields explicitly sent by the client; None means "leave unchanged"."""

    name: str | None = None
    address: str | None = None
    schedule: str | None = None
    phone: str | None = None
    website: str | None = None
    whatsapp: str | None = None

    def apply(self, current: ParkingSettings) -> ParkingSettings:
        return replace(
            current,
            name=self.name if self.name is not None else current.name,
            address=self.address if self.address is not None else current.address,
            schedule=self.schedule if self.schedule is not None else current.schedule,
            phone=self.phone if self.phone is not None else current.phone,
            website=self.website if self.website is not None else current.website,
            whatsapp=self.whatsapp if self.whatsapp is not None else current.whatsapp,
        )
