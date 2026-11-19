"""Frame sources and the reconnecting wrapper.

The RTSP reader is ``cv2.VideoCapture`` (GStreamer pipeline on the Jetson) and
is imported lazily so the hardware-free tests never need OpenCV. The wrapper
detects a stalled stream (no frame for ``stall_seconds``), tears it down and
reconnects with exponential backoff; the backoff resets after 30 s of healthy
frames.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Callable, Protocol

import numpy as np
from numpy.typing import NDArray


@dataclass(frozen=True)
class Frame:
    image: NDArray[np.uint8] | None
    timestamp: float


class FrameSource(Protocol):
    def read(self) -> Frame | None: ...

    def close(self) -> None: ...


class OpenCvSource:
    """A file or RTSP stream through OpenCV (GStreamer on the Jetson)."""

    def __init__(self, target: str | int, *, gstreamer: bool = False) -> None:
        import cv2

        api = cv2.CAP_GSTREAMER if gstreamer else cv2.CAP_ANY
        if isinstance(target, str) and gstreamer:
            pipeline = (
                "rtspsrc location=%s latency=200 ! rtph264depay ! h264parse ! "
                "nvh264dec ! videoconvert ! appsink sync=false" % target
            )
            self._capture = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
        else:
            self._capture = cv2.VideoCapture(target, api)

    def read(self) -> Frame | None:
        ok, image = self._capture.read()
        if not ok or image is None:
            return None
        return Frame(image=image, timestamp=time.monotonic())

    def close(self) -> None:
        self._capture.release()


class FileSource(OpenCvSource):
    def __init__(self, path: str) -> None:
        super().__init__(path)


class RtspSource(OpenCvSource):
    def __init__(self, url: str, *, gstreamer: bool = True) -> None:
        super().__init__(url, gstreamer=gstreamer)


class ReconnectingSource:
    def __init__(
        self,
        factory: Callable[[], FrameSource],
        *,
        stall_seconds: float = 10.0,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._factory = factory
        self._stall_seconds = stall_seconds
        self._clock = clock
        self._source: FrameSource | None = None
        self._last_frame: float | None = None
        self._connected_at: float | None = None
        self._attempt = 0
        self._next_connect = 0.0
        self.reconnects = 0

    @property
    def connected(self) -> bool:
        return self._source is not None

    def read(self) -> Frame | None:
        now = self._clock()
        if self._source is not None and self._last_frame is not None:
            if now - self._last_frame > self._stall_seconds:
                self._teardown(now)
        if self._source is None:
            if now < self._next_connect:
                return None
            try:
                self._source = self._factory()
                self._connected_at = now
                self._last_frame = now
                self.reconnects += 1
            except Exception:
                self._schedule(now)
                return None
        frame = self._source.read()
        if frame is None or frame.image is None:
            return None
        self._last_frame = now
        if self._connected_at is not None and now - self._connected_at >= 30:
            self._attempt = 0
        return frame

    def close(self) -> None:
        if self._source is not None:
            self._source.close()
        self._source = None

    def _teardown(self, now: float) -> None:
        if self._source is not None:
            self._source.close()
        self._source = None
        self._schedule(now)

    def _schedule(self, now: float) -> None:
        delay = min(float(2 ** self._attempt), 30.0)
        self._attempt += 1
        self._next_connect = now + max(0.0, delay)
