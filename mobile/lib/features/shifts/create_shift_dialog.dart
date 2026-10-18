import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/shift_models.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';

class CreateShiftSheet extends StatefulWidget {
  final DateTime? initialDate;

  const CreateShiftSheet({super.key, this.initialDate});

  @override
  State<CreateShiftSheet> createState() => _CreateShiftSheetState();
}

class _CreateShiftSheetState extends State<CreateShiftSheet> {
  late DateTime _selectedDate;
  ShiftTypeModel? _selectedType;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();
  final int _reminderMinutes = 60;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final types = context.watch<ShiftProvider>().shiftTypes;
    if (_selectedType == null && types.isNotEmpty) {
      _selectedType = types.first;
      _parseTimesFromType(_selectedType!);
    }
  }

  void _parseTimesFromType(ShiftTypeModel type) {
    try {
      final sParts = type.startTime.split(':');
      final eParts = type.endTime.split(':');
      setState(() {
        _startTime = TimeOfDay(hour: int.parse(sParts[0]), minute: int.parse(sParts[1]));
        _endTime = TimeOfDay(hour: int.parse(eParts[0]), minute: int.parse(eParts[1]));
      });
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveShift() async {
    if (_selectedType == null) return;

    final startDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    DateTime endDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    // Crosses midnight or 24h
    if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
      endDt = endDt.add(const Duration(days: 1));
    }

    final provider = context.read<ShiftProvider>();
    final success = await provider.createShift(
      shiftTypeId: _selectedType!.id,
      date: _selectedDate,
      startDateTime: startDt,
      endDateTime: endDt,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      reminderMinutes: _reminderMinutes,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('✓ Vardiya başarıyla oluşturuldu'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Vardiya oluşturulamadı.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftTypes = context.watch<ShiftProvider>().shiftTypes;

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
              'Vardiya Ekle',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),

            // Shift Type selector chips
            const Text('Vardiya Tipi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: shiftTypes.map((type) {
                  final isSelected = _selectedType?.id == type.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ShiftChip(
                      label: '${type.shortName} • ${type.name}',
                      color: type.color,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() => _selectedType = type);
                        _parseTimesFromType(type);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Date selector
            const Text('Tarih', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Start - End Times
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Başlangıç', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _startTime);
                          if (t != null) setState(() => _startTime = t);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 18, color: AppColors.textSecondaryLight),
                              const SizedBox(width: 8),
                              Text('${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
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
                      const Text('Bitiş', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _endTime);
                          if (t != null) setState(() => _endTime = t);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 18, color: AppColors.textSecondaryLight),
                              const SizedBox(width: 8),
                              Text('${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Konum / Birim',
                hintText: 'Örn: Ankara Numune Hastanesi',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Note
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Not',
                hintText: 'Örn: Nöbetçi hekim odası',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
            AppButton(
              text: 'Vardiyayı Kaydet',
              isLoading: context.watch<ShiftProvider>().isLoading,
              onPressed: _saveShift,
            ),
          ],
        ),
      ),
    );
  }
}
