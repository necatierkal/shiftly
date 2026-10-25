from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from app.db.session import get_db
from app.models.models import User, Shift, ShiftSwap, TeamMember
from app.schemas.schemas import (
    APIResponse,
    ShiftSwapCreate,
    ShiftSwapResponse,
)
from app.services.shift_service import ShiftService
from app.api.deps import get_current_user

router = APIRouter(prefix="/swaps", tags=["Shift Swaps"])


@router.get("", response_model=APIResponse[List[ShiftSwapResponse]])
def get_swaps(
    tab: Optional[str] = "my",  # "my" or "available"
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if tab == "my":
        swaps = (
            db.query(ShiftSwap)
            .filter(or_(ShiftSwap.requester_id == current_user.id, ShiftSwap.target_user_id == current_user.id))
            .order_by(ShiftSwap.created_at.desc())
            .all()
        )
    else:
        # Available open swaps in teams user belongs to
        my_team_memberships = db.query(TeamMember).filter(TeamMember.user_id == current_user.id).all()
        team_ids = [m.team_id for m in my_team_memberships]

        teammates = db.query(TeamMember.user_id).filter(TeamMember.team_id.in_(team_ids)).distinct().all()
        teammate_ids = [t[0] for t in teammates if t[0] != current_user.id]

        swaps = (
            db.query(ShiftSwap)
            .filter(
                ShiftSwap.status == "PENDING",
                ShiftSwap.requester_id.in_(teammate_ids),
                or_(ShiftSwap.target_user_id.is_(None), ShiftSwap.target_user_id == current_user.id),
            )
            .order_by(ShiftSwap.created_at.desc())
            .all()
        )

    return APIResponse(success=True, data=swaps)


@router.post("", response_model=APIResponse[ShiftSwapResponse])
def create_swap_request(
    swap_in: ShiftSwapCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Rule 1: Shift exists?
    req_shift = db.query(Shift).filter(Shift.id == swap_in.requester_shift_id).first()
    if not req_shift:
        raise HTTPException(status_code=404, detail="Değiştirilecek vardiya bulunamadı.")

    # Rule 2: User owns the shift?
    if req_shift.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bu vardiya size ait değil.")

    # Rule 3: Past shift?
    if req_shift.end_datetime < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Geçmiş tarihteki bir vardiya takas edilemez.")

    # Rule 4: Already in an active swap?
    existing_swap = db.query(ShiftSwap).filter(
        ShiftSwap.requester_shift_id == req_shift.id,
        ShiftSwap.status == "PENDING",
    ).first()
    if existing_swap:
        raise HTTPException(status_code=400, detail="Bu vardiya için zaten açık bir takas talebi var.")

    # Rule 5: If target shift specified, verify target shift
    if swap_in.target_shift_id:
        tgt_shift = db.query(Shift).filter(Shift.id == swap_in.target_shift_id).first()
        if not tgt_shift:
            raise HTTPException(status_code=404, detail="Hedef vardiya bulunamadı.")
        if tgt_shift.user_id == current_user.id:
            raise HTTPException(status_code=400, detail="Kendi vardiyanızla takas yapamazsınız.")

    swap = ShiftSwap(
        requester_id=current_user.id,
        target_user_id=swap_in.target_user_id,
        requester_shift_id=swap_in.requester_shift_id,
        target_shift_id=swap_in.target_shift_id,
        message=swap_in.message,
        status="PENDING",
    )
    db.add(swap)
    db.commit()
    db.refresh(swap)

    return APIResponse(success=True, message="Takas talebi oluşturuldu.", data=swap)


@router.post("/{swap_id}/accept", response_model=APIResponse[dict])
def accept_swap(
    swap_id: int,
    offered_shift_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    swap = db.query(ShiftSwap).filter(ShiftSwap.id == swap_id).first()
    if not swap:
        raise HTTPException(status_code=404, detail="Takas talebi bulunamadı.")
    if swap.status != "PENDING":
        raise HTTPException(status_code=400, detail="Bu talep artık geçerli değil.")
    if swap.requester_id == current_user.id:
        raise HTTPException(status_code=400, detail="Kendi takas talebinizi kabul edemezsiniz.")

    req_shift = db.query(Shift).filter(Shift.id == swap.requester_shift_id).first()
    tgt_shift_id = swap.target_shift_id or offered_shift_id
    if not tgt_shift_id:
        raise HTTPException(status_code=400, detail="Karşılık gelecek bir vardiya belirtilmelidir.")

    tgt_shift = db.query(Shift).filter(Shift.id == tgt_shift_id).first()
    if not tgt_shift or tgt_shift.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Hedef vardiya size ait değil.")

    # Overlap checks for both users
    # Check if target user has overlap with req_shift
    overlap_tgt = ShiftService.check_overlap(
        db, current_user.id, req_shift.start_datetime, req_shift.end_datetime, exclude_shift_id=tgt_shift.id
    )
    if overlap_tgt:
        raise HTTPException(status_code=409, detail="Talep edilen vardiya mevcut takviminizle çakışıyor.")

    # Check if requester user has overlap with tgt_shift
    overlap_req = ShiftService.check_overlap(
        db, swap.requester_id, tgt_shift.start_datetime, tgt_shift.end_datetime, exclude_shift_id=req_shift.id
    )
    if overlap_req:
        raise HTTPException(status_code=409, detail="Bu vardiya karşı tarafın takvimiyle çakışıyor.")

    # Perform swap: exchange user_ids
    req_shift.user_id = current_user.id
    tgt_shift.user_id = swap.requester_id
    swap.status = "ACCEPTED"
    swap.target_user_id = current_user.id
    swap.target_shift_id = tgt_shift.id

    db.commit()

    return APIResponse(success=True, message="Vardiya takası başarıyla gerçekleşti!")


@router.post("/{swap_id}/reject", response_model=APIResponse[dict])
def reject_swap(
    swap_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    swap = db.query(ShiftSwap).filter(ShiftSwap.id == swap_id).first()
    if not swap:
        raise HTTPException(status_code=404, detail="Takas talebi bulunamadı.")
    
    # Verify permission: only target user, requester, or team manager can reject
    is_target = swap.target_user_id is not None and swap.target_user_id == current_user.id
    is_requester = swap.requester_id == current_user.id
    is_admin = current_user.role == "admin"
    if not (is_target or is_requester or is_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu takas talebini reddetme yetkiniz bulunmuyor.",
        )

    swap.status = "REJECTED"
    db.commit()
    return APIResponse(success=True, message="Takas talebi reddedildi.")


@router.post("/{swap_id}/cancel", response_model=APIResponse[dict])
def cancel_swap(
    swap_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    swap = db.query(ShiftSwap).filter(ShiftSwap.id == swap_id, ShiftSwap.requester_id == current_user.id).first()
    if not swap:
        raise HTTPException(status_code=404, detail="Takas talebi bulunamadı veya iptal yetkiniz yok.")
    swap.status = "CANCELLED"
    db.commit()
    return APIResponse(success=True, message="Takas talebi iptal edildi.")
