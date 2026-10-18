import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/shift_models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../shifts/create_shift_dialog.dart';
import '../shifts/auto_pattern_dialog.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shiftProv = context.watch<ShiftProvider>();
    final user = auth.currentUser;
    final now = DateTime.now();

    final todayShift = shiftProv.todayShift;
    final nextShift = shiftProv.nextShift;
    final weekShifts = shiftProv.thisWeekShifts;

    double weekHours = 0;
    for (var s in weekShifts) {
      if (s.shiftType?.isWorking ?? true) {
        weekHours += s.durationHours;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await shiftProv.fetchShifts();
            await shiftProv.fetchStatistics();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header: "Merhaba, Necati 👋"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merhaba, ${user?.firstName ?? 'Çalışan'} 👋',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bugün ${DateFormat('d MMMM, EEEE', 'tr_TR').format(now)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bildirimler güncel')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. Large Featured Card: "BUGÜNKÜ VARDİYAN"
                if (todayShift != null)
                  ShiftCard(shift: todayShift, isFeatured: true, onTap: () {})
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.shiftOff.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'BUGÜN VARDİYA YOK',
                                style: TextStyle(
                                  color: AppColors.shiftOff,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Bugün İzinli veya Boş Gün',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Harika bir gün dileriz! Dinlenmenin tadını çıkarın.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),

                // 3. Next Shift Row
                if (nextShift != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                (nextShift.shiftType?.color ??
                                        AppColors.primary)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            nextShift.shiftType?.isNight ?? false
                                ? Icons.nights_stay_rounded
                                : Icons.wb_sunny_rounded,
                            color:
                                nextShift.shiftType?.color ?? AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SONRAKİ VARDİYA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('dd MMM').format(nextShift.date)} — ${nextShift.shiftType?.name ?? 'Vardiya'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${nextShift.shiftType?.startTime ?? '08:00'} - ${nextShift.shiftType?.endTime ?? '16:00'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 4. Quick Action Chips: Vardiya | Otomatik Döngü | Takvim | Takas
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.add_rounded,
                        label: 'Vardiya',
                        color: AppColors.primary,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const CreateShiftSheet(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.autorenew_rounded,
                        label: 'Döngü (24/48)',
                        color: AppColors.secondary,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const AutoPatternSheet(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.calendar_month_rounded,
                        label: 'Takvim',
                        color: Colors.indigo,
                        onTap: () => onNavigateTab?.call(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Takas',
                        color: AppColors.accent,
                        onTap: () => onNavigateTab?.call(3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 5. This Week Summary: "BU HAFTA"
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'BU HAFTA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            'Çalışma: ${weekHours.toStringAsFixed(0)} saat',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 7 Day Dots Row (Pzt Sal Çar Per Cum Cmt Paz)
                      _buildWeekDaysRow(weekShifts),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 6. Team Widget Card: "EKİBİN — 3 kişi bugün çalışıyor"
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.group_rounded,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EKİBİN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Acil Servis Nöbet Ekibi',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Bugün ekipte 3 kişi nöbette',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onPressed: () => onNavigateTab?.call(2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDaysRow(List<ShiftModel> weekShifts) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayDate = DateTime(
          monday.year,
          monday.month,
          monday.day,
        ).add(Duration(days: i));
        final isToday =
            dayDate.day == now.day &&
            dayDate.month == now.month &&
            dayDate.year == now.year;

        // Check if there is a shift on this day
        ShiftModel? shiftOnDay;
        try {
          shiftOnDay = weekShifts.firstWhere((s) {
            return s.date.day == dayDate.day &&
                s.date.month == dayDate.month &&
                s.date.year == dayDate.year;
          });
        } catch (_) {}

        final dotColor = shiftOnDay != null
            ? (shiftOnDay.shiftType?.color ?? AppColors.primary)
            : AppColors.borderLight;

        return Column(
          children: [
            Text(
              dayNames[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday
                    ? AppColors.primary
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '${dayDate.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday ? AppColors.primary : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      }),
    );
  }
}
