from typing import List, Optional
from datetime import datetime
import urllib.parse
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.models import (
    DutyPlan,
    DutyPlanShift,
    DutyPeriod,
    Team,
    User,
    TeamMember,
)
from app.schemas.schemas import (
    APIResponse,
    PlanGenerateRequest,
    PlanPublishRequest,
    DutyPlanShiftUpdate,
    DutyPlanResponse,
    DutyPlanShiftResponse,
)
from app.services.schedule_service import ScheduleService
from app.services.export_service import ExportService
from app.api.deps import get_current_user, check_team_manager, check_team_member

router = APIRouter(prefix="/plans", tags=["Duty Plans & Scheduling (Nöbet Planlama)"])


@router.post("/generate", response_model=APIResponse[DutyPlanResponse])
def generate_schedule_plan(
    req: PlanGenerateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_team_manager(req.team_id, current_user, db)

    try:
        plan = ScheduleService.generate_draft_plan(
            db=db,
            manager_id=current_user.id,
            req=req,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    res = DutyPlanResponse.model_validate(plan)
    res.unassigned_shifts_count = sum(1 for s in plan.shifts if s.is_unassigned)

    msg = f"Nöbet taslağı oluşturuldu. ({len(plan.shifts)} vardiya, {res.unassigned_shifts_count} atanmamış)"
    return APIResponse(success=True, message=msg, data=res)


@router.get("", response_model=APIResponse[List[DutyPlanResponse]])
def get_plans(
    period_id: Optional[int] = None,
    team_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(DutyPlan)

    if team_id:
        check_team_member(team_id, current_user, db)
        query = query.filter(DutyPlan.team_id == team_id)

    if period_id:
        period = db.query(DutyPeriod).filter(DutyPeriod.id == period_id).first()
        if not period:
            raise HTTPException(status_code=404, detail="Dönem bulunamadı.")
        check_team_member(period.team_id, current_user, db)
        query = query.filter(DutyPlan.period_id == period_id)

    # Check if user is manager; if staff, only show PUBLISHED plans
    is_mgr = False
    if team_id:
        try:
            check_team_manager(team_id, current_user, db)
            is_mgr = True
        except HTTPException:
            is_mgr = False
    elif current_user.role in ["admin", "manager"]:
        is_mgr = True

    if not is_mgr:
        query = query.filter(DutyPlan.status == "PUBLISHED")

    plans = query.order_by(DutyPlan.created_at.desc()).all()
    result = []
    for p in plans:
        item = DutyPlanResponse.model_validate(p)
        item.unassigned_shifts_count = sum(1 for s in p.shifts if s.is_unassigned)
        result.append(item)

    return APIResponse(success=True, data=result)


@router.get("/published/current", response_model=APIResponse[Optional[DutyPlanResponse]])
def get_current_published_plan(
    team_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_team_member(team_id, current_user, db)

    plan = (
        db.query(DutyPlan)
        .filter(DutyPlan.team_id == team_id, DutyPlan.status == "PUBLISHED")
        .order_by(DutyPlan.published_at.desc())
        .first()
    )

    if not plan:
        return APIResponse(success=True, message="Yayımlanmış aktif plan bulunamadı.", data=None)

    res = DutyPlanResponse.model_validate(plan)
    res.unassigned_shifts_count = sum(1 for s in plan.shifts if s.is_unassigned)
    return APIResponse(success=True, data=res)


@router.get("/{plan_id}", response_model=APIResponse[DutyPlanResponse])
def get_plan(
    plan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = db.query(DutyPlan).filter(DutyPlan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan bulunamadı.")

    check_team_member(plan.team_id, current_user, db)

    # If plan is not published, only managers can view it
    if plan.status != "PUBLISHED":
        check_team_manager(plan.team_id, current_user, db)

    res = DutyPlanResponse.model_validate(plan)
    res.unassigned_shifts_count = sum(1 for s in plan.shifts if s.is_unassigned)
    return APIResponse(success=True, data=res)


@router.put("/{plan_id}/shifts/{shift_id}", response_model=APIResponse[DutyPlanShiftResponse])
def update_plan_shift(
    plan_id: int,
    shift_id: int,
    data: DutyPlanShiftUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = db.query(DutyPlan).filter(DutyPlan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan bulunamadı.")

    check_team_manager(plan.team_id, current_user, db)

    try:
        updated_shift, error = ScheduleService.update_shift_assignment(
            db=db,
            manager_id=current_user.id,
            shift_id=shift_id,
            data=data,
        )
        if error:
            raise HTTPException(status_code=409, detail=error)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return APIResponse(
        success=True,
        message="Vardiya ataması güncellendi.",
        data=DutyPlanShiftResponse.model_validate(updated_shift),
    )


@router.post("/{plan_id}/publish", response_model=APIResponse[DutyPlanResponse])
def publish_plan(
    plan_id: int,
    pub_in: Optional[PlanPublishRequest] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = db.query(DutyPlan).filter(DutyPlan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan bulunamadı.")

    check_team_manager(plan.team_id, current_user, db)

    try:
        published_plan = ScheduleService.publish_plan(
            db=db,
            manager_id=current_user.id,
            plan_id=plan_id,
            change_note=pub_in.change_note if pub_in else None,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    res = DutyPlanResponse.model_validate(published_plan)
    res.unassigned_shifts_count = sum(1 for s in published_plan.shifts if s.is_unassigned)

    return APIResponse(
        success=True,
        message="Nöbet planı başarıyla onaylandı ve personelin erişimine yayımlandı!",
        data=res,
    )


@router.get("/{plan_id}/export/excel")
def export_excel(
    plan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = db.query(DutyPlan).filter(DutyPlan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan bulunamadı.")

    check_team_member(plan.team_id, current_user, db)

    # Non-managers can only export published plans
    if plan.status != "PUBLISHED":
        check_team_manager(plan.team_id, current_user, db)

    excel_file = ExportService.generate_excel(plan, db)

    clean_team_name = plan.team.name.replace(" ", "_")
    filename = f"Nobet_Plani_{clean_team_name}_v{plan.version}.xlsx"
    encoded_filename = urllib.parse.quote(filename)

    return StreamingResponse(
        excel_file,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f"attachment; filename*=UTF-8''{encoded_filename}",
        },
    )


@router.get("/{plan_id}/export/pdf")
def export_pdf(
    plan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = db.query(DutyPlan).filter(DutyPlan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan bulunamadı.")

    check_team_member(plan.team_id, current_user, db)

    if plan.status != "PUBLISHED":
        check_team_manager(plan.team_id, current_user, db)

    pdf_file = ExportService.generate_pdf(plan, db)

    clean_team_name = plan.team.name.replace(" ", "_")
    filename = f"Nobet_Plani_{clean_team_name}_v{plan.version}.pdf"
    encoded_filename = urllib.parse.quote(filename)

    return StreamingResponse(
        pdf_file,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f"attachment; filename*=UTF-8''{encoded_filename}",
        },
    )
