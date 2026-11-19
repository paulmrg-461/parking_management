import hashlib
from pathlib import Path

import pytest

from lpr_edge.config import ConfigError, load_config

BASE = """
device:
  gateway_url: https://parking.example.com/functions/v1/device-gateway
  api_key_file: {key}
  firmware_version: lpr-1.0.0
  ca_file: null
capture:
  rtsp_url_file: {rtsp}
  decoder: nvidia
  stall_seconds: 10
sampling:
  idle_fps: 2
  active_fps: 8
  active_hold_s: 3
  motion_threshold: 6.0
  roi: [0.1, 0.2, 0.8, 0.7]
models:
  detector: {{engine: {detector}, sha256: "{sha}", input: 640, score: 0.40}}
  ocr: {{engine: {ocr}, sha256: "{sha_ocr}", width: 128, height: 64}}
plate:
  patterns: ['^[A-Z]{{3}}[0-9]{{3}}$', '^[A-Z]{{3}}[0-9]{{2}}[A-Z]$']
  fold_confusables: true
  accept_unmatched: false
tracking: {{iou_threshold: 0.3, max_age_frames: 15, read_interval_ms: 400, max_reads_per_track: 5}}
queue: {{path: {queue}, max_age_s: 900, max_rows: 2000}}
state: {{path: {state}}}
heartbeat_interval_s: 60
log_level: info
"""


def secret(path: Path, content: str = "x") -> Path:
    path.write_text(content)
    path.chmod(0o600)
    return path


def write(tmp_path: Path, patch: str = "") -> Path:
    key = secret(tmp_path / "api_key")
    rtsp = secret(tmp_path / "rtsp")
    detector = tmp_path / "detector.engine"
    ocr = tmp_path / "ocr.engine"
    detector.write_bytes(b"detector")
    ocr.write_bytes(b"ocr")
    sha = hashlib.sha256(b"detector").hexdigest()
    sha_ocr = hashlib.sha256(b"ocr").hexdigest()
    text = BASE.format(
        key=key,
        rtsp=rtsp,
        detector=detector,
        ocr=ocr,
        sha=sha,
        sha_ocr=sha_ocr,
        queue=tmp_path / "outbox.db",
        state=tmp_path / "state.json",
    )
    text += patch
    config = tmp_path / "lpr.yaml"
    config.write_text(text)
    return config


def test_rejects_unknown_key(tmp_path):
    with pytest.raises(ConfigError, match="unknown key"):
        load_config(write(tmp_path, "typo: 1\n"), verify_models=False)


def test_rejects_a_non_https_gateway(tmp_path):
    config = write(tmp_path)
    config.write_text(config.read_text().replace("https://", "http://"))
    with pytest.raises(ConfigError, match="https"):
        load_config(config, verify_models=False)


def test_rejects_a_key_file_with_loose_permissions(tmp_path):
    config = write(tmp_path)
    (tmp_path / "api_key").chmod(0o644)
    with pytest.raises(ConfigError, match="0600"):
        load_config(config, verify_models=False)


def test_requires_a_sha256_for_every_engine(tmp_path):
    config = write(tmp_path)
    config.write_text(config.read_text().replace('sha256: "', 'sha256: "zz', 1))
    with pytest.raises(ConfigError, match="SHA-256"):
        load_config(config, verify_models=False)


def test_verifies_the_engine_hash(tmp_path):
    config = write(tmp_path)
    parsed = load_config(config)
    assert parsed.models.detector.input == 640
    (tmp_path / "ocr.engine").write_bytes(b"tampered")
    with pytest.raises(ConfigError, match="hash mismatch"):
        load_config(config)


def test_loads_a_valid_config(tmp_path):
    parsed = load_config(write(tmp_path), verify_models=False)
    assert parsed.device.firmware_version == "lpr-1.0.0"
    assert parsed.capture.decoder == "nvidia"
    assert parsed.sampling.roi == (0.1, 0.2, 0.8, 0.7)
    assert parsed.tracking.max_reads_per_track == 5
    assert parsed.queue.max_rows == 2000
    assert parsed.plate.fold_confusables is True
