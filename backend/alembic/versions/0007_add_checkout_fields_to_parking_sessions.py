"""add checkout fields to parking_sessions

Revision ID: 0007
Revises: 0006
Create Date: 2026-09-05

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0007"
down_revision: Union[str, None] = "0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "parking_sessions",
        sa.Column("exit_time", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "parking_sessions",
        sa.Column("amount_charged", sa.Integer(), nullable=True),
    )
    op.add_column(
        "parking_sessions",
        sa.Column("ticket_number", sa.String(length=20), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("parking_sessions", "ticket_number")
    op.drop_column("parking_sessions", "amount_charged")
    op.drop_column("parking_sessions", "exit_time")
