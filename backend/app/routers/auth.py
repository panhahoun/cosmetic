from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.core.security import (
    BCRYPT_MAX_BYTES,
    WeakPasswordError,
    create_access_token,
    get_password_hash,
    verify_password,
)
from app.models.user import User
from app.serializers import serialize_user

router = APIRouter()


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    # Upper bound matches bcrypt's 72-byte limit; longer input is rejected
    # rather than silently truncated to a prefix.
    password: str = Field(min_length=8, max_length=BCRYPT_MAX_BYTES)
    phone: str | None = Field(default=None, max_length=30)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=BCRYPT_MAX_BYTES)


class TokenResponse(BaseModel):
    status: bool
    message: str
    access_token: str
    token_type: str = "bearer"
    data: dict


class RegisterResponse(BaseModel):
    status: bool
    message: str
    data: dict | None = None


@router.post("/register", response_model=RegisterResponse)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == req.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    try:
        password_hash = get_password_hash(req.password)
    except WeakPasswordError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)
        ) from exc

    user = User(
        name=req.name,
        email=req.email,
        phone=req.phone,
        password_hash=password_hash,
        role="user",
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return RegisterResponse(
        status=True,
        message="Registration successful",
        data=serialize_user(user),
    )


@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()

    # Verify against a dummy hash when the user is missing so the response time
    # does not reveal whether the email is registered.
    stored_hash = user.password_hash if user else (
        "$2b$12$K3JNi5wq8Xk7Yq0dXhZ0WeJ6mQ9wG0hZ1p5rQ2x5tUu9v1cQ0eQ4i"
    )
    password_ok = verify_password(req.password, stored_hash)

    if not user or not password_ok:
        # 401, not 200-with-status-false: auth failures must be visible to
        # status-code-based monitoring and rate limiters.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token({"sub": str(user.id), "email": user.email})
    return TokenResponse(
        status=True,
        message="Login successful",
        access_token=token,
        token_type="bearer",
        # Only "data" -- the previous payload duplicated the same object under
        # "user" and forced the client to guess which key to read.
        data=serialize_user(user),
    )


@router.get("/me")
def me(current_user: User = Depends(get_current_active_user)):
    return {"status": True, "message": "Authenticated", "data": serialize_user(current_user)}
