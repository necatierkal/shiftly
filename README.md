# SHIFTLY — Vardiya, Nöbet, Takvim ve Ekip Yönetim Uygulaması

> *"Vardiyan. Takvimin. Ekibin."*

---

## 🌟 Proje Açıklaması
**Shiftly**, sağlık, güvenlik, polis, asker, fabrika, üretim, lojistik ve teknik servis gibi çok çeşitli sektörlerde çalışan personelin vardiyalarını, nöbetlerini, izinlerini ve ekiplerini yönetmelerini sağlayan modern, hızlı ve profesyonel bir mobil platformdur.

Uygulama herhangi bir sektöre bağımlı değildir; kullanıcı ilk açılışta kendi döngüsünü (24/48, 24/72, 12/24, 12/36 vb.) saniyeler içinde takvimine uygulayabilir, ekip arkadaşlarıyla takas yapabilir ve çalışma saatlerini takip edebilir.

---

## 🚀 Temel Özellikler
- **30 Saniyede Başlangıç & Onboarding:** Karmaşık formlar olmadan sektör ve çalışma sistemini seçip anında takvim oluşturabilme.
- **24/48 ve Otomatik Vardiya Döngüsü:** 3 aylık, 6 aylık veya özel periyotlu nöbet çizelgelerini çakışma kontrolüyle tek tıkla oluşturma.
- **Akıllı Dashboard:** Bugünkü vardiya kartı (süre, saat, konum, renk), sonraki vardiya, haftalık çalışma saati ve ekip durumu.
- **Material 3 Takvim:** Ay, hafta görünümleri; renkli kısa harf rozetleri (Gündüz = Mavi, Gece = Mor, İzin = Yeşil).
- **Vardiya Çakışma Denetimi:** Hem frontend hem de backend seviyesinde çakışan saatlerin ve çift nöbetlerin engellenmesi.
- **Vardiya Takası (Shift Swap):** Güvenli, karşılıklı sahiplik doğrulamalı ve anında takvimleri güncelleyen takas sistemi.
- **Ekip Yönetimi & Haftalık Matris:** Ekip oluşturma, davet kodu (`SHF-82K9`), tüm personelin haftalık nöbet matrisi.
- **Çalışma İstatistikleri:** Gece mesaisi, toplam saat, hafta sonu dağılımları ve nöbet dengesi.
- **Google Play Store Hazırlığı:** Gizlilik Politikası, Kullanım Şartları ve Hesap Silme akışları.

---

## 🛠️ Teknolojiler
- **Mobil:** Flutter 3.47+ / Dart 3.13+, Material 3, Provider State Management, Offline-First Local Storage.
- **Backend:** Python 3.12+, FastAPI, SQLAlchemy 2.x, Pydantic v2, Pytest, Bcrypt, JWT.
- **Veritabanı:** Geliştirmede SQLite (`shiftly.db`), Canlıda PostgreSQL.

---

## 💻 Kurulum ve Çalıştırma

### 1. Backend'i Çalıştırma
```powershell
cd shiftly\backend
# Sanal ortamı etkinleştir
.\venv\Scripts\activate

# Bağımlılıkları yükle (zaten kuruluysa atlayın)
pip install -r requirements.txt

# Veritabanını tohumla (Demo kullanıcı ve 24/48 nöbetleri)
python -m app.db.init_db

# Sunucuyu başlat
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
Backend API dökümanlarına `http://localhost:8000/docs` adresinden erişebilirsiniz.

### 2. Mobil Uygulamayı Çalıştırma
```powershell
cd shiftly\mobile

# Paketleri al
flutter pub get

# Uygulamayı başlat (Emülatör, Windows veya Web)
flutter run
```

### 3. Testleri Çalıştırma
- **Backend Testleri (24/48 generator, çakışma, takas, auth):**
  ```powershell
  cd shiftly\backend
  $env:PYTHONPATH="."; .\venv\Scripts\python.exe -m pytest tests/test_backend.py
  ```
- **Flutter Testleri (Modeller, Süre hesaplamaları, Widget ve Logo):**
  ```powershell
  cd shiftly\mobile
  flutter test
  ```

---

## 👤 Demo Giriş Bilgileri
- **E-posta:** `demo@shiftly.app`
- **Şifre:** `demo1234`
- **Sektör:** Sağlık (Acil Servis Ekibi)
- **Düzen:** 24/48 Nöbet Döngüsü
- **Ekip Kodu:** `SHF-82K9`
