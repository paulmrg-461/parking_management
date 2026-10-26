"""Clock port: the single source of "now" for use cases (testable)."""

from collections.abc import Callable
from datetime import UTC, datetime, timedelta

Clock = Callable[[], datetime]

# Tolerated device clock drift for offline-queued check-ins/check-outs.
MAX_CLIENT_CLOCK_SKEW = timedelta(minutes=5)


def system_clock() -> datetime:
    """Current instant as a timezone-aware UTC datetime."""
    return datetime.now(UTC)
