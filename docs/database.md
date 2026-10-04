# Shiftly Veritabanı Şeması

SQLAlchemy 2.0 ORM modelleri ile tasarlanmış ilişkisel veritabanı tabloları:

1. **`users`**
   - `id`: PK (Integer)
   - `uuid`: Benzersiz açık anahtar
   - `email`: E-posta adresi (Index, Unique)
   - `password_hash`: Bcrypt şifre özeti
   - `first_name`, `last_name`: Ad & Soyad
   - `sector`: Sektör bilgisi (Sağlık, Güvenlik, vb.)
   - `job_title`: Görev unvanı
   - `timezone`: Varsayılan 'Europe/Istanbul'
   - `locale`: Varsayılan 'tr'
   - `is_active`: Hesap durumu
   - `created_at`, `updated_at`: Zaman damgaları

2. **`user_settings`**
   - `id`: PK
   - `user_id`: FK -> users.id (Unique)
   - `theme`: 'light' | 'dark' | 'system'
   - `week_start_day`: 1 (Pazartesi)
   - `default_calendar_view`: 'month'
   - `notification_enabled`, `reminder_enabled`: Boolean

3. **`shift_types`**
   - `id`: PK
   - `user_id`: FK -> users.id (Null ise sistem genel şablonu)
   - `name`: '24 Saat Nöbet', 'Gündüz', 'Gece', 'İzin'
   - `short_name`: '24', 'G', 'N', 'İ'
   - `start_time`, `end_time`: 'HH:MM'
   - `color`: Hex renk kodu
   - `is_working`, `is_night`, `is_paid`: Boolean

4. **`shifts`**
   - `id`: PK
   - `user_id`: FK -> users.id
   - `shift_type_id`: FK -> shift_types.id
   - `date`: Tarih (Date)
   - `start_datetime`, `end_datetime`: DateTime
   - `note`, `location`: Açıklama ve lokasyon bilgisi
   - `status`: 'scheduled' | 'completed' | 'swapped'

5. **`work_patterns`**
   - `id`: PK
   - `user_id`: FK -> users.id
   - `name`: 'Benim 24/48 Nöbetim'
   - `cycle_length`: Gün sayısı (örn: 3)
   - `cycle_type`: '24/48', 'custom' vb.
   - `pattern_definition`: JSON dizi

6. **`teams` & `team_members`**
   - `teams`: id, owner_id, name, description, invite_code
   - `team_members`: id, team_id, user_id, role ('owner', 'admin', 'member')

7. **`shift_swaps`**
   - `id`: PK
   - `requester_id`, `target_user_id`: Kullanıcılar
   - `requester_shift_id`, `target_shift_id`: Takas edilecek vardiyalar
   - `status`: 'PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED'
   - `message`: Talep notu
