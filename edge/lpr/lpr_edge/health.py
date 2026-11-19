"""Heartbeat payload and the inference watchdog.

The payload matches the gateway contract (``status`` object, ≤ 2 KB):
``uptime_s``, ``camera`` up/down, ``queue_depth``, ``dropped``, ``fps`` and
``detector_ms_p95``. The watchdog only fires while inference is expected to
advance, so a camera that is simply idle never restarts the service.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable


def heartbeat_payload(
    *,
    uptime_s: int,
    camera_up: bool,
    queue_depth: int,
    dropped: int,
    fps: float,
    detector_ms_p95: float,
    now: datetime | None = None,
) -> dict:
    moment = now or datetime.now(timezone.utc)
    return {
        "uptime_s": max(0, int(uptime_s)),
        "camera": "up" if camera_up else "down",
        "queue_depth": max(0, int(queue_depth)),
        "dropped": max(0, int(dropped)),
        "fps": round(float(fps), 2),
        "detector_ms_p95": round(float(detector_ms_p95), 2),
        "captured_at": moment.astimezone(timezone.utc).isoformat(),
    }


@dataclass
class Watchdog:
    limit_s: float = 60.0
    clock: Callable[[], float] = time.monotonic
    _last_progress: float | None = None

    def arm(self) -> None:
        self._last_progress = self.clock()

    def kick(self) -> None:
        self._last_progress = self.clock()

    def expired(self) -> bool:
        if self._last_progress is None:
            return False
        return self.clock() - self._last_progress > self.limit_s
