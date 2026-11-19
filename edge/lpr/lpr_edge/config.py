"""Strict configuration for the edge service (``lpr.yaml``).

Unknown keys are an error so a typo never silently disables a safeguard. The
gateway URL must be HTTPS, the two secret files must be ``0600`` and owned by
the service user, and the engine hashes are verified before the service runs.
"""

from __future__ import annotations

import hashlib
import os
import re
import stat
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

SHA256 = re.compile(r"^[0-9a-f]{64}$")


class ConfigError(Exception):
    """Invalid or unsafe configuration."""


@dataclass(frozen=True)
class GatewayConfig:
    url: str
    api_key_file: str
    firmware_version: str
    ca_file: str | None = None


@dataclass(frozen=True)
class CaptureConfig:
    rtsp_url_file: str
    decoder: str = "nvidia"
    stall_seconds: int = 10


@dataclass(frozen=True)
class SamplingConfig:
    idle_fps: float = 2
    active_fps: float = 8
    active_hold_s: float = 3
    motion_threshold: float = 6.0
    roi: tuple[float, float, float, float] = (0.1, 0.2, 0.8, 0.7)


@dataclass(frozen=True)
class DetectorConfig:
    engine: str
    sha256: str
    input: int = 640
    score: float = 0.40


@dataclass(frozen=True)
class OcrConfig:
    engine: str
    sha256: str
    width: int = 128
    height: int = 64


@dataclass(frozen=True)
class ModelsConfig:
    detector: DetectorConfig
    ocr: OcrConfig


@dataclass(frozen=True)
class PlateConfig:
    patterns: tuple[str, ...]
    fold_confusables: bool = True
    accept_unmatched: bool = False


@dataclass(frozen=True)
class TrackingConfig:
    iou_threshold: float = 0.3
    max_age_frames: int = 15
    read_interval_ms: int = 400
    max_reads_per_track: int = 5


@dataclass(frozen=True)
class QueueConfig:
    path: str
    max_age_s: int = 900
    max_rows: int = 2000


@dataclass(frozen=True)
class StateConfig:
    path: str


@dataclass(frozen=True)
class Config:
    device: GatewayConfig
    capture: CaptureConfig
    sampling: SamplingConfig
    models: ModelsConfig
    plate: PlateConfig
    tracking: TrackingConfig
    queue: QueueConfig
    state: StateConfig
    heartbeat_interval_s: int = 60
    log_level: str = "info"


