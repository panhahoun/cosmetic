from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.models.product import Product
from app.models.user import User
from app.models.wishlist import WishlistItem
from app.serializers import serialize_product

router = APIRouter()


class AddWishlistRequest(BaseModel):
    product_id: int


class RemoveWishlistRequest(BaseModel):
    product_id: int


def _list_items(db: Session, user_id: int) -> list[WishlistItem]:
    return (
        db.query(WishlistItem)
        .options(joinedload(WishlistItem.product))
        .filter(WishlistItem.user_id == user_id)
        .order_by(WishlistItem.created_at.desc())
        .all()
    )


def _serialize(db: Session, user_id: int) -> list[dict]:
    return [
        serialize_product(item.product)
        for item in _list_items(db, user_id)
        if item.product is not None
    ]


@router.get("/get_wishlist")
def get_wishlist(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    return {"status": True, "data": _serialize(db, current_user.id)}


@router.post("/add")
def add_to_wishlist(
    req: AddWishlistRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    product = db.query(Product).filter(Product.id == req.product_id).first()
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

    existing = (
        db.query(WishlistItem)
        .filter(
            WishlistItem.user_id == current_user.id,
            WishlistItem.product_id == req.product_id,
        )
        .first()
    )
    if existing is None:
        db.add(WishlistItem(user_id=current_user.id, product_id=req.product_id))
        db.commit()

    # Idempotent: toggling twice from a flaky client must not error or duplicate.
    return {"status": True, "message": "Added to wishlist", "data": _serialize(db, current_user.id)}


@router.post("/remove")
def remove_from_wishlist(
    req: RemoveWishlistRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    item = (
        db.query(WishlistItem)
        .filter(
            WishlistItem.user_id == current_user.id,
            WishlistItem.product_id == req.product_id,
        )
        .first()
    )
    if item is not None:
        db.delete(item)
        db.commit()

    return {"status": True, "message": "Removed from wishlist"}