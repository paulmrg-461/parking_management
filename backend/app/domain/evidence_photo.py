"""Evidence photo domain entity."""

from dataclasses import dataclass
from datetime import datetime


@dataclass
class EvidencePhoto:
    id: int | None
    session_id: int
    file_path: str
    taken_at: datetime
