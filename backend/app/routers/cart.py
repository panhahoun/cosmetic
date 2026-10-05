from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.models.cart import CartItem
from app.models.product import Product
from app.models.user import User
from app.serializers import serialize_cart_item

router = APIRouter()

MAX_CART_QUANTITY = 99


class AddToCartRequest(BaseModel):
    product_id: int
    quantity: int = Field(default=1, ge=1, le=MAX_CART_QUANTITY)


class UpdateCartRequest(BaseModel):
    product_id: int
    quantity: int = Field(ge=0, le=MAX_CART_QUANTITY)


class RemoveCartRequest(BaseModel):
    product_id: int


def _serialize_cart(db: Session, user_id: int) -> dict:
    items = (
        db.query(CartItem)
        .options(joinedload(CartItem.product))
        .filter(CartItem.user_id == user_id)
        .order_by(CartItem.id.desc())
        .all()
    )
    return {
        "status": True,
        "data": [serialize_cart_item(i) for i in items],
        "total": sum(i.subtotal for i in items),
    }


@router.post("/add_to_cart")
def add_to_cart(
    req: AddToCartRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    product = db.query(Product).filter(Product.id == req.product_id).first()
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

    existing = (
        db.query(CartItem)
        .filter(
            CartItem.user_id == current_user.id,
            CartItem.product_id == req.product_id,
        )
        .first()
    )

    new_quantity = req.quantity + (existing.quantity if existing else 0)
    if new_quantity > MAX_CART_QUANTITY:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot add {req.quantity}: cart already holds "
            f"{existing.quantity if existing else 0} and the limit is {MAX_CART_QUANTITY}",
        )
    if product.stock is not None and new_quantity > product.stock:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Only {product.stock} in stock",
        )

    if existing:
        existing.quantity = new_quantity
        existing.subtotal = existing.quantity * existing.price
        db.add(existing)
    else:
        price = float(product.price)
        db.add(
            CartItem(
                user_id=current_user.id,
                product_id=req.product_id,
                quantity=req.quantity,
                price=price,
                subtotal=price * req.quantity,
                image=product.image,
                product_name=product.name,
            )
        )
    db.commit()

    return {"message": "Item added to cart", **_serialize_cart(db, current_user.id)}


@router.get("/get_cart")
def get_cart(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    return {"message": "Cart retrieved", **_serialize_cart(db, current_user.id)}


@router.post("/update_cart")
def update_cart(
    req: UpdateCartRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    item = (
        db.query(CartItem)
        .filter(
            CartItem.user_id == current_user.id,
            CartItem.product_id == req.product_id,
        )
        .first()
    )
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Item not found in cart"
        )

    if req.quantity == 0:
        db.delete(item)
    else:
        product = item.product
        if product is not None and product.stock is not None and req.quantity > product.stock:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Only {product.stock} in stock",
            )
        item.quantity = req.quantity
        item.subtotal = item.quantity * item.price
        db.add(item)
    db.commit()

    return {"message": "Cart updated", **_serialize_cart(db, current_user.id)}


@router.post("/remove_from_cart")
def remove_from_cart(
    req: RemoveCartRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    item = (
        db.query(CartItem)
        .filter(
            CartItem.user_id == current_user.id,
            CartItem.product_id == req.product_id,
        )
        .first()
    )
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Item not found in cart"
        )
    db.delete(item)
    db.commit()

    return {"message": "Item removed from cart", **_serialize_cart(db, current_user.id)}


@router.post("/clear_cart")
def clear_cart(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    db.query(CartItem).filter(CartItem.user_id == current_user.id).delete()
    db.commit()
    return {"status": True, "message": "Cart cleared", "data": [], "total": 0}
