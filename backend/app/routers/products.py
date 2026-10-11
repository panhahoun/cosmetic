from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.models.product import Product, Category
from app.serializers import serialize_product

router = APIRouter()


def _pexels(photo_id: int) -> str:
    """Build a hotlinkable Pexels CDN URL for a free stock photo.

    Pexels photos are free to use (Pexels License) and the images CDN allows
    hotlinking, so the demo catalog does not ship real (and possibly
    mis-licensed) brand product shots.
    """
    return (
        f"https://images.pexels.com/photos/{photo_id}/"
        f"pexels-photo-{photo_id}.jpeg?auto=compress&cs=tinysrgb&w=800"
    )


# Demo catalog. Seeding is idempotent and keyed on `name`, so editing an entry
# here (a better image, a price change) propagates to an already-seeded
# database -- local SQLite and the deployed Postgres alike -- on next startup.
_SEED_PRODUCTS = [
    {
        "name": "Hydra Dew Gel Cleanser",
        "description": "Gentle daily gel cleanser that removes makeup and "
        "impurities without stripping the skin barrier.",
        "price": 18.0,
        "image": _pexels(6689393),
        "brand": "Lumiere",
        "size": "150ml",
        "stock": 24,
        "rating": 4.7,
        "review_count": 312,
        "category_name": "Cleanser",
    },
    {
        "name": "Peptide Bounce Serum",
        "description": "Lightweight peptide serum for elasticity, firmness "
        "and a healthy glow.",
        "price": 29.0,
        "image": _pexels(12602356),
        "brand": "NovaSkin",
        "size": "30ml",
        "stock": 18,
        "rating": 4.8,
        "review_count": 521,
        "category_name": "Serum",
    },
    {
        "name": "UV Shield SPF 50+",
        "description": "Invisible broad-spectrum sunscreen that leaves no "
        "white cast. Suitable for daily wear.",
        "price": 21.0,
        "image": _pexels(9496427),
        "brand": "RayDef",
        "size": "50ml",
        "stock": 37,
        "rating": 4.8,
        "review_count": 640,
        "category_name": "Sunscreen",
    },
    {
        "name": "Ceramide Cloud Cream",
        "description": "Rich ceramide moisturizer that repairs and comforts "
        "dry, sensitive skin.",
        "price": 26.0,
        "image": _pexels(6690857),
        "brand": "DermaNest",
        "size": "50ml",
        "stock": 13,
        "rating": 4.9,
        "review_count": 390,
        "category_name": "Moisturizer",
    },
    {
        "name": "Vitamin C Glow Serum",
        "description": "Brightening vitamin C serum that fades dullness and "
        "evens skin tone.",
        "price": 24.0,
        "image": _pexels(4841282),
        "brand": "NovaSkin",
        "size": "30ml",
        "stock": 30,
        "rating": 4.7,
        "review_count": 288,
        "category_name": "Serum",
    },
    {
        "name": "Retinol Renewal Night Serum",
        "description": "Overnight retinol serum that smooths fine lines and "
        "refines skin texture.",
        "price": 34.0,
        "image": _pexels(34823988),
        "brand": "DermaNest",
        "size": "30ml",
        "stock": 15,
        "rating": 4.9,
        "review_count": 476,
        "category_name": "Serum",
    },
    {
        "name": "Hyaluronic Hydra Essence",
        "description": "Layered hydration essence with hyaluronic acid for "
        "plump, dewy skin.",
        "price": 27.0,
        "image": _pexels(29675494),
        "brand": "Lumiere",
        "size": "100ml",
        "stock": 22,
        "rating": 4.6,
        "review_count": 201,
        "category_name": "Essence",
    },
    {
        "name": "Rose Petal Facial Toner",
        "description": "Alcohol-free rose toner that refreshes and rebalances "
        "skin after cleansing.",
        "price": 16.0,
        "image": _pexels(14149693),
        "brand": "Lumiere",
        "size": "200ml",
        "stock": 40,
        "rating": 4.5,
        "review_count": 165,
        "category_name": "Toner",
    },
    {
        "name": "Daily Glow Moisturizer",
        "description": "Featherlight daily moisturizer that keeps makeup "
        "fresh all day.",
        "price": 22.0,
        "image": _pexels(6690236),
        "brand": "GlowLab",
        "size": "50ml",
        "stock": 28,
        "rating": 4.7,
        "review_count": 254,
        "category_name": "Moisturizer",
    },
    {
        "name": "Overnight Repair Cream",
        "description": "Restorative night cream that works with your skin's "
        "natural repair cycle.",
        "price": 31.0,
        "image": _pexels(19173472),
        "brand": "DermaNest",
        "size": "50ml",
        "stock": 12,
        "rating": 4.8,
        "review_count": 319,
        "category_name": "Moisturizer",
    },
    {
        "name": "Soothing Aloe Gel Cream",
        "description": "Cooling aloe gel cream that calms redness and "
        "irritation after sun exposure.",
        "price": 18.0,
        "image": _pexels(24602074),
        "brand": "GlowLab",
        "size": "60ml",
        "stock": 35,
        "rating": 4.6,
        "review_count": 176,
        "category_name": "Moisturizer",
    },
    {
        "name": "Shea Silk Body Lotion",
        "description": "Fast-absorbing shea body lotion for soft, nourished "
        "skin from neck to toe.",
        "price": 19.0,
        "image": _pexels(18996279),
        "brand": "Lumiere",
        "size": "250ml",
        "stock": 33,
        "rating": 4.7,
        "review_count": 188,
        "category_name": "Body Care",
    },
    {
        "name": "Botanic Repair Shampoo",
        "description": "Sulfate-free shampoo that strengthens and adds shine "
        "to dry, damaged hair.",
        "price": 20.0,
        "image": _pexels(16973307),
        "brand": "NovaSkin",
        "size": "300ml",
        "stock": 26,
        "rating": 4.6,
        "review_count": 97,
        "category_name": "Hair Care",
    },
    {
        "name": "Blossom Eau de Parfum",
        "description": "Soft floral eau de parfum with notes of rose, peony "
        "and white musk.",
        "price": 45.0,
        "image": _pexels(12563417),
        "brand": "Lumiere",
        "size": "50ml",
        "stock": 9,
        "rating": 4.8,
        "review_count": 212,
        "category_name": "Fragrance",
    },
    {
        "name": "Mineral Matte Sunscreen SPF 30",
        "description": "Mineral sunscreen with a soft matte finish that "
        "controls shine.",
        "price": 23.0,
        "image": _pexels(16615433),
        "brand": "RayDef",
        "size": "50ml",
        "stock": 20,
        "rating": 4.5,
        "review_count": 133,
        "category_name": "Sunscreen",
    },
    {
        "name": "Daily UV Fluid SPF 50",
        "description": "Ultra-light UV fluid that layers invisibly under "
        "moisturizer and makeup.",
        "price": 25.0,
        "image": _pexels(27401466),
        "brand": "RayDef",
        "size": "50ml",
        "stock": 17,
        "rating": 4.7,
        "review_count": 244,
        "category_name": "Sunscreen",
    },
]


