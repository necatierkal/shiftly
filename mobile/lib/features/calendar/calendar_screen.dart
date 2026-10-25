import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../shifts/create_shift_dialog.dart';
import '../shifts/auto_pattern_dialog.dart';
import '../plans/plan_management_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  Future<void> _exportPlan(String type) async {
    final shiftProv = context.read<ShiftProvider>();
    final plan = shiftProv.currentPlan;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dışa aktarmak için aktif bir nöbet planı bulunamadı.'),
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    final bytes = type == 'excel'
        ? await shiftProv.exportPlanExcel(plan.id)
        : await shiftProv.exportPlanPdf(plan.id);
    setState(() => _isExporting = false);

    if (mounted) {
      if (bytes != null && bytes.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text(
              type == 'excel'
                  ? 'Excel (.xlsx) tablosu hazırlandı (${bytes.lengthInBytes} bayt)'
                  : 'PDF (.pdf) nöbet listesi hazırlandı (${bytes.lengthInBytes} bayt)',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('$type dışa aktarılamadı.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shiftProv = context.watch<ShiftProvider>();
    final isManager = auth.isManager;
    final dayShifts = shiftProv.getShiftsForDate(_selectedDay);
    final lastSync = shiftProv.lastSyncTime;
    final activePeriod = shiftProv.activePeriod;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nöbet & Vardiya Takvimi'),
        actions: [
          if (isManager && activePeriod != null) ...[
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Excel Çizelgesi',
              onPressed: _isExporting ? null : () => _exportPlan('excel'),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'PDF Nöbet Listesi',
              onPressed: _isExporting ? null : () => _exportPlan('pdf'),
            ),
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              tooltip: 'Nöbet Taslak Yönetimi',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => PlanManagementSheet(period: activePeriod),
                );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.autorenew_rounded),
            tooltip: 'Otomatik Döngü Uygula',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AutoPatternSheet(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Vardiya Ekle',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => CreateShiftSheet(initialDate: _selectedDay),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sync status strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_done_outlined,
                    size: 13,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    lastSync != null
                        ? 'Son eşitleme: ${DateFormat('dd.MM.yyyy HH:mm').format(lastSync)}'
                        : 'Çevrimdışı Mod — Yerel Veriler Gösteriliyor',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (isManager)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Yönetici Modu',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Month Header Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat(
                      'MMMM yyyy',
                      'tr_TR',
                    ).format(_focusedMonth).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _previousMonth,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Weekday names header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map(
                  (name) {
                    final isWeekend = name == 'Cmt' || name == 'Paz';
                    return Expanded(
                      child: Center(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isWeekend
                                ? AppColors.accent
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Calendar Grid View
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildMonthGrid(shiftProv),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),

            // Selected Day Header & Shift List
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat(
                      'd MMMM yyyy, EEEE',
                      'tr_TR',
                    ).format(_selectedDay),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) =>
                            CreateShiftSheet(initialDate: _selectedDay),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '+ Nöbet Ekle',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: dayShifts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 40,
                            color: AppColors.textSecondaryLight.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Bu tarihte planlanmış nöbet yok.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Nöbet veya İzin Ekle'),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) =>
                                    CreateShiftSheet(initialDate: _selectedDay),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: dayShifts.length,
                      itemBuilder: (context, index) {
                        final s = dayShifts[index];
                        return ShiftCard(
                          shift: s,
                          onDelete: () => shiftProv.deleteShift(s.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(ShiftProvider shiftProv) {
    final firstDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;

    final offset = firstDayOfMonth.weekday - 1;
    final totalCells = ((offset + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - offset + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final cellDate = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          dayNumber,
        );
        final isSelected =
            cellDate.day == _selectedDay.day &&
            cellDate.month == _selectedDay.month &&
            cellDate.year == _selectedDay.year;

        final shiftsForCell = shiftProv.getShiftsForDate(cellDate);
        final hasShift = shiftsForCell.isNotEmpty;
        final primaryShift = hasShift ? shiftsForCell.first : null;
        final shiftColor = primaryShift?.shiftType?.color ?? AppColors.primary;
        final shiftShort = primaryShift?.shiftType?.shortName ?? '';

        return InkWell(
          onTap: () => setState(() => _selectedDay = cellDate),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppColors.primary, width: 2)
                  : Border.all(
                      color: AppColors.borderLight.withValues(alpha: 0.4),
                    ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.primary : null,
                  ),
                ),
                const SizedBox(height: 2),
                if (hasShift)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: shiftColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shiftShort,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}
