"""Order lifecycle as an explicit transition map.

Payment support is what forces this to exist. Previously `status` was a free
String that any handler could write to, and `place_order` committed stock
immediately. With a real payment provider there are at least two independent
outcomes (money received, goods shipped) that can each succeed or fail, arrive
out of order, and arrive twice. Encoding the legal transitions in one table
means an illegal move fails loudly in one place instead of silently corrupting
an order that money has already been taken against.

Vocabulary:
  pending_payment  order created, stock reserved, awaiting provider confirmation
  paid             provider confirmed settlement (webhook is the only writer)
  confirmed        merchant accepted the paid order
  shipped          handed to the courier
  delivered        customer received it
  payment_failed   provider reported a failure, stock released
  expired          nobody paid within the window, stock released
  cancelled        customer or merchant abandoned it, stock released
  refunded         money returned, stock does not come back automatically

`stock_committed` records whether the reserved units were spent. It is separate
from `status` on purpose: release and commit are about inventory, and
inventory must be undone exactly once per order regardless of how many times
the status is touched.
"""

from __future__ import annotations

from enum import StrEnum


class OrderStatus(StrEnum):
    PENDING_PAYMENT = "pending_payment"
    PAID = "paid"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    PAYMENT_FAILED = "payment_failed"
    EXPIRED = "expired"
    CANCELLED = "cancelled"
    REFUNDED = "refunded"


# Terminal states accept no further transitions. A customer cannot un-receive a
# delivery, and a refund closes the order for good.
TERMINAL_STATUSES: frozenset[OrderStatus] = frozenset(
    {OrderStatus.DELIVERED, OrderStatus.CANCELLED, OrderStatus.REFUNDED}
)

# Statuses after which the reservation has already been returned to available
# stock. Re-releasing would inflate stock on every repeated transition.
STOCK_RELEASED_STATUSES: frozenset[OrderStatus] = frozenset(
    {
        OrderStatus.PAYMENT_FAILED,
        OrderStatus.EXPIRED,
        OrderStatus.CANCELLED,
    }
)

ALLOWED_TRANSITIONS: dict[OrderStatus, frozenset[OrderStatus]] = {
    # Checkout always lands here first. `expired` is reachable from here because
    # a customer who closes the banking app must eventually free their stock.
    OrderStatus.PENDING_PAYMENT: frozenset(
        {
            OrderStatus.PAID,
            OrderStatus.PAYMENT_FAILED,
            OrderStatus.EXPIRED,
            OrderStatus.CANCELLED,
        }
    ),
    # `payment_failed` is reachable from paid so a late failure notice (chargeback,
    # reversal) is not silently dropped.
    OrderStatus.PAID: frozenset(
        {OrderStatus.CONFIRMED, OrderStatus.PAYMENT_FAILED, OrderStatus.REFUNDED}
    ),
    OrderStatus.CONFIRMED: frozenset({OrderStatus.SHIPPED, OrderStatus.REFUNDED}),
    OrderStatus.SHIPPED: frozenset({OrderStatus.DELIVERED, OrderStatus.REFUNDED}),
    OrderStatus.DELIVERED: frozenset({OrderStatus.REFUNDED}),
    OrderStatus.PAYMENT_FAILED: frozenset({OrderStatus.PENDING_PAYMENT}),
    # An expired or cancelled order can be revived if the customer retries with a
    # fresh intent, but only back into pending_payment, never straight to paid.
    OrderStatus.EXPIRED: frozenset({OrderStatus.PENDING_PAYMENT}),
    OrderStatus.CANCELLED: frozenset({OrderStatus.PENDING_PAYMENT}),
    OrderStatus.REFUNDED: frozenset(),
}


class UnknownStatus(ValueError):
    """Raised when a value is not a member of OrderStatus at all.

    Separate from InvalidTransition: "delivered" is a real status that happens
    to be unreachable from here, while "teleported" is not a status at all. The
    two need different handling and different error messages.
    """


class InvalidTransition(ValueError):
    """Raised when a caller tries to move an order to a status it cannot reach."""

    def __init__(self, current: str, target: str) -> None:
        self.current = current
        self.target = target
        # Must tolerate an unparseable `current`: this error is also used to
        # report bad input, and looking it up in the table would raise again.
        allowed = sorted(
            str(s) for s in _safe_targets(current)
        )
        super().__init__(
            f"cannot move order from {current!r} to {target!r}; "
            f"allowed from {current!r}: {allowed or ['<terminal>']}"
        )


def _safe_targets(status: str | OrderStatus) -> frozenset[OrderStatus]:
    try:
        return ALLOWED_TRANSITIONS.get(_coerce(status), frozenset())
    except ValueError:
        return frozenset()


def _coerce(value: OrderStatus | str) -> OrderStatus:
    return value if isinstance(value, OrderStatus) else OrderStatus(value)


def coerce_status(value: OrderStatus | str) -> OrderStatus:
    """Parse a status, rejecting anything not in the enum."""
    try:
        return _coerce(value)
    except ValueError as exc:
        valid = ", ".join(str(s) for s in OrderStatus)
        raise UnknownStatus(f"{value!r} is not a valid order status; expected one of: {valid}") from exc


def can_transition(current: OrderStatus | str, target: OrderStatus | str) -> bool:
    return _coerce(target) in _safe_targets(current)


def assert_transition(current: OrderStatus | str, target: OrderStatus | str) -> None:
    # Validate `current` first: if it is not a real status at all, that is the
    # more useful thing to report than "you cannot get to paid from nowhere".
    from_status = coerce_status(current)
    to_status = coerce_status(target)
    if to_status not in _safe_targets(from_status):
        raise InvalidTransition(str(current), str(target))


def is_terminal(status: OrderStatus | str) -> bool:
    return _coerce(status) in TERMINAL_STATUSES


def releases_stock(status: OrderStatus | str) -> bool:
    """True when entering this status means the reservation goes back on sale."""
    return _coerce(status) in STOCK_RELEASED_STATUSES


def next_statuses(status: OrderStatus | str) -> list[str]:
    """Statuses reachable from here. Exposed for the admin UI and for tests."""
    return sorted(str(s) for s in _safe_targets(status))


__all__ = [
    "ALLOWED_TRANSITIONS",
    "InvalidTransition",
    "UnknownStatus",
    "OrderStatus",
    "STOCK_RELEASED_STATUSES",
    "TERMINAL_STATUSES",
    "assert_transition",
    "can_transition",
    "coerce_status",
    "is_terminal",
    "next_statuses",
    "releases_stock",
]
