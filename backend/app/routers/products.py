from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.models.product import Product, Category
from app.serializers import serialize_product

router = APIRouter()

_SEED_PRODUCTS = [
    {
        "id": 9001,
        "name": "Hydra Dew Gel Cleanser",
        "description": "Gentle daily cleanser for all skin types.",
        "price": 18.0,
        "image": "https://picsum.photos/seed/cleanser1/600/600",
        "brand": "Lumiere",
        "size": "150ml",
        "stock": 24,
        "rating": 4.7,
        "review_count": 312,
        "category_name": "Cleanser",
    },
    {
        "id": 9002,
        "name": "Peptide Bounce Serum",
        "description": "Lightweight serum for elasticity and glow.",
        "price": 29.0,
        "image": "https://picsum.photos/seed/serum1/600/600",
        "brand": "NovaSkin",
        "size": "30ml",
        "stock": 18,
        "rating": 4.8,
        "review_count": 521,
        "category_name": "Serum",
    },
    {
        "id": 9003,
        "name": "UV Shield SPF 50+",
        "description": "Invisible sunscreen with broad-spectrum protection.",
        "price": 21.0,
        "image": "https://picsum.photos/seed/sun1/600/600",
        "brand": "RayDef",
        "size": "50ml",
        "stock": 37,
        "rating": 4.8,
        "review_count": 640,
        "category_name": "Sunscreen",
    },
    {
        "id": 9004,
        "name": "Ceramide Cloud Cream",
        "description": "Moisturizer for dry and sensitive skin.",
        "price": 26.0,
        "image": "https://picsum.photos/seed/moist1/600/600",
        "brand": "DermaNest",
        "size": "50ml",
        "stock": 13,
        "rating": 4.9,
        "review_count": 390,
        "category_name": "Moisturizer",
    },
]


def seed_if_empty(db: Session) -> None:
    """Insert demo catalog data once.

    Called from the app lifespan, not from a GET handler: running this inside
    get_products() meant two concurrent first requests both saw count == 0 and
    both inserted, and it wrote to the database on a read path.
    """
    if db.query(Product).count() > 0:
        return

    cat_map: dict[str, Category] = {}
    for seed in _SEED_PRODUCTS:
        cat_name = seed.get("category_name", "General")
        if cat_name not in cat_map:
            cat = db.query(Category).filter(Category.name == cat_name).first()
            if not cat:
                cat = Category(name=cat_name)
                db.add(cat)
                db.flush()
            cat_map[cat_name] = cat

    for seed in _SEED_PRODUCTS:
        cat = cat_map.get(seed.get("category_name", "General"))
        db.add(
            Product(
                name=seed["name"],
                description=seed["description"],
                price=seed["price"],
                image=seed["image"],
                brand=seed["brand"],
                size=seed["size"],
                stock=seed["stock"],
                rating=seed["rating"],
                review_count=seed["review_count"],
                category_id=cat.id if cat else None,
            )
        )
    db.commit()


@router.get("/get_products")
def get_products(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    category_id: int | None = Query(default=None),
    q: str | None = Query(default=None, max_length=100),
    sort: str = Query(default="newest", pattern="^(newest|price_asc|price_desc|rating)$"),
    db: Session = Depends(get_db),
):
    query = db.query(Product).options(joinedload(Product.category))

    if category_id is not None:
        query = query.filter(Product.category_id == category_id)
    if q:
        like = f"%{q}%"
        query = query.filter(Product.name.ilike(like) | Product.brand.ilike(like))

    total = query.count()

    # Tie-break on id so ordering is stable: created_at is second-resolution
    # and every seeded row shares the same value.
    order_by = {
        "newest": (Product.created_at.desc(), Product.id.desc()),
        "price_asc": (Product.price.asc(), Product.id.asc()),
        "price_desc": (Product.price.desc(), Product.id.desc()),
        "rating": (Product.rating.desc(), Product.id.desc()),
    }[sort]

    products = query.order_by(*order_by).limit(limit).offset(offset).all()
    return {
        "status": True,
        "message": "Products retrieved successfully",
        "data": [serialize_product(p) for p in products],
        "total": total,
        "limit": limit,
        "offset": offset,
    }


@router.get("/get_product/{product_id}")
def get_product(product_id: int, db: Session = Depends(get_db)):
    product = db.query(Product).options(joinedload(Product.category)).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return {
        "status": True,
        "message": "Product retrieved successfully",
        "data": serialize_product(product),
    }
