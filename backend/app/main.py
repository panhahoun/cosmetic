from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings, parse_cors_origins
from app.core.database import create_tables, SessionLocal
from app.routers import auth, products, categories, cart, orders, addresses, payments


@asynccontextmanager
async def lifespan(app: FastAPI):
    create_tables()
    # Seeding runs once at startup instead of on every GET /get_products, which
    # raced on concurrent first requests and wrote to the DB from a read path.
    db = SessionLocal()
    try:
        products.seed_if_empty(db)
        # Release anything a previous run left reserved. Without this an orders
        # table restored from a backup keeps its reserved stock locked forever.
        from app.services.orders import expire_stale_orders

        expired = expire_stale_orders(db)
        if expired:
            print(f"[startup] released {expired} expired order reservation(s)")
    finally:
        db.close()
    yield


app = FastAPI(title=settings.app_name, version=settings.app_version, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    # parse_cors_origins raises if this contains "*" or is empty. The API is
    # credentialed, so an open origin would let any site read authenticated
    # responses.
    allow_origins=parse_cors_origins(settings.cors_origins),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
    max_age=600,
)

app.include_router(auth.router, prefix="/api/auth", tags=["Auth"])
app.include_router(products.router, prefix="/api/products", tags=["Products"])
app.include_router(categories.router, prefix="/api/categories", tags=["Categories"])
app.include_router(cart.router, prefix="/api/cart", tags=["Cart"])
app.include_router(orders.router, prefix="/api/orders", tags=["Orders"])
app.include_router(addresses.router, prefix="/api/addresses", tags=["Addresses"])
app.include_router(payments.router, prefix="/api/payments", tags=["Payments"])


@app.get("/")
def root():
    return {"message": "Cosmetic Store API v1.0", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok"}
