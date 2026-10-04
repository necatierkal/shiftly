from typing import List, Optional
from datetime import date, datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_
from app.db.session import get_db
from app.models.models import User, Shift, ShiftType, Reminder
from app.schemas.schemas import (
    APIResponse,
    ShiftCreate,
    ShiftUpdate,
    ShiftResponse,
    WorkPatternGenerateRequest,
)
from app.services.shift_service import ShiftService
from app.api.deps import get_current_user

router = APIRouter(prefix="/shifts", tags=["Shifts"])


@router.get("", response_model=APIResponse[List[ShiftResponse]])
def get_shifts(
    start_date: Optional[date] = Query(None, description="Başlangıç tarihi (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="Bitiş tarihi (YYYY-MM-DD)"),
    status: Optional[str] = Query(None, description="Vardiya durumu"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Shift).filter(Shift.user_id == current_user.id)
    if start_date:
        query = query.filter(Shift.date >= start_date)
    if end_date:
        query = query.filter(Shift.date <= end_date)
    if status:
        query = query.filter(Shift.status == status)

    shifts = query.order_by(Shift.date.asc(), Shift.start_datetime.asc()).all()
    return APIResponse(success=True, data=shifts)


@router.get("/{shift_id}", response_model=APIResponse[ShiftResponse])
def get_shift_detail(
    shift_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift = db.query(Shift).filter(Shift.id == shift_id, Shift.user_id == current_user.id).first()
    if not shift:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vardiya bulunamadı.")
    return APIResponse(success=True, data=shift)


@router.post("", response_model=APIResponse[ShiftResponse])
def create_shift(
    shift_in: ShiftCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift, error = ShiftService.create_shift(db, current_user.id, shift_in)
    if error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=error)
    return APIResponse(success=True, message="Vardiya başarıyla oluşturuldu.", data=shift)


@router.put("/{shift_id}", response_model=APIResponse[ShiftResponse])
def update_shift(
    shift_id: int,
    shift_in: ShiftUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift = db.query(Shift).filter(Shift.id == shift_id, Shift.user_id == current_user.id).first()
    if not shift:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vardiya bulunamadı.")

    # Check for conflict if dates changed
    s_dt = shift_in.start_datetime or shift.start_datetime
    e_dt = shift_in.end_datetime or shift.end_datetime
    overlap = ShiftService.check_overlap(db, current_user.id, s_dt, e_dt, exclude_shift_id=shift_id)
    if overlap:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu vardiya mevcut vardiyanızla çakışıyor.",
        )

    for field, value in shift_in.model_dump(exclude_unset=True).items():
        if field == "reminder_minutes":
            continue
        setattr(shift, field, value)

    if shift_in.reminder_minutes is not None:
        reminder = db.query(Reminder).filter(Reminder.shift_id == shift.id).first()
        if reminder:
            reminder.reminder_minutes = shift_in.reminder_minutes
        else:
            db.add(Reminder(user_id=current_user.id, shift_id=shift.id, reminder_minutes=shift_in.reminder_minutes))

    db.commit()
    db.refresh(shift)
    return APIResponse(success=True, message="Vardiya güncellendi.", data=shift)


@router.delete("/{shift_id}", response_model=APIResponse[dict])
def delete_shift(
    shift_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift = db.query(Shift).filter(Shift.id == shift_id, Shift.user_id == current_user.id).first()
    if not shift:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vardiya bulunamadı.")
    db.delete(shift)
    db.commit()
    return APIResponse(success=True, message="Vardiya silindi.")


@router.post("/preview-generate", response_model=APIResponse[dict])
def preview_generate_shifts(
    req: WorkPatternGenerateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    days_count = (req.end_date - req.start_date).days + 1
    if days_count <= 0:
        raise HTTPException(status_code=400, detail="Bitiş tarihi başlangıç tarihinden sonra olmalıdır.")

    return APIResponse(
        success=True,
        data={
            "cycle_type": req.cycle_type,
            "start_date": req.start_date.isoformat(),
            "end_date": req.end_date.isoformat(),
            "total_days": days_count,
            "estimated_shifts": days_count,
            "preview_message": f"{days_count} günlük döngü oluşturulacak.",
        },
    )


@router.post("/generate", response_model=APIResponse[dict])
def generate_shifts(
    req: WorkPatternGenerateRequest,
    overwrite: bool = Query(False, description="Çakışan mevcut vardiyaların üzerine yazılsın mı"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    created, conflicts = ShiftService.generate_pattern_shifts(
        db=db,
        user_id=current_user.id,
        cycle_type=req.cycle_type or "24/48",
        start_date=req.start_date,
        end_date=req.end_date,
        custom_pattern=req.custom_pattern,
        overwrite_conflicts=overwrite,
    )
    return APIResponse(
        success=True,
        message=f"{len(created)} vardiya başarıyla oluşturuldu.",
        data={
            "created_count": len(created),
            "conflicts_skipped": conflicts,
            "start_date": req.start_date.isoformat(),
            "end_date": req.end_date.isoformat(),
        },
    )
