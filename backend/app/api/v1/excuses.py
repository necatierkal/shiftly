from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.models import DutyPeriod, DutyExcuse, User, TeamMember
from app.schemas.schemas import (
    APIResponse,
    DutyExcuseCreate,
    DutyExcuseReview,
    DutyExcuseResponse,
)
from app.api.deps import get_current_user, check_team_manager, check_team_member

router = APIRouter(prefix="/excuses", tags=["Duty Excuses (Mazeret Bildirimleri)"])


@router.post("", response_model=APIResponse[DutyExcuseResponse])
def submit_excuse(
    excuse_in: DutyExcuseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    period = db.query(DutyPeriod).filter(DutyPeriod.id == excuse_in.period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail="Nöbet dönemi bulunamadı.")

    # Team membership check
    check_team_member(period.team_id, current_user, db)

    # Status & Deadline check
    now = datetime.utcnow()
    if period.status != "EXCUSES_OPEN":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu dönem için mazeret başvuruları kapalıdır.",
        )
    if now > period.excuse_deadline:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Mazeret başvuru süresi {period.excuse_deadline.strftime('%d.%m.%Y %H:%M')} tarihinde sona ermiştir.",
        )

    # Date range checks
    if excuse_in.start_date > excuse_in.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mazeret başlangıç tarihi bitiş tarihinden sonra olamaz.",
        )

    if excuse_in.start_date < period.start_date or excuse_in.end_date > period.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Mazeret tarihleri dönem aralığında ({period.start_date.strftime('%d.%m.%Y')} - {period.end_date.strftime('%d.%m.%Y')}) olmalıdır.",
        )

    excuse = DutyExcuse(
        period_id=period.id,
        user_id=current_user.id,
        start_date=excuse_in.start_date,
        end_date=excuse_in.end_date,
        is_all_day=excuse_in.is_all_day,
        start_time=excuse_in.start_time,
        end_time=excuse_in.end_time,
        category=excuse_in.category,
        description=excuse_in.description.strip(),
        is_hard_constraint=excuse_in.is_hard_constraint,
        status="SUBMITTED",
    )
    db.add(excuse)
    db.commit()
    db.refresh(excuse)

    return APIResponse(
        success=True,
        message="Mazeret bildiriminiz yönetici incelemesine başarıyla iletildi.",
        data=DutyExcuseResponse.model_validate(excuse),
    )


@router.get("", response_model=APIResponse[List[DutyExcuseResponse]])
def get_excuses(
    period_id: Optional[int] = None,
    user_id: Optional[int] = None,
    status_filter: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(DutyExcuse)

    if period_id:
        period = db.query(DutyPeriod).filter(DutyPeriod.id == period_id).first()
        if not period:
            raise HTTPException(status_code=404, detail="Dönem bulunamadı.")
        check_team_member(period.team_id, current_user, db)
        query = query.filter(DutyExcuse.period_id == period_id)

        # If user is not manager of the team, restrict to own excuses
        try:
            check_team_manager(period.team_id, current_user, db)
            is_mgr = True
        except HTTPException:
            is_mgr = False

        if not is_mgr:
            query = query.filter(DutyExcuse.user_id == current_user.id)
    else:
        # If no period_id, return current user's excuses unless admin
        if current_user.role != "admin":
            query = query.filter(DutyExcuse.user_id == current_user.id)

    if user_id:
        # Only managers/admin can query another user's excuses
        if user_id != current_user.id and current_user.role != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Diğer personellerin mazeretlerini görüntüleme yetkiniz yok.",
            )
        query = query.filter(DutyExcuse.user_id == user_id)

    if status_filter:
        query = query.filter(DutyExcuse.status == status_filter)

    excuses = query.order_by(DutyExcuse.created_at.desc()).all()
    return APIResponse(
        success=True,
        data=[DutyExcuseResponse.model_validate(e) for e in excuses],
    )


@router.get("/{excuse_id}", response_model=APIResponse[DutyExcuseResponse])
def get_excuse(
    excuse_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    excuse = db.query(DutyExcuse).filter(DutyExcuse.id == excuse_id).first()
    if not excuse:
        raise HTTPException(status_code=404, detail="Mazeret kaydı bulunamadı.")

    period = excuse.period
    # Check permissions: owner or manager
    if excuse.user_id != current_user.id:
        check_team_manager(period.team_id, current_user, db)

    return APIResponse(success=True, data=DutyExcuseResponse.model_validate(excuse))


@router.post("/{excuse_id}/review", response_model=APIResponse[DutyExcuseResponse])
def review_excuse(
    excuse_id: int,
    review_in: DutyExcuseReview,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    excuse = db.query(DutyExcuse).filter(DutyExcuse.id == excuse_id).first()
    if not excuse:
        raise HTTPException(status_code=404, detail="Mazeret kaydı bulunamadı.")

    period = excuse.period
    check_team_manager(period.team_id, current_user, db)

    if review_in.status not in ["APPROVED", "REJECTED", "INFO_REQUESTED"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Geçersiz değerlendirme durumu. Kabul (APPROVED), Ret (REJECTED) veya Ek Bilgi (INFO_REQUESTED) seçilmelidir.",
        )

    excuse.status = review_in.status
    excuse.manager_comment = review_in.manager_comment
    if review_in.is_hard_constraint is not None:
        excuse.is_hard_constraint = review_in.is_hard_constraint
    excuse.reviewed_by = current_user.id
    excuse.reviewed_at = datetime.utcnow()

    db.commit()
    db.refresh(excuse)

    msg = "Mazeret kabul edildi." if excuse.status == "APPROVED" else "Mazeret değerlendirmesi kaydedildi."
    return APIResponse(success=True, message=msg, data=DutyExcuseResponse.model_validate(excuse))


@router.delete("/{excuse_id}", response_model=APIResponse[dict])
def cancel_excuse(
    excuse_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    excuse = db.query(DutyExcuse).filter(DutyExcuse.id == excuse_id).first()
    if not excuse:
        raise HTTPException(status_code=404, detail="Mazeret kaydı bulunamadı.")

    if excuse.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Yalnızca kendi mazeretinizi iptal edebilirsiniz.")

    if excuse.status in ["APPROVED", "REJECTED"]:
        raise HTTPException(status_code=400, detail="Değerlendirilmiş bir mazeret silinemez.")

    db.delete(excuse)
    db.commit()
    return APIResponse(success=True, message="Mazeret başvurusu iptal edildi.")
