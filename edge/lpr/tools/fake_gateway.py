#!/usr/bin/env python3
"""Run the fake device gateway for a demo or an integration test.

    python tools/fake_gateway.py [--port 8099]

Inject a fault with ``curl -X POST http://127.0.0.1:8099/control \
-d '{"fault": 503}'`` (``null`` clears it). The gateway records reads and
snapshots in memory and only listens on localhost.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lpr_edge.testing import FakeGateway  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=0)
    args = parser.parse_args()
    with FakeGateway(port=args.port) as gateway:
        print(f"fake gateway on {gateway.url}", flush=True)
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            return 0


if __name__ == "__main__":
    raise SystemExit(main())
