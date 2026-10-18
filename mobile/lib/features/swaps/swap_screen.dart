import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vardiya Takası'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Taleplerim'),
            Tab(text: 'Mevcut Takaslar'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [_buildMySwapsTab(), _buildAvailableSwapsTab()],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
        label: const Text(
          'Takasa Aç',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        onPressed: () {
          _showCreateSwapModal(context);
        },
      ),
    );
  }

  Widget _buildMySwapsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Active swap card example
        _buildSwapCard(
          title: '12 Ekim Gece Nöbeti Takası',
          myShift: '12 Ekim 20:00 — 08:00 (Gece)',
          targetShift: '13 Ekim 20:00 — 08:00 (Mehmet Kaya)',
          status: 'PENDING',
          statusText: 'Onay Bekliyor',
          note: '12 Ekim gece nöbetimi 13 Ekim ile değiştirmek istiyorum.',
        ),
      ],
    );
  }

  Widget _buildAvailableSwapsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSwapCard(
          title: 'Ali Vural — Nöbet Değişimi',
          myShift: '15 Ekim 08:00 — 16:00 (Gündüz)',
          targetShift: '14 Ekim 08:00 — 16:00 (Senin Vardiyan)',
          status: 'AVAILABLE',
          statusText: 'Uygun Takas',
          note: 'Acil işim nedeniyle 15 Ekim gündüzümü verebilirim.',
          canAccept: true,
        ),
      ],
    );
  }

  Widget _buildSwapCard({
    required String title,
    required String myShift,
    required String targetShift,
    required String status,
    required String statusText,
    required String note,
    bool canAccept = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'PENDING'
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: status == 'PENDING'
                          ? AppColors.accent
                          : AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Visual swap representation (Ali 12 Oct <-> Mehmet 13 Oct)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_upward_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          myShift,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: AppColors.textSecondaryLight,
                      size: 20,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_downward_rounded,
                        color: AppColors.secondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          targetShift,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Açıklama: $note',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

            if (canAccept) ...[
              const SizedBox(height: 16),
              AppButton(
                text: 'Takası Kabul Et',
                backgroundColor: AppColors.secondary,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '✓ Takas kabul edildi ve takvimler güncellendi!',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCreateSwapModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vardiyanı Takasa Aç',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text('Takasa açmak istediğiniz vardiyayı seçin:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                  SizedBox(width: 12),
                  Text(
                    '12 Ekim 2026 — Gece Nöbeti',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Açıklama / Tercih Ettiğin Gün',
                hintText: 'Örn: 13 veya 14 Ekim nöbetleriyle değiştirebilirim',
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Takas Talebi Oluştur',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Takas talebi ekibinize iletildi.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
