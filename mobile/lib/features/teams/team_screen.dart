import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekibim ve Ortak Takvim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded),
            tooltip: 'Ekibe Katıl',
            onPressed: () {
              _showJoinTeamDialog(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Team Info Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Acil Servis Nöbet Ekibi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'KOD: SHF-82K9',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '7/24 Acil Müdahale ve Nöbet Organizasyonu • 4 Üye',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Horizontal Weekly Team Calendar (Spec #18)
              const Text(
                'HAFTALIK EKİP TAKVİMİ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              _buildTeamMatrixCard(),

              const SizedBox(height: 24),

              // Team Members List
              const Text(
                'EKİP ÜYELERİ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              _buildMemberTile(
                name: 'Necati Yılmaz (Sen)',
                role: 'Yönetici (Owner)',
                isOnline: true,
              ),
              _buildMemberTile(
                name: 'Ali Vural',
                role: 'Hemşire',
                isOnline: true,
              ),
              _buildMemberTile(
                name: 'Mehmet Kaya',
                role: 'Acil Tıp Teknikeri',
                isOnline: false,
              ),
              _buildMemberTile(
                name: 'Ayşe Demir',
                role: 'Doktor',
                isOnline: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamMatrixCard() {
    final members = [
      {
        'name': 'Necati',
        'shifts': ['G', 'N', 'İ', 'İ', 'G', 'N', 'İ'],
      },
      {
        'name': 'Ali',
        'shifts': ['N', 'İ', 'İ', 'G', 'N', 'İ', 'İ'],
      },
      {
        'name': 'Mehmet',
        'shifts': ['İ', 'G', 'N', 'İ', 'İ', 'G', 'N'],
      },
      {
        'name': 'Ayşe',
        'shifts': ['İ', 'İ', 'G', 'N', 'İ', 'İ', 'G'],
      },
    ];
    final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 52,
          horizontalMargin: 16,
          columnSpacing: 18,
          columns: [
            const DataColumn(
              label: Text(
                'Personel',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ...days.map(
              (d) => DataColumn(
                label: Text(
                  d,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          rows: members.map((m) {
            final shiftList = m['shifts'] as List<String>;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    m['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ...shiftList.map((st) {
                  Color color = AppColors.shiftDay;
                  if (st == 'N') color = AppColors.shiftNight;
                  if (st == 'İ') color = AppColors.shiftOff;

                  return DataCell(
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        st,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMemberTile({
    required String name,
    required String role,
    required bool isOnline,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            name[0],
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(role, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isOnline ? AppColors.success : AppColors.borderLight,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  void _showJoinTeamDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ekibe Katıl'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Davet Kodu',
            hintText: 'Örn: SHF-82K9',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ekip daveti doğrulandı!')),
              );
            },
            child: const Text('Katıl'),
          ),
        ],
      ),
    );
  }
}
