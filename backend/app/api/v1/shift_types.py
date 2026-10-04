from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.db.session import get_db
from app.models.models import User, ShiftType
from app.schemas.schemas import (
    APIResponse,
    ShiftTypeCreate,
    ShiftTypeUpdate,
    ShiftTypeResponse,
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/shift-types", tags=["Shift Types"])


@router.get("", response_model=APIResponse[List[ShiftTypeResponse]])
def get_shift_types(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    types = (
        db.query(ShiftType)
        .filter(or_(ShiftType.user_id == current_user.id, ShiftType.user_id.is_(None)))
        .order_by(ShiftType.id)
        .all()
    )
    return APIResponse(success=True, data=types)


@router.post("", response_model=APIResponse[ShiftTypeResponse])
def create_shift_type(
    item_in: ShiftTypeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift_type = ShiftType(user_id=current_user.id, **item_in.model_dump())
    db.add(shift_type)
    db.commit()
    db.refresh(shift_type)
    return APIResponse(success=True, message="Vardiya tipi oluşturuldu.", data=shift_type)


@router.put("/{type_id}", response_model=APIResponse[ShiftTypeResponse])
def update_shift_type(
    type_id: int,
    item_in: ShiftTypeUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift_type = (
        db.query(ShiftType)
        .filter(ShiftType.id == type_id, ShiftType.user_id == current_user.id)
        .first()
    )
    if not shift_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vardiya tipi bulunamadı veya düzenleme yetkiniz yok.",
        )
    for field, value in item_in.model_dump(exclude_unset=True).items():
        setattr(shift_type, field, value)
    db.commit()
    db.refresh(shift_type)
    return APIResponse(success=True, message="Vardiya tipi güncellendi.", data=shift_type)


@router.delete("/{type_id}", response_model=APIResponse[dict])
def delete_shift_type(
    type_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift_type = (
        db.query(ShiftType)
        .filter(ShiftType.id == type_id, ShiftType.user_id == current_user.id)
        .first()
    )
    if not shift_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vardiya tipi bulunamadı veya silme yetkiniz yok.",
        )
    db.delete(shift_type)
    db.commit()
    return APIResponse(success=True, message="Vardiya tipi silindi.")
