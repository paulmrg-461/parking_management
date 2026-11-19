"""SQLite outbox: a read is durable before it is sent.

The client_ref is generated at enqueue time and never regenerated, so a crash
between insert and send replays the same request and the server answers
``replayed`` without a second event. Old rows and rows beyond the cap are
dropped with a counter the heartbeat reports.
"""

from __future__ import annotations

import sqlite3
import time
import uuid
from dataclasses import dataclass
from pathlib import Path

SCHEMA = """
create table if not exists outbox (
    id integer primary key,
    kind text not null,
    client_ref text not null unique,
    payload text not null,
    snapshot blob,
    created_at real not null,
    attempts integer not null default 0,
    next_try_at real not null default 0
);
create index if not exists ix_outbox_due on outbox(next_try_at, id);
"""


@dataclass(frozen=True)
class Row:
    id: int
    kind: str
    client_ref: str
    payload: str
    snapshot: bytes | None
    created_at: float
    attempts: int
    next_try_at: float


class Outbox:
    def __init__(self, path: str | Path) -> None:
        self._connection = sqlite3.connect(str(path))
        self._connection.row_factory = sqlite3.Row
        self._connection.execute("pragma journal_mode=wal")
        self._connection.execute("pragma synchronous=normal")
        self._connection.executescript(SCHEMA)
        self._connection.commit()

    def enqueue(
        self,
        kind: str,
        payload: str,
        *,
        snapshot: bytes | None = None,
        client_ref: str | None = None,
        now: float | None = None,
    ) -> str:
        reference = client_ref or str(uuid.uuid4())
        self._connection.execute(
            "insert into outbox (kind, client_ref, payload, snapshot, created_at)"
            " values (?, ?, ?, ?, ?)",
            (kind, reference, payload, snapshot, now if now is not None else time.time()),
        )
        self._connection.commit()
        return reference

    def next_due(self, now: float | None = None) -> Row | None:
        moment = now if now is not None else time.time()
        row = self._connection.execute(
            "select * from outbox where next_try_at <= ? order by id limit 1",
            (moment,),
        ).fetchone()
        return _row(row)

    def due(self, now: float | None = None) -> list[Row]:
        moment = now if now is not None else time.time()
        rows = self._connection.execute(
            "select * from outbox where next_try_at <= ? order by id",
            (moment,),
        ).fetchall()
        return [_row(row) for row in rows if row is not None]

    def mark_attempt(
        self,
        row_id: int,
        next_try_at: float,
        *,
        now: float | None = None,
    ) -> None:
        self._connection.execute(
            "update outbox set attempts = attempts + 1, next_try_at = ? where id = ?",
            (next_try_at, row_id),
        )
        self._connection.commit()

    def delete(self, row_id: int) -> None:
        self._connection.execute("delete from outbox where id = ?", (row_id,))
        self._connection.commit()

    def depth(self) -> int:
        row = self._connection.execute("select count(*) as n from outbox").fetchone()
        return int(row["n"]) if row is not None else 0

    def prune(
        self,
        *,
        max_age_s: int,
        max_rows: int,
        now: float | None = None,
    ) -> int:
        moment = now if now is not None else time.time()
        dropped = 0
        cursor = self._connection.execute(
            "delete from outbox where created_at < ?",
            (moment - max_age_s,),
        )
        dropped += cursor.rowcount
        excess = self.depth() - max_rows
        if excess > 0:
            cursor = self._connection.execute(
                "delete from outbox where id in"
                " (select id from outbox order by id limit ?)",
                (excess,),
            )
            dropped += cursor.rowcount
        self._connection.commit()
        return dropped

    def close(self) -> None:
        self._connection.close()


def _row(row: sqlite3.Row | None) -> Row | None:
    if row is None:
        return None
    return Row(
        id=int(row["id"]),
        kind=str(row["kind"]),
        client_ref=str(row["client_ref"]),
        payload=str(row["payload"]),
        snapshot=row["snapshot"],
        created_at=float(row["created_at"]),
        attempts=int(row["attempts"]),
        next_try_at=float(row["next_try_at"]),
    )
