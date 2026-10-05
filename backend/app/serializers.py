from __future__ import annotations

from datetime import timezone
from typing import Any, Optional


def _utc_iso(value: Any) -> Optional[str]:
    """Serialize a timestamp with an explicit UTC offset.

    SQLite ignores the timezone=True on DateTime, so isoformat() was emitting a
    naive string the client could not reliably parse.
    """
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()


def serialize_user(user: Any) -> dict[str, Any]:
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "phone": user.phone,
        "role": user.role,
    }


def serialize_category(category: Any) -> dict[str, Any]:
    return {
        "id": category.id,
        "name": category.name,
        "description": category.description,
    }


def serialize_product(product: Any) -> dict[str, Any]:
    # Explicit None checks: `product.rating or 4.5` turned a genuine 0 into
    # 4.5, fabricating a rating for products with no reviews.
    return {
        "id": product.id,
        "name": product.name,
        "description": product.description or "",
        "price": float(product.price),
        "image": product.image or "",
        "brand": product.brand or "",
        "size": product.size or "",
        "stock": int(product.stock if product.stock is not None else 0),
        "rating": float(product.rating if product.rating is not None else 0.0),
        "review_count": int(
            product.review_count if product.review_count is not None else 0
        ),
        "category_name": (
            product.category.name
            if product.category
            else (getattr(product, "category_name", None) or "")
        ),
        "category_id": product.category_id,
    }


def serialize_cart_item(item: Any) -> dict[str, Any]:
    name = item.product_name or (
        item.product.name if getattr(item, "product", None) else ""
    )
    return {
        "id": item.id,
        "product_id": item.product_id,
        "quantity": int(item.quantity),
        "price": float(item.price),
        "subtotal": float(item.subtotal),
        "image": item.image or "",
        "name": name,
        "product_name": name,
    }


def serialize_order_item(item: Any) -> dict[str, Any]:
    return {
        "id": item.id,
        "product_id": item.product_id,
        "product_name": item.product_name,
        "product_image": item.product_image or "",
        "price": float(item.price),
        "quantity": int(item.quantity),
        "subtotal": float(item.subtotal),
    }


def serialize_order(order: Any) -> dict[str, Any]:
    return {
        "id": order.id,
        "order_number": order.order_number,
        "total_amount": float(order.total_amount),
        "status": order.status,
        "payment_method": order.payment_method,
        "shipping_address": order.shipping_address,
        "notes": order.notes,
        "expires_at": _utc_iso(getattr(order, "expires_at", None)),
        "status_history": list(getattr(order, "status_history", None) or []),
        "created_at": _utc_iso(order.created_at),
        "items": [serialize_order_item(i) for i in getattr(order, "items", [])],
    }


def serialize_payment(payment: Any) -> dict[str, Any]:
    """Payment as the client sees it.

    `provider_payload` is deliberately absent. It is retained raw for
    reconciliation, but echoing gateway internals to a handset leaks
    identifiers that should stay server-side.
    """
    if payment is None:
        return None  # type: ignore[return-value]
    return {
        "id": payment.id,
        "order_id": payment.order_id,
        "provider": payment.provider,
        "status": payment.status,
        "amount": float(payment.amount),
        "currency": payment.currency,
        "attempt": int(payment.attempt or 1),
        "checkout_url": payment.checkout_url or "",
        "qr_payload": payment.qr_payload or "",
        "failure_reason": payment.failure_reason or "",
        "paid_at": _utc_iso(payment.paid_at),
        "created_at": _utc_iso(payment.created_at),
    }


def serialize_address(address: Any) -> dict[str, Any]:
    return {
        "id": address.id,
        "full_name": address.full_name,
        "phone": address.phone,
        "address_line": address.address_line,
        "city": address.city or "",
        "postal_code": address.postal_code or "",
        "is_default": bool(address.is_default),
    }
