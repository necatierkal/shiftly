import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';

class AutoPatternSheet extends StatefulWidget {
  const AutoPatternSheet({super.key});

  @override
  State<AutoPatternSheet> createState() => _AutoPatternSheetState();
}

class _AutoPatternSheetState extends State<AutoPatternSheet> {
  String _selectedCycle = '24/48';
  DateTime _startDate = DateTime(2026, 10, 3);
  DateTime _endDate = DateTime(2026, 12, 31);
  bool _overwrite = false;

  final List<Map<String, String>> _cycleTypes = [
    {'title': '24/48', 'desc': '1 gün çalışma, 2 gün izin (3 günlük döngü)'},
    {'title': '24/72', 'desc': '1 gün çalışma, 3 gün izin (4 günlük döngü)'},
    {'title': '12/24', 'desc': '12 saat gündüz, 24 saat dinlenme'},
    {'title': '12/36', 'desc': '12 saat gece, 36 saat dinlenme'},
    {'title': '2 vardiya', 'desc': 'Gündüz / Gece dönüşümlü döngü'},
    {'title': '3 vardiya', 'desc': 'Sabah / Akşam / Gece dönüşümlü döngü'},
  ];

  int get _totalDays => _endDate.difference(_startDate).inDays + 1;

  int get _estimatedWorkingShifts {
    if (_totalDays <= 0) return 0;
    if (_selectedCycle == '24/48') return (_totalDays / 3).ceil();
    if (_selectedCycle == '24/72') return (_totalDays / 4).ceil();
    if (_selectedCycle == '12/24') return (_totalDays / 2).ceil();
    if (_selectedCycle == '12/36') return (_totalDays / 2).ceil();
    return (_totalDays * 0.4).ceil();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 90));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _generate() async {
    final provider = context.read<ShiftProvider>();
    final success = await provider.generatePattern(
      cycleType: _selectedCycle,
      startDate: _startDate,
      endDate: _endDate,
      overwrite: _overwrite,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '✓ $_estimatedWorkingShifts nöbet başarıyla takvime işlendi!',
                ),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Döngü oluşturulamadı.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Otomatik Vardiya Döngüsü',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Döngüyü ve tarih aralığını belirleyin, takviminiz otomatik oluşturulsun.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),

            // Pattern Selection
            const Text(
              'Döngü Tipi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cycleTypes.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.borderLight),
                itemBuilder: (context, index) {
                  final c = _cycleTypes[index];
                  return RadioListTile<String>(
                    value: c['title']!,
                    groupValue: _selectedCycle,
                    activeColor: AppColors.primary,
                    title: Text(
                      c['title']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      c['desc']!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCycle = val);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Start & End Date Pickers
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Başlangıç',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickStartDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            DateFormat('dd.MM.yyyy').format(_startDate),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bitiş',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickEndDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            DateFormat('dd.MM.yyyy').format(_endDate),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Overwrite Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Mevcut Vardiyaların Üzerine Yaz',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Tarih aralığında çakışan eski kayıtları günceller',
                style: TextStyle(fontSize: 12),
              ),
              value: _overwrite,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _overwrite = val),
            ),
            const SizedBox(height: 12),

            // Preview Box (Spec #13: "78 vardiya oluşturulacak önizleme")
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$_totalDays günlük takvim aralığında yaklaşık $_estimatedWorkingShifts çalışma nöbeti oluşturulacak.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            AppButton(
              text: 'Toplu Vardiya Oluştur',
              isLoading: context.watch<ShiftProvider>().isLoading,
              onPressed: _generate,
            ),
          ],
        ),
      ),
    );
  }
}
