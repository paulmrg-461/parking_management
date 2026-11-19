"""Greedy IoU tracker and the read schedule for each vehicle.

The schedule is deliberately simple and deterministic: a track posts at most
one read every ``read_interval_ms`` and at most ``max_reads_per_track`` reads
in total, all with the same ``track_id``. The best crop (highest
``min(ocr, detector) * area``) is kept as the snapshot candidate.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class Box:
    x1: float
    y1: float
    x2: float
    y2: float
    score: float = 0.0

    @property
    def area(self) -> float:
        return max(0.0, self.x2 - self.x1) * max(0.0, self.y2 - self.y1)

    def iou(self, other: "Box") -> float:
        left = max(self.x1, other.x1)
        top = max(self.y1, other.y1)
        right = min(self.x2, other.x2)
        bottom = min(self.y2, other.y2)
        if right <= left or bottom <= top:
            return 0.0
        intersection = (right - left) * (bottom - top)
        union = self.area + other.area - intersection
        return intersection / union if union > 0 else 0.0


@dataclass
class Track:
    id: str
    box: Box
    last_frame: int
    reads: int = 0
    last_read_ms: float | None = None
    snapshot: bytes | None = None
    snapshot_score: float = 0.0


@dataclass(frozen=True)
class TrackerConfig:
    iou_threshold: float = 0.3
    max_age_frames: int = 15
    read_interval_ms: int = 400
    max_reads_per_track: int = 5


class Tracker:
    def __init__(self, config: TrackerConfig | None = None) -> None:
        self.config = config or TrackerConfig()
        self._tracks: dict[str, Track] = {}
        self._counter = 0
        self._last_boxes: list[Box] = []

    @property
    def tracks(self) -> list[Track]:
        return list(self._tracks.values())

    def update(self, boxes: list[Box], frame: int) -> list[Track]:
        """Match boxes to live tracks (greedy by IoU) and expire old ones."""
        unmatched = list(self._tracks.values())
        updated: list[Track] = []
        for box in boxes:
            best = None
            best_iou = 0.0
            for track in unmatched:
                overlap = track.box.iou(box)
                if overlap >= self.config.iou_threshold and overlap > best_iou:
                    best = track
                    best_iou = overlap
            if best is None:
                self._counter += 1
                best = Track(id=f"t-{self._counter}", box=box, last_frame=frame)
                self._tracks[best.id] = best
            else:
                unmatched.remove(best)
                best.box = box
                best.last_frame = frame
            updated.append(best)
        for track in list(self._tracks.values()):
            if frame - track.last_frame > self.config.max_age_frames:
                self._tracks.pop(track.id, None)
        self._last_boxes = boxes
        return updated

    def should_read(self, track: Track, now_ms: float) -> bool:
        if track.reads >= self.config.max_reads_per_track:
            return False
        if track.last_read_ms is None:
            return True
        return now_ms - track.last_read_ms >= self.config.read_interval_ms

    def mark_read(self, track: Track, now_ms: float) -> None:
        track.reads += 1
        track.last_read_ms = now_ms

    def offer_snapshot(self, track: Track, jpeg: bytes, score: float) -> bool:
        """Keep the best crop; returns True when it replaced the previous one."""
        if track.snapshot is not None and score <= track.snapshot_score:
            return False
        track.snapshot = jpeg
        track.snapshot_score = score
        return True
