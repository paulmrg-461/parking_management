from pathlib import Path

import numpy as np

from lpr_edge.capture import Frame
from lpr_edge.config import GatewayConfig
from lpr_edge.gateway import GatewayClient, GatewayState, urllib_transport
from lpr_edge.models import ExpectedFrame, FakeDetector, FakeOcr
from lpr_edge.outbox import Outbox
from lpr_edge.postprocess import PlateRules
from lpr_edge.sampler import Sampler, SamplingConfig
from lpr_edge.service import Service
from lpr_edge.testing import FakeGateway
from lpr_edge.tracker import Box, Tracker


def build(tmp_path: Path, gateway_url: str):
    key = tmp_path / "api_key"
    key.write_text("pkd_test")
    config = GatewayConfig(
        url=gateway_url,
        api_key_file=str(key),
        firmware_version="lpr-test",
    )
    outbox = Outbox(tmp_path / "outbox.db")
    client = GatewayClient(
        config,
        GatewayState(tmp_path / "state.json"),
        urllib_transport(),
        wall=lambda: 1000.0,
    )
    frames = [
        ExpectedFrame(
            boxes=[Box(10, 10, 60, 30, score=0.95)],
            text="abc123",
            confidence=0.97,
        ),
        ExpectedFrame(
            boxes=[Box(10, 10, 60, 30, score=0.95)],
            text="abc123",
            confidence=0.97,
        ),
    ]
    service = Service(
        sampler=Sampler(SamplingConfig(idle_fps=100, active_fps=100)),
        tracker=Tracker(),
        detector=FakeDetector(frames),
        ocr=FakeOcr(frames),
        rules=PlateRules(),
        outbox=outbox,
        gateway=client,
        encoder=lambda crop: b"\xff\xd8\xff" + crop.tobytes(),
        wall=lambda: 1000.0,
    )
    return service, outbox, client


def test_end_to_end_read_decision_and_snapshot(tmp_path):
    with FakeGateway() as gateway:
        service, outbox, _ = build(tmp_path, gateway.url)
        image = np.zeros((80, 80, 3), dtype=np.uint8)
        plate = service.process(Frame(image=image, timestamp=0.0), now=0.0)
        assert plate == "ABC123"
        assert outbox.depth() == 1
        assert service.drain(now=0.0) == 1
        assert outbox.depth() == 0
        assert len(gateway.reads) == 1
        assert gateway.reads[0]["plate"] == "ABC123"
        assert gateway.reads[0]["confidence"] == 0.95
        assert gateway.snapshots, "the snapshot of the decided read was uploaded"
        assert gateway.snapshots[0][1].startswith(b"\xff\xd8\xff")
        outbox.close()


def test_replay_is_sent_once(tmp_path):
    with FakeGateway() as gateway:
        service, outbox, _ = build(tmp_path, gateway.url)
        image = np.zeros((80, 80, 3), dtype=np.uint8)
        service.process(Frame(image=image, timestamp=0.0), now=0.0)
        service.drain(now=0.0)
        payload = gateway.reads[0]
        outbox.enqueue(
            "read",
            __import__("json").dumps(payload),
            client_ref=payload["client_ref"],
            now=1.0,
        )
        service.drain(now=1.0)
        assert len(gateway.reads) == 1
        assert outbox.depth() == 0
        outbox.close()


def test_network_outage_keeps_the_row_and_recovers(tmp_path):
    with FakeGateway() as gateway:
        service, outbox, client = build(tmp_path, gateway.url)
        image = np.zeros((80, 80, 3), dtype=np.uint8)
        service.process(Frame(image=image, timestamp=0.0), now=0.0)
        gateway.fault = 503
        assert service.drain(now=0.0) == 0
        assert outbox.depth() == 1
        row = outbox.next_due(now=100)
        assert row is not None and row.attempts == 1
        gateway.fault = None
        assert service.drain(now=row.next_try_at) == 1
        assert outbox.depth() == 0
        outbox.close()
