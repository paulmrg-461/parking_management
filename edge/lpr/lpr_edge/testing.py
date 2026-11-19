"""A stdlib fake of the device gateway for integration tests and demos.

Routes: ``/v1/time``, ``/v1/heartbeat``, ``/v1/lpr/config``,
``/v1/lpr/reads`` and ``/v1/lpr/events/<id>/snapshot``, plus a ``/control``
endpoint to inject a fault (a status code) or read the recorded calls. Runs on
localhost only; no external network.
"""

from __future__ import annotations

import json
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class FakeGateway:
    def __init__(self, port: int = 0) -> None:
        self.reads: list[dict] = []
        self.snapshots: list[tuple[int, bytes]] = []
        self.heartbeats: list[dict] = []
        self.fault: int | None = None
        self._events: dict[str, int] = {}
        self._next_event = 100
        self._lock = threading.Lock()
        self.server = ThreadingHTTPServer(("127.0.0.1", port), self._handler())
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    @property
    def url(self) -> str:
        host, port = self.server.server_address[:2]
        return f"http://{host}:{port}"

    def __enter__(self) -> "FakeGateway":
        self.thread.start()
        return self

    def __exit__(self, *_) -> None:
        self.stop()

    def stop(self) -> None:
        self.server.shutdown()
        self.server.server_close()

    def _handler(self):
        gateway = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args) -> None:
                return

            def _json(self, status: int, body: dict) -> None:
                payload = json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

            def _body(self) -> dict:
                length = int(self.headers.get("Content-Length", "0"))
                raw = self.rfile.read(length) if length else b""
                return json.loads(raw) if raw else {}

            def do_GET(self) -> None:
                if gateway.fault is not None and self.path != "/control":
                    return self._json(gateway.fault, {"error": "ServiceUnavailable"})
                if self.path.endswith("/v1/time"):
                    return self._json(200, {
                        "server_time": datetime.now(timezone.utc).isoformat(),
                        "max_skew_s": 300,
                    })
                if self.path.endswith("/v1/lpr/config"):
                    return self._json(200, {
                        "direction": "entry",
                        "min_confidence": 0.8,
                        "vote_window_seconds": 8,
                        "heartbeat_interval_s": 60,
                    })
                return self._json(404, {"message": "NotFound"})

            def do_POST(self) -> None:
                body = self._body()
                if self.path == "/control":
                    gateway.fault = body.get("fault")
                    return self._json(200, {"fault": gateway.fault})
                if gateway.fault is not None:
                    return self._json(gateway.fault, {"error": "ServiceUnavailable"})
                if self.path.endswith("/v1/heartbeat"):
                    gateway.heartbeats.append(body)
                    return self._json(200, {"heartbeat_interval_s": 60})
                if self.path.endswith("/v1/lpr/reads"):
                    reference = str(body.get("client_ref", ""))
                    if self.headers.get("Idempotency-Key") != reference:
                        return self._json(400, {"message": "InvalidDataError"})
                    with gateway._lock:
                        known = reference in gateway._events
                        if not known:
                            gateway._next_event += 1
                            gateway._events[reference] = gateway._next_event
                            gateway.reads.append(body)
                        event_id = gateway._events[reference]
                    return self._json(200, {
                        "read_id": event_id,
                        "outcome": "replayed" if known else "decided",
                        "event": {"id": event_id, "status": "pending"},
                        "snapshot_wanted": not known,
                    })
                return self._json(404, {"message": "NotFound"})

            def do_PUT(self) -> None:
                length = int(self.headers.get("Content-Length", "0"))
                raw = self.rfile.read(length) if length else b""
                if gateway.fault is not None:
                    return self._json(gateway.fault, {"error": "ServiceUnavailable"})
                parts = self.path.split("/")
                try:
                    event_id = int(parts[parts.index("events") + 1])
                except (ValueError, IndexError):
                    return self._json(404, {"message": "NotFound"})
                if self.headers.get("Content-Type") != "image/jpeg":
                    return self._json(400, {"message": "InvalidDataError"})
                gateway.snapshots.append((event_id, raw))
                return self._json(200, {"event_id": event_id, "session_id": None})

        return Handler
