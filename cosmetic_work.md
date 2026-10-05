# Cosmetic Project Work Summary

Date: 2026
Project: `M-Commerce/cosmetic` — Flutter (GetX + Dio) client, FastAPI backend

---

## 1. Initial build

### 1.1 Baseline analysis
Original app used `http` + `setState`, no GetX. Reviewed models, services,
screens, configs; established a `flutter analyze` baseline.

### 1.2 FastAPI backend created (`backend/`)

```
backend/app/
  core/     config.py, database.py, deps.py, security.py
  models/   user.py, product.py (Category), cart.py, order.py (Address, OrderItem)
  routers/  auth.py, products.py, categories.py, cart.py, orders.py, addresses.py
  schemas/  __init__.py  (stub)
  serializers.py, main.py
```

### 1.3 Flutter restructured to GetX + Dio

```
lib/
  config/     api_config.dart, app_colors.dart, app_settings.dart
  core/       network/dio_client.dart, routes/app_routes.dart + app_pages.dart
  features/   splash, auth, home, cart, main, profile, wishlist
              (each: controller + binding + view, data/ for API calls)
  models/     product_model.dart, user_model.dart
  widgets/    product_card.dart, cart_item_tile.dart
  main.dart   GetMaterialApp with bindings/routes
```

### 1.4 UI palette applied

Tokens centralised in `lib/config/app_colors.dart`; every previously hardcoded
`Color(0x...)` in the live views replaced.

| Purpose | Token | Hex |
| --- | --- | --- |
| Primary (rose) | `AppColors.primary` | `#C98F9B` |
| Secondary (soft blush) | `AppColors.secondary` | `#F4E4E7` |
| Background (warm ivory) | `AppColors.background` | `#FCF9F7` |
| Surface / card | `AppColors.surface` | `#FFFFFF` |
| Main text (deep brown) | `AppColors.textPrimary` | `#2D2526` |
| Secondary text (warm gray) | `AppColors.textMuted` | `#7D7374` |
| Accent (champagne gold) | `AppColors.accent` | `#C6A15B` |
| Border (soft beige) | `AppColors.border` | `#E8DDDA` |
| Success (sage green) | `AppColors.success` | `#6F8A72` |
| Error (soft red) | `AppColors.error` | `#C65D63` |
| Bottom nav unselected | `AppColors.navUnselected` | `#A69B9C` |

`main.dart` builds a full `ThemeData` from these tokens: app bar, cards, bottom
navigation (selected/unselected icon + label), buttons, inputs, chips.
Category chips: selected `#C98F9B`, unselected `#F4E4E7`. Product card: white
surface, `#2D2526` name, `#C98F9B` price, `#C65D63` discount, `#C98F9B` favorite.

**Known trade-off (accepted deliberately):** `#C98F9B` on white is 2.66:1 and
`#A69B9C` on white is 2.70:1, both below WCAG AA 4.5:1. White text on primary
buttons and unselected bottom-nav labels are therefore low contrast.
`AppColors.primaryPressed` (`#B07683`) and `AppColors.primaryDark`
(`#D8A6B0`) are the accessible alternatives if this is revisited. A darker rose
of the same hue that passes AA is `#8F5A66` (5.49:1 with white).

---

## 2. Security and correctness pass

A code review found the backend was fully exploitable. All findings below are
fixed and covered by `backend/smoke_test.py` (44 checks).

### 2.1 Authentication was entirely absent

`get_current_user` existed in `app/core/deps.py` but was **referenced by zero
routers**. Cart, order and address endpoints took a caller-supplied `user_id`,
so anyone could read or mutate any account's data by changing one integer.
`GET /api/orders/get_order/{id}` made the ownership filter *optional*
(`if user_id:`), so omitting the parameter returned any order by sequential id.

Fixed: every cart/order/address route depends on
`get_current_active_user`; `user_id` was removed from all request bodies and
query parameters. Ownership is now part of the query, never a conditional.
Cross-account access returns `404` (not `403`) so it cannot be used to probe
which order ids exist. Added `require_admin`, a `/api/auth/me` probe, and
address `PUT`/`DELETE` endpoints (previously addresses could be created but
never corrected or removed).

