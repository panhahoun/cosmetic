from __future__ import annotations

from functools import lru_cache
from typing import List

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_PLACEHOLDER_SECRETS = {
    "change-this-secret-key",
    "change_this_to_strong_secret_key",
    "secret",
    "changeme",
}

# Gateways this build knows how to talk to. "none" disables card checkout
# entirely rather than half-enabling it.
_KNOWN_PAYMENT_PROVIDERS = frozenset({"none", "baray", "payway", "bakong", "fake"})

# Credentials each provider needs before it may be enabled. Kept next to the
# provider list so adding a gateway means adding one entry here.
_PROVIDER_SECRET_FIELDS: dict[str, tuple[str, ...]] = {
    "baray": ("baray_secret_key", "baray_iv", "baray_public_key"),
    "payway": ("payway_api_key", "payway_api_secret"),
    "bakong": ("bakong_access_token",),
    # Sandbox provider used by the test suite. No credentials by design.
    "fake": (),
}

# Gateway credentials. Absent until a provider is actually selected, which is
# why the default PAYMENT_PROVIDER is "none".
baray_secret_key: str = ""
baray_iv: str = ""
baray_public_key: str = ""
payway_api_key: str = ""
payway_api_secret: str = ""
bakong_access_token: str = ""

# The algorithm is intentionally not configurable: an operator-supplied value
# ("none", or an asymmetric algorithm paired with a public key) turns JWT
# verification into an algorithm-confusion bypass. See CVE-2016-10555 family.
JWT_ALGORITHM = "HS256"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "Cosmetic Store API"
    app_version: str = "1.0.0"

    database_url: str = "sqlite:///./cosmetic_store.db"

    # No default on purpose. A committed default signing key lets anyone mint a
    # token for any user. Startup fails instead of running on a known key.
    secret_key: str

    access_token_expire_minutes: int = 30

    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173,http://localhost:8080,http://127.0.0.1:8080"

    # --- payments -------------------------------------------------------
    # Currency is explicit rather than implied. KHQR settles in KHR and Baray
    # settles in USD, and mixing the two is how a paid order ends up matching
    # the wrong total. Every Payment row records this value.
    currency: str = "USD"

    # How long an order may sit in pending_payment before its reservation is
    # released back to saleable stock. Also bounds how stale a QR can get, so it
    # must be shorter than the provider's own QR lifetime (KHQR caps at 10
    # minutes for a single-use token).
    payment_window_minutes: int = 15

    # Gateway actually enabled. "none" keeps checkout on cash on delivery and
    # makes intent creation fail loudly instead of pretending to take money.
    payment_provider: str = "none"

    # Public HTTPS origin of the deployed API. The provider posts webhooks here,
    # so a non-HTTPS value in production means payments silently never confirm.
    # Left empty for local dev, where the tunnel URL differs per session.
    public_base_url: str = ""

    @field_validator("currency")
    @classmethod
    def validate_currency(cls, v: str) -> str:
        code = (v or "").strip().upper()
        if len(code) != 3 or not code.isalpha():
            raise ValueError(
                f"CURRENCY must be a 3-letter ISO 4217 code, got {v!r}. "
                "KHQR settles in KHR; most card gateways settle in USD."
            )
        return code

    @field_validator("payment_provider")
    @classmethod
    def validate_payment_provider(cls, v: str) -> str:
        name = (v or "").strip().lower()
        if name not in _KNOWN_PAYMENT_PROVIDERS:
            raise ValueError(
                f"PAYMENT_PROVIDER must be one of {sorted(_KNOWN_PAYMENT_PROVIDERS)}, "
                f"got {v!r}. Use 'none' to keep checkout on cash on delivery."
            )
        return name

    @field_validator("payment_window_minutes")
    @classmethod
    def validate_payment_window(cls, v: int) -> int:
        if not 1 <= v <= 120:
            raise ValueError(
                "PAYMENT_WINDOW_MINUTES must be between 1 and 120. A window longer "
                "than the provider's QR lifetime leaves orders waiting on a token "
                "that can no longer be paid."
            )
        return v

    @model_validator(mode="after")
    def validate_payment_wiring(self) -> "Settings":
        # A provider without its credentials is the same class of outage as the
        # placeholder JWT secret: it fails at the first customer checkout rather
        # than at deploy time.
        if self.payment_provider != "none":
            missing = [
                name
                for name in _PROVIDER_SECRET_FIELDS.get(self.payment_provider, ())
                if not (getattr(self, name, "") or "").strip()
            ]
            if missing:
                raise ValueError(
                    f"PAYMENT_PROVIDER={self.payment_provider} requires "
                    f"{', '.join(missing)}. Take real money only with credentials "
                    "that are actually set."
                )
        if self.public_base_url and not self.public_base_url.startswith("https://"):
            raise ValueError(
                "PUBLIC_BASE_URL must use https://. Payment providers refuse to "
                "deliver webhooks over plaintext, so an http:// value means no "
                "payment will ever be confirmed."
            )
        return self

    @field_validator("database_url")
    @classmethod
    def normalize_database_url(cls, v: str) -> str:
        # Bare "sqlite://" without the third slash resolves to a relative path;
        # accept it rather than failing on a common typo.
        if v.startswith("sqlite://") and not v.startswith("sqlite:///"):
            v = v.replace("sqlite://", "sqlite:///", 1)

        # Force the psycopg (v3) driver for Postgres. SQLAlchemy 2.1 switched
        # the default driver for a bare "postgresql://" URL from psycopg2 to
        # psycopg (v3), and hosted Postgres (Neon, Render, ...) hands out a bare
        # URL. Pinning the driver here keeps the app and Alembic (both read this
        # setting) on the same driver, which is the psycopg[binary] dependency
        # in requirements.txt. Without this the deployed image would import
        # psycopg2 and crash with "No module named 'psycopg2'".
        if v.startswith("postgres://"):
            v = "postgresql+psycopg://" + v[len("postgres://"):]
        elif v.startswith("postgresql://"):
            v = "postgresql+psycopg://" + v[len("postgresql://"):]
        return v

    @field_validator("cors_origins")
    @classmethod
    def validate_cors_origins(cls, v: str) -> str:
        parse_cors_origins(v)
        return v

    @model_validator(mode="after")
    def reject_weak_secret(self) -> "Settings":
        key = (self.secret_key or "").strip()
        if not key:
            raise ValueError(
                "SECRET_KEY is required. Generate one with: "
                "python -c \"import secrets; print(secrets.token_urlsafe(64))\""
            )
        if key.lower() in _PLACEHOLDER_SECRETS:
            raise ValueError(
                "SECRET_KEY is still the placeholder value. Generate a real one with: "
                "python -c \"import secrets; print(secrets.token_urlsafe(64))\""
            )
        if len(key) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters.")
        return self


def parse_cors_origins(value: str) -> List[str]:
    origins = [origin.strip() for origin in value.split(",") if origin.strip()]
    if not origins:
        raise ValueError(
            "CORS_ORIGINS resolved to an empty list. Set it to an explicit "
            "comma-separated allowlist, e.g. http://localhost:8080"
        )
    if "*" in origins:
        raise ValueError(
            "CORS_ORIGINS must not contain '*'. The API is credentialed "
            "(Authorization: Bearer), so a wildcard origin lets any website "
            "read authenticated responses. List explicit origins instead."
        )
    return origins


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
