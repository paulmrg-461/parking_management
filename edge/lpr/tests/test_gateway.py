import ssl
from pathlib import Path

import pytest

from lpr_edge.config import GatewayConfig
from lpr_edge.gateway import (
    GatewayClient,
    GatewayState,
    NonRetryableError,
    Response,
    RetryableError,
)


def config(tmp_path: Path) -> GatewayConfig:
    key = tmp_path / "api_key"
    key.write_text("pkd_test")
    return GatewayConfig(
        url="https://gw.example/functions/v1/device-gateway",
        api_key_file=str(key),
        firmware_version="lpr-test",
    )


class FakeTransport:
    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []

    def __call__(self, method, url, headers, body):
        self.calls.append((method, url, dict(headers), body))
        if not self.responses:
            return Response(200, {})
        return self.responses.pop(0)


def client(tmp_path, responses, wall=lambda: 1000.0):
    state = GatewayState(tmp_path / "state.json")
    return GatewayClient(config(tmp_path), state, FakeTransport(responses), wall=wall)


def test_seq_uses_boot_counter_and_increases(tmp_path):
    state = GatewayState(tmp_path / "state.json")
    gateway = GatewayClient(config(tmp_path), state, FakeTransport([]))
    first = gateway.next_seq()
    second = gateway.next_seq()
    assert first >> 32 == state.boot_counter
    assert second >> 32 == state.boot_counter
    assert second == first + 1


def test_replay_error_adopts_last_seq(tmp_path):
    last = (7 << 32) | 9
    fake = FakeTransport([
        Response(409, {"error": "DeviceReplayError", "last_seq": last}),
        Response(200, {"outcome": "replayed"}),
    ])
    state = GatewayState(tmp_path / "state.json")
    gateway = GatewayClient(config(tmp_path), state, fake)
    response = gateway.post_read({"client_ref": "ref-1", "plate": "ABC123"})
    assert response.status == 200
    assert state.boot_counter == 8
    retry_seq = int(fake.calls[-1][2]["X-Device-Seq"])
    assert retry_seq >> 32 == 8
    assert retry_seq & 0xFFFFFFFF == 1
    # The retry keeps the same idempotency key.
    assert fake.calls[0][2]["Idempotency-Key"] == "ref-1"
    assert fake.calls[1][2]["Idempotency-Key"] == "ref-1"


def test_clock_skew_syncs_time_and_retries_once(tmp_path):
    fake = FakeTransport([
        Response(400, {"error": "DeviceClockSkewError"}),
        Response(200, {"server_time": "1970-01-01T00:18:20+00:00"}),
        Response(200, {"outcome": "recorded"}),
    ])
    gateway = client(tmp_path, [], wall=lambda: 1000.0)
    gateway.transport = fake
    response = gateway.post_read({"client_ref": "ref-1", "plate": "ABC123"})
    assert response.status == 200
    first_ts = int(fake.calls[0][2]["X-Device-Timestamp"])
    retry_ts = int(fake.calls[-1][2]["X-Device-Timestamp"])
    assert first_ts == 1000
    assert retry_ts == 1100
    assert fake.calls[1][0] == "GET"
    assert fake.calls[1][1].endswith("/v1/time")


def test_new_seq_on_retry(tmp_path):
    fake = FakeTransport([
        Response(409, {"error": "DeviceReplayError", "last_seq": (1 << 32) | 4}),
        Response(200, {}),
    ])
    gateway = client(tmp_path, [])
    gateway.transport = fake
    gateway.post_read({"client_ref": "ref", "plate": "ABC123"})
    first = int(fake.calls[0][2]["X-Device-Seq"])
    second = int(fake.calls[1][2]["X-Device-Seq"])
    assert first != second


def test_does_not_retry_400_family(tmp_path):
    fake = FakeTransport([Response(400, {"message": "InvalidPlateError"})])
    gateway = client(tmp_path, [])
    gateway.transport = fake
    with pytest.raises(NonRetryableError):
        gateway.post_read({"client_ref": "ref", "plate": "bad"})
    assert len(fake.calls) == 1


def test_5xx_is_retryable(tmp_path):
    fake = FakeTransport([Response(502, {"message": "AiUpstreamError"})])
    gateway = client(tmp_path, [])
    gateway.transport = fake
    with pytest.raises(RetryableError):
        gateway.post_read({"client_ref": "ref", "plate": "ABC123"})


def test_backoff_schedule_and_jitter_bounds(tmp_path):
    gateway = client(tmp_path, [], wall=lambda: 0.0)
    gateway.jitter = lambda: 0.0
    assert gateway.backoff(0) == pytest.approx(0.8)
    gateway.jitter = lambda: 1.0
    assert gateway.backoff(0) == pytest.approx(1.2)
    gateway.jitter = lambda: 0.5
    assert gateway.backoff(10) <= 30.0
    assert gateway.backoff(10) >= 0.0


def test_tls_verify_never_disabled(tmp_path):
    gateway = client(tmp_path, [])
    context = gateway.tls_context()
    assert isinstance(context, ssl.SSLContext)
    assert context.verify_mode == ssl.CERT_REQUIRED
    assert context.check_hostname is True
