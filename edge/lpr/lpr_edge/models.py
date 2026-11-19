"""Detector and OCR ports plus deterministic fakes.

The owner's weights define the real adapters (ONNX on CPU, TensorRT on the
Jetson); this module fixes the interface and ships fakes so the loop and the
tests run with no model, no GPU and no camera.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

import numpy as np
from numpy.typing import NDArray

from .tracker import Box


class PlateDetector(Protocol):
    def detect(self, frame: NDArray[np.uint8]) -> list[Box]: ...


class PlateOcr(Protocol):
    def read(self, crop: NDArray[np.uint8]) -> tuple[str, float]: ...


@dataclass(frozen=True)
class ExpectedFrame:
    boxes: list[Box]
    text: str
    confidence: float


def load_expectations(path: str | Path) -> list[ExpectedFrame]:
    """Read a ``expected/*.json`` fixture: boxes + the OCR answer per frame."""
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    frames = []
    for item in raw.get("frames", []):
        boxes = [
            Box(
                x1=float(box["x1"]),
                y1=float(box["y1"]),
                x2=float(box["x2"]),
                y2=float(box["y2"]),
                score=float(box.get("score", 0.9)),
            )
            for box in item.get("boxes", [])
        ]
        frames.append(
            ExpectedFrame(
                boxes=boxes,
                text=str(item.get("text", "")),
                confidence=float(item.get("confidence", 0.95)),
            )
        )
    return frames


class FakeDetector:
    """Replays the boxes of the fixture, one entry per call."""

    def __init__(self, frames: list[ExpectedFrame]) -> None:
        self._frames = list(frames)
        self._index = 0

    def detect(self, frame: NDArray[np.uint8]) -> list[Box]:
        if self._index >= len(self._frames):
            return []
        boxes = self._frames[self._index].boxes
        self._index += 1
        return list(boxes)


class FakeOcr:
    """Returns the fixture text/confidence in order (or empty when exhausted)."""

    def __init__(self, frames: list[ExpectedFrame]) -> None:
        self._frames = list(frames)
        self._index = 0

    def read(self, crop: NDArray[np.uint8]) -> tuple[str, float]:
        if self._index >= len(self._frames):
            return "", 0.0
        frame = self._frames[self._index]
        self._index += 1
        return frame.text, frame.confidence
