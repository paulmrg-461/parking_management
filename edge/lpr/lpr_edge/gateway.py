"""Device-gateway client: sequence, replay, clock skew and retries.

``seq = (boot_counter << 32) | n`` with the boot counter persisted atomically
at start-up. A replay response adopts the server's ``last_seq`` (one retry), a
clock-skew response syncs with ``/v1/time`` (one retry), the 400 family is
never retried and the same ``client_ref`` is the idempotency key on every
attempt. TLS is always verified.
"""

from __future__ import annotations

import json
import os
import random as random_module
import ssl
import tempfile
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

from .config import GatewayConfig


@dataclass(frozen=True)
class Response:
    status: int
    body: dict | None = None


class GatewayError(Exception):
    pass


class RetryableError(GatewayError):
    """Network error or 5xx: keep the row queued and back off."""


class NonRetryableError(GatewayError):
    """The server rejected the read: drop it (no point retrying)."""


Transport = Callable[[str, str, dict[str, str], bytes | None], Response]


class GatewayState:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.boot_counter = 0
        if self.path.is_file():
            data = json.loads(self.path.read_text(encoding="utf-8"))
            self.boot_counter = int(data.get("boot_counter", 0))
        self.boot_counter += 1
        self.save()

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        handle, temp = tempfile.mkstemp(dir=self.path.parent)
        try:
            with os.fdopen(handle, "w", encoding="utf-8") as stream:
                json.dump({"boot_counter": self.boot_counter}, stream)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temp, self.path)
        finally:
            if os.path.exists(temp):
                os.unlink(temp)


class GatewayClient:
    def __init__(
        self,
        config: GatewayConfig,
        state: GatewayState,
        transport: Transport,
        *,
        api_key: str | None = None,
        wall: Callable[[], float] = time.time,
        jitter: Callable[[], float] = random_module.random,
    ) -> None:
        self.config = config
        self.state = state
        self.transport = transport
        self.wall = wall
        self.jitter = jitter
        self._api_key = api_key
        self._counter = 0
        self._offset = 0.0

    @property
    def api_key(self) -> str:
        if self._api_key is None:
            self._api_key = Path(self.config.api_key_file).read_text(encoding="utf-8").strip()
        return self._api_key

    def next_seq(self) -> int:
        self._counter += 1
        return (self.state.boot_counter << 32) | self._counter

    def timestamp(self) -> int:
        return int(self.wall() + self._offset)

    def headers(self, client_ref: str) -> dict[str, str]:
        return {
            "X-Device-Key": self.api_key,
            "X-Device-Seq": str(self.next_seq()),
            "X-Device-Timestamp": str(self.timestamp()),
            "X-Device-Firmware": self.config.firmware_version,
            "Idempotency-Key": client_ref,
            "Content-Type": "application/json",
        }

    def post_read(self, payload: dict) -> Response:
        reference = str(payload.get("client_ref", ""))
        body = json.dumps(payload).encode("utf-8")
        for attempt in (0, 1):
            response = self.transport(
                "POST",
                f"{self.config.url}/v1/lpr/reads",
                self.headers(reference),
                body,
            )
            if 200 <= response.status < 300:
                return response
            error = _error(response)
            if attempt == 0 and error == "DeviceReplayError":
                self._adopt_last_seq(response.body or {})
                continue
            if attempt == 0 and error == "DeviceClockSkewError":
                self._sync_clock()
                continue
            if 400 <= response.status < 500:
                raise NonRetryableError(error or f"HTTP {response.status}")
            raise RetryableError(error or f"HTTP {response.status}")
        raise NonRetryableError("retry exhausted")

    def backoff(self, attempt: int) -> float:
        base = min(float(2**attempt), 30.0)
        return min(30.0, base * (0.8 + 0.4 * self.jitter()))

    def tls_context(self) -> ssl.SSLContext:
        context = ssl.create_default_context(cafile=self.config.ca_file)
        context.check_hostname = True
        context.verify_mode = ssl.CERT_REQUIRED
        return context

    def _adopt_last_seq(self, body: dict) -> None:
        last_seq = int(body.get("last_seq", 0))
        self.state.boot_counter = (last_seq >> 32) + 1
        self.state.save()
        self._counter = 0

    def _sync_clock(self) -> None:
        response = self.transport("GET", f"{self.config.url}/v1/time", {}, None)
        if response.status != 200 or not isinstance(response.body, dict):
            raise RetryableError("clock sync failed")
        server_time = response.body.get("server_time")
        if not isinstance(server_time, str):
            raise RetryableError("clock sync failed")
        moment = datetime.fromisoformat(server_time.replace("Z", "+00:00"))
        self._offset = moment.timestamp() - self.wall()


def _error(response: Response) -> str:
    body = response.body
    if isinstance(body, dict):
        for key in ("error", "message"):
            value = body.get(key)
            if isinstance(value, str):
                return value
    return ""