def load_config(path: str | Path, verify_models: bool = True) -> Config:
    raw = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ConfigError("lpr.yaml must be a mapping")
    _keys(
        raw,
        {
            "device", "capture", "sampling", "models", "plate", "tracking",
            "queue", "state", "heartbeat_interval_s", "log_level",
        },
        "root",
    )
    device = _section(raw, "device")
    _keys(
        device,
        {"gateway_url", "api_key_file", "firmware_version", "ca_file"},
        "device",
    )
    url = _text(device, "gateway_url", "device")
    if not url.startswith("https://"):
        raise ConfigError("device.gateway_url must be https")
    key_file = _text(device, "api_key_file", "device")
    _secret_file(key_file, "device.api_key_file")

    capture = _section(raw, "capture")
    _keys(capture, {"rtsp_url_file", "decoder", "stall_seconds"}, "capture")
    rtsp_file = _text(capture, "rtsp_url_file", "capture")
    _secret_file(rtsp_file, "capture.rtsp_url_file")
    decoder = str(capture.get("decoder", "nvidia"))
    if decoder not in ("nvidia", "software"):
        raise ConfigError("capture.decoder must be nvidia or software")

    sampling_raw = _section(raw, "sampling")
    _keys(
        sampling_raw,
        {"idle_fps", "active_fps", "active_hold_s", "motion_threshold", "roi"},
        "sampling",
    )
    roi = sampling_raw.get("roi", [0.1, 0.2, 0.8, 0.7])
    if not isinstance(roi, list) or len(roi) != 4:
        raise ConfigError("sampling.roi must have four fractions")
    roi_tuple = tuple(float(value) for value in roi)
    if any(value < 0 or value > 1 for value in roi_tuple):
        raise ConfigError("sampling.roi values are fractions in 0..1")
    if roi_tuple[0] + roi_tuple[2] > 1 or roi_tuple[1] + roi_tuple[3] > 1:
        raise ConfigError("sampling.roi exceeds the frame")

    models_raw = _section(raw, "models")
    _keys(models_raw, {"detector", "ocr"}, "models")
    detector_raw = _mapping(models_raw, "detector", "models")
    _keys(detector_raw, {"engine", "sha256", "input", "score"}, "models.detector")
    ocr_raw = _mapping(models_raw, "ocr", "models")
    _keys(ocr_raw, {"engine", "sha256", "width", "height"}, "models.ocr")
    detector = DetectorConfig(
        engine=_text(detector_raw, "engine", "models.detector"),
        sha256=_hash(detector_raw, "sha256", "models.detector"),
        input=int(detector_raw.get("input", 640)),
        score=float(detector_raw.get("score", 0.40)),
    )
    ocr = OcrConfig(
        engine=_text(ocr_raw, "engine", "models.ocr"),
        sha256=_hash(ocr_raw, "sha256", "models.ocr"),
        width=int(ocr_raw.get("width", 128)),
        height=int(ocr_raw.get("height", 64)),
    )
    if verify_models:
        _verify_engine(detector.engine, detector.sha256)
        _verify_engine(ocr.engine, ocr.sha256)

    plate_raw = _section(raw, "plate")
    _keys(plate_raw, {"patterns", "fold_confusables", "accept_unmatched"}, "plate")
    patterns = plate_raw.get("patterns")
    if not isinstance(patterns, list) or not patterns:
        raise ConfigError("plate.patterns must be a non-empty list")
    if any(not isinstance(item, str) for item in patterns):
        raise ConfigError("plate.patterns must be strings")

    tracking_raw = _section(raw, "tracking")
    _keys(
        tracking_raw,
        {"iou_threshold", "max_age_frames", "read_interval_ms", "max_reads_per_track"},
        "tracking",
    )
    queue_raw = _section(raw, "queue")
    _keys(queue_raw, {"path", "max_age_s", "max_rows"}, "queue")
    state_raw = _section(raw, "state")
    _keys(state_raw, {"path"}, "state")

    log_level = str(raw.get("log_level", "info"))
    if log_level not in ("debug", "info", "warning", "error"):
        raise ConfigError("log_level must be debug, info, warning or error")

    return Config(
        device=GatewayConfig(
            url=url,
            api_key_file=key_file,
            firmware_version=_text(device, "firmware_version", "device"),
            ca_file=device.get("ca_file"),
        ),
        capture=CaptureConfig(
            rtsp_url_file=rtsp_file,
            decoder=decoder,
            stall_seconds=int(capture.get("stall_seconds", 10)),
        ),
        sampling=SamplingConfig(
            idle_fps=float(sampling_raw.get("idle_fps", 2)),
            active_fps=float(sampling_raw.get("active_fps", 8)),
            active_hold_s=float(sampling_raw.get("active_hold_s", 3)),
            motion_threshold=float(sampling_raw.get("motion_threshold", 6.0)),
            roi=roi_tuple,  # type: ignore[arg-type]
        ),
        models=ModelsConfig(detector=detector, ocr=ocr),
        plate=PlateConfig(
            patterns=tuple(patterns),
            fold_confusables=bool(plate_raw.get("fold_confusables", True)),
            accept_unmatched=bool(plate_raw.get("accept_unmatched", False)),
        ),
        tracking=TrackingConfig(
            iou_threshold=float(tracking_raw.get("iou_threshold", 0.3)),
            max_age_frames=int(tracking_raw.get("max_age_frames", 15)),
            read_interval_ms=int(tracking_raw.get("read_interval_ms", 400)),
            max_reads_per_track=int(tracking_raw.get("max_reads_per_track", 5)),
        ),
        queue=QueueConfig(
            path=_text(queue_raw, "path", "queue"),
            max_age_s=int(queue_raw.get("max_age_s", 900)),
            max_rows=int(queue_raw.get("max_rows", 2000)),
        ),
        state=StateConfig(path=_text(state_raw, "path", "state")),
        heartbeat_interval_s=int(raw.get("heartbeat_interval_s", 60)),
        log_level=log_level,
    )


def _keys(section: dict[str, Any], allowed: set[str], where: str) -> None:
    unknown = set(section) - allowed
    if unknown:
        raise ConfigError(f"unknown key(s) in {where}: {', '.join(sorted(unknown))}")


def _section(raw: dict[str, Any], name: str) -> dict[str, Any]:
    value = raw.get(name)
    if not isinstance(value, dict):
        raise ConfigError(f"{name} must be a mapping")
    return value


def _mapping(raw: dict[str, Any], name: str, where: str) -> dict[str, Any]:
    value = raw.get(name)
    if not isinstance(value, dict):
        raise ConfigError(f"{where}.{name} must be a mapping")
    return value


def _text(raw: dict[str, Any], name: str, where: str) -> str:
    value = raw.get(name)
    if not isinstance(value, str) or value.strip() == "":
        raise ConfigError(f"{where}.{name} is required")
    return value.strip()


def _hash(raw: dict[str, Any], name: str, where: str) -> str:
    value = _text(raw, name, where)
    if not SHA256.match(value):
        raise ConfigError(f"{where}.{name} must be a 64-character hex SHA-256")
    return value


def _secret_file(path: str, where: str) -> None:
    target = Path(path)
    if not target.is_file():
        raise ConfigError(f"{where} does not exist: {path}")
    info = os.stat(target)
    if stat.S_IMODE(info.st_mode) & 0o077:
        raise ConfigError(f"{where} must be mode 0600 (got {oct(info.st_mode & 0o777)})")
    if info.st_uid != os.geteuid():
        raise ConfigError(f"{where} must be owned by the service user")


def _verify_engine(path: str, expected: str) -> None:
    target = Path(path)
    if not target.is_file():
        raise ConfigError(f"engine not found: {path}")
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    if digest != expected:
        raise ConfigError(f"engine hash mismatch: {path}")
