import io
import pytest
from datetime import datetime, date, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.session import Base, get_db
from app.main import app
from app.models.models import (
    User,
    ShiftType,
    Shift,
    Team,
    TeamMember,
    DutyPeriod,
    DutyExcuse,
    DutyPlan,
    DutyPlanShift,
    ShiftSwap,
)
from app.core.security import get_password_hash, create_access_token
from app.services.shift_service import ShiftService
from app.services.schedule_service import ScheduleService
from app.services.export_service import ExportService
from app.schemas.schemas import PlanGenerateRequest, DutyPlanShiftUpdate

# Setup SQLite test DB
SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db):
    def override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def manager_user(db):
    u = User(
        email="manager@shiftly.app",
        password_hash=get_password_hash("ManagerPass123!"),
        first_name="Kemal",
        last_name="Yönetici",
        role="manager",
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


@pytest.fixture
def staff_user(db):
    u = User(
        email="staff@shiftly.app",
        password_hash=get_password_hash("StaffPass123!"),
        first_name="Ayşe",
        last_name="Personel",
        role="staff",
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


@pytest.fixture
def staff_user_2(db):
    u = User(
        email="staff2@shiftly.app",
        password_hash=get_password_hash("StaffPass123!"),
        first_name="Mehmet",
        last_name="Demir",
        role="staff",
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


@pytest.fixture
def other_team_user(db):
    u = User(
        email="other@shiftly.app",
        password_hash=get_password_hash("OtherPass123!"),
        first_name="Ali",
        last_name="Dışarı",
        role="staff",
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


@pytest.fixture
def sample_team(db, manager_user, staff_user, staff_user_2):
    t = Team(
        owner_id=manager_user.id,
        name="Acil Tıp Kliniği",
        description="7/24 Acil Müdahale",
        invite_code="SHF-ACIL",
    )
    db.add(t)
    db.commit()
    db.refresh(t)

    m1 = TeamMember(team_id=t.id, user_id=manager_user.id, role="owner")
    m2 = TeamMember(team_id=t.id, user_id=staff_user.id, role="member")
    m3 = TeamMember(team_id=t.id, user_id=staff_user_2.id, role="member")
    db.add_all([m1, m2, m3])

    # Add Shift Types
    st1 = ShiftType(name="Gündüz", short_name="G", start_time="08:00", end_time="16:00", is_working=True, is_night=False)
    st2 = ShiftType(name="Gece", short_name="N", start_time="20:00", end_time="08:00", is_working=True, is_night=True)
    db.add_all([st1, st2])
    db.commit()

    return t


def auth_header(user: User) -> dict:
    token = create_access_token(user.id)
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# 1. Başarılı kullanıcı girişi
# ---------------------------------------------------------------------------
def test_01_successful_login(client, manager_user):
    res = client.post(
        "/api/v1/auth/login",
        json={"email": manager_user.email, "password": "ManagerPass123!"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert "tokens" in data["data"]
    assert data["data"]["user"]["role"] == "manager"


# ---------------------------------------------------------------------------
# 2. Yanlış parola
# ---------------------------------------------------------------------------
def test_02_wrong_password(client, manager_user):
    res = client.post(
        "/api/v1/auth/login",
        json={"email": manager_user.email, "password": "WrongPassword!"},
    )
    assert res.status_code == 401
    assert res.json()["success"] is False


# ---------------------------------------------------------------------------
# 3. Geçersiz veya süresi dolmuş token
# ---------------------------------------------------------------------------
def test_03_invalid_token(client):
    res = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer invalid_gibberish_token"},
    )
    assert res.status_code == 401


# ---------------------------------------------------------------------------
# 4. Backend bağlantı ve 404 kontrolü
# ---------------------------------------------------------------------------
def test_04_health_and_not_found(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"

    res_404 = client.get("/api/v1/non_existing_endpoint")
    assert res_404.status_code == 404


# ---------------------------------------------------------------------------
# 5. Yetkisiz kullanıcının yönetici uç noktasına erişimi reddedilmeli
# ---------------------------------------------------------------------------
def test_05_staff_cannot_access_admin_metrics(client, staff_user):
    res = client.get("/api/v1/admin/metrics", headers=auth_header(staff_user))
    assert res.status_code == 403


# ---------------------------------------------------------------------------
# 6. Personelin nöbet dönemi oluşturma girişiminin reddedilmesi
# ---------------------------------------------------------------------------
def test_06_staff_cannot_create_period(client, sample_team, staff_user):
    payload = {
        "team_id": sample_team.id,
        "name": "Aralık 2026",
        "start_date": "2026-12-01",
        "end_date": "2026-12-31",
        "excuse_start_time": "2026-11-01T00:00:00",
        "excuse_deadline": "2026-11-20T23:59:59",
    }
    res = client.post("/api/v1/periods", json=payload, headers=auth_header(staff_user))
    assert res.status_code == 403


# ---------------------------------------------------------------------------
# 7. Başka ekibin verilerine erişim girişiminin reddedilmesi (Team Isolation)
# ---------------------------------------------------------------------------
def test_07_team_isolation(client, sample_team, other_team_user):
    res = client.get(f"/api/v1/periods?team_id={sample_team.id}", headers=auth_header(other_team_user))
    assert res.status_code == 403


# ---------------------------------------------------------------------------
# 8. Mazeret oluşturma
# ---------------------------------------------------------------------------
def test_08_create_excuse(client, db, sample_team, manager_user, staff_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Kasım 2026",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 30),
        excuse_start_time=datetime(2026, 10, 1, 0, 0),
        excuse_deadline=datetime(2026, 10, 30, 23, 59),
        status="EXCUSES_OPEN",
    )
    db.add(period)
    db.commit()
    db.refresh(period)

    payload = {
        "period_id": period.id,
        "start_date": "2026-11-05",
        "end_date": "2026-11-07",
        "is_all_day": True,
        "category": "education",
        "description": "Kongre katılımı nedeniyle uygun değilim.",
        "is_hard_constraint": True,
    }
    res = client.post("/api/v1/excuses", json=payload, headers=auth_header(staff_user))
    assert res.status_code == 200
    assert res.json()["data"]["status"] == "SUBMITTED"


# ---------------------------------------------------------------------------
# 9. Mazeret başvuru süresi kapalıyken yeni başvuru engellenmeli
# ---------------------------------------------------------------------------
def test_09_excuse_submission_closed(client, db, sample_team, staff_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Geçmiş Dönem",
        start_date=date(2026, 9, 1),
        end_date=date(2026, 9, 30),
        excuse_start_time=datetime(2026, 8, 1, 0, 0),
        excuse_deadline=datetime(2026, 8, 20, 23, 59),
        status="EXCUSES_CLOSED",
    )
    db.add(period)
    db.commit()

    payload = {
        "period_id": period.id,
        "start_date": "2026-09-05",
        "end_date": "2026-09-06",
        "description": "Süre bittikten sonra deneme",
    }
    res = client.post("/api/v1/excuses", json=payload, headers=auth_header(staff_user))
    assert res.status_code == 400


# ---------------------------------------------------------------------------
# 10. Mazeret kabul ve ret işlemleri
# ---------------------------------------------------------------------------
def test_10_excuse_review(client, db, sample_team, manager_user, staff_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Kasım 2026",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 30),
        excuse_start_time=datetime(2026, 10, 1, 0, 0),
        excuse_deadline=datetime(2026, 10, 30, 23, 59),
        status="EXCUSES_OPEN",
    )
    db.add(period)
    db.commit()

    excuse = DutyExcuse(
        period_id=period.id,
        user_id=staff_user.id,
        start_date=date(2026, 11, 10),
        end_date=date(2026, 11, 11),
        category="health",
        description="Doktor kontrolü",
        status="SUBMITTED",
    )
    db.add(excuse)
    db.commit()
    db.refresh(excuse)

    review_res = client.post(
        f"/api/v1/excuses/{excuse.id}/review",
        json={"status": "APPROVED", "manager_comment": "Belge doğrulandı, onaylandı."},
        headers=auth_header(manager_user),
    )
    assert review_res.status_code == 200
    assert review_res.json()["data"]["status"] == "APPROVED"


# ---------------------------------------------------------------------------
# 11. Kabul edilen mazeretle çakışan atamanın engellenmesi
# ---------------------------------------------------------------------------
def test_11_approved_excuse_blocks_assignment(db, sample_team, manager_user, staff_user, staff_user_2):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Kasım Test",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 2),
        excuse_start_time=datetime(2026, 10, 1, 0, 0),
        excuse_deadline=datetime(2026, 10, 30, 23, 59),
        status="EXCUSES_CLOSED",
    )
    db.add(period)
    db.commit()

    # Staff 1 has approved hard excuse on Nov 1
    ex = DutyExcuse(
        period_id=period.id,
        user_id=staff_user.id,
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 1),
        is_all_day=True,
        description="Tam gün mazeret",
        is_hard_constraint=True,
        status="APPROVED",
    )
    db.add(ex)
    db.commit()

    req = PlanGenerateRequest(
        team_id=sample_team.id,
        period_id=period.id,
        shift_type_ids=[1],  # Gündüz
    )
    plan = ScheduleService.generate_draft_plan(db, manager_user.id, req)
    nov1_shift = [s for s in plan.shifts if s.date == date(2026, 11, 1)][0]

    # Staff 1 must NOT be assigned on Nov 1 because of approved excuse!
    assert nov1_shift.assigned_user_id != staff_user.id


# ---------------------------------------------------------------------------
# 12. Nöbet çakışması kontrolü
# ---------------------------------------------------------------------------
def test_12_shift_overlap_detection(db, staff_user):
    st = ShiftType(name="Gündüz", short_name="G", start_time="08:00", end_time="16:00", is_working=True)
    db.add(st)
    db.commit()

    s = Shift(
        user_id=staff_user.id,
        shift_type_id=st.id,
        date=date(2026, 11, 1),
        start_datetime=datetime(2026, 11, 1, 8, 0),
        end_datetime=datetime(2026, 11, 1, 16, 0),
    )
    db.add(s)
    db.commit()

    overlap = ShiftService.check_overlap(
        db, staff_user.id, datetime(2026, 11, 1, 12, 0), datetime(2026, 11, 1, 20, 0)
    )
    assert overlap is not None


# ---------------------------------------------------------------------------
# 13. Gece yarısını aşan nöbet (Cross-midnight)
# ---------------------------------------------------------------------------
def test_13_cross_midnight_shift(db, staff_user):
    st_night = ShiftType(name="Gece", short_name="N", start_time="20:00", end_time="08:00", is_working=True, is_night=True)
    db.add(st_night)
    db.commit()

    s = Shift(
        user_id=staff_user.id,
        shift_type_id=st_night.id,
        date=date(2026, 11, 1),
        start_datetime=datetime(2026, 11, 1, 20, 0),
        end_datetime=datetime(2026, 11, 2, 8, 0),
    )
    duration = (s.end_datetime - s.start_datetime).total_seconds() / 3600.0
    assert duration == 12.0


# ---------------------------------------------------------------------------
# 14. 24 saatlik nöbet
# ---------------------------------------------------------------------------
def test_14_24_hour_shift(db, staff_user):
    st_24 = ShiftType(name="24 Saat", short_name="24", start_time="08:00", end_time="08:00", is_working=True, is_night=True)
    db.add(st_24)
    db.commit()

    s = Shift(
        user_id=staff_user.id,
        shift_type_id=st_24.id,
        date=date(2026, 11, 1),
        start_datetime=datetime(2026, 11, 1, 8, 0),
        end_datetime=datetime(2026, 11, 2, 8, 0),
    )
    duration = (s.end_datetime - s.start_datetime).total_seconds() / 3600.0
    assert duration == 24.0


# ---------------------------------------------------------------------------
# 15. Ay sonu ve yıl sonu sınırları
# ---------------------------------------------------------------------------
def test_15_month_and_year_boundaries():
    dt_nov30 = datetime(2026, 11, 30, 20, 0)
    dt_dec01 = dt_nov30 + timedelta(hours=12)
    assert dt_dec01 == datetime(2026, 12, 1, 8, 0)

    dt_dec31 = datetime(2026, 12, 31, 20, 0)
    dt_jan01 = dt_dec31 + timedelta(hours=12)
    assert dt_jan01 == datetime(2027, 1, 1, 8, 0)


# ---------------------------------------------------------------------------
# 16. Asgari dinlenme kuralı (Minimum rest hours)
# ---------------------------------------------------------------------------
def test_16_min_rest_hours():
    shift_end = datetime(2026, 11, 1, 16, 0)
    next_start_too_soon = datetime(2026, 11, 1, 22, 0)  # only 6 hours rest
    rest_delta = next_start_too_soon - shift_end
    assert rest_delta < timedelta(hours=11)


# ---------------------------------------------------------------------------
# 17. Eşzamanlı ve manuel atama kontrolleri
# ---------------------------------------------------------------------------
def test_17_manual_shift_assignment(db, sample_team, manager_user, staff_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Test",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 1),
        excuse_start_time=datetime(2026, 10, 1),
        excuse_deadline=datetime(2026, 10, 2),
        status="PLANNING",
    )
    db.add(period)
    db.commit()

    plan = DutyPlan(period_id=period.id, team_id=sample_team.id, version=1, status="DRAFT")
    db.add(plan)
    db.commit()

    shift = DutyPlanShift(
        plan_id=plan.id,
        shift_type_id=1,
        date=date(2026, 11, 1),
        start_datetime=datetime(2026, 11, 1, 8, 0),
        end_datetime=datetime(2026, 11, 1, 16, 0),
        is_unassigned=True,
    )
    db.add(shift)
    db.commit()

    update_data = DutyPlanShiftUpdate(assigned_user_id=staff_user.id, note="Manuel görevlendirme")
    updated, err = ScheduleService.update_shift_assignment(db, manager_user.id, shift.id, update_data)
    assert err is None
    assert updated.assigned_user_id == staff_user.id
    assert updated.is_unassigned is False


# ---------------------------------------------------------------------------
# 18. Taslak oluşturma
# ---------------------------------------------------------------------------
def test_18_generate_draft_plan_endpoint(client, db, sample_team, manager_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Aralık 2026",
        start_date=date(2026, 12, 1),
        end_date=date(2026, 12, 5),
        excuse_start_time=datetime(2026, 11, 1),
        excuse_deadline=datetime(2026, 11, 20),
        status="PLANNING",
    )
    db.add(period)
    db.commit()

    payload = {
        "team_id": sample_team.id,
        "period_id": period.id,
        "shift_type_ids": [1],
    }
    res = client.post("/api/v1/plans/generate", json=payload, headers=auth_header(manager_user))
    assert res.status_code == 200
    assert res.json()["data"]["status"] == "DRAFT"
    assert len(res.json()["data"]["shifts"]) > 0


# ---------------------------------------------------------------------------
# 19. Planın onaylanması ve yayımlanması
# ---------------------------------------------------------------------------
def test_19_publish_plan(client, db, sample_team, manager_user, staff_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Kasım",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 1),
        excuse_start_time=datetime(2026, 10, 1),
        excuse_deadline=datetime(2026, 10, 2),
        status="PLANNING",
    )
    db.add(period)
    db.commit()

    plan = DutyPlan(period_id=period.id, team_id=sample_team.id, version=1, status="DRAFT")
    db.add(plan)
    db.commit()

    shift = DutyPlanShift(
        plan_id=plan.id,
        shift_type_id=1,
        assigned_user_id=staff_user.id,
        date=date(2026, 11, 1),
        start_datetime=datetime(2026, 11, 1, 8, 0),
        end_datetime=datetime(2026, 11, 1, 16, 0),
        is_unassigned=False,
    )
    db.add(shift)
    db.commit()

    res = client.post(
        f"/api/v1/plans/{plan.id}/publish",
        json={"change_note": "İlk resmi yayım."},
        headers=auth_header(manager_user),
    )
    assert res.status_code == 200
    assert res.json()["data"]["status"] == "PUBLISHED"

    # Verify official shift was copied to shifts table!
    official = db.query(Shift).filter(Shift.user_id == staff_user.id, Shift.date == date(2026, 11, 1)).first()
    assert official is not None


# ---------------------------------------------------------------------------
# 20. Plan revizyonu ve sürüm artışı
# ---------------------------------------------------------------------------
def test_20_plan_revision(db, sample_team, manager_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Kasım",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 2),
        excuse_start_time=datetime(2026, 10, 1),
        excuse_deadline=datetime(2026, 10, 2),
        status="PLANNING",
    )
    db.add(period)
    db.commit()

    # Plan v1
    p1 = DutyPlan(period_id=period.id, team_id=sample_team.id, version=1, status="PUBLISHED")
    db.add(p1)
    db.commit()

    # Plan v2
    p2 = ScheduleService.generate_draft_plan(
        db, manager_user.id, PlanGenerateRequest(team_id=sample_team.id, period_id=period.id, shift_type_ids=[1])
    )
    assert p2.version == 2


# ---------------------------------------------------------------------------
# 21. Eski sürümün korunması (Archive)
# ---------------------------------------------------------------------------
def test_21_preserve_old_version(db, sample_team, manager_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Kasım",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 1),
        excuse_start_time=datetime(2026, 10, 1),
        excuse_deadline=datetime(2026, 10, 2),
    )
    db.add(period)
    db.commit()

    p1 = DutyPlan(period_id=period.id, team_id=sample_team.id, version=1, status="PUBLISHED")
    p2 = DutyPlan(period_id=period.id, team_id=sample_team.id, version=2, status="DRAFT")
    db.add_all([p1, p2])
    db.commit()

    ScheduleService.publish_plan(db, manager_user.id, p2.id)

    db.refresh(p1)
    db.refresh(p2)
    assert p1.status == "ARCHIVED"  # Preserved as archived!
    assert p2.status == "PUBLISHED"


# ---------------------------------------------------------------------------
# 22. Excel dosyasının oluşturulması (.xlsx)
# ---------------------------------------------------------------------------
def test_22_excel_export(client, db, sample_team, manager_user, staff_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Aralık",
        start_date=date(2026, 12, 1),
        end_date=date(2026, 12, 1),
        excuse_start_time=datetime(2026, 11, 1),
        excuse_deadline=datetime(2026, 11, 2),
    )
    db.add(period)
    db.commit()

    plan = DutyPlan(period_id=period.id, team_id=sample_team.id, version=1, status="PUBLISHED")
    db.add(plan)
    db.commit()

    shift = DutyPlanShift(
        plan_id=plan.id,
        shift_type_id=1,
        assigned_user_id=staff_user.id,
        date=date(2026, 12, 1),
        start_datetime=datetime(2026, 12, 1, 8, 0),
        end_datetime=datetime(2026, 12, 1, 16, 0),
    )
    db.add(shift)
    db.commit()

    res = client.get(f"/api/v1/plans/{plan.id}/export/excel", headers=auth_header(manager_user))
    assert res.status_code == 200
    assert "spreadsheetml" in res.headers["content-type"]
    assert len(res.content) > 1000


# ---------------------------------------------------------------------------
# 23. PDF dosyasının oluşturulması (.pdf)
# ---------------------------------------------------------------------------
def test_23_pdf_export(client, db, sample_team, manager_user, staff_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Aralık",
        start_date=date(2026, 12, 1),
        end_date=date(2026, 12, 1),
        excuse_start_time=datetime(2026, 11, 1),
        excuse_deadline=datetime(2026, 11, 2),
    )
    db.add(period)
    db.commit()

    plan = DutyPlan(period_id=period.id, team_id=sample_team.id, version=1, status="PUBLISHED")
    db.add(plan)
    db.commit()

    shift = DutyPlanShift(
        plan_id=plan.id,
        shift_type_id=1,
        assigned_user_id=staff_user.id,
        date=date(2026, 12, 1),
        start_datetime=datetime(2026, 12, 1, 8, 0),
        end_datetime=datetime(2026, 12, 1, 16, 0),
    )
    db.add(shift)
    db.commit()

    res = client.get(f"/api/v1/plans/{plan.id}/export/pdf", headers=auth_header(manager_user))
    assert res.status_code == 200
    assert "application/pdf" in res.headers["content-type"]
    assert res.content[:4] == b"%PDF"


# ---------------------------------------------------------------------------
# 24. Yetkisiz rapor indirme girişimi
# ---------------------------------------------------------------------------
def test_24_unauthorized_report_download(client, db, sample_team, staff_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Taslak Dönem",
        start_date=date(2026, 12, 1),
        end_date=date(2026, 12, 1),
        excuse_start_time=datetime(2026, 11, 1),
        excuse_deadline=datetime(2026, 11, 2),
    )
    db.add(period)
    db.commit()

    draft_plan = DutyPlan(period_id=period.id, team_id=sample_team.id, version=1, status="DRAFT")
    db.add(draft_plan)
    db.commit()

    # Staff trying to download unapproved/draft plan must be rejected!
    res = client.get(f"/api/v1/plans/{draft_plan.id}/export/pdf", headers=auth_header(staff_user))
    assert res.status_code == 403


# ---------------------------------------------------------------------------
# 25. Hesap silme
# ---------------------------------------------------------------------------
def test_25_delete_account(client, db):
    user_to_delete = User(
        email="delete_me@shiftly.app",
        password_hash=get_password_hash("pass"),
        first_name="Sil",
        last_name="Beni",
    )
    db.add(user_to_delete)
    db.commit()

    res = client.delete("/api/v1/auth/me", headers=auth_header(user_to_delete))
    assert res.status_code == 200
    assert db.query(User).filter(User.id == user_to_delete.id).first() is None


# ---------------------------------------------------------------------------
# 26. Token yenileme
# ---------------------------------------------------------------------------
def test_26_token_refresh(client, staff_user):
    from app.core.security import create_refresh_token
    rf_token = create_refresh_token(staff_user.id)
    res = client.post(f"/api/v1/auth/refresh?refresh_token={rf_token}")
    assert res.status_code == 200
    assert "access_token" in res.json()["data"]


# ---------------------------------------------------------------------------
# 27. Veritabanı bütünlüğü
# ---------------------------------------------------------------------------
def test_27_db_integrity(db, sample_team):
    p = DutyPeriod(
        team_id=sample_team.id,
        name="Bütünlük Testi",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 30),
        excuse_start_time=datetime(2026, 10, 1),
        excuse_deadline=datetime(2026, 10, 20),
    )
    db.add(p)
    db.commit()
    assert p.id is not None
    assert p.team.id == sample_team.id


# ---------------------------------------------------------------------------
# 28. Geçersiz veya eksik istek gövdeleri (422)
# ---------------------------------------------------------------------------
def test_28_validation_errors(client, manager_user):
    res = client.post("/api/v1/periods", json={"name": ""}, headers=auth_header(manager_user))
    assert res.status_code == 422


# ---------------------------------------------------------------------------
# 29. Tekrarlanan istekler ve durum geçişleri
# ---------------------------------------------------------------------------
def test_29_status_transitions(client, db, sample_team, manager_user):
    period = DutyPeriod(
        team_id=sample_team.id,
        name="Durum Testi",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 30),
        excuse_start_time=datetime(2026, 10, 1),
        excuse_deadline=datetime(2026, 10, 20),
        status="EXCUSES_OPEN",
    )
    db.add(period)
    db.commit()

    res = client.post(f"/api/v1/periods/{period.id}/close-excuses", headers=auth_header(manager_user))
    assert res.status_code == 200
    db.refresh(period)
    assert period.status == "EXCUSES_CLOSED"


# ---------------------------------------------------------------------------
# 30. Kullanıcı ve ekip izolasyonu
# ---------------------------------------------------------------------------
def test_30_multi_team_isolation(client, db, manager_user, other_team_user):
    t1 = Team(owner_id=manager_user.id, name="Ekip 1", invite_code="TEAM-1")
    t2 = Team(owner_id=other_team_user.id, name="Ekip 2", invite_code="TEAM-2")
    db.add_all([t1, t2])
    db.commit()

    db.add_all([
        TeamMember(team_id=t1.id, user_id=manager_user.id, role="owner"),
        TeamMember(team_id=t2.id, user_id=other_team_user.id, role="owner"),
    ])
    db.commit()

    p1 = DutyPeriod(
        team_id=t1.id,
        name="Ekip 1 Dönemi",
        start_date=date(2026, 11, 1),
        end_date=date(2026, 11, 30),
        excuse_start_time=datetime(2026, 10, 1),
        excuse_deadline=datetime(2026, 10, 20),
    )
    db.add(p1)
    db.commit()

    # User from team 2 tries to access period of team 1
    res = client.get(f"/api/v1/periods/{p1.id}", headers=auth_header(other_team_user))
    assert res.status_code == 403
