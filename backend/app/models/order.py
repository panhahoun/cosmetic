from __future__ import annotations

from sqlalchemy import (
    JSON,
    CheckConstraint,
    Column,
    Integer,
    Numeric,
    String,
    Text,
    DateTime,
    Boolean,
    ForeignKey,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class Address(Base):
    __tablename__ = "addresses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    full_name = Column(String(100), nullable=False)
    phone = Column(String(30), nullable=False)
    address_line = Column(Text, nullable=False)
    city = Column(String(100), nullable=True)
    postal_code = Column(String(20), nullable=True)
    is_default = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User")


class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    order_number = Column(String(50), unique=True, nullable=False)
    total_amount = Column(Numeric(12, 2), nullable=False)
    # Constrained rather than free text. The legal transitions live in
    # app/services/order_state.py; this check only stops a typo or a stray
    # UPDATE from writing a status the rest of the system cannot interpret.
    status = Column(String(30), default="pending_payment", nullable=False)
    payment_method = Column(String(30), default="cash_on_delivery", nullable=False)
    shipping_address = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)
    # Client-supplied key that makes order placement retry-safe. Unique per
    # user so a retried checkout returns the original order instead of
    # creating a second one.
    idempotency_key = Column(String(64), nullable=True)
    # How long this order may sit in pending_payment before its reservation is
    # released. Set at creation so the expiry sweep does not have to guess a
    # window from the provider.
    expires_at = Column(DateTime(timezone=True), nullable=True)
    # Inventory bookkeeping, deliberately separate from `status`. An order can
    # have its status written several times (webhook retries, a late failure
    # notice) but its stock must be released exactly once, and only orders
    # still holding a reservation are candidates.
    stock_committed = Column(Boolean, default=False, nullable=False)
    stock_released = Column(Boolean, default=False, nullable=False)
    # Audit trail for every accepted transition: from, to, actor, timestamp.
    status_history = Column(JSON, nullable=False, default=list)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("user_id", "idempotency_key", name="uq_order_user_idempotency"),
        CheckConstraint(
            "status IN ('pending_payment','paid','confirmed','shipped','delivered',"
            "'payment_failed','expired','cancelled','refunded')",
            name="ck_orders_status_known",
        ),
        CheckConstraint(
            "payment_method IN ('cash_on_delivery','khqr','bank_card','bank_transfer')",
            name="ck_orders_payment_method_known",
        ),
        CheckConstraint("total_amount >= 0", name="ck_orders_total_non_negative"),
    )

    user = relationship("User")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    payment = relationship(
        "Payment",
        back_populates="order",
        uselist=False,
        cascade="all, delete-orphan",
    )


class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    # Name and image are snapshots, not live lookups: an order must stay
    # readable after the product is renamed or deleted.
    product_name = Column(String(200), nullable=False)
    product_image = Column(String(500), nullable=True)
    price = Column(Numeric(12, 2), nullable=False)
    quantity = Column(Integer, nullable=False)
    subtotal = Column(Numeric(12, 2), nullable=False)

    order = relationship("Order", back_populates="items")
    product = relationship("Product")


class Payment(Base):
    """One payment attempt's worth of state for an order.

    Kept 1:1 with Order (`order_id` is unique) rather than 1:N. Retrying with a
    fresh provider intent reuses this row and bumps `attempt`, because the
    business question is "is this order paid?" rather than "what did every
    attempt do?" The per-attempt detail lives in `provider_payload` and
    `PaymentEvent`.
    """

    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    provider = Column(String(30), nullable=False)
    # The provider's own identifier for the intent. Unique so a replayed or
    # duplicated intent can never create a second live payment for one order.
    provider_intent_id = Column(String(200), nullable=True)
    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(3), nullable=False, default="USD")
    # created / pending / processing / paid / failed / expired / cancelled /
    # refunded. Kept separate from OrderStatus because payment providers have
    # their own vocabulary and an order can be `cancelled` while a payment
    # attempt sits in `refunded`.
    status = Column(String(30), nullable=False, default="created")
    attempt = Column(Integer, nullable=False, default=1)
    # The opaque value handed to the client to render a QR or redirect.
    # Never trusted for anything: the amount and currency sent to the provider
    # are read back from the order, not from this blob.
    checkout_url = Column(String(500), nullable=True)
    qr_payload = Column(Text, nullable=True)
    # Raw provider responses, keyed by call. Retained for reconciliation and
    # dispute evidence; treat as untrusted input.
    provider_payload = Column(JSON, nullable=True)
    failure_reason = Column(Text, nullable=True)
    paid_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("order_id", name="uq_payments_order"),
        UniqueConstraint(
            "provider", "provider_intent_id", name="uq_payments_provider_intent"
        ),
        CheckConstraint("amount >= 0", name="ck_payments_amount_non_negative"),
        CheckConstraint(
            "status IN ('created','pending','processing','paid','failed','expired',"
            "'cancelled','refunded','manual_review')",
            name="ck_payments_status_known",
        ),
    )

    order = relationship("Order", back_populates="payment")
    events = relationship(
        "PaymentEvent", back_populates="payment", cascade="all, delete-orphan"
    )


class PaymentEvent(Base):
    """Immutable log of everything a provider told us.

    Two jobs. First, the unique constraint on (provider, provider_event_id) is
    what makes webhook handling idempotent: gateways retry deliveries for days,
    and a duplicate must be a no-op rather than a second credit. Second, a raw
    body per event is the only evidence available when a reconciliation gap turns
    into a dispute.
    """

    __tablename__ = "payment_events"

    id = Column(Integer, primary_key=True, index=True)
    payment_id = Column(Integer, ForeignKey("payments.id"), nullable=True)
    provider = Column(String(30), nullable=False)
    # The provider's event/delivery id. Null when the gateway does not send one.
    provider_event_id = Column(String(200), nullable=True)
    event_type = Column(String(60), nullable=True)
    # True only after the provider's signature or encrypted field has been
    # verified. An unverified payload is stored for debugging but must never
    # move an order to paid.
    verified = Column(Boolean, default=False, nullable=False)
    raw_payload = Column(JSON, nullable=True)
    # Set when processing raised, so a failed webhook is visible instead of
    # being retried silently forever.
    error = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint(
            "provider", "provider_event_id", name="uq_payment_events_provider_event"
        ),
    )

    payment = relationship("Payment", back_populates="events")
