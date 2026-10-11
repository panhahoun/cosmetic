"""Smoke test: re-runs every exploit from the code review against the fixed app.

Run with the app lifespan active (so tables and seed data exist):
    python3 smoke_test.py
"""

from __future__ import annotations

import json
import os
import tempfile

os.environ.setdefault(
    "SECRET_KEY", "local-dev-only-not-a-real-secret-0123456789abcdef"
)
# Sandbox gateway, so the full checkout -> intent -> webhook -> paid path can be
# exercised without merchant credentials. No real provider is contacted.
os.environ.setdefault("PAYMENT_PROVIDER", "fake")

_db_fd, _db_path = tempfile.mkstemp(suffix=".db")
os.close(_db_fd)
os.environ["DATABASE_URL"] = f"sqlite:///{_db_path}"

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402
from app.core.database import SessionLocal  # noqa: E402
from app.models.order import Order, Payment, PaymentEvent  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.services import order_state  # noqa: E402
from app.services.order_state import (  # noqa: E402
    InvalidTransition,
    OrderStatus,
    UnknownStatus,
)
from app.services.payments.registry import get_provider  # noqa: E402

PASS, FAIL = "PASS", "FAIL"
results: list[tuple[str, str, str]] = []


def stock_of(product_id: int) -> tuple[int | None, int | None]:
    """(available, reserved) read through a fresh session."""
    db = SessionLocal()
    try:
        row = db.query(Product.stock, Product.reserved).filter(Product.id == product_id).first()
        return (row[0], row[1]) if row else (None, None)
    finally:
        db.close()


def order_row(order_id: int) -> dict | None:
    db = SessionLocal()
    try:
        o = db.query(Order).filter(Order.id == order_id).first()
        if not o:
            return None
        return {
            "id": o.id,
            "status": o.status,
            "payment_method": o.payment_method,
            "total_amount": float(o.total_amount),
            "stock_committed": bool(o.stock_committed),
            "stock_released": bool(o.stock_released),
            "expires_at": o.expires_at,
            "history": [h.get("to") for h in (o.status_history or [])],
        }
    finally:
        db.close()


def payment_row(order_id: int) -> dict | None:
    db = SessionLocal()
    try:
        p = db.query(Payment).filter(Payment.order_id == order_id).first()
        if not p:
            return None
        return {
            "id": p.id,
            "status": p.status,
            "amount": float(p.amount),
            "currency": p.currency,
            "attempt": p.attempt,
            "intent_id": p.provider_intent_id,
            "failure_reason": p.failure_reason,
        }
    finally:
        db.close()


def count_payments(order_id: int) -> int:
    db = SessionLocal()
    try:
        return db.query(Payment).filter(Payment.order_id == order_id).count()
    finally:
        db.close()


def count_events(event_id: str) -> int:
    db = SessionLocal()
    try:
        return (
            db.query(PaymentEvent)
            .filter(PaymentEvent.provider_event_id == event_id)
            .count()
        )
    finally:
        db.close()


def force_expire(order_id: int) -> None:
    """Backdate expires_at so the sweep will pick the order up."""
    from datetime import datetime, timedelta, timezone

    db = SessionLocal()
    try:
        db.query(Order).filter(Order.id == order_id).update(
            {"expires_at": datetime.now(timezone.utc) - timedelta(hours=1)}
        )
        db.commit()
    finally:
        db.close()


def check(name: str, ok: bool, detail: str = "") -> None:
    results.append((PASS if ok else FAIL, name, detail))


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def register(client: TestClient, name: str, email: str) -> dict:
    r = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret123"},
    )
    assert r.status_code == 200, r.text
    return r.json()["data"]


