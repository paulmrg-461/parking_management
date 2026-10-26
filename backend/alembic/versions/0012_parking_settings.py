"""parking_settings: singleton parking identity (branding) record

Holds the public-facing parking data (name, address, schedule, phone,
website, WhatsApp) plus the logo version/path. The row is created on the
first save with id = 1.

Revision ID: 0012
Revises: 0011
Create Date: 2026-09-28

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0012"
down_revision: str | None = "0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "parking_settings",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=False),
        sa.Column(
            "name", sa.String(length=80), nullable=False, server_default="Parqueadero"
        ),
        sa.Column(
            "address", sa.String(length=160), nullable=False, server_default=""
        ),
        sa.Column(
            "schedule", sa.String(length=120), nullable=False, server_default=""
        ),
        sa.Column("phone", sa.String(length=32), nullable=False, server_default=""),
        sa.Column(
            "website", sa.String(length=200), nullable=False, server_default=""
        ),
        sa.Column(
            "whatsapp", sa.String(length=32), nullable=False, server_default=""
        ),
        sa.Column(
            "logo_version", sa.Integer(), nullable=False, server_default="0"
        ),
        sa.Column("logo_path", sa.String(length=255), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_table("parking_settings")
