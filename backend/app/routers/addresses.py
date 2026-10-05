from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.models.order import Address
from app.models.user import User
from app.serializers import serialize_address

router = APIRouter()


class AddressRequest(BaseModel):
    full_name: str = Field(min_length=1, max_length=100)
    phone: str = Field(min_length=1, max_length=30)
    address_line: str = Field(min_length=1)
    city: str | None = Field(default=None, max_length=100)
    postal_code: str | None = Field(default=None, max_length=20)
    is_default: bool = False


class AddressUpdateRequest(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=100)
    phone: str | None = Field(default=None, min_length=1, max_length=30)
    address_line: str | None = Field(default=None, min_length=1)
    city: str | None = Field(default=None, max_length=100)
    postal_code: str | None = Field(default=None, max_length=20)
    is_default: bool | None = None


def _clear_other_defaults(db: Session, user_id: int, keep_id: int | None = None) -> None:
    query = db.query(Address).filter(Address.user_id == user_id)
    if keep_id is not None:
        query = query.filter(Address.id != keep_id)
    query.update({Address.is_default: 0}, synchronize_session=False)


@router.get("/get_addresses")
def get_addresses(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    addresses = (
        db.query(Address)
        .filter(Address.user_id == current_user.id)
        .order_by(Address.is_default.desc(), Address.id.desc())
        .all()
    )
    return {
        "status": True,
        "message": "Addresses retrieved",
        "data": [serialize_address(a) for a in addresses],
    }


@router.post("/add_address", status_code=status.HTTP_201_CREATED)
def add_address(
    req: AddressRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    if req.is_default:
        _clear_other_defaults(db, current_user.id)
    addr = Address(
        user_id=current_user.id,
        full_name=req.full_name,
        phone=req.phone,
        address_line=req.address_line,
        city=req.city,
        postal_code=req.postal_code,
        is_default=1 if req.is_default else 0,
    )
    db.add(addr)
    db.commit()
    db.refresh(addr)
    return {
        "status": True,
        "message": "Address added",
        "data": serialize_address(addr),
    }


def _get_owned_address(db: Session, user_id: int, address_id: int) -> Address:
    addr = (
        db.query(Address)
        .filter(Address.id == address_id, Address.user_id == user_id)
        .first()
    )
    if not addr:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Address not found"
        )
    return addr


@router.put("/update_address/{address_id}")
def update_address(
    address_id: int,
    req: AddressUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    addr = _get_owned_address(db, current_user.id, address_id)

    for field in (
        "full_name",
        "phone",
        "address_line",
        "city",
        "postal_code",
    ):
        value = getattr(req, field)
        if value is not None:
            setattr(addr, field, value)

    if req.is_default is not None:
        if req.is_default:
            _clear_other_defaults(db, current_user.id, keep_id=addr.id)
        addr.is_default = 1 if req.is_default else 0

    db.add(addr)
    db.commit()
    db.refresh(addr)
    return {
        "status": True,
        "message": "Address updated",
        "data": serialize_address(addr),
    }


@router.delete("/delete_address/{address_id}")
def delete_address(
    address_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    addr = _get_owned_address(db, current_user.id, address_id)
    was_default = bool(addr.is_default)
    db.delete(addr)
    db.commit()

    # Never leave the user with zero defaults.
    if was_default:
        replacement = (
            db.query(Address)
            .filter(Address.user_id == current_user.id)
            .order_by(Address.id.desc())
            .first()
        )
        if replacement is not None:
            replacement.is_default = 1
            db.add(replacement)
            db.commit()

    return {"status": True, "message": "Address deleted", "data": None}
