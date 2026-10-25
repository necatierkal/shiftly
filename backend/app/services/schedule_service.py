from datetime import datetime, date, timedelta, time
from typing import List, Optional, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from app.models.models import (
    DutyPeriod,
    DutyExcuse,
    DutyPlan,
    DutyPlanShift,
    PlanAuditLog,
    Shift,
    ShiftType,
    Team,
    TeamMember,
    User,
)
from app.schemas.schemas import PlanGenerateRequest, DutyPlanShiftUpdate


class ScheduleService:
    @staticmethod
    def is_excuse_active(
        excuse: DutyExcuse,
        shift_date: date,
        start_datetime: datetime,
        end_datetime: datetime,
    ) -> bool:
        """Checks if an approved excuse covers the shift time window."""
        if excuse.status != "APPROVED":
            return False

        # Date range check
        if not (excuse.start_date <= shift_date <= excuse.end_date):
            return False

        # If all day, it covers the entire day
        if excuse.is_all_day:
            return True

        # Time range check
        if excuse.start_time and excuse.end_time:
            try:
                sh, sm = [int(p) for p in excuse.start_time.split(":")]
                eh, em = [int(p) for p in excuse.end_time.split(":")]
                excuse_s = datetime(shift_date.year, shift_date.month, shift_date.day, sh, sm)
                excuse_e = datetime(shift_date.year, shift_date.month, shift_date.day, eh, em)
                if excuse_e <= excuse_s:
                    excuse_e += timedelta(days=1)

                # Overlap: start1 < end2 and end1 > start2
                return start_datetime < excuse_e and end_datetime > excuse_s
            except Exception:
                return True

        return True

    @staticmethod
    def generate_draft_plan(
        db: Session,
        manager_id: int,
        req: PlanGenerateRequest,
    ) -> DutyPlan:
        """
        Generates an intelligent duty schedule draft respecting:
        1. Approved excuses (Hard constraints)
        2. No double-booking / shift overlaps
        3. Minimum rest hours between shifts (e.g., 11 hours)
        4. Fair distribution of workload, night shifts, and weekend shifts
        5. Unassigned shift detection when constraints prevent assignment
        """
        period = db.query(DutyPeriod).filter(DutyPeriod.id == req.period_id).first()
        if not period:
            raise ValueError("Nöbet dönemi bulunamadı.")

        team = db.query(Team).filter(Team.id == req.team_id).first()
        if not team:
            raise ValueError("Ekip bulunamadı.")

        # Active team members
        memberships = (
            db.query(TeamMember)
            .join(User, TeamMember.user_id == User.id)
            .filter(TeamMember.team_id == req.team_id, User.is_active == True)
            .all()
        )
        staff_users = [m.user for m in memberships]
        if not staff_users:
            raise ValueError("Ekipte aktif personel bulunamadı.")

        # Shift types to schedule
        if req.shift_type_ids:
            shift_types = (
                db.query(ShiftType)
                .filter(ShiftType.id.in_(req.shift_type_ids))
                .all()
            )
        else:
            # Default to working shift types
            shift_types = (
                db.query(ShiftType)
                .filter(ShiftType.is_working == True)
                .all()
            )
            if not shift_types:
                # Fallback to all shift types
                shift_types = db.query(ShiftType).all()

        if not shift_types:
            raise ValueError("Tanımlı vardiya türü bulunamadı.")

        # Fetch all approved excuses for this period
        approved_excuses = (
            db.query(DutyExcuse)
            .filter(
                DutyExcuse.period_id == req.period_id,
                DutyExcuse.status == "APPROVED",
            )
            .all()
        )
        excuses_by_user: Dict[int, List[DutyExcuse]] = {}
        for ex in approved_excuses:
            excuses_by_user.setdefault(ex.user_id, []).append(ex)

        # Check existing draft plans for this period and team to determine version
        existing_plans_count = (
            db.query(DutyPlan)
            .filter(DutyPlan.period_id == req.period_id, DutyPlan.team_id == req.team_id)
            .count()
        )
        version = existing_plans_count + 1

        # Create new DutyPlan
        plan = DutyPlan(
            period_id=req.period_id,
            team_id=req.team_id,
            version=version,
            status="DRAFT",
            change_note=f"Sürüm {version} otomatik oluşturuldu.",
            rules_config={
                "min_rest_hours": req.min_rest_hours,
                "max_shifts_per_person": req.max_shifts_per_person,
                "fair_night_distribution": req.fair_night_distribution,
                "fair_weekend_distribution": req.fair_weekend_distribution,
            },
        )
        db.add(plan)
        db.commit()
        db.refresh(plan)

        # Tracking state during generation
        # user_id -> {'total_shifts': int, 'total_hours': float, 'night_shifts': int, 'weekend_shifts': int, 'last_end_datetime': datetime}
        user_stats: Dict[int, Dict[str, Any]] = {
            u.id: {
                "total_shifts": 0,
                "total_hours": 0.0,
                "night_shifts": 0,
                "weekend_shifts": 0,
                "shifts": [],  # List of (start_dt, end_dt)
            }
            for u in staff_users
        }

        min_rest_delta = timedelta(hours=req.min_rest_hours or 11)
        cur_date = period.start_date
        plan_shifts: List[DutyPlanShift] = []

        while cur_date <= period.end_date:
            is_weekend = cur_date.weekday() in (5, 6)  # Saturday=5, Sunday=6

            for st in shift_types:
                # Parse start & end datetime
                try:
                    sh, sm = [int(p) for p in st.start_time.split(":")]
                    eh, em = [int(p) for p in st.end_time.split(":")]
                except Exception:
                    sh, sm, eh, em = 8, 0, 16, 0

                s_dt = datetime(cur_date.year, cur_date.month, cur_date.day, sh, sm)
                if st.name == "24 Saat Nöbet" or (eh == sh and em == sm):
                    e_dt = s_dt + timedelta(hours=24)
                elif eh < sh or (eh == sh and em < sm) or st.is_night:
                    e_dt = datetime(cur_date.year, cur_date.month, cur_date.day, eh, em) + timedelta(days=1)
                else:
                    e_dt = datetime(cur_date.year, cur_date.month, cur_date.day, eh, em)

                duration_hours = (e_dt - s_dt).total_seconds() / 3600.0

                # Find eligible candidates
                eligible_candidates: List[Tuple[User, float]] = []

                for u in staff_users:
                    stats = user_stats[u.id]

                    # 1. Check max shifts limit
                    if req.max_shifts_per_person and stats["total_shifts"] >= req.max_shifts_per_person:
                        continue

                    # 2. Check approved excuses
                    user_excuses = excuses_by_user.get(u.id, [])
                    has_conflict_excuse = any(
                        ScheduleService.is_excuse_active(ex, cur_date, s_dt, e_dt)
                        for ex in user_excuses
                        if ex.is_hard_constraint
                    )
                    if has_conflict_excuse:
                        continue

                    # 3. Check overlapping shifts & minimum rest hours with previously assigned shifts
                    has_overlap = False
                    violates_rest = False
                    for prev_s, prev_e in stats["shifts"]:
                        # Overlap:
                        if s_dt < prev_e and e_dt > prev_s:
                            has_overlap = True
                            break
                        # Rest:
                        if s_dt >= prev_e and (s_dt - prev_e) < min_rest_delta:
                            violates_rest = True
                            break
                        if prev_s >= e_dt and (prev_s - e_dt) < min_rest_delta:
                            violates_rest = True
                            break

                    if has_overlap or violates_rest:
                        continue

                    # Candidate is eligible. Calculate score (lower score = higher priority)
                    # Base score on total assigned shifts/hours to ensure balance
                    score = float(stats["total_shifts"] * 10 + stats["total_hours"])

                    # If night shift, weight by night shift count
                    if req.fair_night_distribution and st.is_night:
                        score += stats["night_shifts"] * 15

                    # If weekend shift, weight by weekend shift count
                    if req.fair_weekend_distribution and is_weekend:
                        score += stats["weekend_shifts"] * 15

                    eligible_candidates.append((u, score))

                if eligible_candidates:
                    # Select candidate with lowest score
                    eligible_candidates.sort(key=lambda x: x[1])
                    selected_user = eligible_candidates[0][0]

                    # Update selected user's stats
                    u_stats = user_stats[selected_user.id]
                    u_stats["total_shifts"] += 1
                    u_stats["total_hours"] += duration_hours
                    if st.is_night:
                        u_stats["night_shifts"] += 1
                    if is_weekend:
                        u_stats["weekend_shifts"] += 1
                    u_stats["shifts"].append((s_dt, e_dt))

                    plan_shift = DutyPlanShift(
                        plan_id=plan.id,
                        shift_type_id=st.id,
                        assigned_user_id=selected_user.id,
                        date=cur_date,
                        start_datetime=s_dt,
                        end_datetime=e_dt,
                        note=f"{st.name} (Otomatik Atandı)",
                        is_unassigned=False,
                    )
                else:
                    # No candidate could be assigned without violating a hard constraint
                    plan_shift = DutyPlanShift(
                        plan_id=plan.id,
                        shift_type_id=st.id,
                        assigned_user_id=None,
                        date=cur_date,
                        start_datetime=s_dt,
                        end_datetime=e_dt,
                        note="Personel Atanamadı",
                        is_unassigned=True,
                        unassigned_reason="Tüm personel mazeretli veya asgari dinlenme kuralı nedeniyle uygun değil.",
                    )

                db.add(plan_shift)
                plan_shifts.append(plan_shift)

            cur_date += timedelta(days=1)

        db.commit()

        # Audit log
        audit = PlanAuditLog(
            plan_id=plan.id,
            user_id=manager_id,
            action="CREATE_DRAFT",
            details={
                "version": version,
                "total_shifts": len(plan_shifts),
                "unassigned_count": sum(1 for s in plan_shifts if s.is_unassigned),
            },
        )
        db.add(audit)
        db.commit()
        db.refresh(plan)

        return plan

    @staticmethod
    def update_shift_assignment(
        db: Session,
        manager_id: int,
        shift_id: int,
        data: DutyPlanShiftUpdate,
    ) -> Tuple[DutyPlanShift, Optional[str]]:
        """Manually assigns or unassigns a shift in a draft plan with conflict checking."""
        shift = db.query(DutyPlanShift).filter(DutyPlanShift.id == shift_id).first()
        if not shift:
            raise ValueError("Vardiya kaydı bulunamadı.")

        warning = None

        if data.assigned_user_id:
            user = db.query(User).filter(User.id == data.assigned_user_id).first()
            if not user:
                raise ValueError("Atanacak personel bulunamadı.")

            # Check for conflict with other shifts in the same plan
            conflict = (
                db.query(DutyPlanShift)
                .filter(
                    DutyPlanShift.plan_id == shift.plan_id,
                    DutyPlanShift.id != shift.id,
                    DutyPlanShift.assigned_user_id == data.assigned_user_id,
                    DutyPlanShift.start_datetime < shift.end_datetime,
                    DutyPlanShift.end_datetime > shift.start_datetime,
                )
                .first()
            )
            if conflict:
                if not data.override_reason:
                    return shift, "Seçilen personelin bu saatte başka bir nöbeti bulunuyor."
                warning = f"Uyarı: Çakışma mevcut ({data.override_reason})"

            shift.assigned_user_id = data.assigned_user_id
            shift.is_unassigned = False
            shift.unassigned_reason = None
            shift.violation_warning = warning
        else:
            shift.assigned_user_id = None
            shift.is_unassigned = True
            shift.unassigned_reason = "Manuel olarak boş bırakıldı."

        if data.note is not None:
            shift.note = data.note
        if data.location is not None:
            shift.location = data.location

        db.commit()
        db.refresh(shift)

        # Audit log
        audit = PlanAuditLog(
            plan_id=shift.plan_id,
            user_id=manager_id,
            action="MANUAL_EDIT",
            details={
                "shift_id": shift.id,
                "assigned_user_id": shift.assigned_user_id,
                "warning": warning,
            },
        )
        db.add(audit)
        db.commit()

        return shift, None

    @staticmethod
    def publish_plan(
        db: Session,
        manager_id: int,
        plan_id: int,
        change_note: Optional[str] = None,
    ) -> DutyPlan:
        """Approves and publishes a plan, syncing official shifts to the 'shifts' table."""
        plan = db.query(DutyPlan).filter(DutyPlan.id == plan_id).first()
        if not plan:
            raise ValueError("Plan bulunamadı.")

        # Archive previously published plans for this period and team
        prev_published = (
            db.query(DutyPlan)
            .filter(
                DutyPlan.period_id == plan.period_id,
                DutyPlan.team_id == plan.team_id,
                DutyPlan.id != plan.id,
                DutyPlan.status == "PUBLISHED",
            )
            .all()
        )
        for prev in prev_published:
            prev.status = "ARCHIVED"

        # Mark current plan as published
        plan.status = "PUBLISHED"
        plan.published_at = datetime.utcnow()
        plan.published_by = manager_id
        if change_note:
            plan.change_note = change_note

        # Update period status to PUBLISHED
        period = db.query(DutyPeriod).filter(DutyPeriod.id == plan.period_id).first()
        if period:
            period.status = "PUBLISHED"

        # Sync assigned shifts to official shifts table
        for ps in plan.shifts:
            if ps.assigned_user_id and not ps.is_unassigned:
                # Check if official shift already exists for this date and user
                existing = (
                    db.query(Shift)
                    .filter(
                        Shift.user_id == ps.assigned_user_id,
                        Shift.date == ps.date,
                        Shift.shift_type_id == ps.shift_type_id,
                    )
                    .first()
                )
                if not existing:
                    off_shift = Shift(
                        user_id=ps.assigned_user_id,
                        shift_type_id=ps.shift_type_id,
                        date=ps.date,
                        start_datetime=ps.start_datetime,
                        end_datetime=ps.end_datetime,
                        note=ps.note or "Onaylı Nöbet Planı",
                        location=ps.location,
                        status="scheduled",
                    )
                    db.add(off_shift)

        # Audit log
        audit = PlanAuditLog(
            plan_id=plan.id,
            user_id=manager_id,
            action="PUBLISH",
            details={
                "version": plan.version,
                "change_note": change_note,
                "published_at": plan.published_at.isoformat(),
            },
        )
        db.add(audit)
        db.commit()
        db.refresh(plan)

        return plan
