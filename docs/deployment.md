# Shiftly Dağıtım ve Yayınlama Kılavuzu (Deployment Guide)

## 1. Backend Dağıtımı (Production)
Backend, Docker veya doğrudan Linux sunucu (Ubuntu / Debian) üzerinde çalıştırılabilir.

### Ortam Değişkenleri (.env)
```env
PROJECT_NAME="Shiftly"
ENVIRONMENT="production"
SECRET_KEY="<GÜVENLİ_ÜRETİLMİŞ_64_KARAKTER_ANAHTAR>"
DATABASE_URL="postgresql+psycopg2://shiftly_user:password@localhost:5432/shiftly_db"
ACCESS_TOKEN_EXPIRE_MINUTES=1440
REFRESH_TOKEN_EXPIRE_DAYS=30
```

### Systemd Servis Örneği (`/etc/systemd/system/shiftly.service`)
```ini
[Unit]
Description=Shiftly FastAPI Backend
After=network.target

[Service]
User=www-data
WorkingDirectory=/var/www/shiftly/backend
ExecStart=/var/www/shiftly/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=always

[Install]
WantedBy=multi-user.target
```

## 2. Mobil Uygulama (Google Play Store Release)
- **Paket Adı:** `com.shiftly.app`
- **Sürüm:** 1.0.0 (Build 1)

### Release APK / App Bundle (AAB) Oluşturma:
```bash
cd shiftly/mobile
flutter build appbundle --release
```
Oluşturulan `.aab` dosyası: `build/app/outputs/bundle/release/app-release.aab`
Google Play Console'a yüklemeye hazırdır.
