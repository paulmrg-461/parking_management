"""Local filesystem implementation of the evidence storage port."""

import os
import uuid

import anyio

from app.domain.evidence_storage import EvidenceStoragePort


class LocalEvidenceStorage(EvidenceStoragePort):
    def __init__(self, root_path: str):
        self._root_path = root_path
        os.makedirs(self._root_path, exist_ok=True)

    async def save(self, filename: str, content: bytes) -> str:
        extension = os.path.splitext(filename)[1]
        stored_name = f"{uuid.uuid4().hex}{extension}"
        relative_path = stored_name
        absolute_path = os.path.join(self._root_path, stored_name)
        async with await anyio.open_file(absolute_path, "wb") as file:
            await file.write(content)
        return relative_path
