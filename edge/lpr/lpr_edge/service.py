"""The edge loop: frames -> tracks -> reads -> outbox -> gateway.

The loop is deliberately small and synchronous so it can be tested without a
camera or a model: the caller supplies the source, the detector, the OCR, the
sampler, the tracker and the gateway transport. ``__main__`` wires the real
adapters.
"""

from __future__ import annotations

import json
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Callable

import numpy as np

from .capture import Frame
from .gateway import GatewayClient, NonRetryableError, RetryableError
from .health import heartbeat_payload
from .models import PlateDetector, PlateOcr
from .outbox import Outbox
from .postprocess import PlateRules, normalize
from .sampler import Sampler
from .tracker import Box, Tracker


@dataclass
class Counters:
    dropped: int = 0
    stale: int = 0
    sent: int = 0
    failed: int = 0
    samples: int = 0


@dataclass
class Service:
    sampler: Sampler
    tracker: Tracker
    detector: PlateDetector
    ocr: PlateOcr
    rules: PlateRules
    outbox: Outbox
    gateway: GatewayClient
    encoder: Callable[[np.ndarray], bytes] | None = None
    counters: Counters = field(default_factory=Counters)
    wall: Callable[[], float] = time.time
    _previous_gray: np.ndarray | None = field(default=None, init=False)
    _frame_index: int = field(default=0, init=False)
    _started: float = field(default_factory=time.monotonic, init=False)

    def process(self, frame: Frame, now: float) -> str | None:
        """Handle one frame. Returns the plate when a read was enqueued."""
        if frame.image is None:
            return None
        if self.sampler.is_stale(frame.timestamp, now):
            self.counters.stale += 1
            return None
        gray = _gray(frame.image)
        motion = self.sampler.motion_score(self._previous_gray, gray)
        self._previous_gray = gray
        self.sampler.observe(motion, now)
        if not self.sampler.should_sample(now):
            return None
        self.counters.samples += 1
        self._frame_index += 1
        crop = self.sampler.crop(frame.image)
        boxes = self.detector.detect(crop)
        tracks = self.tracker.update(boxes, self._frame_index)
        plate = None
        for track in tracks:
            if not self.tracker.should_read(track, now * 1000):
                continue
            raw, ocr_confidence = self.ocr.read(_crop(frame.image, track.box))
            candidate = normalize(raw, self.rules)
            confidence = min(ocr_confidence, track.box.score)
            self.tracker.mark_read(track, now * 1000)
            if candidate is None or confidence <= 0:
                continue
            plate = candidate
            if self.encoder is not None:
                score = confidence * max(track.box.area, 1.0)
                jpeg = self.encoder(_crop(frame.image, track.box))
                self.tracker.offer_snapshot(track, jpeg, score)
            self._enqueue(track.id, candidate, confidence, now)
        return plate

    def drain(self, now: float) -> int:
        """Send due rows oldest first; returns how many left the queue."""
        sent = 0
        for _ in range(20):
            row = self.outbox.next_due(now)
            if row is None:
                break
            payload = json.loads(row.payload)
            try:
                response = self.gateway.post_read(payload)
            except NonRetryableError:
                self.outbox.delete(row.id)
                self.counters.failed += 1
                continue
            except RetryableError:
                self.outbox.mark_attempt(
                    row.id,
                    next_try_at=now + self.gateway.backoff(row.attempts),
                )
                self.counters.failed += 1
                break
            self._maybe_snapshot(response, row.snapshot)
            self.outbox.delete(row.id)
            self.counters.sent += 1
            sent += 1
        return sent

    def heartbeat(self, *, now: float, camera_up: bool, fps: float) -> dict:
        return heartbeat_payload(
            uptime_s=int(now - self._started),
            camera_up=camera_up,
            queue_depth=self.outbox.depth(),
            dropped=self.counters.dropped,
            fps=fps,
            detector_ms_p95=0.0,
            now=datetime.fromtimestamp(self.wall(), tz=timezone.utc),
        )

    def prune(self, max_age_s: int, max_rows: int, now: float) -> int:
        dropped = self.outbox.prune(
            max_age_s=max_age_s,
            max_rows=max_rows,
            now=now,
        )
        self.counters.dropped += dropped
        return dropped

    def _enqueue(self, track_id: str, plate: str, confidence: float, now: float) -> None:
        payload = {
            "client_ref": str(uuid.uuid4()),
            "plate": plate,
            "confidence": round(float(confidence), 3),
            "captured_at": datetime.fromtimestamp(
                self.wall(), tz=timezone.utc
            ).isoformat(),
            "track_id": track_id,
        }
        current = self.tracker.tracks
        snapshot = None
        for track in current:
            if track.id == track_id and track.snapshot is not None:
                snapshot = track.snapshot
                break
        self.outbox.enqueue(
            "read",
            json.dumps(payload),
            snapshot=snapshot,
            client_ref=payload["client_ref"],
            now=now,
        )

    def _maybe_snapshot(self, response, snapshot: bytes | None) -> None:
        body = response.body if isinstance(response.body, dict) else {}
        if not snapshot or not body.get("snapshot_wanted"):
            return
        event = body.get("event") or {}
        event_id = event.get("id")
        if not isinstance(event_id, int):
            return
        try:
            self.gateway.put_snapshot(event_id, snapshot)
        except (RetryableError, NonRetryableError):
            # The event keeps its place without the image; the server expires it.
            pass


def _gray(image: np.ndarray) -> np.ndarray:
    if image.ndim == 2:
        return image
    return image[:, :, :3].mean(axis=2).astype(np.uint8)


def _crop(image: np.ndarray, box: Box) -> np.ndarray:
    height, width = image.shape[:2]
    x1 = max(0, min(width - 1, int(box.x1)))
    y1 = max(0, min(height - 1, int(box.y1)))
    x2 = max(x1 + 1, min(width, int(box.x2)))
    y2 = max(y1 + 1, min(height, int(box.y2)))
    return image[y1:y2, x1:x2]
