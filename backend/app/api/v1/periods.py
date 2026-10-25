from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.models import DutyPeriod, DutyExcuse, Team, User, TeamMember
from app.schemas.schemas import (
    APIResponse,
    DutyPeriodCreate,
    DutyPeriodUpdate,
    DutyPeriodResponse,
)
from app.api.deps import get_current_user, check_team_manager, check_team_member

router = APIRouter(prefix="/periods", tags=["Duty Periods (Nöbet Dönemleri)"])


@router.post("", response_model=APIResponse[DutyPeriodResponse])
def create_period(
    period_in: DutyPeriodCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Manager check for the team
    check_team_manager(period_in.team_id, current_user, db)

    # Date validations
    if period_in.start_date > period_in.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Başlangıç tarihi bitiş tarihinden sonra olamaz.",
        )
    if period_in.excuse_start_time > period_in.excuse_deadline:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mazeret başlangıç zamanı son başvuru tarihinden sonra olamaz.",
        )

    period = DutyPeriod(
        team_id=period_in.team_id,
        name=period_in.name,
        start_date=period_in.start_date,
        end_date=period_in.end_date,
        excuse_start_time=period_in.excuse_start_time,
        excuse_deadline=period_in.excuse_deadline,
        status="EXCUSES_OPEN",
        manager_note=period_in.manager_note,
    )
    db.add(period)
    db.commit()
    db.refresh(period)

    res_data = DutyPeriodResponse.model_validate(period)
    res_data.excuses_count = 0
    res_data.pending_excuses_count = 0

    return APIResponse(
        success=True,
        message="Nöbet dönemi başarıyla oluşturuldu ve mazeret başvurularına açıldı.",
        data=res_data,
    )


@router.get("", response_model=APIResponse[List[DutyPeriodResponse]])
def get_periods(
    team_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(DutyPeriod)
    if team_id:
        check_team_member(team_id, current_user, db)
        query = query.filter(DutyPeriod.team_id == team_id)
    else:
        # Get periods of all teams user belongs to
        my_team_ids = [
            m.team_id
            for m in db.query(TeamMember.team_id).filter(TeamMember.user_id == current_user.id).all()
        ]
        if current_user.role == "admin":
            query = query
        else:
            query = query.filter(DutyPeriod.team_id.in_(my_team_ids))

    periods = query.order_by(DutyPeriod.start_date.desc()).all()

    result: List[DutyPeriodResponse] = []
    for p in periods:
        p_res = DutyPeriodResponse.model_validate(p)
        p_res.excuses_count = db.query(DutyExcuse).filter(DutyExcuse.period_id == p.id).count()
        p_res.pending_excuses_count = (
            db.query(DutyExcuse)
            .filter(DutyExcuse.period_id == p.id, DutyExcuse.status.in_(["SUBMITTED", "UNDER_REVIEW"]))
            .count()
        )
        result.append(p_res)

    return APIResponse(success=True, data=result)


@router.get("/{period_id}", response_model=APIResponse[DutyPeriodResponse])
def get_period(
    period_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    period = db.query(DutyPeriod).filter(DutyPeriod.id == period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail="Nöbet dönemi bulunamadı.")

    check_team_member(period.team_id, current_user, db)

    res = DutyPeriodResponse.model_validate(period)
    res.excuses_count = db.query(DutyExcuse).filter(DutyExcuse.period_id == period.id).count()
    res.pending_excuses_count = (
        db.query(DutyExcuse)
        .filter(DutyExcuse.period_id == period.id, DutyExcuse.status.in_(["SUBMITTED", "UNDER_REVIEW"]))
        .count()
    )
    return APIResponse(success=True, data=res)


@router.put("/{period_id}", response_model=APIResponse[DutyPeriodResponse])
def update_period(
    period_id: int,
    data: DutyPeriodUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    period = db.query(DutyPeriod).filter(DutyPeriod.id == period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail="Nöbet dönemi bulunamadı.")

    check_team_manager(period.team_id, current_user, db)

    for field, val in data.model_dump(exclude_unset=True).items():
        setattr(period, field, val)

    db.commit()
    db.refresh(period)

    res = DutyPeriodResponse.model_validate(period)
    return APIResponse(success=True, message="Nöbet dönemi güncellendi.", data=res)


@router.post("/{period_id}/close-excuses", response_model=APIResponse[dict])
def close_excuses(
    period_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    period = db.query(DutyPeriod).filter(DutyPeriod.id == period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail="Nöbet dönemi bulunamadı.")

    check_team_manager(period.team_id, current_user, db)

    period.status = "EXCUSES_CLOSED"
    db.commit()

    return APIResponse(success=True, message="Mazeret bildirim süreci kapatıldı.")


@router.post("/{period_id}/open-excuses", response_model=APIResponse[dict])
def open_excuses(
    period_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    period = db.query(DutyPeriod).filter(DutyPeriod.id == period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail="Nöbet dönemi bulunamadı.")

    check_team_manager(period.team_id, current_user, db)

    period.status = "EXCUSES_OPEN"
    db.commit()

    return APIResponse(success=True, message="Mazeret bildirim süreci açıldı.")