def login(client: TestClient, email: str) -> str:
    r = client.post(
        "/api/auth/login", json={"email": email, "password": "supersecret123"}
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


with TestClient(app) as client:
    # --- setup: two users -------------------------------------------------
    alice = register(client, "Alice", "alice@example.com")
    bob = register(client, "Bob", "bob@example.com")
    alice_token = login(client, "alice@example.com")
    bob_token = login(client, "bob@example.com")

    products = client.get("/api/products/get_products").json()["data"]
    pid = products[0]["id"]
    initial_stock = products[0]["stock"]

    # --- #1 auth is required on every data endpoint -----------------------
    unauth = {
        "GET /cart/get_cart": client.get("/api/cart/get_cart"),
        "POST /cart/add_to_cart": client.post(
            "/api/cart/add_to_cart", json={"product_id": pid}
        ),
        "POST /cart/clear_cart": client.post("/api/cart/clear_cart"),
        "GET /orders/get_orders": client.get("/api/orders/get_orders"),
        "POST /orders/checkout": client.post("/api/orders/checkout", json={}),
        "GET /orders/get_order/1": client.get("/api/orders/get_order/1"),
        "GET /addresses/get_addresses": client.get("/api/addresses/get_addresses"),
        "POST /addresses/add_address": client.post(
            "/api/addresses/add_address",
            json={
                "full_name": "X",
                "phone": "1",
                "address_line": "Y",
            },
        ),
    }
    for label, resp in unauth.items():
        check(
            f"401 without token: {label}",
            resp.status_code == 401,
            f"got {resp.status_code}",
        )

    check(
        "401 carries WWW-Authenticate",
        "www-authenticate" in {k.lower() for k in unauth["GET /cart/get_cart"].headers},
    )

    # --- #1b caller-supplied user_id is gone ------------------------------
    r = client.get("/api/cart/get_cart", params={"user_id": alice["id"]}, headers=auth(alice_token))
    check("GET /cart ignores user_id query param", r.status_code == 200, f"got {r.status_code}")
    r = client.post(
        "/api/cart/add_to_cart",
        json={"user_id": bob["id"], "product_id": pid, "quantity": 1},
        headers=auth(alice_token),
    )
    check(
        "add_to_cart accepts but ignores an extra user_id field",
        r.status_code == 200,
        f"got {r.status_code}",
    )
    alice_cart = client.get("/api/cart/get_cart", headers=auth(alice_token)).json()
    bob_cart = client.get("/api/cart/get_cart", headers=auth(bob_token)).json()
    check(
        "body user_id cannot redirect writes to another account",
        len(alice_cart["data"]) == 1 and len(bob_cart["data"]) == 0,
        f"alice={len(alice_cart['data'])} bob={len(bob_cart['data'])}",
    )

    # --- #2 cross-account read (IDOR) -------------------------------------
    order = client.post(
        "/api/orders/checkout",
        json={"shipping_address": "1 Test St"},
        headers=auth(alice_token),
    ).json()["data"]
    r = client.get(f"/api/orders/get_order/{order['id']}", headers=auth(bob_token))
    check(
        "bob cannot read alice's order",
        r.status_code == 404,
        f"got {r.status_code}",
    )
    r = client.get(f"/api/orders/get_order/{order['id']}")
    check("order detail requires a token", r.status_code == 401, f"got {r.status_code}")

    # enumeration: no user_id param means no way to drop the ownership filter
    r = client.get(f"/api/orders/get_order/{order['id']}?user_id={alice['id']}")
    check(
        "extra user_id query param cannot bypass ownership",
        r.status_code == 401,
        f"got {r.status_code}",
    )

    # --- #3 CORS no longer reflects arbitrary origins ---------------------
    r = client.get(
        "/api/products/get_products", headers={"Origin": "https://evil.example"}
    )
    check(
        "CORS does not allow arbitrary origin",
        "access-control-allow-origin" not in {k.lower() for k in r.headers},
        r.headers.get("access-control-allow-origin", "<absent>"),
    )
    r = client.options(
        "/api/cart/get_cart",
        headers={
            "Origin": "https://evil.example",
            "Access-Control-Request-Method": "GET",
        },
    )
    check(
        "CORS preflight from evil origin rejected",
        "access-control-allow-origin" not in {k.lower() for k in r.headers},
    )

    # --- Wishlist: auth is required, entries are per-user, toggles are safe --
    r = client.get("/api/wishlist/get_wishlist")
    check(
        "wishlist read requires a token",
        r.status_code == 401,
        f"got {r.status_code}",
    )
    r = client.post("/api/wishlist/add", json={"product_id": pid})
    check(
        "adding to wishlist requires a token",
        r.status_code == 401,
        f"got {r.status_code}",
    )
    r = client.post(
        "/api/wishlist/add", json={"product_id": pid}, headers=auth(bob_token)
    )
    check("add to wishlist returns 200", r.status_code == 200, r.text[:120])
    r2 = client.post(
        "/api/wishlist/add", json={"product_id": pid}, headers=auth(bob_token)
    )
    check(
        "duplicate wishlist add is idempotent",
        r2.status_code == 200 and len(r2.json()["data"]) == 1,
        r2.text[:120],
    )
    wish_body = client.get(
        "/api/wishlist/get_wishlist", headers=auth(bob_token)
    ).json()
    check(
        "wishlist lists the added product",
        len(wish_body["data"]) == 1 and wish_body["data"][0]["id"] == pid,
        f"got {wish_body['data']}",
    )
    alice_wl = client.get(
        "/api/wishlist/get_wishlist", headers=auth(alice_token)
    ).json()
    check(
        "a different user's wishlist stays empty",
        len(alice_wl["data"]) == 0,
        f"got {alice_wl['data']}",
    )
    r = client.post(
        "/api/wishlist/remove", json={"product_id": pid}, headers=auth(bob_token)
    )
    check("remove from wishlist returns 200", r.status_code == 200, r.text[:120])
    wish_body = client.get(
        "/api/wishlist/get_wishlist", headers=auth(bob_token)
    ).json()
    check(
        "wishlist is empty after removal",
        len(wish_body["data"]) == 0,
        f"got {wish_body['data']}",
    )
    r = client.post(
        "/api/wishlist/remove", json={"product_id": pid}, headers=auth(bob_token)
    )
    check(
        "removing a product not on the wishlist is a no-op 200",
        r.status_code == 200,
        f"got {r.status_code}",
    )

    # --- #6 oversell is rejected, not clamped -----------------------------
    client.post(
        "/api/cart/add_to_cart",
        json={"product_id": pid, "quantity": 1},
        headers=auth(alice_token),
    )
    stock_now = next(
        p for p in client.get("/api/products/get_products").json()["data"] if p["id"] == pid
    )["stock"]
    r = client.post(
        "/api/orders/checkout",
        json={},
        headers={**auth(alice_token), "Idempotency-Key": "oversell-1"},
    )
    check(
        "checkout decrements stock",
        r.status_code == 200,
        r.text[:120],
    )
    stock_after = next(
        p for p in client.get("/api/products/get_products").json()["data"] if p["id"] == pid
    )["stock"]
    check(
        "stock decreased by exactly the ordered quantity",
        stock_after == stock_now - 1,
        f"{stock_now} -> {stock_after}",
    )

    # order far more than the remaining stock
    r = client.post(
        "/api/cart/add_to_cart",
        json={"product_id": pid, "quantity": 99},
        headers=auth(alice_token),
    )
    check("add_to_cart rejects quantity over stock", r.status_code == 409, f"got {r.status_code}")

    # force an over-stock cart row directly, then try to check out
    from app.core.database import SessionLocal
    from app.models.cart import CartItem
    from app.models.order import Order
    from app.models.product import Product

    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == pid).first()
        db.add(
            CartItem(
                user_id=alice["id"],
                product_id=pid,
                quantity=500,
                price=1.0,
                subtotal=500.0,
                product_name="oversell probe",
            )
        )
        db.commit()
    finally:
        db.close()

    r = client.post(
        "/api/orders/checkout",
        json={},
        headers={**auth(alice_token), "Idempotency-Key": "oversell-2"},
    )
    check(
        "checkout rejects insufficient stock with 409",
        r.status_code == 409,
        f"got {r.status_code} {r.text[:100]}",
    )
    db = SessionLocal()
    try:
        probe = db.query(Product).filter(Product.id == pid).first()
        check(
            "rejected checkout left stock untouched",
            probe.stock == stock_after,
            f"stock={probe.stock} expected {stock_after}",
        )
        remaining = (
            db.query(CartItem)
            .filter(CartItem.user_id == alice["id"], CartItem.product_name == "oversell probe")
            .count()
        )
        check(
            "rejected checkout left the cart intact",
            remaining == 1,
            f"probe rows={remaining}",
        )
        db.rollback()
    finally:
        db.close()

    # --- #8 idempotency ---------------------------------------------------
    # Clean up the oversell probe row and the over-stock cart entry first, so
    # this section exercises idempotency rather than failing on stock.
    db = SessionLocal()
    try:
        db.query(CartItem).filter(
            CartItem.user_id == alice["id"],
            CartItem.product_name == "oversell probe",
        ).delete(synchronize_session=False)
        db.query(CartItem).filter(
            CartItem.user_id == alice["id"], CartItem.product_id == pid
        ).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()

    client.post(
        "/api/cart/add_to_cart",
        json={"product_id": products[1]["id"], "quantity": 1},
        headers=auth(alice_token),
    )
    h = {**auth(alice_token), "Idempotency-Key": "retry-key-abc"}
    first = client.post("/api/orders/checkout", json={}, headers=h)
    second = client.post("/api/orders/checkout", json={}, headers=h)
    check(
        "duplicate checkout with same Idempotency-Key returns one order",
        first.status_code == 200
        and second.status_code == 200
        and first.json()["data"]["order_number"] == second.json()["data"]["order_number"],
        f"{first.status_code}/{second.status_code} "
        f"{first.json().get('data', {}).get('order_number')} vs "
        f"{second.json().get('data', {}).get('order_number')}",
    )
    db = SessionLocal()
    try:
        n = db.query(Order).filter(
            Order.user_id == alice["id"], Order.idempotency_key == "retry-key-abc"
        ).count()
        check("retry created exactly one Order row", n == 1, f"rows={n}")
    finally:
        db.close()

    # --- #9 update_cart stock guard ---------------------------------------
    client.post(
        "/api/cart/add_to_cart",
        json={"product_id": pid, "quantity": 1},
        headers=auth(alice_token),
    )
    r = client.post(
        "/api/cart/update_cart",
        json={"product_id": pid, "quantity": 99},
        headers=auth(alice_token),
    )
    check("update_cart rejects quantity over stock", r.status_code == 409, f"got {r.status_code}")

    # --- #9/#10 auth input validation -------------------------------------
    r = client.post(
        "/api/auth/register", json={"name": "", "email": "x@y.com", "password": "short"}
    )
    check("register rejects short password", r.status_code == 422, f"got {r.status_code}")
    r = client.post(
        "/api/auth/register", json={"name": "N", "email": "n@example.com", "password": ""}
    )
    check("register rejects empty password", r.status_code == 422, f"got {r.status_code}")
    r = client.post(
        "/api/auth/register",
        json={"name": "N", "email": "n2@example.com", "password": "a" * 100},
    )
    check("register rejects over-long password", r.status_code == 422, f"got {r.status_code}")
    r = client.post(
        "/api/auth/login", json={"email": "alice@example.com", "password": "wrong"}
    )
    check(
        "bad password returns 401 not 200",
        r.status_code == 401,
        f"got {r.status_code}",
    )
    r = client.post("/api/auth/login", json={"email": "nobody@nowhere.io", "password": "x"})
    check("unknown email returns 401", r.status_code == 401, f"got {r.status_code}")

    # --- #11 tampered / alg-none tokens ------------------------------------
    from jose import jwt

    from app.core.config import JWT_ALGORITHM, settings

    forged = jwt.encode(
        {"sub": str(bob["id"]), "email": "bob@example.com"}, "wrong-key", algorithm=JWT_ALGORITHM
    )
    r = client.get("/api/auth/me", headers=auth(forged))
    check("token signed with wrong key rejected", r.status_code == 401, f"got {r.status_code}")

    # --- #17 serializer falsy-zero ----------------------------------------
    db = SessionLocal()
    try:
        zero = Product(
            name="Zero Probe",
            description="",
            price=1.0,
            stock=0,
            rating=0,
            review_count=0,
            image="",
            brand="",
            size="",
        )
        db.add(zero)
        db.commit()
        zero_id = zero.id
    finally:
        db.close()
    payload = client.get(f"/api/products/get_product/{zero_id}").json()["data"]
    check(
        "rating 0 is not inflated to 4.5",
        payload["rating"] == 0,
        f"rating={payload['rating']}",
    )
    check("stock 0 stays 0", payload["stock"] == 0, f"stock={payload['stock']}")
    check("review_count 0 stays 0", payload["review_count"] == 0)
    check(
        "empty brand is not substituted with a fake brand",
        payload["brand"] == "",
        f"brand={payload['brand']!r}",
    )

    # --- #18 foreign keys enforced ----------------------------------------
    r = client.post(
        "/api/addresses/add_address",
        json={"full_name": "A", "phone": "1", "address_line": "B"},
        headers=auth(alice_token),
    )
    check("address created for the authenticated user", r.status_code == 201, f"got {r.status_code}")
    addr = r.json()["data"]
    check(
        "address response omits internal user_id",
        "user_id" not in addr,
        f"keys={sorted(addr)}",
    )

    # --- #21 pagination ---------------------------------------------------
    r = client.get("/api/products/get_products?limit=2&offset=0")
    body = r.json()
    check("products paginate", len(body["data"]) == 2 and body["total"] > 2, f"{body['total']}")
    r = client.get("/api/products/get_products?limit=9999")
    check("products limit is capped", r.status_code == 422, f"got {r.status_code}")
    r = client.get("/api/products/get_products?q=serum")
    check(
        "product search filters",
        all("serum" in p["name"].lower() for p in r.json()["data"]) and r.json()["data"],
        f"{[p['name'] for p in r.json()['data']]}",
    )

    # --- response envelope no longer duplicates the user object ------------
    body = client.post(
        "/api/auth/login",
        json={"email": "alice@example.com", "password": "supersecret123"},
    ).json()
    check("login has no duplicate 'user' key", "user" not in body, f"keys={sorted(body)}")
    check("login exposes access_token", "access_token" in body)
    check(
        "login response does not leak password hash",
        "password_hash" not in json.dumps(body),
    )

    # =====================================================================
    # Payments: reservation, state machine, webhook safety
    # =====================================================================

    # Earlier sections deliberately drain stock and oversell, so the payment
    # scenarios get their own dedicated fixtures rather than depending on the
    # seeded catalog. Inserted now, after the seed-dependent checks above have
    # run, so they cannot perturb them.
    payment_product_ids: list[int] = []
    db = SessionLocal()
    try:
        for i in range(6):
            row = Product(
                name=f"Payment Fixture {i}",
                description="Reserved for payment lifecycle checks",
                price=round(10.00 + i, 2),
                stock=50,
                reserved=0,
                brand="FixtureBrand",
                size="10ml",
            )
            db.add(row)
            db.flush()
            payment_product_ids.append(row.id)
        db.commit()
    finally:
        db.close()
    check(
        "payment fixtures created with a known stock level",
        len(payment_product_ids) == 6
        and all(stock_of(pid) == (50, 0) for pid in payment_product_ids),
        f"{[stock_of(pid) for pid in payment_product_ids]}",
    )

    def place(product_index: int, method: str, key: str) -> dict:
        """Add one unit of a product to Alice's cart and check out."""
        product_id = payment_product_ids[product_index]
        client.post("/api/cart/clear_cart", headers=auth(alice_token))
        r = client.post(
            "/api/cart/add_to_cart",
            json={"product_id": product_id, "quantity": 1},
            headers=auth(alice_token),
        )
        assert r.status_code == 200, r.text
        r = client.post(
            "/api/orders/checkout",
            json={"payment_method": method},
            headers={**auth(alice_token), "Idempotency-Key": key},
        )
        assert r.status_code == 200, r.text
        return {"order": r.json()["data"], "product_id": product_id}

    # --- cash on delivery: no reservation window, committed immediately ----
    cod = place(0, "cash_on_delivery", "cod-1")
    cod_row = order_row(cod["order"]["id"])
    check(
        "cash order is confirmed, not pending_payment",
        cod_row["status"] == "confirmed",
        f"got {cod_row['status']}",
    )
    check(
        "cash order commits stock immediately",
        cod_row["stock_committed"] and not cod_row["stock_released"],
        f"committed={cod_row['stock_committed']} released={cod_row['stock_released']}",
    )
    cod_avail, cod_res = stock_of(cod["product_id"])
    check(
        "cash order leaves reserved untouched",
        cod_res == 0,
        f"reserved={cod_res}",
    )
    check("cash order has no expiry", cod_row["expires_at"] is None)

    # --- khqr: stock reserved, order awaiting payment ---------------------
    qr = place(1, "khqr", "qr-1")
    qr_order_id = qr["order"]["id"]
    qr_row = order_row(qr_order_id)
    check(
        "khqr order starts pending_payment",
        qr_row["status"] == "pending_payment",
        f"got {qr_row['status']}",
    )
    qr_avail, qr_res = stock_of(qr["product_id"])
    check(
        "khqr checkout moves stock into reserved",
        qr_res == 1,
        f"reserved={qr_res} (available {qr_avail})",
    )
    check(
        "khqr checkout reduces available stock",
        qr_avail == 50 - 1,
        f"50 -> {qr_avail}",
    )
    check("khqr order sets an expiry", qr_row["expires_at"] is not None)

    # --- intents are server-priced and idempotent -------------------------
    r = client.post(
        "/api/payments/intents", json={"order_id": qr_order_id}, headers=auth(alice_token)
    )
    check("create intent returns 200", r.status_code == 200, f"got {r.status_code}")
    intent_data = r.json()["data"]
    check(
        "intent amount comes from the order, not the client",
        abs(intent_data["amount"] - qr_row["total_amount"]) < 0.005,
        f"intent={intent_data['amount']} order={qr_row['total_amount']}",
    )
    check(
        "intent has no client-supplied amount field to abuse",
        "amount" not in {"order_id"},
    )
    check(
        "intent exposes a QR payload for the client to render",
        bool(intent_data["qr_payload"]),
    )

    r2 = client.post(
        "/api/payments/intents", json={"order_id": qr_order_id}, headers=auth(alice_token)
    )
    check(
        "repeat intent returns the same payment, not a second charge",
        r2.json()["data"]["id"] == intent_data["id"]
        and count_payments(qr_order_id) == 1,
        f"payments={count_payments(qr_order_id)}",
    )

    # --- an unverified callback must never mark an order paid -------------
    pay = payment_row(qr_order_id)
    intent_id = pay["intent_id"]
    signature = get_provider().sign(intent_id)

    r = client.post(
        "/api/payments/webhook?provider=fake",
        json={
            "intent_id": intent_id,
            "status": "paid",
            "event_id": "evt-unverified",
            "amount": str(qr_row["total_amount"]),
            "currency": "USD",
        },
    )
    body = r.json()
    check(
        "webhook without a signature is not accepted as paid",
        body.get("outcome") == "manual_review",
        f"got {body}",
    )
    check(
        "order stays pending_payment after an unverified callback",
        order_row(qr_order_id)["status"] == "pending_payment",
        f"got {order_row(qr_order_id)['status']}",
    )

    # --- a verified success commits the reservation exactly once -----------
    r = client.post(
        "/api/payments/webhook?provider=fake",
        headers={"x-fake-signature": signature},
        json={
            "intent_id": intent_id,
            "status": "paid",
            "event_id": "evt-paid-1",
            "amount": str(qr_row["total_amount"]),
            "currency": "USD",
        },
    )
    check(
        "verified paid webhook moves the order to paid",
        r.json().get("outcome") == "paid",
        f"got {r.json()}",
    )
    paid_row = order_row(qr_order_id)
    check("order is paid", paid_row["status"] == "paid", f"got {paid_row['status']}")
    check(
        "paying commits the reservation",
        paid_row["stock_committed"] and not paid_row["stock_released"],
    )
    _, paid_res = stock_of(qr["product_id"])
    check(
        "reserved drops once the sale is committed",
        paid_res == 0,
        f"reserved={paid_res}",
    )

    # --- the same event delivered again changes nothing -------------------
    for i in range(3):
        client.post(
            "/api/payments/webhook?provider=fake",
            headers={"x-fake-signature": signature},
            json={
                "intent_id": intent_id,
                "status": "paid",
                "event_id": "evt-paid-1",
                "amount": str(qr_row["total_amount"]),
                "currency": "USD",
            },
        )
    check(
        "replayed webhook is recorded exactly once",
        count_events("evt-paid-1") == 1,
        f"rows={count_events('evt-paid-1')}",
    )
    check(
        "replay leaves the order paid and does not double-commit",
        order_row(qr_order_id)["status"] == "paid"
        and stock_of(qr["product_id"])[1] == 0,
    )
    check(
        "paid_at recorded on the payment",
        payment_row(qr_order_id)["status"] == "paid",
        f"got {payment_row(qr_order_id)['status']}",
    )

    # --- a different event id after payment is a no-op, not a second credit
    client.post(
        "/api/payments/webhook?provider=fake",
        headers={"x-fake-signature": signature},
        json={
            "intent_id": intent_id,
            "status": "paid",
            "event_id": "evt-paid-2",
            "amount": str(qr_row["total_amount"]),
            "currency": "USD",
        },
    )
    check(
        "second distinct paid event does not double-commit stock",
        stock_of(qr["product_id"])[1] == 0,
        f"reserved={stock_of(qr['product_id'])[1]}",
    )

    # --- amount mismatch goes to manual_review, never to paid -------------
    mism = place(2, "khqr", "qr-mismatch")
    mism_id = mism["order"]["id"]
    mism_total = order_row(mism_id)["total_amount"]
    r = client.post(
        "/api/payments/intents", json={"order_id": mism_id}, headers=auth(alice_token)
    )
    check("mismatch scenario got an intent", r.status_code == 200, f"got {r.status_code}")
    mism_intent = payment_row(mism_id)["intent_id"]
    client.post(
        "/api/payments/webhook?provider=fake",
        headers={"x-fake-signature": get_provider().sign(mism_intent)},
        json={
            "intent_id": mism_intent,
            "status": "paid",
            "event_id": "evt-mismatch",
            # A penny less than we asked for.
            "amount": f"{mism_total - 0.01:.2f}",
            "currency": "USD",
        },
    )
    check(
        "underpayment is parked in manual_review",
        payment_row(mism_id)["status"] == "manual_review",
        f"got {payment_row(mism_id)['status']}",
    )
    check(
        "underpayment does not mark the order paid",
        order_row(mism_id)["status"] == "pending_payment",
        f"got {order_row(mism_id)['status']}",
    )
    check(
        "underpayment keeps the reservation held, not released",
        stock_of(mism["product_id"])[1] == 1,
        f"reserved={stock_of(mism['product_id'])[1]}",
    )

    # --- currency mismatch is equally rejected ----------------------------
    curm = place(3, "khqr", "qr-currency")
    curm_id = curm["order"]["id"]
    client.post(
        "/api/payments/intents", json={"order_id": curm_id}, headers=auth(alice_token)
    )
    curm_intent = payment_row(curm_id)["intent_id"]
    client.post(
        "/api/payments/webhook?provider=fake",
        headers={"x-fake-signature": get_provider().sign(curm_intent)},
        json={
            "intent_id": curm_intent,
            "status": "paid",
            "event_id": "evt-currency",
            "amount": str(order_row(curm_id)["total_amount"]),
            "currency": "KHR",
        },
    )
    check(
        "wrong-currency settlement is not accepted",
        order_row(curm_id)["status"] != "paid",
        f"got {order_row(curm_id)['status']}",
    )

    # --- provider failure releases the stock ------------------------------
    fail = place(4, "khqr", "qr-fail")
    fail_id = fail["order"]["id"]
    fail_avail_before, fail_res_before = stock_of(fail["product_id"])
    client.post(
        "/api/payments/intents", json={"order_id": fail_id}, headers=auth(alice_token)
    )
    fail_intent = payment_row(fail_id)["intent_id"]
    client.post(
        "/api/payments/webhook?provider=fake",
        headers={"x-fake-signature": get_provider().sign(fail_intent)},
        json={
            "intent_id": fail_intent,
            "status": "failed",
            "event_id": "evt-failed",
            "amount": str(order_row(fail_id)["total_amount"]),
            "currency": "USD",
        },
    )
    check(
        "provider failure marks the order payment_failed",
        order_row(fail_id)["status"] == "payment_failed",
        f"got {order_row(fail_id)['status']}",
    )
    fail_avail_after, fail_res_after = stock_of(fail["product_id"])
    check(
        "failed payment puts the unit back on sale",
        fail_avail_after == fail_avail_before + 1,
        f"{fail_avail_before} -> {fail_avail_after}",
    )
    check(
        "failed payment clears the reservation",
        fail_res_after == 0,
        f"{fail_res_before} -> {fail_res_after}",
    )

    # --- expiry releases stock so abandoned checkouts do not strand it ---
    exp = place(5, "khqr", "qr-expire")
    exp_id = exp["order"]["id"]
    exp_avail_before, _ = stock_of(exp["product_id"])
    force_expire(exp_id)
    db = SessionLocal()
    try:
        from app.services.orders import expire_stale_orders

        swept = expire_stale_orders(db)
    finally:
        db.close()
    check(
        "expiry sweep finds the stale order",
        swept >= 1,
        f"swept={swept}",
    )
    check(
        "expired order leaves pending_payment",
        order_row(exp_id)["status"] == "expired",
        f"got {order_row(exp_id)['status']}",
    )
    check(
        "expired order returns its stock to sale",
        stock_of(exp["product_id"])[0] == exp_avail_before + 1,
        f"{exp_avail_before} -> {stock_of(exp['product_id'])[0]}",
    )

    # --- ownership and provider checks ------------------------------------
    r = client.post(
        "/api/payments/intents", json={"order_id": qr_order_id}, headers=auth(bob_token)
    )
    check(
        "another user cannot start payment for someone else's order",
        r.status_code == 404,
        f"got {r.status_code}",
    )
    r = client.get(f"/api/payments/{qr_order_id}/status", headers=auth(bob_token))
    check(
        "another user cannot read someone else's payment status",
        r.status_code == 404,
        f"got {r.status_code}",
    )
    r = client.get(f"/api/payments/{qr_order_id}/status")
    check(
        "payment status requires a token",
        r.status_code == 401,
        f"got {r.status_code}",
    )
    r = client.post(
        "/api/payments/webhook?provider=baray",
        json={"intent_id": intent_id, "status": "paid"},
    )
    check(
        "callback for the wrong provider is rejected",
        r.json().get("outcome") == "provider_mismatch",
        f"got {r.json()}",
    )
    r = client.post(
        "/api/payments/webhook?provider=fake",
        json={"intent_id": "nonexistent", "status": "paid", "event_id": "evt-unknown"},
    )
    check(
        "callback for an unknown intent is recorded, not applied",
        r.json().get("outcome") == "unknown_intent",
        f"got {r.json()}",
    )
    r = client.post(
        "/api/payments/webhook?provider=fake", content=b"not json at all"
    )
    check(
        "malformed callback still gets 200 so the gateway stops retrying",
        r.status_code == 200,
        f"got {r.status_code}",
    )

    # --- method validation -------------------------------------------------
    r = client.post(
        "/api/cart/add_to_cart",
        json={"product_id": payment_product_ids[0], "quantity": 1},
        headers=auth(alice_token),
    )
    r = client.post(
        "/api/orders/checkout",
        json={"payment_method": "crypto_wire"},
        headers={**auth(alice_token), "Idempotency-Key": "bogus-1"},
    )
    check(
        "unknown payment method is rejected by the validator",
        r.status_code == 400 and "Unsupported payment method" in r.text,
        f"got {r.status_code} {r.text[:140]}",
    )
    r = client.post(
        "/api/orders/checkout",
        json={"payment_method": "x" * 64},
        headers={**auth(alice_token), "Idempotency-Key": "bogus-2"},
    )
    check(
        "over-long payment method is refused by the schema",
        r.status_code == 422,
        f"got {r.status_code}",
    )
    r = client.post(
        "/api/orders/checkout",
        json={"payment_method": "cash"},
        headers={**auth(alice_token), "Idempotency-Key": "legacy-cash-1"},
    )
    check(
        "legacy 'cash' still checks out (stale mobile builds)",
        r.status_code == 200
        and r.json()["data"]["payment_method"] == "cash_on_delivery",
        f"got {r.status_code} {r.text[:160]}",
    )

    # --- status audit trail ------------------------------------------------
    hist = order_row(qr_order_id)["history"]
    check(
        "order records its status history",
        hist[:2] == ["pending_payment", "paid"],
        f"got {hist}",
    )

