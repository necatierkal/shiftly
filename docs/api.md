# Shiftly API Dokümantasyonu

Tüm API yanıtları standart formatta sunulur:
```json
{
  "success": true,
  "message": "...",
  "code": "OK",
  "data": { ... }
}
```

## Kimlik Doğrulama (`/api/v1/auth`)
- `POST /register`: Ad, soyad, e-posta, şifre ve sektör ile yeni kayıt.
- `POST /login`: Giriş, access_token ve refresh_token üretimi.
- `POST /refresh`: Refresh token ile yeni access token.
- `GET /me`: Oturum açan kullanıcının profil ve ayarları.
- `PUT /me`: Profil güncelleme.
- `DELETE /me`: Google Play Store gereksinimi: Kullanıcı hesabını ve tüm verilerini kalıcı silme.

## Vardiya Tipleri (`/api/v1/shift-types`)
- `GET /`: Kullanıcının ve sistemin vardiya tipleri (Gündüz, Gece, 24 Saat Nöbet, İzin).
- `POST /`: Yeni özel vardiya tipi tanımlama.

## Vardiyalar (`/api/v1/shifts`)
- `GET /`: Tarih aralığına göre vardiya listeleme (`start_date`, `end_date`).
- `POST /`: Tekil vardiya oluşturma (Backend çakışma denetimli).
- `PUT /{id}`: Vardiya güncelleme.
- `DELETE /{id}`: Vardiya silme.
- `POST /generate`: 24/48, 24/72, 12/24 veya özel döngü ile toplu vardiya oluşturma.

## Ekipler (`/api/v1/teams`)
- `GET /`: Üye veya sahip olunan ekipler.
- `POST /`: Yeni ekip oluşturma ve otomatik davet kodu (örn: SHF-82K9) üretimi.
- `POST /join`: Davet kodu ile ekibe katılma.
- `GET /{id}/calendar`: Haftalık ekip vardiya matrisi.

## Vardiya Takası (`/api/v1/swaps`)
- `GET /`: Açık ve kişisel takas talepleri.
- `POST /`: Vardiyayı takasa açma.
- `POST /{id}/accept`: Karşılıklı vardiya takasını onaylama ve takvimleri güncelleme.
- `POST /{id}/reject`: Takası reddetme.
- `POST /{id}/cancel`: Talebi iptal etme.

## İstatistikler (`/api/v1/statistics`)
- `GET /`: Haftalık/aylık saatler, gece/gündüz nöbet dağılım oranları, hafta sonu mesaileri.