### 2.2 CORS open to any origin

`CORS_ORIGINS` defaulted to a list containing `*` with `allow_credentials=True`,
so `https://evil.example` was reflected as an allowed origin. Verified before
the fix. `parse_cors_origins` also fell back to `["*"]` on an empty value.

Fixed: `*` now raises at startup, an empty list raises, defaults no longer
include it, and `allow_methods`/`allow_headers` are explicit rather than `*`.

### 2.3 Committed default JWT signing key

`secret_key: str = "change-this-secret-key"` shipped in `config.py`, and the
placeholder `CHANGE_THIS_TO_STRONG_SECRET_KEY` was in both `.env.example`
files — so a copy-paste deploy ran on a public key.

Fixed: `secret_key` has no default. Startup refuses to boot if it is missing,
shorter than 32 characters, or matches a known placeholder. Verified all three
guards fire. `ALGORITHM` is no longer configurable — it is pinned to `HS256` in
`config.py` because an operator-supplied value (`none`, or an asymmetric
algorithm paired with a public key) is an algorithm-confusion bypass. Tokens
now carry `iat`, `iss` and `jti`.

### 2.4 Overselling on checkout

`create_order` did `if prod and prod.stock > 0: prod.stock -= qty`. Three
defects: a 500-unit order against 24 units of stock was accepted and clamped
stock to 0; zero-stock products skipped the decrement entirely and still sold;
and read-modify-write had no row lock, so two concurrent checkouts of the last
unit both succeeded.

Fixed: a conditional `UPDATE ... WHERE stock >= quantity` that re-checks at
write time. Zero rows updated → `409`, rollback, cart and stock untouched.
Verified by force-inserting an over-stock cart row and confirming stock and
cart are both unchanged after rejection.

### 2.5 No transaction rollback

`get_db` had `try/finally` with no `except`, so a handler raising after mutating
the session left flushed-but-uncommitted changes on a pooled connection.

Fixed: `except Exception: db.rollback(); raise`. Added SQLite
`PRAGMA foreign_keys=ON` — FKs were declared but unenforced, and an order for
`user_id=999` persisted.

### 2.6 Non-idempotent order creation

Order numbers used `datetime.utcnow()` (deprecated, naive) with a random suffix.
The client times out at 12s and retries, so the same cart produced two orders.

Fixed: a unique `(user_id, idempotency_key)` constraint plus an `Idempotency-Key`
header. Verified a replayed key returns the original order and creates exactly
one row.

### 2.7 Login and password handling

Login returned `200` with `{"status": false}` on bad credentials, which defeats
status-code-based monitoring and any rate limiter. `RegisterRequest` had no
length validation, so `{"name": "", "password": ""}` created an account.

Fixed: `401` with `WWW-Authenticate`, plus a dummy-hash comparison so response
time does not reveal whether an email exists. Password constrained to 8–72
bytes. `passlib` dropped entirely — the `passlib 1.7.4` + `bcrypt 4.1` pairing
logged an `AttributeError` on *every* hash and verify, and passlib has been
unmaintained since 2020. bcrypt is used directly, with an explicit error
instead of silent 72-byte truncation.

### 2.8 Serializer fabricated data

`float(product.rating or 4.5)` treated a genuine `0` as absent, so every
unrated product displayed a fabricated 4.5-star rating. `brand or "GlowLab"` and
`size or "50ml"` invented product data. `created_at` was serialised without a
timezone offset, which SQLite drops. Nested responses echoed `user_id`.

Fixed: explicit `is not None` checks, no fabricated defaults (client
`Product.fromJson` aligned), UTC-aware timestamps, `user_id` removed from
nested payloads.

### 2.9 Other

- Seed data ran inside `GET /get_products` — two concurrent first requests both
  saw `count == 0` and both inserted. Moved to app startup. Ordering now
  tie-breaks on `id` since `created_at` is second-resolution.
