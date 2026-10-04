from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.models import User, WorkPattern
from app.schemas.schemas import (
    APIResponse,
    WorkPatternCreate,
    WorkPatternResponse,
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/patterns", tags=["Work Patterns"])


@router.get("", response_model=APIResponse[List[WorkPatternResponse]])
def get_user_patterns(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    patterns = db.query(WorkPattern).filter(WorkPattern.user_id == current_user.id).all()
    return APIResponse(success=True, data=patterns)


@router.post("", response_model=APIResponse[WorkPatternResponse])
def create_pattern(
    pattern_in: WorkPatternCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    pattern = WorkPattern(
        user_id=current_user.id,
        name=pattern_in.name,
        description=pattern_in.description,
        cycle_length=pattern_in.cycle_length,
        cycle_type=pattern_in.cycle_type,
        pattern_definition=[d.model_dump() for d in pattern_in.pattern_definition],
        start_date=pattern_in.start_date,
        is_active=True,
    )
    db.add(pattern)
    db.commit()
    db.refresh(pattern)
    return APIResponse(success=True, message="Vardiya düzeni kaydedildi.", data=pattern)


@router.delete("/{pattern_id}", response_model=APIResponse[dict])
def delete_pattern(
    pattern_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    pattern = (
        db.query(WorkPattern)
        .filter(WorkPattern.id == pattern_id, WorkPattern.user_id == current_user.id)
        .first()
    )
    if not pattern:
        raise HTTPException(status_code=404, detail="Düzen bulunamadı.")
    db.delete(pattern)
    db.commit()
    return APIResponse(success=True, message="Düzen silindi.")
