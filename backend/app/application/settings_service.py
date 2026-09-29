"""Parking settings use cases."""

import os
from dataclasses import replace

from app.domain.evidence_photo import PhotoUpload
from app.domain.logo_storage import LogoStoragePort
from app.domain.parking_settings import LogoAsset, ParkingSettings, ParkingSettingsPatch
from app.domain.repositories import ParkingSettingsRepository


class SettingsService:
    def __init__(self, settings: ParkingSettingsRepository, logos: LogoStoragePort):
        self._settings = settings
        self._logos = logos

    async def get(self) -> ParkingSettings:
        """Current record; defaults until the first admin save."""
        return await self._settings.get() or ParkingSettings.defaults()

    async def update(self, patch: ParkingSettingsPatch) -> ParkingSettings:
        merged = patch.apply(await self.get())
        return await self._settings.save(merged)

    async def upload_logo(self, upload: PhotoUpload) -> ParkingSettings:
        """Store the new logo, bump its version, then drop the old file."""
        current = await self.get()
        path = await self._logos.save(upload.content, upload.extension)
        saved = await self._settings.save(
            replace(current, logo_path=path, logo_version=current.logo_version + 1)
        )
        if current.logo_path:
            await self._logos.delete(current.logo_path)
        return saved

    async def logo_asset(self) -> LogoAsset | None:
        """Bytes to serve; None before the first upload (or if the file is gone)."""
        current = await self.get()
        if not current.logo_path:
            return None
        content = await self._logos.read(current.logo_path)
        if content is None:
            return None
        return LogoAsset(
            version=current.logo_version,
            content=content,
            extension=os.path.splitext(current.logo_path)[1] or ".png",
        )