- Added pagination, search, category filter and sorting to products; pagination
  to orders; address list ordering.
- `checkout` no longer calls the `create_order` route handler as a plain
  function. Shared logic lives in `app/services/orders.py`.
- `401` responses now include `WWW-Authenticate: Bearer`.
- Added `/health`, Docker `HEALTHCHECK`, non-root `USER`, `.dockerignore`,
  `backend/.gitignore`, and `run.py` no longer forces `reload=True`.
- `test_api.py` could never run: `TestClient` was constructed at import time so
  the lifespan never fired and every request failed with `no such table`.
  Replaced by `smoke_test.py`.

---

## 3. Flutter client pass

### 3.1 The access token was discarded

`AuthService.login` received `access_token` from the server and threw it away,
storing only `id`/`name`/`email`/`role` in SharedPreferences. No
`Authorization` header was ever sent, so the backend's entire auth layer was
unused even after it was written.

Fixed: token persisted in `flutter_secure_storage` (Keychain /
EncryptedSharedPreferences) via a new `SessionStore`, and a Dio
`InterceptorsWrapper` attaches `Authorization: Bearer <token>` to every request
except `/auth/login`, `/auth/register` and preflight `OPTIONS`. The token is
primed before `runApp` so the first frame's requests are authenticated.
`PrettyDioLogger` no longer logs request headers and is now `kDebugMode`-only.

### 3.2 Dead architecture removed

Two parallel trees existed. `lib/screens/` (9 files) and `lib/services/`
(4 files) were reachable only from each other and called `.php` endpoints
(`get_cart.php`, `add_to_cart.php`, `login.php`) that the FastAPI backend never
had — every call 404'd. All deleted. The one piece of live logic they held (the
cart badge notifiers and offline mirror) moved to
`lib/features/cart/data/cart_cache.dart`, which has no network dependency.
`package:http` dropped.

### 3.3 Other client bugs

- `logout()` called `SharedPreferences.clear()`, leaving the access token valid
  in the keychain for its full 30-minute expiry.
- `CartCache.resolve` preferred whichever side held more items, so a stale local
  cache could resurrect an emptied cart after a successful checkout. Local state
  is now cleared unconditionally on success.
- `Product.fromJson` did `int.parse(json['id'].toString())` unguarded, so any
  missing field crashed instead of degrading.
- `SessionStore.clear()` could throw on the SharedPreferences call *after* the
  token was already discarded, leaving logout half-done. Each step is guarded.
- `CartController` now surfaces `401` (re-login) and `409` (business rule, e.g.
  insufficient stock) as distinct messages instead of a generic failure.

---

## 4. Current state

| Check | Result |
| --- | --- |
| `flutter analyze` | 1 pre-existing info |
| `flutter test` | 12/12 pass |
| `backend/smoke_test.py` | **100/100** pass (was 44) |
| `alembic check` | no drift between models and migrations |
| `alembic upgrade head` | verified on fresh DB, on a legacy DB with real rows, and on downgrade/re-upgrade |

---

## 5. Payment foundation (built)

The first three phases of the §7 roadmap are done. Card checkout is still
**off** — `PAYMENT_PROVIDER=none` and no gateway is wired — but the parts that
are provider-agnostic are in place and tested.

### 5.1 Stock reservation (the blocker from §6.1)

`products.stock` is now stock *available to new orders*; `products.reserved` is
units held by unpaid orders.

| Event | `stock` | `reserved` |
| --- | --- | --- |
| khqr / bank_card / bank_transfer checkout | −q | +q |
| verified webhook → `paid` | — | −q |
| webhook failure / expiry / cancel | +q | −q |
| cash on delivery checkout | −q | — (committed immediately) |

Decrement and reservation share one conditional
`UPDATE ... WHERE stock >= quantity`, so the oversell fix from §2.4 is preserved.
Release is guarded by `orders.stock_released`, so a replayed transition cannot
inflate stock. `orders.stock_committed` stops an already-sold order being
auto-restocked by a late chargeback notice — restocking is a decision, not a
side effect of a status write.

