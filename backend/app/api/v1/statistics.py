from datetime import datetime, date, timedelta
from typing import Dict, Any
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.models import User, Shift, ShiftType
from app.schemas.schemas import APIResponse, StatisticsResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/statistics", tags=["Statistics"])


@router.get("", response_model=APIResponse[StatisticsResponse])
def get_user_statistics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    today = date.today()
    # Calculate week boundaries (Monday to Sunday)
    start_of_week = today - timedelta(days=today.weekday())
    end_of_week = start_of_week + timedelta(days=6)

    # Calculate month boundaries
    start_of_month = date(today.year, today.month, 1)
    if today.month == 12:
        end_of_month = date(today.year + 1, 1, 1) - timedelta(days=1)
    else:
        end_of_month = date(today.year, today.month + 1, 1) - timedelta(days=1)

    # Fetch shifts for this month
    month_shifts = (
        db.query(Shift)
        .filter(
            Shift.user_id == current_user.id,
            Shift.date >= start_of_month,
            Shift.date <= end_of_month,
            Shift.status != "cancelled",
        )
        .all()
    )

    # Fetch shifts for this week
    week_shifts = (
        db.query(Shift)
        .filter(
            Shift.user_id == current_user.id,
            Shift.date >= start_of_week,
            Shift.date <= end_of_week,
            Shift.status != "cancelled",
        )
        .all()
    )

    def calc_hours(shift_list):
        total = 0.0
        for s in shift_list:
            if s.shift_type and s.shift_type.is_working:
                diff = s.end_datetime - s.start_datetime
                total += max(0.0, diff.total_seconds() / 3600.0)
        return total

    total_week_hours = calc_hours(week_shifts)
    total_month_hours = calc_hours(month_shifts)

    night_hours = 0.0
    day_count = 0
    night_count = 0
    off_count = 0
    weekend_count = 0

    for s in month_shifts:
        st = s.shift_type
        if st and not st.is_working:
            off_count += 1
        elif st and st.is_night:
            night_count += 1
            diff = s.end_datetime - s.start_datetime
            night_hours += max(0.0, diff.total_seconds() / 3600.0)
        elif st and st.is_working:
            day_count += 1

        if s.date.weekday() in (5, 6):  # Saturday or Sunday
            weekend_count += 1

    return APIResponse(
        success=True,
        data=StatisticsResponse(
            total_hours_this_week=round(total_week_hours, 1),
            total_hours_this_month=round(total_month_hours, 1),
            night_shift_hours=round(night_hours, 1),
            off_days_count=off_count,
            total_shifts_count=len(month_shifts),
            day_shift_count=day_count,
            night_shift_count=night_count,
            weekend_shifts_count=weekend_count,
            distribution={
                "day_percentage": round((day_count / max(1, day_count + night_count)) * 100, 1),
                "night_percentage": round((night_count / max(1, day_count + night_count)) * 100, 1),
            },
        ),
    )
