"""payment foundation: Numeric money, stock reservation, payments tables

Revision ID: 0002_payment_foundation
Revises: 0001_baseline

Four changes, all in service of taking real money safely:

1. Money becomes Numeric(12,2). A Float cannot represent 0.1, so totals drift
   and a provider reconciling against them will disagree.

2. products.reserved, splitting "available to sell" from "held for an unpaid
   order". Without this split, taking payment for an order means either holding
   stock forever for orders nobody pays for, or releasing it while the customer
   is still deciding.

3. orders gains a constrained status, an expiry, the two stock-bookkeeping
   flags, and an audit trail.

4. payments / payment_events. The unique constraint on
   (provider, provider_event_id) in payment_events is what makes webhook
   delivery idempotent; gateways retry the same event for days.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0002_payment_foundation"
down_revision = "0001_baseline"
branch_labels = None
depends_on = None

MONEY = sa.Numeric(12, 2)


def upgrade() -> None:
    # --- 1. money ---------------------------------------------------------
    # batch_alter_table is required on SQLite, which cannot ALTER a column type
    # and instead rebuilds the table. On Postgres it degrades to a plain ALTER.
    with op.batch_alter_table("products", schema=None) as batch:
        batch.alter_column(
            "price", type_=MONEY, existing_type=sa.Float(), existing_nullable=False
        )
    with op.batch_alter_table("cart_items", schema=None) as batch:
        batch.alter_column(
            "price", type_=MONEY, existing_type=sa.Float(), existing_nullable=False
        )
        batch.alter_column(
            "subtotal", type_=MONEY, existing_type=sa.Float(), existing_nullable=False
        )
    with op.batch_alter_table("orders", schema=None) as batch:
        batch.alter_column(
            "total_amount", type_=MONEY, existing_type=sa.Float(), existing_nullable=False
        )
    with op.batch_alter_table("order_items", schema=None) as batch:
        batch.alter_column(
            "price", type_=MONEY, existing_type=sa.Float(), existing_nullable=False
        )
        batch.alter_column(
            "subtotal", type_=MONEY, existing_type=sa.Float(), existing_nullable=False
        )

    # --- 2. product reservation ------------------------------------------
    with op.batch_alter_table("products", schema=None) as batch:
        # server_default keeps the ADD COLUMN valid against rows that already
        # exist; the model default then takes over for new rows.
        batch.add_column(
            sa.Column("reserved", sa.Integer(), nullable=False, server_default="0")
        )
        batch.alter_column("stock", existing_type=sa.Integer(), nullable=False)
        batch.create_check_constraint("ck_products_stock_non_negative", "stock >= 0")
        batch.create_check_constraint("ck_products_reserved_non_negative", "reserved >= 0")

    # --- 3. order lifecycle ----------------------------------------------
    with op.batch_alter_table("orders", schema=None) as batch:
        batch.alter_column(
            "status",
            type_=sa.String(length=30),
            existing_type=sa.String(length=30),
            nullable=False,
            server_default="pending_payment",
        )
        # Old values are rewritten before the CHECK lands, otherwise every
        # pre-existing 'cash' / 'pending' row violates the new constraint.
        batch.execute(
            sa.text("UPDATE orders SET status = 'confirmed' WHERE status = 'pending'")
        )
        batch.execute(
            sa.text(
                "UPDATE orders SET payment_method = 'cash_on_delivery' "
                "WHERE payment_method = 'cash'"
            )
        )
        batch.execute(
            sa.text("UPDATE orders SET payment_method = 'bank_card' WHERE payment_method = 'card'")
        )
        batch.alter_column(
            "payment_method",
            type_=sa.String(length=30),
            existing_type=sa.String(length=30),
            nullable=False,
            server_default="cash_on_delivery",
        )
        batch.add_column(sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(
            sa.Column(
                "stock_committed", sa.Boolean(), nullable=False, server_default=sa.false()
            )
        )
        batch.add_column(
            sa.Column("stock_released", sa.Boolean(), nullable=False, server_default=sa.false()
            )
        )
        batch.add_column(sa.Column("status_history", sa.JSON(), nullable=True))
        batch.create_check_constraint(
            "ck_orders_status_known",
            "status IN ('pending_payment','paid','confirmed','shipped','delivered',"
            "'payment_failed','expired','cancelled','refunded')",
        )
        batch.create_check_constraint(
            "ck_orders_payment_method_known",
            "payment_method IN ('cash_on_delivery','khqr','bank_card','bank_transfer')",
        )
        batch.create_check_constraint("ck_orders_total_non_negative", "total_amount >= 0")

    # Legacy rows predate the audit trail; backfill rather than leave nulls.
    op.execute(sa.text("UPDATE orders SET status_history = '[]' WHERE status_history IS NULL"))
    with op.batch_alter_table("orders", schema=None) as batch:
        batch.alter_column(
            "status_history",
            type_=sa.JSON(),
            existing_type=sa.JSON(),
            nullable=False,
        )

    # --- 4. payments ------------------------------------------------------
    op.create_table(
        "payments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("provider", sa.String(length=30), nullable=False),
        sa.Column("provider_intent_id", sa.String(length=200), nullable=True),
        sa.Column("amount", MONEY, nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False, server_default="USD"),
        sa.Column("status", sa.String(length=30), nullable=False, server_default="created"),
        sa.Column("attempt", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("checkout_url", sa.String(length=500), nullable=True),
        sa.Column("qr_payload", sa.Text(), nullable=True),
        sa.Column("provider_payload", sa.JSON(), nullable=True),
        sa.Column("failure_reason", sa.Text(), nullable=True),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True
        ),
        sa.ForeignKeyConstraint(["order_id"], ["orders.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("order_id", name="uq_payments_order"),
        # Stops a duplicated intent from becoming a second live charge.
        sa.UniqueConstraint("provider", "provider_intent_id", name="uq_payments_provider_intent"),
        sa.CheckConstraint("amount >= 0", name="ck_payments_amount_non_negative"),
        sa.CheckConstraint(
            "status IN ('created','pending','processing','paid','failed','expired',"
            "'cancelled','refunded','manual_review')",
            name="ck_payments_status_known",
        ),
    )
    op.create_index(op.f("ix_payments_id"), "payments", ["id"], unique=False)

    op.create_table(
        "payment_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("payment_id", sa.Integer(), nullable=True),
        sa.Column("provider", sa.String(length=30), nullable=False),
        sa.Column("provider_event_id", sa.String(length=200), nullable=True),
        sa.Column("event_type", sa.String(length=60), nullable=True),
        sa.Column("verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("raw_payload", sa.JSON(), nullable=True),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True
        ),
        sa.ForeignKeyConstraint(["payment_id"], ["payments.id"]),
        sa.PrimaryKeyConstraint("id"),
        # This is the idempotency guarantee for webhook delivery.
        sa.UniqueConstraint(
            "provider", "provider_event_id", name="uq_payment_events_provider_event"
        ),
    )
    op.create_index(op.f("ix_payment_events_id"), "payment_events", ["id"], unique=False)


def downgrade() -> None:
    op.drop_table("payment_events")
    op.drop_table("payments")

    with op.batch_alter_table("orders", schema=None) as batch:
        batch.drop_constraint("ck_orders_total_non_negative", type_="check")
        batch.drop_constraint("ck_orders_payment_method_known", type_="check")
        batch.drop_constraint("ck_orders_status_known", type_="check")
        batch.drop_column("status_history")
        batch.drop_column("stock_released")
        batch.drop_column("stock_committed")
        batch.drop_column("expires_at")
        batch.alter_column(
            "payment_method",
            type_=sa.String(length=30),
            existing_type=sa.String(length=30),
            server_default="cash",
        )
        batch.alter_column(
            "status",
            type_=sa.String(length=30),
            existing_type=sa.String(length=30),
            server_default="pending",
        )

    with op.batch_alter_table("products", schema=None) as batch:
        batch.drop_constraint("ck_products_reserved_non_negative", type_="check")
        batch.drop_constraint("ck_products_stock_non_negative", type_="check")
        batch.drop_column("reserved")

    with op.batch_alter_table("order_items", schema=None) as batch:
        batch.alter_column(
            "subtotal", type_=sa.Float(), existing_type=MONEY, existing_nullable=False
        )
        batch.alter_column(
            "price", type_=sa.Float(), existing_type=MONEY, existing_nullable=False
        )
    with op.batch_alter_table("orders", schema=None) as batch:
        batch.alter_column(
            "total_amount", type_=sa.Float(), existing_type=MONEY, existing_nullable=False
        )
    with op.batch_alter_table("cart_items", schema=None) as batch:
        batch.alter_column(
            "subtotal", type_=sa.Float(), existing_type=MONEY, existing_nullable=False
        )
        batch.alter_column(
            "price", type_=sa.Float(), existing_type=MONEY, existing_nullable=False
        )
    with op.batch_alter_table("products", schema=None) as batch:
        batch.alter_column(
            "price", type_=sa.Float(), existing_type=MONEY, existing_nullable=False
        )
