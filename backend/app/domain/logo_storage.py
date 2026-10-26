"""Parking logo storage port."""

from abc import ABC, abstractmethod


class LogoStoragePort(ABC):
    @abstractmethod
    async def save(self, content: bytes, extension: str) -> str:
        """Persist already-validated logo bytes; return the stored path."""
        raise NotImplementedError

    @abstractmethod
    async def read(self, path: str) -> bytes | None:
        """Stored bytes, or None when the file is gone."""
        raise NotImplementedError

    @abstractmethod
    async def delete(self, path: str) -> None:
        """Remove a replaced logo; missing files are ignored."""
        raise NotImplementedError
