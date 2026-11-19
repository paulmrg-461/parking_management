import numpy as np

from lpr_edge.capture import Frame, ReconnectingSource


class Clock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now


class FakeSource:
    def __init__(self, timestamps):
        self._timestamps = list(timestamps)
        self.closed = False

    def read(self):
        if not self._timestamps:
            return None
        moment = self._timestamps.pop(0)
        return Frame(image=np.zeros((2, 2), dtype=np.uint8), timestamp=moment)

    def close(self):
        self.closed = True


def test_stall_triggers_teardown():
    clock = Clock()
    created: list[FakeSource] = []

    def factory():
        source = FakeSource([0.0])
        created.append(source)
        return source

    source = ReconnectingSource(factory, stall_seconds=10.0, clock=clock)
    frame = source.read()
    assert frame is not None
    assert source.connected is True
    clock.now = 11.0
    source.read()  # detects the stall, closes, schedules a reconnect
    assert created[0].closed is True
    assert source.connected is False
    # Reconnect after the backoff.
    clock.now = 12.1
    source.read()
    assert source.connected is True
    assert len(created) == 2


def test_reconnect_backoff_resets_after_30s_of_frames():
    clock = Clock()
    created: list[FakeSource] = []

    def factory():
        source = FakeSource([0.0] * 100)
        created.append(source)
        return source

    source = ReconnectingSource(factory, stall_seconds=100.0, clock=clock)
    source.read()
    # Force a couple of failed reconnects to grow the attempt counter.
    source.close()
    source._next_connect = 0.0
    source._attempt = 3
    clock.now = 0.0
    source._source = None
    source.read()
    assert source.connected is True
    # Thirty seconds of healthy frames reset the backoff.
    clock.now = 31.0
    source.read()
    assert source._attempt == 0


def test_close_releases_the_source():
    clock = Clock()
    holder = {}

    def factory():
        source = FakeSource([0.0])
        holder["source"] = source
        return source

    source = ReconnectingSource(factory, clock=clock)
    source.read()
    source.close()
    assert holder["source"].closed is True
