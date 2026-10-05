# Cosmetic Store — Backend Deployment Note (VPS + Domain)

> **The domain is settled:** `<DOMAIN>` in this document = `hpn.world`, and the
> API host is **`cosmetic.api.hpn.world`**, so the app talks to
> **`https://cosmetic.api.hpn.world/api`**.
> SSH alias for the VPS is **`panha`** (same host as `nextgen`).
>
> This page is the general walkthrough. For the concrete, copy-paste version with
> today's values filled in, use **`backend/deploy/RUNBOOK.md`** + `deploy.sh`.
> **Status:** API target is `https://cosmetic.api.hpn.world`. The backend lives in
> `backend/` (FastAPI + SQLAlchemy + Alembic). The Flutter web build will be
> served from `/var/www/cosmetic-web/` via Nginx.

Step-by-step to put the cosmetic store API live on your Contabo VPS behind
HTTPS, following the same pattern as the NextGen/Fashion setup (`contabo_vps_lesson.md`).

> **Read this first:** replace `<DOMAIN>` everywhere with `hpn.world` (already done
> below). The concrete commands use `cosmetic.api.hpn.world`.

**Marked `Mac` = run on your computer. `server` = run inside `ssh panha`.**

---

## 0. The plan (and the one big gotcha)

```
Flutter web ──HTTPS──> https://cosmetic.api.hpn.world
                          │  nginx (443, certbot cert)
                          ▼
                   127.0.0.1:8002   ← cosmetic-api (Docker container)
                   127.0.0.1:8001   ← fashion-api (already there)
                   127.0.0.1:8000   ← NextGen API (already there — DO NOT touch)
```

- Same server, same nginx+certbot, same Docker — same pattern you already know.
- **Ports are taken**: NextGen `8000`, Fashion `8001`. The cosmetic API binds
  **8002** (`127.0.0.1:8002:8000` in compose). Do not change to an existing port.
- SQLite database is persisted in `~/cosmetic-api/deploy/data/` (a mounted
  folder, not a file — file mounts become directories in Docker).

---

## 1. Prereqs — verify everything is already there (Mac)

```bash
ssh panha                          # you can log in
ssh panha "docker --version"       # Docker installed
ssh panha "systemctl is-active nginx"   # should print: active
ssh panha "ss -tlnp | grep -E ':(8000|8001|8002)\b'"   # confirm ports in use
ssh panha "sudo ufw status"        # should list 26078/tcp, 80/tcp, 443/tcp
```

All good → continue.

---

## 2. DNS: point a subdomain at your server (Mac → Namecheap)

Already configured as requested:

| Type | Host          | Value           |
|------|---------------|-----------------|
| A    | `cosmetic.api` | `169.58.139.98` |

Verify from your Mac:

```bash
dig +short cosmetic.api.hpn.world     # must print 169.58.139.98
```

If it prints that IP, DNS is live.

---

## 3. Deploy files (prepare for the copy-paste runbook)

These files will live under `backend/deploy/` and mirror the Fashion setup:

| File | What it does |
|---|---|
| `backend/Dockerfile` | `python:3.12-slim` + `requirements.txt` + `app/`, runs uvicorn on 8000 |
| `backend/.dockerignore` | keeps `.env`, `.venv`, dev db, tests out of the image |
| `backend/deploy/docker-compose.yml` | builds + runs the API, `127.0.0.1:8002:8000`, mounts `./data` for SQLite, project `cosmetic` |
| `backend/deploy/.env.example` | template for the production `.env` (put on the server) |
| `backend/deploy/RUNBOOK.md` | concrete, copy-pasteable commands for this deployment |
| `backend/deploy/deploy.sh` | rsync + build/recreate + verify script |

---

## 4. Sync the backend to the server (Mac)

```bash
cd /Users/lyznhara/Desktop/pj/mobile_application2/M-Commerce/cosmetic
rsync -avz \
  --exclude='.git' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='.venv' \
  --exclude='.env' \
  --exclude='*.db' \
  --exclude='deploy/.env' \
  --exclude='deploy/data/' \
  backend/ panha:~/cosmetic-api/
```

- `.env` and SQLite DB are excluded on purpose — the server owns secrets/data.
- `deploy/` is synced (minus its `.env` and `data/`).

---

## 5. Write the production `.env` (server)

```bash
ssh panha
cd ~/cosmetic-api/deploy
cp .env.example .env
nano .env
```

Set at minimum (values match the backend config you have):

```env
APP_NAME="Cosmetic Store API"
APP_VERSION=1.0.0
DEBUG=false

# SQLite — absolute path inside container
DATABASE_URL=sqlite:////app/data/cosmetic_store.db

# Generate with: openssl rand -hex 32
SECRET_KEY=<run: openssl rand -hex 32>

ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS: for Flutter web served at this domain, it's fine to keep '*' or restrict
CORS_ORIGINS=*

# Payments
CURRENCY=USD
PAYMENT_PROVIDER=none
PAYMENT_WINDOW_MINUTES=15

# Public HTTPS origin (webhooks require HTTPS)
PUBLIC_BASE_URL=https://cosmetic.api.hpn.world
```

Generate `SECRET_KEY`:

```bash
openssl rand -hex 32
```

Create data dir:

```bash
mkdir -p ~/cosmetic-api/deploy/data
```

---

## 6. Build + start the API (server)

```bash
cd ~/cosmetic-api/deploy
docker compose up -d --build
```

Check logs and health:

```bash
docker logs --tail 60 cosmetic-api
curl -s http://127.0.0.1:8002/health
curl -s "http://127.0.0.1:8002/api/products/get_products?limit=1"
```

