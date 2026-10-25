import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shiftProv = context.watch<ShiftProvider>();
    final user = auth.currentUser;
    final stats = shiftProv.statistics;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil & İstatistikler')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (user?.firstName.isNotEmpty ?? false)
                            ? user!.firstName[0]
                            : 'S',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Necati Yılmaz',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? 'demo@shiftly.app',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${user?.sector ?? 'Sağlık'} • ${user?.jobTitle ?? 'Personel'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Statistics Section (Spec #20)
              const Text(
                'ÇALIŞMA İSTATİSTİKLERİ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      title: 'Bu Hafta',
                      value:
                          '${stats?.totalHoursThisWeek.toStringAsFixed(0) ?? '32'}s',
                      subtitle: 'Çalışma Saati',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      title: 'Bu Ay',
                      value:
                          '${stats?.totalHoursThisMonth.toStringAsFixed(0) ?? '168'}s',
                      subtitle: 'Toplam Süre',
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      title: 'Gece Nöbeti',
                      value:
                          '${stats?.nightShiftHours.toStringAsFixed(0) ?? '48'}s',
                      subtitle: 'Gece Mesaisi',
                      color: AppColors.shiftNight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      title: 'İzin Günleri',
                      value: '${stats?.offDaysCount ?? '6'} Gün',
                      subtitle: 'Dinlenme',
                      color: AppColors.shiftOff,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Settings & Legal List
              const Text(
                'AYARLAR & BİLGİ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),

              _buildSettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'Hatırlatıcılar & Bildirimler',
                subtitle: 'Vardiyadan 60 dk önce uyar',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.sync_alt_rounded,
                title: 'Rolü Değiştir (Yönetici / Personel)',
                subtitle: auth.isManager ? 'Şu an: Yönetici (Personel moduna geç)' : 'Şu an: Personel (Yönetici moduna geç)',
                onTap: () async {
                  if (auth.isManager) {
                    await auth.loginAsStaff();
                  } else {
                    await auth.loginAsManager();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Aktif rol değiştirildi: ${auth.isManager ? 'Yönetici' : 'Personel'}'),
                      ),
                    );
                  }
                },
              ),
              _buildSettingsTile(
                icon: Icons.settings_ethernet_rounded,
                title: 'Sunucu Bağlantı Adresi (API URL)',
                subtitle: 'Yerel ağ / IP adresi yapılandırması',
                onTap: () => _showServerSettings(context, auth),
              ),
              _buildSettingsTile(
                icon: Icons.calendar_month_outlined,
                title: 'Hafta Başlangıç Günü',
                subtitle: 'Pazartesi',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.language_rounded,
                title: 'Uygulama Dili',
                subtitle: 'Türkçe',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Gizlilik Politikası (Privacy Policy)',
                subtitle: 'Kişisel verileriniz ve güvenlik ilkeleri',
                onTap: () => _showPrivacyPolicy(context),
              ),
              _buildSettingsTile(
                icon: Icons.description_outlined,
                title: 'Kullanım Koşulları (Terms of Service)',
                subtitle: 'Shiftly kullanım ve hizmet sözleşmesi',
                onTap: () => _showTerms(context),
              ),

              const SizedBox(height: 20),

              // Logout & Delete Account
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                label: const Text(
                  'Çıkış Yap',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 12),

              TextButton.icon(
                icon: const Icon(
                  Icons.delete_forever_rounded,
                  size: 18,
                  color: AppColors.textSecondaryLight,
                ),
                label: const Text(
                  'Hesabımı ve Verilerimi Kalıcı Olarak Sil',
                  style: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => _confirmDeleteAccount(context, auth),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: onTap,
      ),
    );
  }

  void _showServerSettings(BuildContext context, AuthProvider auth) {
    final urlController = TextEditingController(
      text: 'http://10.0.2.2:8000/api/v1',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sunucu Bağlantı Adresi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fiziksel telefonda çalıştırırken bilgisayarınızın yerel IP adresini giriniz (Örn: http://192.168.1.35:8000/api/v1):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.setCustomServerUrl(urlController.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sunucu adresi güncellendi: ${urlController.text.trim()}'),
                ),
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gizlilik Politikası'),
        content: const SingleChildScrollView(
          child: Text(
            'Shiftly, kullanıcılarının gizliliğine ve kişisel verilerine en üst düzeyde önem verir.\n\n'
            '1. Veri Toplama: Sadece vardiya yönetimi için gerekli olan nöbet saatleri ve kullanıcı bilgileri işlenir.\n'
            '2. Güvenlik: Şifreleriniz modern bcrypt algoritması ile tek yönlü hashlenerek saklanır.\n'
            '3. Üçüncü Taraflar: Verileriniz hiçbir reklam veya analiz şirketiyle paylaşılmaz.\n'
            '4. Haklarınız: Dilediğiniz zaman hesabınızı ve tüm vardiya kayıtlarınızı silebilirsiniz.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kullanım Koşulları'),
        content: const SingleChildScrollView(
          child: Text(
            'Shiftly uygulamasını kullanarak aşağıdaki şartları kabul etmiş olursunuz:\n\n'
            '1. Vardiya ve takas verileri personelin kendi sorumluluğundadır.\n'
            '2. Resmi kurum nöbet listeleriyle olası uyuşmazlıklarda kurumun resmi çizelgesi esastır.\n'
            '3. Hizmet kesintisizliği için azami gayret gösterilmektedir.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hesabı Sil?'),
        content: const Text(
          'Hesabınızı sildiğinizde tüm vardiyalarınız, ekipleriniz ve takas geçmişiniz kalıcı olarak silinecektir. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              final success = await auth.deleteAccount();
              if (success && context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );
  }
}
