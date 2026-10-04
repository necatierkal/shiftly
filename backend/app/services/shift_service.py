from datetime import datetime, date, timedelta, time
from typing import List, Optional, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from app.models.models import Shift, ShiftType, Reminder, WorkPattern
from app.schemas.schemas import ShiftCreate, ShiftUpdate, PatternDayDef


class ShiftService:
    @staticmethod
    def check_overlap(
        db: Session,
        user_id: int,
        start_datetime: datetime,
        end_datetime: datetime,
        exclude_shift_id: Optional[int] = None,
    ) -> Optional[Shift]:
        """
        Check if any active shift for the user overlaps with [start_datetime, end_datetime].
        Two intervals overlap if start1 < end2 and end1 > start2.
        """
        query = db.query(Shift).filter(
            Shift.user_id == user_id,
            Shift.status != "cancelled",
            Shift.start_datetime < end_datetime,
            Shift.end_datetime > start_datetime,
        )
        if exclude_shift_id:
            query = query.filter(Shift.id != exclude_shift_id)
        return query.first()

    @staticmethod
    def create_shift(
        db: Session,
        user_id: int,
        shift_in: ShiftCreate,
    ) -> Tuple[Optional[Shift], Optional[str]]:
        # Conflict check
        overlap = ShiftService.check_overlap(
            db, user_id, shift_in.start_datetime, shift_in.end_datetime
        )
        if overlap:
            return None, "Bu vardiya mevcut vardiyanızla çakışıyor."

        shift = Shift(
            user_id=user_id,
            shift_type_id=shift_in.shift_type_id,
            date=shift_in.date,
            start_datetime=shift_in.start_datetime,
            end_datetime=shift_in.end_datetime,
            note=shift_in.note,
            location=shift_in.location,
            status="scheduled",
        )
        db.add(shift)
        db.commit()
        db.refresh(shift)

        # Create reminder if requested
        if shift_in.reminder_minutes:
            reminder = Reminder(
                user_id=user_id,
                shift_id=shift.id,
                reminder_minutes=shift_in.reminder_minutes,
                is_enabled=True,
            )
            db.add(reminder)
            db.commit()

        return shift, None

    @staticmethod
    def generate_pattern_shifts(
        db: Session,
        user_id: int,
        cycle_type: str,
        start_date: date,
        end_date: date,
        custom_pattern: Optional[List[PatternDayDef]] = None,
        overwrite_conflicts: bool = False,
    ) -> Tuple[List[Shift], int]:
        """
        Generates shifts according to a repeating pattern between start_date and end_date.
        Built-in patterns:
        - "24/48": 3-day cycle (Day 0: Work 24h, Day 1: Off, Day 2: Off)
        - "24/72": 4-day cycle (Day 0: Work 24h, Day 1: Off, Day 2: Off, Day 3: Off)
        - "12/24": 2-day cycle (Day 0: Work 12h, Day 1: Off)
        - "12/36": 2-day cycle or custom
        - "8/16": standard daily work
        - "2 vardiya": Gündüz / Gece dönüşümlü
        - "3 vardiya": Sabah / Akşam / Gece dönüşümlü
        - "custom": Uses user defined sequence of days
        """
        # Fetch or resolve shift types for this user
        user_shift_types = db.query(ShiftType).filter(
            or_(ShiftType.user_id == user_id, ShiftType.user_id.is_(None))
        ).all()
        type_by_name: Dict[str, ShiftType] = {st.name.lower(): st for st in user_shift_types}

        work_type = type_by_name.get("gündüz") or (user_shift_types[0] if user_shift_types else None)
        off_type = type_by_name.get("izin") or (user_shift_types[-1] if user_shift_types else None)
        night_type = type_by_name.get("gece") or work_type

        # Build pattern cycle list of (is_working, shift_type_id, start_time_str, end_time_str, is_next_day_end)
        cycle_steps: List[Dict[str, Any]] = []

        if cycle_type == "24/48":
            cycle_steps = [
                {"is_working": True, "type": work_type, "start_time": "08:00", "end_time": "08:00", "is_24h": True, "name": "24 Saat Nöbet"},
                {"is_working": False, "type": off_type, "start_time": "00:00", "end_time": "23:59", "is_24h": False, "name": "İzin"},
                {"is_working": False, "type": off_type, "start_time": "00:00", "end_time": "23:59", "is_24h": False, "name": "İzin"},
            ]
        elif cycle_type == "24/72":
            cycle_steps = [
                {"is_working": True, "type": work_type, "start_time": "08:00", "end_time": "08:00", "is_24h": True, "name": "24 Saat Nöbet"},
                {"is_working": False, "type": off_type, "start_time": "00:00", "end_time": "23:59", "is_24h": False, "name": "İzin"},
                {"is_working": False, "type": off_type, "start_time": "00:00", "end_time": "23:59", "is_24h": False, "name": "İzin"},
                {"is_working": False, "type": off_type, "start_time": "00:00", "end_time": "23:59", "is_24h": False, "name": "İzin"},
            ]
        elif cycle_type == "12/24":
            cycle_steps = [
                {"is_working": True, "type": work_type, "start_time": "08:00", "end_time": "20:00", "is_24h": False, "name": "Gündüz (12s)"},
                {"is_working": False, "type": off_type, "start_time": "00:00", "end_time": "23:59", "is_24h": False, "name": "İzin"},
            ]
        elif cycle_type == "12/36":
            cycle_steps = [
                {"is_working": True, "type": night_type, "start_time": "20:00", "end_time": "08:00", "is_24h": False, "name": "Gece (12s)", "cross_midnight": True},
                {"is_working": False, "type": off_type, "start_time": "00:00", "end_time": "23:59", "is_24h": False, "name": "İzin"},
            ]
        elif custom_pattern:
            for p in custom_pattern:
                target_type = None
                if p.shift_type_id:
                    target_type = db.query(ShiftType).filter(ShiftType.id == p.shift_type_id).first()
                elif p.shift_type_name:
                    target_type = type_by_name.get(p.shift_type_name.lower())

                if not target_type:
                    target_type = work_type if p.is_working else off_type

                cycle_steps.append({
                    "is_working": p.is_working,
                    "type": target_type,
                    "start_time": target_type.start_time if target_type else "08:00",
                    "end_time": target_type.end_time if target_type else "16:00",
                    "is_24h": False,
                    "name": target_type.name if target_type else "Vardiya",
                })
        else:
            # Default fallback 24/48
            cycle_steps = [
                {"is_working": True, "type": work_type, "start_time": "08:00", "end_time": "08:00", "is_24h": True, "name": "Çalışma"},
                {"is_working": False, "type": off_type, "start_time": "00:00", "end_time": "23:59", "is_24h": False, "name": "İzin"},
                {"is_working": False, "type": off_type, "start_time": "00:00", "end_time": "23:59", "is_24h": False, "name": "İzin"},
            ]

        cycle_len = len(cycle_steps)
        if cycle_len == 0:
            return [], 0

        created_shifts: List[Shift] = []
        conflicts_count = 0
        current_curr = start_date
        step_idx = 0

        while current_curr <= end_date:
            step = cycle_steps[step_idx % cycle_len]
            st_type = step["type"]
            is_working = step["is_working"]

            # Parse start and end datetimes
            start_parts = [int(p) for p in step["start_time"].split(":")]
            end_parts = [int(p) for p in step["end_time"].split(":")]

            s_dt = datetime(current_curr.year, current_curr.month, current_curr.day, start_parts[0], start_parts[1])
            
            if step.get("is_24h"):
                e_dt = s_dt + timedelta(hours=24)
            elif step.get("cross_midnight") or (end_parts[0] < start_parts[0]):
                e_dt = datetime(current_curr.year, current_curr.month, current_curr.day, end_parts[0], end_parts[1]) + timedelta(days=1)
            else:
                e_dt = datetime(current_curr.year, current_curr.month, current_curr.day, end_parts[0], end_parts[1])

            overlap = ShiftService.check_overlap(db, user_id, s_dt, e_dt)
            if overlap:
                if overwrite_conflicts:
                    db.delete(overlap)
                    db.commit()
                else:
                    conflicts_count += 1
                    current_curr += timedelta(days=1)
                    step_idx += 1
                    continue

            new_shift = Shift(
                user_id=user_id,
                shift_type_id=st_type.id if st_type else 1,
                date=current_curr,
                start_datetime=s_dt,
                end_datetime=e_dt,
                note=f"Otomatik Döngü ({cycle_type})",
                status="scheduled",
            )
            db.add(new_shift)
            created_shifts.append(new_shift)

            current_curr += timedelta(days=1)
            step_idx += 1

        db.commit()
        for s in created_shifts:
            db.refresh(s)

        return created_shifts, conflicts_count
