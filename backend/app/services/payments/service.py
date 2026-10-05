"""Payment orchestration: create intents, apply verified callbacks.

Two invariants drive everything here.

1. **The amount is server-side.** `create_payment_intent` reads
   `Order.total_amount` and never accepts one from the caller. No client-facing
   schema in this project has an amount field for that reason.

2. **A webhook is evidence, not a command.** Gateways retry deliveries for
   days, and anyone can POST to the callback URL. Every inbound event is written
   to `payment_events` under a unique constraint first, so a replay is a no-op,
   and the order only moves to `paid` after the provider's own signature or
   encrypted field checks out *and* the amount and currency match what we asked
   for. Anything else goes to `manual_review` — visible to an operator, never
   silently auto-approved.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.models.order import Order, Payment, PaymentEvent
from app.services.orders import OrderError, _money, transition_order
from app.services.order_state import OrderStatus
from app.services.payments.base import (
    CreateIntentRequest,
    PaymentConfigurationError,
    ProviderError,
    WebhookEvent,
)

# Payment statuses that mean "do not create another intent".
_LIVE_PAYMENT_STATUSES = frozenset({"created", "pending", "processing", "paid"})


def _public_url(path: str) -> str:
    base = settings.public_base_url.rstrip("/")
    return f"{base}{path}"


def get_payment_for_order(db: Session, order_id: int) -> Payment | None:
    return (
        db.query(Payment)
        .filter(Payment.order_id == order_id)
        .order_by(Payment.id.desc())
        .first()
    )


def create_payment_intent(db: Session, order: Order) -> Payment:
    """Register an intent with the gateway for `order`, or return the live one.

    Idempotent by construction: a Payment row is unique per order, so a
    double-tap or a client retry cannot produce two live charges for one order.
    A caller that genuinely needs a new attempt after a failure gets the
    existing row bumped to a new `attempt` and a fresh provider intent.
    """
    if order.status != str(OrderStatus.PENDING_PAYMENT):
        raise OrderError(
            status.HTTP_409_CONFLICT,
            f"Order {order.order_number} is {order.status}; only a "
            f"pending_payment order can start a payment.",
        )

    existing = get_payment_for_order(db, order.id)
    if existing and existing.status in _LIVE_PAYMENT_STATUSES:
        # Already live or already paid. Hand back the same intent rather than
        # charging the customer twice.
        return existing

    # Server-side amount. `order.total_amount` was summed from cart snapshots at
    # checkout and is never client-supplied.
    amount = _money(order.total_amount)

    request = CreateIntentRequest(
        order_id=order.id,
        order_number=order.order_number,
        amount=amount,
        currency=settings.currency,
        description=f"Order {order.order_number}",
        return_url=_public_url(f"/api/payments/{order.id}/status"),
        cancel_url=_public_url("/"),
        callback_url=_public_url("/api/payments/webhook"),
    )

    from app.services.payments.registry import get_provider

    try:
        provider = get_provider()
        intent = provider.create_intent(request)
    except PaymentConfigurationError as exc:
        raise OrderError(status.HTTP_503_SERVICE_UNAVAILABLE, str(exc)) from exc
    except ProviderError as exc:
        raise OrderError(status.HTTP_502_BAD_GATEWAY, f"Payment provider error: {exc}") from exc

    if existing:
        # Retry after a previous failure: reuse the row so the 1:1 with the
        # order holds, and record that this is attempt N.
        existing.provider = intent.provider
        existing.provider_intent_id = intent.provider_intent_id
        existing.amount = amount
        existing.currency = settings.currency
        existing.status = "pending"
        existing.attempt = (existing.attempt or 1) + 1
        existing.checkout_url = intent.checkout_url
        existing.qr_payload = intent.qr_payload
        existing.provider_payload = intent.raw
        existing.failure_reason = None
        db.add(existing)
        try:
            db.commit()
        except IntegrityError as exc:
            db.rollback()
            raise OrderError(
                status.HTTP_409_CONFLICT,
                "A payment intent already exists for this order.",
            ) from exc
        db.refresh(existing)
        return existing

    payment = Payment(
        order_id=order.id,
        provider=intent.provider,
        provider_intent_id=intent.provider_intent_id,
        amount=amount,
        currency=settings.currency,
        status="pending",
        attempt=1,
        checkout_url=intent.checkout_url,
        qr_payload=intent.qr_payload,
        provider_payload=intent.raw,
    )
    db.add(payment)
    try:
        db.commit()
    except IntegrityError as exc:
        # Lost a race with a concurrent request for the same order. The unique
        # index did its job; return the winner's row.
        db.rollback()
        winner = get_payment_for_order(db, order.id)
        if winner:
            return winner
        raise OrderError(
            status.HTTP_409_CONFLICT, "A payment intent already exists for this order."
        ) from exc
    db.refresh(payment)
    return payment


def record_event(
    db: Session,
    provider: str,
    event: WebhookEvent,
    payment: Payment | None = None,
) -> tuple[PaymentEvent | None, bool]:
    """Persist an inbound callback. Returns (event, created).

    `created` is False when this exact provider event was already recorded,
    which is the signal that the caller must not apply it twice. Gateways retry
    the same event id many times over hours or days.
    """
    if event.provider_event_id:
        existing = (
            db.query(PaymentEvent)
            .filter(
                PaymentEvent.provider == provider,
                PaymentEvent.provider_event_id == event.provider_event_id,
            )
            .first()
        )
        if existing:
            return existing, False

    row = PaymentEvent(
        payment_id=payment.id if payment is not None else None,
        provider=provider,
        provider_event_id=event.provider_event_id,
        event_type=event.event_type,
        verified=event.verified,
        raw_payload=event.raw,
    )
    db.add(row)
    try:
        db.commit()
    except IntegrityError:
        # Two deliveries raced past the check above.
        db.rollback()
        existing = (
            db.query(PaymentEvent)
            .filter(
                PaymentEvent.provider == provider,
                PaymentEvent.provider_event_id == event.provider_event_id,
            )
            .first()
        )
        return existing, False
    db.refresh(row)
    return row, True


def _mismatches(payment: Payment, event: WebhookEvent) -> str | None:
    """Compare what the provider reports against what we asked for."""
    if event.amount is None or event.currency is None:
        return None  # Gateway did not report the figures; nothing to contradict.
    if _money(event.amount) != _money(payment.amount):
        return (
            f"amount mismatch: expected {payment.amount} {payment.currency}, "
            f"provider reported {event.amount} {event.currency}"
        )
    if event.currency.upper() != payment.currency.upper():
        return (
            f"currency mismatch: expected {payment.currency}, "
            f"provider reported {event.currency}"
        )
    return None


def apply_event(
    db: Session,
    payment: Payment,
    event: WebhookEvent,
    event_row: PaymentEvent,
) -> str:
    """Move the order according to a recorded event. Returns the outcome.

    Only `verified` events can mark an order paid. An unverifiable or
    contradictory payload is parked in `manual_review` so it shows up in
    reconciliation instead of quietly becoming revenue or quietly vanishing.
    """
    if not event.verified:
        payment.status = "manual_review"
        payment.failure_reason = "callback failed provider verification"
        event_row.error = "unverified"
        db.commit()
        return "manual_review"

    problem = _mismatches(payment, event)
    if problem:
        # Do not auto-approve, and do not auto-refund: an operator has to look.
        payment.status = "manual_review"
        payment.failure_reason = problem
        event_row.error = problem
        db.commit()
        return "manual_review"

    order = (
        db.query(Order)
        .options(joinedload(Order.items))
        .filter(Order.id == payment.order_id)
        .first()
    )
    if order is None:  # pragma: no cover - FK makes this unreachable
        event_row.error = "order missing"
        db.commit()
        return "orphan"

    if event.is_success:
        payment.status = "paid"
        payment.paid_at = datetime.now(timezone.utc)
        payment.failure_reason = None
        if order.status != str(OrderStatus.PAID):
            try:
                transition_order(
                    db,
                    order,
                    OrderStatus.PAID,
                    actor=f"webhook:{event.provider}",
                    reason=f"{event.event_type} {event.provider_event_id or ''}".strip(),
                )
            except Exception as exc:  # invalid transition or DB guard
                # Money arrived but the order cannot legally move. Surface it;
                # never swallow, and never force the status.
                event_row.error = f"transition to paid rejected: {exc}"
                db.commit()
                return "conflict"
        db.commit()
        return "paid"

    # Explicit failure from the provider: give the stock back.
    payment.status = "failed"
    payment.failure_reason = f"{event.event_type} {event.provider_event_id or ''}".strip()
    try:
        transition_order(
            db,
            order,
            OrderStatus.PAYMENT_FAILED,
            actor=f"webhook:{event.provider}",
            reason=event.event_type,
        )
    except Exception as exc:
        event_row.error = f"transition to payment_failed rejected: {exc}"
    db.commit()
    return "failed"


def handle_webhook(
    db: Session,
    provider_name: str,
    headers: dict[str, str],
    body: bytes,
) -> dict[str, str | bool]:
    """Entry point for an inbound provider callback.

    Always returns rather than raising for provider-caused problems: the reply is
    `200` with a body describing what happened. Raising would make the gateway
    retry a payload that will never become valid.
    """
    from app.services.payments.registry import get_provider

    try:
        provider = get_provider()
    except PaymentConfigurationError as exc:
        return {"status": False, "outcome": "no_provider", "detail": str(exc)}

    if provider.name != provider_name:
        return {
            "status": False,
            "outcome": "provider_mismatch",
            "detail": f"callback addressed to {provider_name!r} but {provider.name!r} is active",
        }

    event = provider.parse_webhook(headers, body)

    payment = None
    if event.provider_intent_id:
        payment = (
            db.query(Payment)
            .filter(
                Payment.provider == provider.name,
                Payment.provider_intent_id == event.provider_intent_id,
            )
            .first()
        )

    row, created = record_event(db, provider.name, event, payment)
    if not created:
        # Duplicate delivery. Nothing to do, and saying so is correct: the first
        # delivery already had its effect.
        return {"status": True, "outcome": "duplicate"}

    if payment is None:
        row.error = row.error or "no payment matches the reported intent"
        db.commit()
        return {
            "status": False,
            "outcome": "unknown_intent",
            "detail": f"no payment for intent {event.provider_intent_id!r}",
        }

    outcome = apply_event(db, payment, event, row)
    return {
        "status": outcome in {"paid", "failed"},
        "outcome": outcome,
        "order_id": payment.order_id,
    }


__all__ = [
    "apply_event",
    "create_payment_intent",
    "get_payment_for_order",
    "handle_webhook",
    "record_event",
]
