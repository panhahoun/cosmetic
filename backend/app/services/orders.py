from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import ROUND_HALF_UP, Decimal

from fastapi import HTTPException, status
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.models.cart import CartItem
from app.models.order import Order, OrderItem
from app.models.product import Product
from app.services import order_state
from app.services.order_state import OrderStatus

# Methods that require a provider to confirm before the order counts as paid.
# Everything else (cash on delivery) is fulfilled without a payment step.
DEFERRED_PAYMENT_METHODS: frozenset[str] = frozenset({"khqr", "bank_card", "bank_transfer"})
VALID_PAYMENT_METHODS: frozenset[str] = frozenset({"cash_on_delivery"}) | (
    DEFERRED_PAYMENT_METHODS
)

# Mobile builds are deployed asynchronously, so a client can still be sending the
# old value after the canonical set changed. Normalising at the boundary turns a
# hard 400 into a working checkout instead of stranding a paying customer.
_LEGACY_PAYMENT_METHOD_ALIASES: dict[str, str] = {
    "cash": "cash_on_delivery",
    "card": "bank_card",
}


class OrderError(HTTPException):
    """Business-rule failure that maps to a specific HTTP status."""

    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(status_code=status_code, detail=detail)


@dataclass(frozen=True)
class OrderRequest:
    payment_method: str = "cash_on_delivery"
    shipping_address: str | None = None
    notes: str | None = None


def generate_order_number() -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    return f"ORD-{stamp}-{uuid.uuid4().hex[:6].upper()}"


def _money(value: float | Decimal | int | str | None) -> Decimal:
    """Quantise to 2dp. Every amount in the system passes through here."""
    if value is None:
        return Decimal("0.00")
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def requires_payment(payment_method: str) -> bool:
    return payment_method in DEFERRED_PAYMENT_METHODS


def normalize_payment_method(value: str | None) -> str:
    """Map a client-supplied method onto the canonical vocabulary."""
    method = (value or "cash_on_delivery").strip().lower()
    return _LEGACY_PAYMENT_METHOD_ALIASES.get(method, method)


def get_cart_subtotal(db: Session, user_id: int) -> Decimal:
    cart_items = (
        db.query(CartItem)
        .options(joinedload(CartItem.product))
        .filter(CartItem.user_id == user_id)
        .order_by(CartItem.id)
        .all()
    )
    return sum((_money(i.subtotal) for i in cart_items), Decimal("0.00"))


def _order_items(db: Session, order_id: int) -> list[OrderItem]:
    """Read items from the session.

    Deliberately not `order.items`: rows inserted during checkout are added as
    standalone OrderItem objects, so the in-memory relationship is empty until
    it is expired. Reading through it here would silently update zero products.
    """
    return (
        db.query(OrderItem)
        .filter(OrderItem.order_id == order_id)
        .order_by(OrderItem.id)
        .all()
    )


def _commit_reservation(db: Session, order: Order) -> None:
    """Reservation becomes a sale: units leave the held pool, `stock` unchanged."""
    for item in _order_items(db, order.id):
        db.query(Product).filter(Product.id == item.product_id).update(
            {"reserved": Product.reserved - item.quantity},
            synchronize_session=False,
        )
    order.stock_committed = True
    order.stock_released = False


def _release_reservation(db: Session, order: Order) -> None:
    """Reserved units go back on sale. Guarded so it can only happen once."""
    if order.stock_released or order.stock_committed:
        return
    for item in _order_items(db, order.id):
        db.query(Product).filter(Product.id == item.product_id).update(
            {
                "stock": Product.stock + item.quantity,
                "reserved": Product.reserved - item.quantity,
            },
            synchronize_session=False,
        )
    order.stock_released = True


def transition_order(
    db: Session,
    order: Order,
    target: OrderStatus | str,
    *,
    actor: str = "system",
    reason: str | None = None,
) -> Order:
    """Move an order to `target`, enforcing the transition map and keeping stock honest.

    Inventory effects, applied at most once per order:
      - entering `paid` commits the reservation (`reserved` drops, units sold);
      - entering a releasing status (`payment_failed`, `expired`, `cancelled`)
        returns the units to sale, but only while a reservation is still held.

    An order that already committed is never auto-restocked. A chargeback or a
    refund is a decision to put goods back, not a side effect of writing a
    status, so it needs an explicit call.

    Raises InvalidTransition rather than writing an illegal status.
    """
    target_status = order_state.coerce_status(target)

    # Re-applying the current status is a no-op, not an error: providers resend
    # "paid" aggressively and a replayed webhook must be harmless.
    if order_state.coerce_status(order.status) == target_status:
        return order

    order_state.assert_transition(order.status, target_status)

    holds_reservation = not bool(order.stock_committed) and not bool(order.stock_released)

    if target_status is OrderStatus.PAID and holds_reservation:
        _commit_reservation(db, order)
    elif order_state.releases_stock(target_status) and holds_reservation:
        _release_reservation(db, order)

    history = list(order.status_history or [])
    history.append(
        {
            "from": str(order.status),
            "to": str(target_status),
            "actor": actor,
            "reason": reason,
            "at": datetime.now(timezone.utc).isoformat(),
        }
    )
    order.status_history = history
    order.status = str(target_status)
    return order