`expire_stale_orders()` releases reservations past `orders.expires_at`. It runs
at startup and needs a periodic schedule in production; without it, every
abandoned KHQR checkout strands its units.

### 5.2 Order state machine

`app/services/order_state.py` declares the legal transitions once:

```
pending_payment -> paid -> confirmed -> shipped -> delivered
pending_payment -> payment_failed | expired | cancelled
```

Anything else raises `InvalidTransition`. Re-applying the current status is a
no-op, because providers resend `paid` aggressively. Every accepted transition is
appended to `orders.status_history` with actor, reason and timestamp.

`status` also carries a `CHECK` constraint, so a stray `UPDATE` cannot write a
status the rest of the system cannot interpret.

### 5.3 Money

`Float` → `Numeric(12,2)` across `products.price`, `cart_items.price/subtotal`,
`orders.total_amount`, `order_items.price/subtotal`, `payments.amount`.
Serializers already coerced with `float()`, so the JSON contract and the Flutter
client are unaffected.

### 5.4 Payments

`payments` (1:1 with an order) and `payment_events` (immutable log). Three
properties, each covered by tests:

1. **The amount is server-side.** `CreateIntentRequestBody` has no amount field;
   the total comes from `Order.total_amount`.
2. **Webhooks are idempotent.** Every delivery is written to `payment_events`
   first, under a unique constraint on `(provider, provider_event_id)`.
3. **An order only reaches `paid` on verified, matching evidence.** Unsigned or
   amount/currency-mismatched callbacks go to `manual_review` — visible to
   reconciliation, never auto-approved.

The webhook always answers `200`; failures are recorded on the event row.
Returning 4xx/5xx for a permanently-invalid payload invites a retry storm.

Endpoints: `POST /api/payments/intents`, `GET /api/payments/{order_id}/status`,
`POST /api/payments/webhook?provider=<name>`.

### 5.5 Migrations

Alembic with `render_as_batch` (SQLite cannot `ALTER COLUMN`). Two revisions:
`0001_baseline` captures the pre-payment schema so a database created by the old
`create_all()` can be stamped and brought forward; `0002_payment_foundation`
rewrites legacy `pending`→`confirmed` and `cash`/`card`→`cash_on_delivery`
*before* adding the `CHECK` constraints, so existing rows survive.

`alembic check` reports no drift. This closes item 1 of the old §4 list.

### 5.6 Sandbox provider

`PAYMENT_PROVIDER=fake` is an in-process gateway used by the test suite. It
issues a per-intent secret, so "an unverified payload must not mark an order
paid" is genuinely exercised rather than assumed.

### 5.7 Breaking changes

- `payment_method` is now constrained to `cash_on_delivery | khqr | bank_card |
  bank_transfer`. The legacy `cash` and `card` are accepted and normalised so an
  already-installed build does not start failing at checkout after a deploy.
- Order `status` values changed (`pending` → `pending_payment`/`confirmed`).
  The Flutter client does not branch on this yet.
- Flutter `checkout()` default changed to `cash_on_delivery`.

### 5.8 Test evidence

The 100 checks were mutation-tested to confirm they have teeth:

| Mutation | Result |
| --- | --- |
| Accept unsigned callbacks | 2 failures |
| Skip amount/currency comparison | 4 failures |
| Stop reserving stock | crashes on `ck_products_reserved_non_negative` |
| Remove webhook dedup (both layers) | crashes on `uq_payment_events_provider_event` |

The last two surface as crashes rather than clean failures, because the schema
constraints are the hard backstop underneath the application checks. That is the
intended layering, but it means a regression in reservation or dedup aborts the
suite instead of reporting a named failure.

Two bugs were found and fixed while writing the tests: `coerce_status` reused
`InvalidTransition`, whose constructor re-parsed the bad value and raised a
`ValueError` from inside the error handler; and COD commit read `order.items`,
which is empty in memory during checkout, so it silently updated zero products.

---

## 6. Known outstanding

