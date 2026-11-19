import os
import subprocess
import sys
from pathlib import Path

from lpr_edge.outbox import Outbox


def test_enqueue_before_send_keeps_client_ref(tmp_path):
    outbox = Outbox(tmp_path / "outbox.db")
    reference = outbox.enqueue("read", '{"plate": "ABC123"}', client_ref="ref-1")
    row = outbox.next_due(now=0)
    assert reference == "ref-1"
    assert row is not None
    assert row.client_ref == "ref-1"
    assert row.payload == '{"plate": "ABC123"}'
    assert row.attempts == 0
    outbox.close()


def test_order_preserved(tmp_path):
    outbox = Outbox(tmp_path / "outbox.db")
    first = outbox.enqueue("read", "{}", now=1)
    second = outbox.enqueue("read", "{}", now=2)
    third = outbox.enqueue("read", "{}", now=3)
    rows = outbox.due(now=10)
    assert [row.client_ref for row in rows] == [first, second, third]
    outbox.close()


def test_attempt_backs_off(tmp_path):
    outbox = Outbox(tmp_path / "outbox.db")
    outbox.enqueue("read", "{}", client_ref="ref", now=0)
    row = outbox.next_due(now=0)
    outbox.mark_attempt(row.id, next_try_at=5)
    assert outbox.next_due(now=4) is None
    assert outbox.next_due(now=5).attempts == 1
    outbox.close()


def test_expired_rows_dropped_and_counted(tmp_path):
    outbox = Outbox(tmp_path / "outbox.db")
    outbox.enqueue("read", "{}", now=0)
    outbox.enqueue("read", "{}", now=1000)
    dropped = outbox.prune(max_age_s=900, max_rows=10, now=1000)
    assert dropped == 1
    assert outbox.depth() == 1
    outbox.close()


def test_max_rows_drops_oldest(tmp_path):
    outbox = Outbox(tmp_path / "outbox.db")
    for index in range(5):
        outbox.enqueue("read", f"{index}", now=index)
    dropped = outbox.prune(max_age_s=3600, max_rows=2, now=10)
    assert dropped == 3
    rows = outbox.due(now=10)
    assert [row.payload for row in rows] == ["3", "4"]
    outbox.close()


def test_kill_between_enqueue_and_send_keeps_one_row(tmp_path):
    path = tmp_path / "outbox.db"
    script = (
        "import os\n"
        "from lpr_edge.outbox import Outbox\n"
        f"outbox = Outbox({str(path)!r})\n"
        "outbox.enqueue('read', '{}', client_ref='crash-ref', now=1)\n"
        "os._exit(9)\n"
    )
    result = subprocess.run(
        [sys.executable, "-c", script],
        cwd=Path(__file__).resolve().parents[1],
        env={**os.environ, "PYTHONPATH": str(Path(__file__).resolve().parents[1])},
    )
    assert result.returncode == 9
    outbox = Outbox(path)
    row = outbox.next_due(now=10)
    assert row is not None
    assert row.client_ref == "crash-ref"
    assert outbox.depth() == 1
    outbox.close()