def expire_stale_orders(db: Session, now: datetime | None = None) -> int:
    """Release stock held by orders nobody paid for.

    Called on startup and from a periodic job. Without it every abandoned KHQR
    checkout strands its reserved units until an operator intervenes.
    """
    now = now or datetime.now(timezone.utc)
    stale = (
        db.query(Order)
        .filter(
            Order.status == str(OrderStatus.PENDING_PAYMENT),
            Order.expires_at.isnot(None),
            Order.expires_at <= now,
        )
        .all()
    )
    for order in stale:
        transition_order(
            db,
            order,
            OrderStatus.EXPIRED,
            actor="expiry_sweep",
            reason="payment window elapsed",
        )
    if stale:
        db.commit()
    return len(stale)


def place_order(
    db: Session,
    user_id: int,
    request: OrderRequest,
    idempotency_key: str | None = None,
) -> Order:
    """Reserve stock and create an order from the user's cart.

    Stock is *reserved*, not committed. For a method that needs payment,
    `stock` (available to new orders) drops and `reserved` rises, and the units
    are only spent when the provider confirms. Cash on delivery never waits on
    anyone, so it skips the reservation entirely. This is what lets an unpaid
    order exist without overselling the shop.

    Raises OrderError and leaves the session unmodified on any failure.
    """
    payment_method = normalize_payment_method(request.payment_method)
    if payment_method not in VALID_PAYMENT_METHODS:
        raise OrderError(
            status.HTTP_400_BAD_REQUEST,
            f"Unsupported payment method {payment_method!r}. "
            f"Expected one of: {', '.join(sorted(VALID_PAYMENT_METHODS))}",
        )

    if idempotency_key:
        existing = (
            db.query(Order)
            .options(joinedload(Order.items))
            .filter(Order.user_id == user_id, Order.idempotency_key == idempotency_key)
            .first()
        )
        if existing:
            return existing

    cart_items = (
        db.query(CartItem)
        .options(joinedload(CartItem.product))
        .filter(CartItem.user_id == user_id)
        .order_by(CartItem.id)
        .all()
    )
    if not cart_items:
        raise OrderError(status.HTTP_400_BAD_REQUEST, "Cart is empty")

    for ci in cart_items:
        if ci.product is None:
            raise OrderError(
                status.HTTP_409_CONFLICT,
                f"Product {ci.product_id} is no longer available",
            )
        if ci.quantity <= 0:
            raise OrderError(
                status.HTTP_400_BAD_REQUEST,
                f"Invalid quantity for {ci.product_name or ci.product_id}",
            )

    total = sum((_money(i.subtotal) for i in cart_items), Decimal("0.00"))
    deferred = requires_payment(payment_method)
    now = datetime.now(timezone.utc)

    order = Order(
        user_id=user_id,
        order_number=generate_order_number(),
        total_amount=total,
        status=str(OrderStatus.PENDING_PAYMENT if deferred else OrderStatus.CONFIRMED),
        payment_method=payment_method,
        shipping_address=request.shipping_address,
        notes=request.notes,
        idempotency_key=idempotency_key,
        expires_at=(
            now + timedelta(minutes=settings.payment_window_minutes) if deferred else None
        ),
        # Cash on delivery is committed the moment the order exists; a payment
        # order stays uncommitted until a verified webhook says `paid`.
        stock_committed=not deferred,
        stock_released=False,
        status_history=[
            {
                "from": None,
                "to": str(OrderStatus.PENDING_PAYMENT if deferred else OrderStatus.CONFIRMED),
                "actor": "checkout",
                "reason": "order created",
                "at": now.isoformat(),
            }
        ],
    )
    db.add(order)
    db.flush()

    for ci in cart_items:
        # Conditional UPDATE: the WHERE clause re-checks stock at write time, so
        # two concurrent checkouts of the last unit cannot both succeed. Only a
        # deferred order moves units into `reserved`.
        deltas = {"stock": Product.stock - ci.quantity}
        if deferred:
            deltas["reserved"] = Product.reserved + ci.quantity
        updated = (
            db.query(Product)
            .filter(Product.id == ci.product_id, Product.stock >= ci.quantity)
            .update(deltas, synchronize_session=False)
        )
        if not updated:
            db.rollback()
            raise OrderError(
                status.HTTP_409_CONFLICT,
                f"Insufficient stock for {ci.product_name or ci.product_id} "
                f"(requested {ci.quantity}, available {ci.product.stock})",
            )

        db.add(
            OrderItem(
                order_id=order.id,
                product_id=ci.product_id,
                product_name=ci.product_name or ci.product.name,
                product_image=ci.image or ci.product.image,
                price=_money(ci.price),
                quantity=ci.quantity,
                subtotal=_money(ci.subtotal),
            )
        )

    db.query(CartItem).filter(CartItem.user_id == user_id).delete()
    db.commit()

    return (
        db.query(Order)
        .options(joinedload(Order.items))
        .filter(Order.id == order.id)
        .first()
        or order
    )
