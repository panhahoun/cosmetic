from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.models.order import Order
from app.models.user import User
from app.serializers import serialize_order, serialize_payment
from app.services.orders import OrderError
from app.services.payments.service import create_payment_intent, get_payment_for_order

router = APIRouter()


class CreateIntentRequestBody(BaseModel):
    # No amount field, deliberately. The total is read from the order on the
    # server; a client that could state its own amount could state a smaller one.
    order_id: int = Field(gt=0)


def _owned_order(db: Session, order_id: int, user: User) -> Order:
    order = (
        db.query(Order)
        .options(joinedload(Order.items))
        .filter(Order.id == order_id, Order.user_id == user.id)
        .first()
    )
    if not order:
        # 404 rather than 403, for the same reason as get_order: do not leak
        # which order ids exist.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Order not found"
        )
    return order


@router.post("/intents")
def create_intent(
    req: CreateIntentRequestBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    order = _owned_order(db, req.order_id, current_user)

    try:
        payment = create_payment_intent(db, order)
    except OrderError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return {
        "status": True,
        "message": "Payment intent ready",
        "data": serialize_payment(payment),
    }


@router.get("/{order_id}/status")
def payment_status(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Poll target for the checkout screen.

    The client polls this after showing a QR or after returning from a banking
    app. It reports what the server knows; it never asserts that a payment
    succeeded on its own. The webhook is the only thing that can say `paid`.
    """
    order = _owned_order(db, order_id, current_user)
    payment = get_payment_for_order(db, order.id)

    return {
        "status": True,
        "message": "Payment status",
        "data": {
            "order": serialize_order(order),
            "payment": serialize_payment(payment) if payment else None,
        },
    }


@router.post("/webhook")
async def payment_webhook(
    request: Request,
    db: Session = Depends(get_db),
    provider: str = Query(
        ...,
        description="Gateway that delivered this callback, e.g. baray.",
    ),
):
    """Inbound provider callback. Deliberately unauthenticated.

    Gateways authenticate with their own signature or encrypted field, not with
    a bearer token, so requiring one would reject every real delivery. Trust
    therefore comes entirely from verification inside the provider adapter and
    the unique constraint on payment_events.
    """
    from app.services.payments.service import handle_webhook

    body = await request.body()
    headers = {k.lower(): v for k, v in request.headers.items()}

    result = handle_webhook(db, provider.lower(), headers, body)

    # Always 200. A 4xx/5xx here tells the gateway the event failed, which for a
    # permanently-invalid payload means an unbounded retry storm. Failures are
    # recorded on the event row instead.
    return {"received": True, **result}
