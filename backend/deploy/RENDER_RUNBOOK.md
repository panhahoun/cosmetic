# Cosmetic Store — Render (Free) Deployment (Neon Postgres)
Goal: same as fashion_app: live API at `https://<app-name>.onrender.com` with Postgres.

## 1. Prereqs
- Git repo pushed to `hpn/main` (cosmetic.git)
- Neon project for cosmetic created (separate from fashion)
- Cosmetic DB URL (pooled): postgresql://... (Render/Neon work with the pooled connection)

## 2. Create Render Web Service
Render → New + → Web Service
- Connect repository: `cosmetic`
- Branch: `main`
- Root Directory: `backend`

## 3. Build & Start Command
Render auto-detects Dockerfile. If it shows "Docker" that's fine.
Build: `pip install --no-cache-dir -r requirements.txt` (Docker)
Start: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

## 4. Environment Variables (Render → Environment)
Add:
- APP_NAME=Cosmetic Store API
- APP_VERSION=1.0.0
- DATABASE_URL=<your pooled Neon URL>
- SECRET_KEY=<openssl rand -hex 32>
- ACCESS_TOKEN_EXPIRE_MINUTES=30
- CORS_ORIGINS=http://localhost:8080
- CURRENCY=USD
- PAYMENT_PROVIDER=none
- PAYMENT_WINDOW_MINUTES=15
- PUBLIC_BASE_URL=

Notes:
- `postgresql://`/`postgres://` will be normalized to `postgresql+psycopg://` by the backend
- CORS must not be `*` (cosmetic rejects it). For mobile apps CORS is not the constraint.

## 5. Deploy
Click Deploy. Watch logs: it should create tables + seed on first run.

## 6. Verify
- GET https://<app>.onrender.com/health → {"status":"ok"}
- GET https://<app>.onrender.com/api/products/get_products
- Swagger https://<app>.onrender.com/docs

## 7. Point Flutter client
Update `lib/config/api_config.dart` (commit + push):
```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://<app>.onrender.com/api',
);
```
Then build/run with --dart-define=API_BASE_URL=https://<app>.onrender.com/api
