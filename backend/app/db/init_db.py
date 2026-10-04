from datetime import datetime, date, timedelta
from sqlalchemy.orm import Session
from app.db.session import Base, engine, SessionLocal
from app.core.security import get_password_hash
from app.models.models import (
    User,
    UserSettings,
    ShiftType,
    Shift,
    WorkPattern,
    Team,
    TeamMember,
    Subscription,
)
from app.services.shift_service import ShiftService


def init_db(db: Session = None):
    Base.metadata.create_all(bind=engine)

    close_db_later = False
    if db is None:
        db = SessionLocal()
        close_db_later = True

    try:
        # Check if demo user exists
        demo_user = db.query(User).filter(User.email == "demo@shiftly.app").first()
        if not demo_user:
            demo_user = User(
                email="demo@shiftly.app",
                password_hash=get_password_hash("demo1234"),
                first_name="Necati",
                last_name="Yılmaz",
                sector="Sağlık",
                job_title="Hemşire / Sağlık Personeli",
                timezone="Europe/Istanbul",
                locale="tr",
                is_active=True,
            )
            db.add(demo_user)
            db.commit()
            db.refresh(demo_user)

            # Settings
            db.add(UserSettings(user_id=demo_user.id))
            db.add(Subscription(user_id=demo_user.id, plan="PREMIUM"))

            # Shift Types
            shift_types = [
                ShiftType(user_id=demo_user.id, name="Gündüz", short_name="G", start_time="08:00", end_time="16:00", color="#3157D5", icon="wb_sunny", is_working=True, is_night=False),
                ShiftType(user_id=demo_user.id, name="Gece", short_name="N", start_time="20:00", end_time="08:00", color="#7C3AED", icon="nights_stay", is_working=True, is_night=True),
                ShiftType(user_id=demo_user.id, name="24 Saat Nöbet", short_name="24", start_time="08:00", end_time="08:00", color="#2563EB", icon="medical_services", is_working=True, is_night=True),
                ShiftType(user_id=demo_user.id, name="İzin", short_name="İ", start_time="00:00", end_time="23:59", color="#10B981", icon="beach_access", is_working=False, is_night=False),
            ]
            for st in shift_types:
                db.add(st)
            db.commit()

            # Create 24/48 pattern for October 2026
            start_oct = date(2026, 10, 3)
            end_oct = date(2026, 10, 31)

            ShiftService.generate_pattern_shifts(
                db=db,
                user_id=demo_user.id,
                cycle_type="24/48",
                start_date=start_oct,
                end_date=end_oct,
            )

            # Also create demo team
            team = Team(
                owner_id=demo_user.id,
                name="Acil Servis Ekibi",
                description="7/24 Acil Müdahale Nöbet Ekibi",
                invite_code="SHF-82K9",
            )
            db.add(team)
            db.commit()
            db.refresh(team)

            member = TeamMember(team_id=team.id, user_id=demo_user.id, role="owner")
            db.add(member)
            db.commit()

            print("Demo user & 24/48 shifts initialized successfully!")
    finally:
        if close_db_later:
            db.close()


if __name__ == "__main__":
    init_db()
