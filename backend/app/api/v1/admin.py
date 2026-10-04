from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.models import User, Shift, Team, ShiftSwap
from app.schemas.schemas import APIResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/admin", tags=["Admin (Internal)"])


@router.get("/metrics", response_model=APIResponse[dict])
def get_admin_metrics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_count = db.query(User).count()
    active_user_count = db.query(User).filter(User.is_active == True).count()
    team_count = db.query(Team).count()
    shift_count = db.query(Shift).count()
    swap_count = db.query(ShiftSwap).count()

    return APIResponse(
        success=True,
        data={
            "user_count": user_count,
            "active_user_count": active_user_count,
            "team_count": team_count,
            "shift_count": shift_count,
            "swap_count": swap_count,
            "health": "healthy",
        },
    )
