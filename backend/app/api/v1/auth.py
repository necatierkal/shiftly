from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.core.config import settings
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.models.models import User, UserSettings, ShiftType
from app.schemas.schemas import (
    APIResponse,
    Token,
    UserCreate,
    UserLogin,
    UserResponse,
    UserUpdate,
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=APIResponse[dict])
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    # Check if user already exists
    existing = db.query(User).filter(User.email == user_in.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu e-posta adresiyle kayıtlı bir hesap zaten var.",
        )

    # Create new user
    user = User(
        email=user_in.email,
        password_hash=get_password_hash(user_in.password),
        first_name=user_in.first_name,
        last_name=user_in.last_name,
        role=user_in.role or "staff",
        phone=user_in.phone,
        sector=user_in.sector or "Diğer",
        job_title=user_in.job_title,
        timezone=user_in.timezone or "Europe/Istanbul",
        locale=user_in.locale or "tr",
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Create default settings
    user_settings = UserSettings(user_id=user.id)
    db.add(user_settings)

    # Seed default shift types for this user
    default_types = [
        {"name": "Gündüz", "short_name": "G", "start_time": "08:00", "end_time": "16:00", "color": "#3157D5", "icon": "wb_sunny", "is_working": True, "is_night": False},
        {"name": "Gece", "short_name": "N", "start_time": "20:00", "end_time": "08:00", "color": "#7C3AED", "icon": "nights_stay", "is_working": True, "is_night": True},
        {"name": "Sabah", "short_name": "S", "start_time": "07:00", "end_time": "15:00", "color": "#0284C7", "icon": "wb_twilight", "is_working": True, "is_night": False},
        {"name": "Akşam", "short_name": "A", "start_time": "15:00", "end_time": "23:00", "color": "#D97706", "icon": "wb_twilight", "is_working": True, "is_night": False},
        {"name": "İzin", "short_name": "İ", "start_time": "00:00", "end_time": "23:59", "color": "#10B981", "icon": "beach_access", "is_working": False, "is_night": False},
    ]
    for dt in default_types:
        st = ShiftType(user_id=user.id, **dt)
        db.add(st)

    db.commit()

    # Generate tokens
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    return APIResponse(
        success=True,
        message="Kayıt başarıyla tamamlandı.",
        data={
            "user": {
                "id": user.id,
                "email": user.email,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "role": user.role,
                "sector": user.sector,
                "job_title": user.job_title,
            },
            "tokens": {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            },
        },
    )


@router.post("/login", response_model=APIResponse[dict])
def login(login_data: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == login_data.email).first()
    if not user or not verify_password(login_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-posta veya şifre hatalı.",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Hesabınız askıya alınmış.",
        )

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    return APIResponse(
        success=True,
        message="Giriş başarılı.",
        data={
            "user": {
                "id": user.id,
                "email": user.email,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "role": user.role,
                "sector": user.sector,
                "job_title": user.job_title,
            },
            "tokens": {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            },
        },
    )


@router.post("/refresh", response_model=APIResponse[dict])
def refresh_token(refresh_token: str, db: Session = Depends(get_db)):
    payload = decode_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Geçersiz yenileme belirteci.",
        )
    user_id = payload.get("sub")
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Kullanıcı bulunamadı.",
        )

    new_access_token = create_access_token(user.id)
    return APIResponse(
        success=True,
        message="Belirteç yenilendi.",
        data={
            "access_token": new_access_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        },
    )


@router.get("/me", response_model=APIResponse[UserResponse])
def get_me(current_user: User = Depends(get_current_user)):
    return APIResponse(success=True, data=current_user)


@router.put("/me", response_model=APIResponse[UserResponse])
def update_me(
    user_in: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    for field, value in user_in.model_dump(exclude_unset=True).items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    return APIResponse(success=True, message="Profil güncellendi.", data=current_user)


@router.delete("/me", response_model=APIResponse[dict])
def delete_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Google Play Store account deletion requirement
    current_user.is_active = False
    db.delete(current_user)
    db.commit()
    return APIResponse(success=True, message="Hesabınız ve tüm verileriniz başarıyla silindi.")
