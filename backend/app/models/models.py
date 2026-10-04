import uuid
from datetime import datetime
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    Date,
    Time,
    ForeignKey,
    Text,
    Enum,
    JSON,
)
from sqlalchemy.orm import relationship
from app.db.session import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String(36), unique=True, index=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, index=True, nullable=False)
    phone = Column(String(50), nullable=True)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    avatar_url = Column(String(500), nullable=True)
    sector = Column(String(100), default="Diğer")
    job_title = Column(String(100), nullable=True)
    timezone = Column(String(50), default="Europe/Istanbul")
    locale = Column(String(10), default="tr")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    shifts = relationship("Shift", back_populates="user", cascade="all, delete-orphan")
    custom_shift_types = relationship("ShiftType", back_populates="user", cascade="all, delete-orphan")
    work_patterns = relationship("WorkPattern", back_populates="user", cascade="all, delete-orphan")
    owned_teams = relationship("Team", back_populates="owner")
    team_memberships = relationship("TeamMember", back_populates="user", cascade="all, delete-orphan")
    settings = relationship("UserSettings", back_populates="user", uselist=False, cascade="all, delete-orphan")
    subscription = relationship("Subscription", back_populates="user", uselist=False, cascade="all, delete-orphan")


class UserSettings(Base):
    __tablename__ = "user_settings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    theme = Column(String(20), default="system")  # light, dark, system
    week_start_day = Column(Integer, default=1)  # 1 = Monday, 7 = Sunday
    default_calendar_view = Column(String(20), default="month")  # month, week, day
    notification_enabled = Column(Boolean, default=True)
    reminder_enabled = Column(Boolean, default=True)
    language = Column(String(10), default="tr")

    user = relationship("User", back_populates="settings")


class ShiftType(Base):
    __tablename__ = "shift_types"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Null if system default
    name = Column(String(100), nullable=False)
    short_name = Column(String(10), nullable=False)
    start_time = Column(String(10), nullable=False)  # HH:MM format
    end_time = Column(String(10), nullable=False)    # HH:MM format
    color = Column(String(20), default="#3157D5")
    icon = Column(String(50), default="work")
    is_working = Column(Boolean, default=True)
    is_night = Column(Boolean, default=False)
    is_paid = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="custom_shift_types")
    shifts = relationship("Shift", back_populates="shift_type")


class Shift(Base):
    __tablename__ = "shifts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    shift_type_id = Column(Integer, ForeignKey("shift_types.id"), nullable=False)
    date = Column(Date, nullable=False, index=True)
    start_datetime = Column(DateTime, nullable=False)
    end_datetime = Column(DateTime, nullable=False)
    note = Column(Text, nullable=True)
    location = Column(String(255), nullable=True)
    status = Column(String(50), default="scheduled")  # scheduled, completed, cancelled, swapped
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="shifts")
    shift_type = relationship("ShiftType", back_populates="shifts")
    reminders = relationship("Reminder", back_populates="shift", cascade="all, delete-orphan")


class WorkPattern(Base):
    __tablename__ = "work_patterns"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    description = Column(String(255), nullable=True)
    cycle_length = Column(Integer, nullable=False)  # e.g., 3 days for 24/48, 4 for 24/72
    cycle_type = Column(String(50), nullable=False)  # "24/48", "12/24", "custom"
    pattern_definition = Column(JSON, nullable=False)  # List of shift_type_ids or templates per cycle day
    start_date = Column(Date, nullable=False)
    is_active = Column(Boolean, default=True)

    user = relationship("User", back_populates="work_patterns")


class Team(Base):
    __tablename__ = "teams"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(String(255), nullable=True)
    invite_code = Column(String(20), unique=True, index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    owner = relationship("User", back_populates="owned_teams")
    members = relationship("TeamMember", back_populates="team", cascade="all, delete-orphan")


class TeamMember(Base):
    __tablename__ = "team_members"

    id = Column(Integer, primary_key=True, index=True)
    team_id = Column(Integer, ForeignKey("teams.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    role = Column(String(20), default="member")  # owner, admin, member
    joined_at = Column(DateTime, default=datetime.utcnow)

    team = relationship("Team", back_populates="members")
    user = relationship("User", back_populates="team_memberships")


class ShiftSwap(Base):
    __tablename__ = "shift_swaps"

    id = Column(Integer, primary_key=True, index=True)
    requester_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    target_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # can be open swap or targeted
    requester_shift_id = Column(Integer, ForeignKey("shifts.id"), nullable=False)
    target_shift_id = Column(Integer, ForeignKey("shifts.id"), nullable=True)
    status = Column(String(20), default="PENDING")  # PENDING, ACCEPTED, REJECTED, CANCELLED
    message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Reminder(Base):
    __tablename__ = "reminders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    shift_id = Column(Integer, ForeignKey("shifts.id"), nullable=False)
    reminder_minutes = Column(Integer, default=60)
    is_enabled = Column(Boolean, default=True)

    shift = relationship("Shift", back_populates="reminders")


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=False)
    type = Column(String(50), default="shift_reminder")
    is_read = Column(Boolean, default=False)
    scheduled_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    plan = Column(String(50), default="FREE")  # FREE, PREMIUM
    status = Column(String(50), default="active")
    started_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=True)

    user = relationship("User", back_populates="subscription")
