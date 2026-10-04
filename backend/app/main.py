from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.db.init_db import init_db
from app.api.v1 import auth, shifts, shift_types, patterns, teams, swaps, statistics, admin


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize DB tables and seed demo data if development
    init_db()
    yield
    # Shutdown logic if any


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Shiftly — Vardiya, Nöbet, Takvim ve Ekip Yönetim Backend API",
    version=settings.VERSION,
    lifespan=lifespan,
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Global Exception Handlers for consistent API responses
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "message": exc.detail,
            "code": f"HTTP_{exc.status_code}",
            "data": None,
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = exc.errors()
    first_error_msg = errors[0].get("msg") if errors else "Geçersiz veri formatı."
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "success": False,
            "message": f"Doğrulama hatası: {first_error_msg}",
            "code": "VALIDATION_ERROR",
            "data": errors,
        },
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "message": "Beklenmeyen bir sunucu hatası oluştu. Lütfen tekrar deneyin.",
            "code": "INTERNAL_SERVER_ERROR",
            "data": None,
        },
    )


# Health check
@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok", "app": settings.PROJECT_NAME, "version": settings.VERSION}


# Include Routers
api_v1 = settings.API_V1_STR
app.include_router(auth.router, prefix=api_v1)
app.include_router(shifts.router, prefix=api_v1)
app.include_router(shift_types.router, prefix=api_v1)
app.include_router(patterns.router, prefix=api_v1)
app.include_router(teams.router, prefix=api_v1)
app.include_router(swaps.router, prefix=api_v1)
app.include_router(statistics.router, prefix=api_v1)
app.include_router(admin.router, prefix=api_v1)
