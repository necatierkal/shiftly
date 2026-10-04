# Shiftly — Mimari ve Sistem Tasarımı

## 1. Genel Bakış
Shiftly, çok sektörlü (Sağlık, Güvenlik, Fabrika, vb.) çalışanlar için geliştirilmiş modern, hızlı ve ölçeklenebilir vardiya, nöbet, takvim ve ekip yönetim uygulamasıdır.

## 2. Mimari Katmanlar
Sistem, temiz mimari (Clean Architecture) ve Offline-First ilkeleriyle iki ana parçadan oluşur:

### 2.1 Mobil Uygulama (Flutter / Dart)
- **State Management:** Provider (MultiProvider)
- **Storage:** LocalStorageService (SharedPreferences / Caching)
- **Theme:** Material 3 Dark/Light tema sistemi (`AppTheme`, `AppColors`)
- **Branding:** Merkezi yapı (`AppConfig`), dinamik vektörel `ShiftlyLogo` CustomPainter
- **Routing & Navigation:** `SplashScreen`, `OnboardingScreen`, `AuthScreen`, `MainNavScreen` (5 sekme: Dashboard, Calendar, Team, Swap, Profile)

### 2.2 Backend API (Python / FastAPI)
- **Framework:** FastAPI
- **ORM:** SQLAlchemy 2.x
- **Veritabanı:** SQLite (Geliştirme) / PostgreSQL (Canlı)
- **Kimlik Doğrulama:** JWT (Access Token + Refresh Token), Bcrypt şifre hashleme
- **Validasyon:** Pydantic v2
- **Kurallar:** Backend tabanlı çakışma kontrolü (Overlap Detection), Takas sahiplik kontrolleri (Ownership Checks)

## 3. Temel Akışlar
1. **24/48 ve Döngü Motoru:** Başlangıç tarihinden itibaren `Work -> Off -> Off -> Work` döngüsünü hesaplar, çakışmaları doğrular ve toplu takvim oluşturur.
2. **Vardiya Takası:** İki kullanıcı arasında karşılıklı vardiya takasında; her iki kullanıcının takviminde çakışma olmaması ve tarihlerin geçerliliği backend tarafından denetlenir.