1. **No payment provider.** `baray`, `payway` and `bakong` are recognised by
   config and rejected by `build_provider()` with a clear message. Each needs
   merchant credentials and a sandbox account.
2. **SQLite.** Still single-writer. Conditional updates and the reservation
   split need real row locking, which means PostgreSQL before real payments.
   The `batch_alter_table` migrations run on both.
3. **No refresh tokens.** 30-minute access token, no `jti` revocation, so a
   leaked token cannot be invalidated.
4. **No rate limiting** on `/login` or on intent creation.
5. **Expiry sweep not scheduled.** Runs at startup; needs a periodic job.
6. **No reconciliation job.** `manual_review` payments and webhook gaps are not
   yet surfaced anywhere.
7. **No refunds.** `OrderStatus.REFUNDED` exists in the state machine, but
   refunds are not a flow — there is no `refunds` table and no provider call.
8. **Client has no payment UI.** The profile screen still says
   `payment_methods_coming_soon`; there is no QR display or status polling.

---

## 7. Next steps

1. **Decide the gateway.** Baray first (two endpoints, one integration across
   ABA/ACLEDA/Sathapana/Wing), then ABA PayWay if card acceptance matters.
   Keep cash on delivery. This choice unblocks nothing in §5 — it only starts
   §8.
2. **Move to PostgreSQL** and make `expire_stale_orders` a scheduled job.
3. **Client checkout feature** (`lib/features/checkout/`): payment method
   selection, QR display with an expiry countdown, status polling, deep-link
   return, resumable checkout.
4. **Reconciliation job, refunds, audit logging, alerting.**
5. **Rate limiting, refresh tokens, admin role enforcement.**

---

## 8. Payment integration (reference)

### 8.1 Where payment stood before this work

`orders.payment_method` was free text defaulting to `"cash"`; the Flutter
profile rendered `payment_methods_coming_soon`; there was no intent, no
callback, no reconciliation. Critically, `place_order` decremented stock and
cleared the cart immediately on order creation, regardless of payment — money
would have been taken against orders that could never be paid for.

### 8.2 Provider options (Cambodia)

| Option | Shape | Notes |
| --- | --- | --- |
| **Baray** | Aggregator. `POST /pay` + webhook | Single integration for ABA / ACLEDA / Sathapana / Wing. AES-256-CBC encrypted payload, hosted checkout at `pay.baray.io/{intent_id}`. Smallest API surface — two endpoints. Not a PSP, never holds funds. |
| **ABA PayWay** | Direct bank | KHQR, cards, WeChat, Alipay. Sandbox keys by email; production keys via Merchant Acquisition. Most complete card support locally. |
| **Bakong / KHQR** (NBC) | Direct, scheme-level | Generate EMVCo QR yourself, then poll `check_transaction_by_md5`. Token expires in **90 days** and must be renewed. No webhooks — polling only. |
| **Wing Bank OpenAPI** | Direct | Deep-link to the Wing app or embedded KHQR SDK. Good if Wing is the target segment. |
| **Stripe** | International cards | Likely *not* viable as the primary method: card penetration in Cambodia is low and USD settlement into a local bank account is awkward. Reasonable as a secondary option for diaspora/expat customers. |

Currency: products are priced in USD in the UI. KHQR settles in KHR (minimum
KHR 100). `CURRENCY` must match what the provider settles in, or every webhook
lands in `manual_review`. The mismatch test in the suite covers exactly this.

### 8.3 Constraints any provider must satisfy

- `PUBLIC_BASE_URL` must be a deployed HTTPS origin — providers refuse plaintext
  webhooks, so an `http://` value means payments are never confirmed.
- `PAYMENT_WINDOW_MINUTES` must stay below the provider's QR lifetime
  (KHQR caps at 10 minutes) or orders wait on a token that can no longer be paid.
- A KHQR-only merchant account may need CASA registration before a bank account
  can receive settlement. Worth asking the provider during onboarding.
- Never accept a card PAN in this app. Use the gateway's hosted fields; that
  keeps PCI-DSS scope off this codebase entirely.

