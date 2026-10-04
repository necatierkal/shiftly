import pytest
from datetime import datetime, date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.session import Base
from app.models.models import User, ShiftType, Shift, WorkPattern, ShiftSwap, Team, TeamMember
from app.core.security import get_password_hash, verify_password, create_access_token, decode_token
from app.services.shift_service import ShiftService

# In-memory SQLite for testing
SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(SQLALCHEMY_TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    yield db
    db.close()
    Base.metadata.drop_all(bind=engine)


def test_password_hash_and_jwt():
    raw_pass = "ShiftlySecure2026!"
    hashed = get_password_hash(raw_pass)
    assert verify_password(raw_pass, hashed) is True
    assert verify_password("wrongpassword", hashed) is False

    token = create_access_token(subject=42)
    decoded = decode_token(token)
    assert decoded is not None
    assert decoded.get("sub") == "42"


def test_24_48_pattern_generator(db_session):
    # Setup user and shift types
    user = User(
        email="test2448@shiftly.app",
        password_hash=get_password_hash("pass"),
        first_name="Test",
        last_name="User",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    st_work = ShiftType(user_id=user.id, name="Gündüz", short_name="G", start_time="08:00", end_time="08:00", is_working=True)
    st_off = ShiftType(user_id=user.id, name="İzin", short_name="İ", start_time="00:00", end_time="23:59", is_working=False)
    db_session.add_all([st_work, st_off])
    db_session.commit()

    start_date = date(2026, 10, 3)
    end_date = date(2026, 10, 8)

    shifts, conflicts = ShiftService.generate_pattern_shifts(
        db=db_session,
        user_id=user.id,
        cycle_type="24/48",
        start_date=start_date,
        end_date=end_date,
    )

    assert len(shifts) == 6
    assert conflicts == 0

    # Verify 24/48:
    # 03 Oct -> Work
    # 04 Oct -> Off
    # 05 Oct -> Off
    # 06 Oct -> Work
    # 07 Oct -> Off
    # 08 Oct -> Off
    assert shifts[0].date == date(2026, 10, 3)
    assert shifts[0].shift_type.is_working is True

    assert shifts[1].date == date(2026, 10, 4)
    assert shifts[1].shift_type.is_working is False

    assert shifts[2].date == date(2026, 10, 5)
    assert shifts[2].shift_type.is_working is False

    assert shifts[3].date == date(2026, 10, 6)
    assert shifts[3].shift_type.is_working is True

    assert shifts[4].date == date(2026, 10, 7)
    assert shifts[4].shift_type.is_working is False

    assert shifts[5].date == date(2026, 10, 8)
    assert shifts[5].shift_type.is_working is False


def test_overlap_detection(db_session):
    user = User(
        email="overlap@shiftly.app",
        password_hash=get_password_hash("pass"),
        first_name="Overlap",
        last_name="Test",
    )
    db_session.add(user)
    db_session.commit()

    st = ShiftType(user_id=user.id, name="Gündüz", short_name="G", start_time="08:00", end_time="16:00", is_working=True)
    db_session.add(st)
    db_session.commit()

    # Shift 1: 08:00 to 16:00 on 2026-10-03
    s1 = Shift(
        user_id=user.id,
        shift_type_id=st.id,
        date=date(2026, 10, 3),
        start_datetime=datetime(2026, 10, 3, 8, 0),
        end_datetime=datetime(2026, 10, 3, 16, 0),
    )
    db_session.add(s1)
    db_session.commit()

    # Check overlapping shift: 14:00 to 22:00
    overlap1 = ShiftService.check_overlap(
        db_session, user.id, datetime(2026, 10, 3, 14, 0), datetime(2026, 10, 3, 22, 0)
    )
    assert overlap1 is not None
    assert overlap1.id == s1.id

    # Check non-overlapping shift: 16:30 to 23:00
    overlap2 = ShiftService.check_overlap(
        db_session, user.id, datetime(2026, 10, 3, 16, 30), datetime(2026, 10, 3, 23, 0)
    )
    assert overlap2 is None


def test_swap_shifts(db_session):
    u1 = User(email="ali@shiftly.app", password_hash=get_password_hash("pass"), first_name="Ali", last_name="V")
    u2 = User(email="mehmet@shiftly.app", password_hash=get_password_hash("pass"), first_name="Mehmet", last_name="K")
    db_session.add_all([u1, u2])
    db_session.commit()

    st_night = ShiftType(user_id=u1.id, name="Gece", short_name="N", start_time="20:00", end_time="08:00", is_working=True, is_night=True)
    db_session.add(st_night)
    db_session.commit()

    # Ali: 12 Oct Gece
    shift_ali = Shift(
        user_id=u1.id,
        shift_type_id=st_night.id,
        date=date(2026, 10, 12),
        start_datetime=datetime(2026, 10, 12, 20, 0),
        end_datetime=datetime(2026, 10, 13, 8, 0),
    )
    # Mehmet: 13 Oct Gece
    shift_mehmet = Shift(
        user_id=u2.id,
        shift_type_id=st_night.id,
        date=date(2026, 10, 13),
        start_datetime=datetime(2026, 10, 13, 20, 0),
        end_datetime=datetime(2026, 10, 14, 8, 0),
    )
    db_session.add_all([shift_ali, shift_mehmet])
    db_session.commit()

    # Create swap request from Ali
    swap = ShiftSwap(
        requester_id=u1.id,
        target_user_id=u2.id,
        requester_shift_id=shift_ali.id,
        target_shift_id=shift_mehmet.id,
        status="PENDING",
        message="12 Ekim gecemi 13 Ekim ile değiştirmek istiyorum.",
    )
    db_session.add(swap)
    db_session.commit()

    # Simulate accept
    shift_ali.user_id = u2.id
    shift_mehmet.user_id = u1.id
    swap.status = "ACCEPTED"
    db_session.commit()

    # Verify swapped owners
    db_session.refresh(shift_ali)
    db_session.refresh(shift_mehmet)
    assert shift_ali.user_id == u2.id
    assert shift_mehmet.user_id == u1.id