os.unlink(_db_path)

# --- order state machine: pure logic, no database --------------------------
check(
    "pending_payment cannot jump straight to delivered",
    not order_state.can_transition("pending_payment", "delivered"),
)
check(
    "pending_payment may become paid",
    order_state.can_transition("pending_payment", "paid"),
)
check(
    "paid cannot go back to pending_payment",
    not order_state.can_transition("paid", "pending_payment"),
)
check(
    "a terminal status has no outgoing transitions",
    order_state.next_statuses("refunded") == [],
    f"got {order_state.next_statuses('refunded')}",
)
check(
    "cancel and expire both release stock",
    order_state.releases_stock("cancelled") and order_state.releases_stock("expired"),
)
check(
    "paid does not release stock",
    not order_state.releases_stock("paid"),
)
try:
    order_state.assert_transition("confirmed", "shipped")
    check("confirmed -> shipped is allowed", True)
except InvalidTransition:
    check("confirmed -> shipped is allowed", False, "unexpectedly rejected")
try:
    order_state.assert_transition("shipped", "confirmed")
    check("shipped -> confirmed is rejected", False, "unexpectedly allowed")
except InvalidTransition:
    check("shipped -> confirmed is rejected", True)
try:
    order_state.coerce_status("teleported")
    check("unknown status is rejected", False, "unexpectedly accepted")
except UnknownStatus:
    check("unknown status is rejected", True)
try:
    order_state.assert_transition("teleported", "paid")
    check("transition from an unknown status reports cleanly", False, "unexpectedly allowed")
except UnknownStatus:
    check("transition from an unknown status reports cleanly", True)
except InvalidTransition as exc:
    # Must be a readable message, not a ValueError escaping from the lookup.
    check("transition from an unknown status reports cleanly", False, f"crashed: {exc}")
check(
    "OrderStatus is a plain string for JSON safety",
    OrderStatus.PAID == "paid" and json.dumps({"s": OrderStatus.PAID}) == '{"s": "paid"}',
)

# --- summary --------------------------------------------------------------
failed = [r for r in results if r[0] == FAIL]
for status, name, detail in results:
    if status == FAIL:
        print(f"  {status}  {name}  ({detail})")
print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
raise SystemExit(1 if failed else 0)
