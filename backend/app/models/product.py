from __future__ import annotations

from sqlalchemy import (
    CheckConstraint,
    Column,
    Integer,
    Numeric,
    String,
    Float,
    Text,
    DateTime,
    ForeignKey,
    func,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    products = relationship("Product", back_populates="category")


class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    # Prices are stored as NUMERIC, not FLOAT. A binary float cannot represent
    # 0.1, so summing floats accumulates error and a payment provider
    # reconciling against these totals will disagree. Postgres NUMERIC is exact;
    # note that SQLite does not enforce the scale (see alembic env.py).
    price = Column(Numeric(12, 2), nullable=False)
    image = Column(String(500), nullable=True)
    brand = Column(String(100), nullable=True)
    size = Column(String(50), nullable=True)
    # `stock` is stock available to new orders, not physical on-hand. It is
    # decremented when an order reserves units and incremented back when that
    # order fails, expires or is cancelled. `reserved` counts the units
    # currently held by orders in `pending_payment`.
    stock = Column(Integer, default=0, nullable=False)
    reserved = Column(Integer, default=0, nullable=False)
    rating = Column(Float, default=4.5)
    review_count = Column(Integer, default=0)
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    category = relationship("Category", back_populates="products")

    __table_args__ = (
        # Keeps the two counters from drifting apart into a negative or
        # nonsensical combination. `reserved` is allowed to exceed `stock`
        # because stock-available and units-held are deliberately different
        # quantities; only the two obvious impossibilities are rejected here.
        CheckConstraint("stock >= 0", name="ck_products_stock_non_negative"),
        CheckConstraint("reserved >= 0", name="ck_products_reserved_non_negative"),
    )
