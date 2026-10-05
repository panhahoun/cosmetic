from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from uuid import uuid4

from jose import JWTError, jwt

from app.core.config import JWT_ALGORITHM, settings

# bcrypt silently truncates at 72 bytes, so a longer password is not an error
# the user can see -- it just quietly becomes a shorter password. Reject it.
BCRYPT_MAX_BYTES = 72


class WeakPasswordError(ValueError):
    pass


def _bcrypt(password: str) -> bytes:
    encoded = password.encode("utf-8")
    if len(encoded) > BCRYPT_MAX_BYTES:
        raise WeakPasswordError(
            f"Password must be at most {BCRYPT_MAX_BYTES} bytes when UTF-8 encoded."
        )
    return encoded


def verify_password(plain_password: str, hashed_password: str) -> bool:
    import bcrypt

    try:
        return bcrypt.checkpw(_bcrypt(plain_password), hashed_password.encode("utf-8"))
    except (ValueError, TypeError):
        # Malformed hash in the database: treat as a failed login, not a 500.
        return False


def get_password_hash(password: str) -> str:
    import bcrypt

    return bcrypt.hashpw(_bcrypt(password), bcrypt.gensalt()).decode("utf-8")


def create_access_token(
    data: dict[str, Any],
    expires_delta: Optional[timedelta] = None,
) -> str:
    now = datetime.now(timezone.utc)
    expire = now + (
        expires_delta
        or timedelta(minutes=settings.access_token_expire_minutes)
    )
    to_encode = data.copy()
    # iat/iss let the client reason about freshness; jti gives us a handle for
    # server-side revocation when a refresh-token flow is added.
    to_encode.update({"iat": now, "exp": expire, "iss": "cosmetic-api", "jti": uuid4().hex})
    return jwt.encode(to_encode, settings.secret_key, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> Optional[dict[str, Any]]:
    try:
        # Algorithm is pinned here rather than read from settings.
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=[JWT_ALGORITHM],
            issuer="cosmetic-api",
        )
        return payload
    except JWTError:
        return None
