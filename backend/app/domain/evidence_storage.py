"""Evidence photo storage port."""

from abc import ABC, abstractmethod


class EvidenceStoragePort(ABC):
    @abstractmethod
    async def save(self, filename: str, content: bytes) -> str:
        """Persist the photo bytes and return the stored file path."""
        raise NotImplementedError