def seed_catalog(db: Session) -> None:
    """Insert the demo catalog and keep it in sync on every startup.

    This runs on each start rather than only when the table is empty, so new
    seed products and corrected images reach an already-populated database --
    local SQLite and the deployed Postgres alike -- on the next deploy/restart.
    Matching is by product name, so an entry edited here updates the existing
    row instead of duplicating it.

    Only presentational fields are refreshed. `stock` and `reserved` are left
    untouched so a restart never resurrects inventory that orders consumed.
    """
    changed = False

    def category_for(name: str) -> Category:
        nonlocal changed
        cat = db.query(Category).filter(Category.name == name).first()
        if cat is None:
            cat = Category(name=name)
            db.add(cat)
            db.flush()
            changed = True
        return cat

    for seed in _SEED_PRODUCTS:
        cat = category_for(seed.get("category_name", "General"))
        product = db.query(Product).filter(Product.name == seed["name"]).first()

        if product is None:
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
                    category_id=cat.id,
                )
            )
            changed = True
            continue

        desired = {
            "description": seed["description"],
            "price": seed["price"],
            "image": seed["image"],
            "brand": seed["brand"],
            "size": seed["size"],
            "rating": seed["rating"],
            "review_count": seed["review_count"],
            "category_id": cat.id,
        }
        for field, value in desired.items():
            if getattr(product, field) != value:
                setattr(product, field, value)
                changed = True

    if changed:
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
