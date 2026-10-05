from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.product import Category
from app.serializers import serialize_category

router = APIRouter()


@router.get("/get_categories")
def get_categories(db: Session = Depends(get_db)):
    categories = db.query(Category).order_by(Category.name).all()
    return {
        "status": True,
        "message": "Categories retrieved successfully",
        "data": [serialize_category(c) for c in categories],
    }
