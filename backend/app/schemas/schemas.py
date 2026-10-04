from typing import Generic, TypeVar, Optional, List, Any, Dict
from datetime import datetime, date, time
from pydantic import BaseModel, EmailStr, Field, ConfigDict

T = TypeVar("T")


class APIResponse(BaseModel, Generic[T]):
    success: bool = True
    message: Optional[str] = None
    data: Optional[T] = None
    code: Optional[str] = "OK"


# Auth Schemas
class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenPayload(BaseModel):
    sub: Optional[str] = None
    exp: Optional[int] = None
    type: Optional[str] = None


class UserBase(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str
    sector: Optional[str] = "Diğer"
    job_title: Optional[str] = None
    phone: Optional[str] = None
    timezone: Optional[str] = "Europe/Istanbul"
    locale: Optional[str] = "tr"


class UserCreate(UserBase):
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    sector: Optional[str] = None
    job_title: Optional[str] = None
    timezone: Optional[str] = None
    locale: Optional[str] = None


class UserSettingsSchema(BaseModel):
    theme: str = "system"
    week_start_day: int = 1
    default_calendar_view: str = "month"
    notification_enabled: bool = True
    reminder_enabled: bool = True
    language: str = "tr"

    model_config = ConfigDict(from_attributes=True)


class UserResponse(UserBase):
    id: int
    uuid: str
    avatar_url: Optional[str] = None
    is_active: bool
    created_at: datetime
    settings: Optional[UserSettingsSchema] = None

    model_config = ConfigDict(from_attributes=True)


# Shift Type Schemas
class ShiftTypeBase(BaseModel):
    name: str
    short_name: str
    start_time: str  # HH:MM
    end_time: str    # HH:MM
    color: str = "#3157D5"
    icon: str = "work"
    is_working: bool = True
    is_night: bool = False
    is_paid: bool = True


class ShiftTypeCreate(ShiftTypeBase):
    pass


class ShiftTypeUpdate(BaseModel):
    name: Optional[str] = None
    short_name: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    color: Optional[str] = None
    icon: Optional[str] = None
    is_working: Optional[bool] = None
    is_night: Optional[bool] = None
    is_paid: Optional[bool] = None


class ShiftTypeResponse(ShiftTypeBase):
    id: int
    user_id: Optional[int] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# Shift Schemas
class ShiftBase(BaseModel):
    shift_type_id: int
    date: date
    start_datetime: datetime
    end_datetime: datetime
    note: Optional[str] = None
    location: Optional[str] = None


class ShiftCreate(ShiftBase):
    reminder_minutes: Optional[int] = 60


class ShiftUpdate(BaseModel):
    shift_type_id: Optional[int] = None
    start_datetime: Optional[datetime] = None
    end_datetime: Optional[datetime] = None
    note: Optional[str] = None
    location: Optional[str] = None
    status: Optional[str] = None
    reminder_minutes: Optional[int] = None


class ShiftResponse(ShiftBase):
    id: int
    user_id: int
    status: str
    created_at: datetime
    shift_type: Optional[ShiftTypeResponse] = None

    model_config = ConfigDict(from_attributes=True)


# Work Pattern Schemas
class PatternDayDef(BaseModel):
    day_index: int
    is_working: bool
    shift_type_name: Optional[str] = None
    shift_type_id: Optional[int] = None


class WorkPatternBase(BaseModel):
    name: str
    description: Optional[str] = None
    cycle_length: int
    cycle_type: str  # 24/48, 12/24, 24/72, 8/16, custom
    pattern_definition: List[PatternDayDef]
    start_date: date


class WorkPatternCreate(WorkPatternBase):
    pass


class WorkPatternGenerateRequest(BaseModel):
    pattern_id: Optional[int] = None
    cycle_type: Optional[str] = "24/48"
    start_date: date
    end_date: date
    custom_pattern: Optional[List[PatternDayDef]] = None


class WorkPatternResponse(WorkPatternBase):
    id: int
    user_id: int
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


# Team Schemas
class TeamCreate(BaseModel):
    name: str
    description: Optional[str] = None


class TeamJoin(BaseModel):
    invite_code: str


class TeamMemberResponse(BaseModel):
    id: int
    user_id: int
    role: str
    joined_at: datetime
    user: Optional[UserResponse] = None

    model_config = ConfigDict(from_attributes=True)


class TeamResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    invite_code: str
    owner_id: int
    created_at: datetime
    members: List[TeamMemberResponse] = []

    model_config = ConfigDict(from_attributes=True)


# Swap Schemas
class ShiftSwapCreate(BaseModel):
    requester_shift_id: int
    target_user_id: Optional[int] = None
    target_shift_id: Optional[int] = None
    message: Optional[str] = None


class ShiftSwapResponse(BaseModel):
    id: int
    requester_id: int
    target_user_id: Optional[int] = None
    requester_shift_id: int
    target_shift_id: Optional[int] = None
    status: str
    message: Optional[str] = None
    created_at: datetime
    requester_shift: Optional[ShiftResponse] = None
    target_shift: Optional[ShiftResponse] = None

    model_config = ConfigDict(from_attributes=True)


# Statistics Schemas
class StatisticsResponse(BaseModel):
    total_hours_this_week: float
    total_hours_this_month: float
    night_shift_hours: float
    off_days_count: int
    total_shifts_count: int
    day_shift_count: int
    night_shift_count: int
    weekend_shifts_count: int
    distribution: Dict[str, Any]
