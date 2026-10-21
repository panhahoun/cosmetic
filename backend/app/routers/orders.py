from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.models.order import Order
from app.models.user import User
from app.serializers import serialize_order
from app.services.orders import OrderRequest, place_order

router = APIRouter()


class CreateOrderRequest(BaseModel):
    payment_method: str = Field(default="cash_on_delivery", max_length=30)
    shipping_address: str | None = None
    notes: str | None = None


class CheckoutRequest(BaseModel):
    payment_method: str = Field(default="cash_on_delivery", max_length=30)
    shipping_address: str | None = None
    notes: str | None = None


@router.post("/create_order")
def create_order(
    req: CreateOrderRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    order = place_order(
        db,
        current_user.id,
        OrderRequest(
            payment_method=req.payment_method,
            shipping_address=req.shipping_address,
            notes=req.notes,
        ),
        idempotency_key=idempotency_key,
    )
    return {
        "status": True,
        "message": "Order created successfully",
        "data": serialize_order(order),
    }


@router.post("/checkout")
def checkout(
    req: CheckoutRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    order = place_order(
        db,
        current_user.id,
        OrderRequest(
            payment_method=req.payment_method,
            shipping_address=req.shipping_address,
            notes=req.notes,
        ),
        idempotency_key=idempotency_key,
    )
    return {
        "status": True,
        "message": "Order created successfully",
        "data": serialize_order(order),
    }


@router.get("/get_orders")
def get_orders(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    base = db.query(Order).filter(Order.user_id == current_user.id)
    total = base.count()
    orders = (
        base.options(joinedload(Order.items))
        .order_by(Order.created_at.desc(), Order.id.desc())
        .limit(limit)
        .offset(offset)
        .all()
    )
    return {
        "status": True,
        "message": "Orders retrieved",
        "data": [serialize_order(o) for o in orders],
        "total": total,
        "limit": limit,
        "offset": offset,
    }


@router.get("/get_order/{order_id}")
def get_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    # Ownership is part of the query: a caller-supplied user_id must not widen it.
    order = (
        db.query(Order)
        .options(joinedload(Order.items))
        .filter(Order.id == order_id, Order.user_id == current_user.id)
        .first()
    )
    if not order:
        # 404 rather than 403 so this cannot be used to probe which order ids
        # exist in the system.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Order not found"
        )
    return {
        "status": True,
        "message": "Order retrieved",
        "data": serialize_order(order),
    }