Expect `{"status":"ok"}` and JSON results. DB is at `~/cosmetic-api/deploy/data/cosmetic_store.db`.

---

## 7. nginx: reverse proxy (server)

Create site:

```bash
sudo nano /etc/nginx/sites-available/cosmetic.api.hpn.world
```

Paste (note port **8002**):

```nginx
server {
    listen 80;
    server_name cosmetic.api.hpn.world;

    location / {
        proxy_pass http://127.0.0.1:8002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable + test + reload:

```bash
sudo ln -s /etc/nginx/sites-available/cosmetic.api.hpn.world /etc/nginx/sites-enabled/
sudo nginx -t                    # must say "syntax is ok"
sudo systemctl reload nginx
```

Test plain HTTP from Mac:

```bash
curl -I http://cosmetic.api.hpn.world/health
```

Should return `200 OK` (proxied through nginx to port 8002).

---

## 8. HTTPS with Certbot (server)

```bash
sudo certbot --nginx -d cosmetic.api.hpn.world
```

Choose to redirect HTTP to HTTPS when prompted. Verify:

```bash
curl -I https://cosmetic.api.hpn.world/health
curl https://cosmetic.api.hpn.world/health
curl https://cosmetic.api.hpn.world/docs
```

Also confirm the cert chain:

```bash
echo | openssl s_client -connect cosmetic.api.hpn.world:443 2>/dev/null \
  | grep -E "^ *[0-9] s:|^ *i:"
```

---

## 9. Deploy Flutter Web

### 9.1 Point Flutter to Production API (Mac)

`lib/config/api_config.dart` is already correct:

```dart
static const String baseUrl = kDebugMode
    ? 'http://10.0.2.2:8000/api'
    : 'https://cosmetic.api.hpn.world/api';
```

### 9.2 Build Flutter Web (Mac)

```bash
cd /Users/lyznhara/Desktop/pj/mobile_application2/M-Commerce/cosmetic
flutter build web --release
```

### 9.3 Upload Build to VPS (Mac)

```bash
rsync -avz --progress build/web/ panha:/var/www/cosmetic-web/
```

Fix permissions (server):

```bash
ssh panha "chown -R www-data:www-data /var/www/cosmetic-web"
```

### 9.4 Serve Flutter Web via Nginx (server)

Update the site block to serve static files for `/` and proxy `/api/` (cleaner separation):

```bash
sudo nano /etc/nginx/sites-available/cosmetic.api.hpn.world
```

Replace with:

```nginx
server {
    listen 80;
    server_name cosmetic.api.hpn.world;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name cosmetic.api.hpn.world;

    # certbot-managed
    ssl_certificate /etc/letsencrypt/live/cosmetic.api.hpn.world/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cosmetic.api.hpn.world/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    client_max_body_size 20M;

    # API routes
    location /api/ {
        proxy_pass http://127.0.0.1:8002/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
    }

    # Flutter Web
    location / {
        root /var/www/cosmetic-web;
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache";
    }
}
```

Test and reload:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

---

## 10. Post-deployment Verification

From Mac:

```bash
# API health
curl https://cosmetic.api.hpn.world/health

# Products
curl "https://cosmetic.api.hpn.world/api/products/get_products?limit=1"

# Services
ssh panha "systemctl is-active nginx"

# Container
ssh panha "docker ps --filter name=cosmetic-api --format '{{.Names}}  {{.Status}}  {{.Ports}}'"

# SSL
ssh panha "sudo certbot certificates"
```

In browser:
- `https://cosmetic.api.hpn.world` – Flutter Web App
- `https://cosmetic.api.hpn.world/docs` – FastAPI Swagger UI

Register/login, cart, checkout with `cash_on_delivery` should work.

---

## 11. Maintenance & Troubleshooting

| Task | Command |
|---|---|
| View API logs (live) | `ssh panha "docker logs --tail 100 -f cosmetic-api"` |
| View Nginx logs | `ssh panha "tail -f /var/log/nginx/access.log /var/log/nginx/error.log"` |
| Restart API | `ssh panha "cd ~/cosmetic-api/deploy && docker compose restart"` |
| Rebuild + restart | `ssh panha "cd ~/cosmetic-api/deploy && docker compose up -d --build"` |
| Apply migrations (new code) | `ssh panha "cd ~/cosmetic-api/deploy && docker compose exec api alembic upgrade head && docker compose restart api"` |
| Rebuild & redeploy web (Mac) | `cd /Users/lyznhara/Desktop/pj/mobile_application2/M-Commerce/cosmetic && flutter build web --release && rsync -avz build/web/ panha:/var/www/cosmetic-web/` |
| SSL auto-renew test | `ssh panha "sudo certbot renew --dry-run"` |

### Notes

- **Payments**: Keep `PAYMENT_PROVIDER=none` until you've selected and sandbox-tested a gateway. Enabling requires `PUBLIC_BASE_URL=https://cosmetic.api.hpn.world` and real credentials.
- **Database**: SQLite is single-writer and fine for MVP/single-instance. Move to PostgreSQL before production payment volume/webhooks.
- **Secrets**: Never commit `.env`. Regenerate `SECRET_KEY` per environment.
- **Port isolation**: Cosmetic runs on `8002`, Fashion `8001`, NextGen `8000` — binding to `127.0.0.1` only means Docker published ports never bypass ufw.
- **Compose project name**: `name: cosmetic` in `docker-compose.yml` prevents the "deploy" directory name from clobbering other stacks (the collision lesson from Fashion/NextGen).

If you hit any issue, share the exact error + logs and I'll walk you through it.