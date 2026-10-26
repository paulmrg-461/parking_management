"""Local filesystem implementation of the logo storage port.

The root directory is created once at application startup
(`ensure_storage_root`), not per request.
"""

import os
import uuid

import anyio

from app.domain.logo_storage import LogoStoragePort


class LocalLogoStorage(LogoStoragePort):
    def __init__(self, root_path: str):
        self._root_path = root_path

    async def save(self, content: bytes, extension: str) -> str:
        # Name is server-generated; extension comes from sniffed content.
        stored_name = f"{uuid.uuid4().hex}{extension}"
        async with await anyio.open_file(self._absolute(stored_name), "wb") as file:
            await file.write(content)
        return stored_name

    async def read(self, path: str) -> bytes | None:
        target = anyio.Path(self._absolute(os.path.basename(path)))
        if not await target.exists():
            return None
        return await target.read_bytes()

    async def delete(self, path: str) -> None:
        target = anyio.Path(self._absolute(os.path.basename(path)))
        await target.unlink(missing_ok=True)

    def _absolute(self, stored_name: str) -> str:
        return os.path.join(self._root_path, stored_name)
