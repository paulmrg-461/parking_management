"""Frame sampling: idle/active cadence, motion gate, ROI and stale frames.

Everything here is pure and testable with numpy arrays; the RTSP source lives
in ``capture.py`` and only calls these helpers.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass(frozen=True)
class SamplingConfig:
    idle_fps: float = 2
    active_fps: float = 8
    active_hold_s: float = 3
    motion_threshold: float = 6.0
    roi: tuple[float, float, float, float] = (0.1, 0.2, 0.8, 0.7)
    max_frame_age_s: float = 1.0


class Sampler:
    def __init__(self, config: SamplingConfig | None = None) -> None:
        self.config = config or SamplingConfig()
        self._active_until = 0.0
        self._last_sample = float("-inf")

    def motion_score(self, previous: np.ndarray | None, current: np.ndarray) -> float:
        """Mean absolute difference of two grayscale frames (0..255)."""
        if previous is None or previous.shape != current.shape:
            return 0.0
        return float(np.mean(np.abs(current.astype(np.int16) - previous.astype(np.int16))))

    def observe(self, motion: float, now: float) -> bool:
        """Update the active window; returns True when motion crossed the gate."""
        active = motion >= self.config.motion_threshold
        if active:
            self._active_until = now + self.config.active_hold_s
        return active

    @property
    def active(self) -> bool:
        return self._active_until > 0

    def is_active(self, now: float) -> bool:
        return now < self._active_until

    def should_sample(self, now: float) -> bool:
        fps = self.config.active_fps if self.is_active(now) else self.config.idle_fps
        if fps <= 0:
            return False
        interval = 1.0 / fps
        if now - self._last_sample >= interval:
            self._last_sample = now
            return True
        return False

    def is_stale(self, frame_timestamp: float, now: float) -> bool:
        return now - frame_timestamp > self.config.max_frame_age_s

    def crop(self, frame: np.ndarray) -> np.ndarray:
        """Crop the configured ROI (fractions of width/height)."""
        height, width = frame.shape[:2]
        x, y, w, h = self.config.roi
        left = int(x * width)
        top = int(y * height)
        right = max(left + 1, int((x + w) * width))
        bottom = max(top + 1, int((y + h) * height))
        return frame[top:bottom, left:right]
