# Cosmetic Store API

FastAPI backend for the Cosmetic e-commerce app.

## Features

- JWT authentication; every cart, order and address route requires a bearer token
- Products with pagination, search, category filter and sorting
- Cart CRUD with stock validation
- Idempotent order placement with atomic stock decrement
- Address CRUD with a single default per user
- SQLite by default, seeded with a demo catalog on startup

## Setup

### Local Development

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate  # on Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# SECRET_KEY is required. Generate one:
python -c "import secrets; print(secrets.token_urlsafe(64))"

python run.py
```

API docs: http://localhost:8000/docs

### Docker

```bash
cd backend/deploy
cp .env.example .env
# set SECRET_KEY in .env, then:
docker compose up -d --build
```

## Authentication

`POST /api/auth/login` returns `access_token`. Send it as
`Authorization: Bearer <token>` on every other request. The account id is taken
from the token — there is no `user_id` parameter on any endpoint, so one
account can never read or write another account's cart, orders or addresses.

`POST /api/auth/register` and `POST /api/auth/login` are the only unauthenticated
data routes; `GET /api/products/*` and `GET /api/categories/*` are public.

## Order placement

`POST /api/orders/checkout` and `POST /api/orders/create_order` accept an
optional `Idempotency-Key` header (max 64 chars). Retrying with the same key
returns the original order instead of creating a duplicate, which matters
because the Flutter client times out after 12s and retries.

`payment_method` is constrained to `cash_on_delivery`, `khqr`, `bank_card` or
`bank_transfer`. The legacy values `cash` and `card` are still accepted and
normalised, so an already-installed mobile build does not start failing at
checkout after a server deploy.

### Stock is reserved, not committed

`products.stock` is stock **available to new orders**. `products.reserved` is
units held by orders awaiting payment.

- A `khqr`/`bank_card`/`bank_transfer` checkout moves units from `stock` into
  `reserved` and creates the order in `pending_payment`. The units are only
  spent when a verified webhook moves it to `paid`.
- `cash_on_delivery` never waits on anyone, so it commits immediately and skips
  the reservation.

Returning units to sale is guarded by `orders.stock_released`, so a replayed or
repeated transition cannot inflate stock. Orders still holding a reservation
past `orders.expires_at` are released by `expire_stale_orders()`, which runs at
startup and should run on a schedule.

Decrement and reservation share one conditional `UPDATE ... WHERE stock >=
quantity`, so two concurrent checkouts of the last unit cannot both succeed.
Insufficient stock returns `409` and leaves cart and stock untouched.

## Order status

`orders.status` is constrained to a known set, and legal moves are declared once
in `app/services/order_state.py`:

```
pending_payment -> paid -> confirmed -> shipped -> delivered
pending_payment -> payment_failed | expired | cancelled
```

Anything else raises `InvalidTransition`. Re-applying the current status is a
no-op, because providers resend `paid` aggressively. Every accepted transition is
appended to `orders.status_history`.

## Schema migrations

`create_all()` cannot alter an existing table, so every schema change needs a
revision. Alembic is configured to read the same `DATABASE_URL` as the app, and
`render_as_batch` is enabled because SQLite cannot `ALTER COLUMN` in place.

```bash
alembic upgrade head          # bring a database to current
alembic check                 # assert models and migrations agree
alembic downgrade -1
```

A database created by the old `create_all()` path predates Alembic. Bring it
forward in two steps:

```bash
alembic stamp 0001_baseline
alembic upgrade head
```

`0002_payment_foundation` rewrites legacy `status='pending'` to `confirmed` and
`cash`/`card` to `cash_on_delivery` before adding the `CHECK` constraints, so
existing rows survive the upgrade.

## Payments

Card checkout is **off by default** (`PAYMENT_PROVIDER=none`). With no provider
selected, `POST /api/payments/intents` returns `503` and cash on delivery still
works.

### Endpoints

| Endpoint | Auth | Purpose |
| --- | --- | --- |
| `POST /api/payments/intents` | yes | Create or reuse the provider intent for `order_id`. |
| `GET /api/payments/{order_id}/status` | yes | Poll target for the checkout screen. |
| `POST /api/payments/webhook?provider=<name>` | no | Provider callback. |

### Rules the code enforces

**The amount is server-side.** `CreateIntentRequestBody` has no amount field.
The total comes from `Order.total_amount`, summed from cart snapshots at
checkout. A client that can state its own amount can state a smaller one.

**A webhook is evidence, not a command.** Every delivery is written to
`payment_events` first. The unique constraint on
`(provider, provider_event_id)` is what makes retries idempotent — gateways
resend the same event for days. An order only reaches `paid` when the provider's
own signature or encrypted field verifies **and** the reported amount and
currency match what we asked for.

Anything unverifiable or contradictory goes to `manual_review`: visible to
reconciliation, never auto-approved, never auto-refunded.

The webhook always answers `200`. Returning 4xx/5xx for a permanently-invalid
payload invites an unbounded retry storm; failures are recorded on the event row
instead.

### Adding a gateway

Implement `PaymentProvider` in `app/services/payments/<name>.py` (see
`base.py`), then register it in `build_provider()` and add its credentials to
`_PROVIDER_SECRET_FIELDS` in `app/core/config.py`. Selecting a provider without
its credentials fails at startup rather than at the first checkout.

`PAYMENT_PROVIDER=fake` is an in-process sandbox used by the test suite. It
issues a per-intent secret so the "unverified payload must not mark an order
paid" rule is genuinely exercised.

`PUBLIC_BASE_URL` must be the deployed HTTPS origin in production: the provider
posts webhooks there, and a plaintext URL means payments are never confirmed.

## Environment Variables

| Variable | Required | Notes |
| --- | --- | --- |
| `SECRET_KEY` | yes | Min 32 chars. Startup fails if missing, short, or a known placeholder. |
| `DATABASE_URL` | no | Defaults to `sqlite:///./cosmetic_store.db`. |
| `CORS_ORIGINS` | no | Comma-separated allowlist. `*` is rejected at startup. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | no | Defaults to 30. |
| `CURRENCY` | no | ISO 4217. Must match what the provider settles in. |
| `PAYMENT_PROVIDER` | no | `none` (default), `fake`, `baray`, `payway`, `bakong`. |
| `PAYMENT_WINDOW_MINUTES` | no | Defaults to 15. Must stay under the provider's QR lifetime. |
| `PUBLIC_BASE_URL` | in prod | HTTPS origin the provider posts webhooks to. |

`ALGORITHM` is not configurable. The JWT algorithm is pinned to HS256 in
`app/core/config.py` because an operator-supplied value (`none`, or an
asymmetric algorithm paired with a public key) is an algorithm-confusion bypass.

## Tests

`test_api.py` instantiated `TestClient` at import time, so the lifespan never
ran and every request failed with `no such table: products`. It has been
replaced by:

```bash
python smoke_test.py
```

This runs the app through its lifespan and asserts on 100 behaviours, including
that unauthenticated requests to protected routes return 401, that one user
cannot read another's order or start payment for it, that a wildcard/reflected
CORS origin is refused, that oversized quantities are rejected with 409, that a
replayed `Idempotency-Key` does not create a second order, that short passwords
are refused, and that a forged or wrong-key token is rejected.

The payment section additionally verifies that a khqr checkout moves stock into
`reserved`, that cash on delivery commits without reserving, that an unsigned or
mismatched callback cannot mark an order paid, that a replayed event id is
recorded once, that a failed or expired payment returns stock to sale exactly
once, and that an unknown payment method is refused.

These were mutation-tested: accepting unsigned callbacks, and skipping the
amount/currency comparison, both produce failures. Removing stock reservation or
webhook dedup instead surfaces as a `CHECK`/`UNIQUE` constraint violation, so
the schema is a hard backstop underneath the application checks.
