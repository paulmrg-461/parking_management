from datetime import datetime, timezone

import numpy as np

from lpr_edge.sampler import Sampler, SamplingConfig


def test_idle_to_active_on_detection():
    sampler = Sampler(SamplingConfig(motion_threshold=5.0, active_hold_s=3.0))
    assert sampler.observe(1.0, now=0.0) is False
    assert sampler.is_active(now=0.0) is False
    assert sampler.observe(8.0, now=1.0) is True
    assert sampler.is_active(now=2.0) is True
    assert sampler.is_active(now=4.5) is False


def test_motion_gate():
    sampler = Sampler(SamplingConfig(motion_threshold=6.0))
    frame = np.zeros((10, 10), dtype=np.uint8)
    moved = frame.copy()
    moved[0:2, 0:2] = 255
    assert sampler.motion_score(None, frame) == 0.0
    assert sampler.motion_score(frame, moved) > 0
    assert sampler.observe(sampler.motion_score(frame, moved), now=0) is True


def test_active_fps_is_faster_than_idle():
    sampler = Sampler(SamplingConfig(idle_fps=2, active_fps=8, active_hold_s=10))
    assert sampler.should_sample(now=0.0) is True
    assert sampler.should_sample(now=0.2) is False
    sampler.observe(10.0, now=0.2)
    assert sampler.should_sample(now=0.3) is True
    assert sampler.should_sample(now=0.4) is False
    assert sampler.should_sample(now=0.5) is True


def test_stale_frame_dropped():
    sampler = Sampler(SamplingConfig(max_frame_age_s=1.0))
    assert sampler.is_stale(frame_timestamp=10.0, now=10.5) is False
    assert sampler.is_stale(frame_timestamp=10.0, now=11.5) is True


def test_roi_crop():
    sampler = Sampler(SamplingConfig(roi=(0.5, 0.5, 0.5, 0.5)))
    frame = np.arange(100).reshape(10, 10)
    cropped = sampler.crop(frame)
    assert cropped.shape == (5, 5)
    assert cropped[0, 0] == frame[5, 5]


def test_health_payload_shape():
    from lpr_edge.health import heartbeat_payload

    payload = heartbeat_payload(
        uptime_s=10,
        camera_up=True,
        queue_depth=3,
        dropped=2,
        fps=4.5,
        detector_ms_p95=12.0,
        now=datetime(2026, 11, 19, 12, 0, tzinfo=timezone.utc),
    )
    assert payload["uptime_s"] == 10
    assert payload["camera"] == "up"
    assert payload["queue_depth"] == 3
    assert payload["dropped"] == 2
    assert payload["fps"] == 4.5
    assert payload["detector_ms_p95"] == 12.0
    assert payload["captured_at"].startswith("2026-11-19T12:00:00")
