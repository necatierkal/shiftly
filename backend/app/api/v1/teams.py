import random
import string
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.models import User, Team, TeamMember, Shift
from app.schemas.schemas import (
    APIResponse,
    TeamCreate,
    TeamJoin,
    TeamResponse,
    ShiftResponse,
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/teams", tags=["Teams"])


def generate_invite_code() -> str:
    chars = string.ascii_uppercase + string.digits
    rand = "".join(random.choices(chars, k=6))
    return f"SHF-{rand}"


@router.get("", response_model=APIResponse[List[TeamResponse]])
def get_my_teams(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Teams where user is member or owner
    memberships = db.query(TeamMember).filter(TeamMember.user_id == current_user.id).all()
    team_ids = [m.team_id for m in memberships]
    teams = db.query(Team).filter(Team.id.in_(team_ids)).all()
    return APIResponse(success=True, data=teams)


@router.post("", response_model=APIResponse[TeamResponse])
def create_team(
    team_in: TeamCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    code = generate_invite_code()
    team = Team(
        owner_id=current_user.id,
        name=team_in.name,
        description=team_in.description,
        invite_code=code,
    )
    db.add(team)
    db.commit()
    db.refresh(team)

    # Add owner as admin/owner member
    member = TeamMember(
        team_id=team.id,
        user_id=current_user.id,
        role="owner",
    )
    db.add(member)
    db.commit()
    db.refresh(team)

    return APIResponse(success=True, message="Ekip oluşturuldu.", data=team)


@router.post("/join", response_model=APIResponse[TeamResponse])
def join_team(
    join_in: TeamJoin,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    team = db.query(Team).filter(Team.invite_code == join_in.invite_code.strip().upper()).first()
    if not team:
        raise HTTPException(status_code=404, detail="Geçersiz davet kodu.")

    existing = (
        db.query(TeamMember)
        .filter(TeamMember.team_id == team.id, TeamMember.user_id == current_user.id)
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Zaten bu ekibin üyesisiniz.")

    member = TeamMember(
        team_id=team.id,
        user_id=current_user.id,
        role="member",
    )
    db.add(member)
    db.commit()
    db.refresh(team)

    return APIResponse(success=True, message=f"'{team.name}' ekibine katıldınız.", data=team)


@router.get("/{team_id}/calendar", response_model=APIResponse[List[dict]])
def get_team_calendar(
    team_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Verify membership
    is_member = (
        db.query(TeamMember)
        .filter(TeamMember.team_id == team_id, TeamMember.user_id == current_user.id)
        .first()
    )
    if not is_member:
        raise HTTPException(status_code=403, detail="Bu ekibin takvimini görüntüleme yetkiniz yok.")

    members = db.query(TeamMember).filter(TeamMember.team_id == team_id).all()
    user_ids = [m.user_id for m in members]

    shifts = (
        db.query(Shift)
        .filter(Shift.user_id.in_(user_ids), Shift.status != "cancelled")
        .order_by(Shift.date.asc())
        .all()
    )

    calendar_data = []
    for s in shifts:
        calendar_data.append({
            "shift_id": s.id,
            "user_id": s.user_id,
            "user_name": f"{s.user.first_name} {s.user.last_name}",
            "date": s.date.isoformat(),
            "shift_type_name": s.shift_type.name if s.shift_type else "Vardiya",
            "shift_type_short": s.shift_type.short_name if s.shift_type else "V",
            "shift_type_color": s.shift_type.color if s.shift_type else "#3157D5",
            "start_time": s.start_datetime.strftime("%H:%M"),
            "end_time": s.end_datetime.strftime("%H:%M"),
        })

    return APIResponse(success=True, data=calendar_data)
