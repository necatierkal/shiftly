import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/shift_models.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';

class PlanManagementSheet extends StatefulWidget {
  final DutyPeriodModel period;

  const PlanManagementSheet({super.key, required this.period});

  @override
  State<PlanManagementSheet> createState() => _PlanManagementSheetState();
}

class _PlanManagementSheetState extends State<PlanManagementSheet> {
  bool _isGenerating = false;
  bool _isPublishing = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShiftProvider>().fetchPublishedPlan(widget.period.id);
    });
  }

  Future<void> _generateDraft() async {
    setState(() => _isGenerating = true);
    final shiftProv = context.read<ShiftProvider>();

    final plan = await shiftProv.generateDraftPlan(
      periodId: widget.period.id,
      teamId: widget.period.teamId,
      minRestHours: 11,
      maxConsecutiveDays: 6,
      targetShiftsPerPerson: 7,
      respectNightRules: true,
    );

    setState(() => _isGenerating = false);

    if (mounted) {
      if (plan != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text(
              'v${plan.version} taslak planı oluşturuldu. Atanamayan nöbet: ${plan.unassignedCount}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Plan oluşturulurken bir hata oluştu.'),
          ),
        );
      }
    }
  }

  Future<void> _publishPlan(int planId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Planı Yayımla'),
        content: const Text(
          'Bu taslağı onaylayıp tüm personele resmi nöbet listesi olarak yayımlamak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yayımla ve Bildir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isPublishing = true);
    final success = await context.read<ShiftProvider>().publishPlan(planId);
    setState(() => _isPublishing = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text('Nöbet planı başarıyla yayımlandı!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Yayımlama sırasında bir sorun oluştu.'),
          ),
        );
      }
    }
  }

  Future<void> _export(String type, int planId) async {
    setState(() => _isExporting = true);
    final shiftProv = context.read<ShiftProvider>();
    final bytes = type == 'excel'
        ? await shiftProv.exportPlanExcel(planId)
        : await shiftProv.exportPlanPdf(planId);
    setState(() => _isExporting = false);

    if (mounted) {
      if (bytes != null && bytes.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text(
              type == 'excel'
                  ? 'Excel çizelgesi hazırlandı (${bytes.lengthInBytes} bayt)'
                  : 'PDF nöbet listesi hazırlandı (${bytes.lengthInBytes} bayt)',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('$type dışa aktarımı başarısız oldu.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftProv = context.watch<ShiftProvider>();
    final plan = shiftProv.currentPlan;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nöbet Planlama & Taslak',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.period.name,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: plan == null ? 'Otomatik Taslak Üret' : 'Taslağı Yeniden Üret',
                  icon: Icons.auto_awesome,
                  isLoading: _isGenerating,
                  onPressed: _generateDraft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (plan != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: plan.isPublished
                    ? AppColors.secondary.withValues(alpha: 0.1)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: plan.isPublished
                      ? AppColors.secondary.withValues(alpha: 0.3)
                      : Colors.blue.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Sürüm', 'v${plan.version}'),
                  _buildStatItem('Durum', plan.isPublished ? 'Yayımlandı' : 'Taslak'),
                  _buildStatItem('Nöbet Sayısı', '${plan.shifts.length}'),
                  _buildStatItem(
                    'Atanamayan',
                    '${plan.unassignedCount}',
                    isWarning: plan.unassignedCount > 0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!plan.isPublished)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isPublishing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Planı Yayımla'),
                      onPressed: _isPublishing ? null : () => _publishPlan(plan.id),
                    ),
                  ),
                if (!plan.isPublished) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.table_chart, size: 18),
                    label: const Text('Excel (.xlsx)'),
                    onPressed: _isExporting ? null : () => _export('excel', plan.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF (.pdf)'),
                    onPressed: _isExporting ? null : () => _export('pdf', plan.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Nöbet Listesi Detayı',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: plan.shifts.length,
                itemBuilder: (ctx, i) {
                  final s = plan.shifts[i];
                  final isUnassigned = s.assignedUserId == null;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: isUnassigned
                            ? AppColors.error.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.15),
                        child: Icon(
                          isUnassigned ? Icons.warning_amber_rounded : Icons.person,
                          color: isUnassigned ? AppColors.error : AppColors.primary,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        isUnassigned
                            ? 'ATANMADI (Boş Vardiya)'
                            : (s.assignedUser?.fullName ?? 'Personel #${s.assignedUserId}'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isUnassigned ? AppColors.error : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        '${DateFormat('dd.MM.yyyy').format(s.date)} • ${s.shiftType?.name ?? 'Nöbet'} (${DateFormat('HH:mm').format(s.startDateTime)} - ${DateFormat('HH:mm').format(s.endDateTime)})',
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_send_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Henüz bu dönem için bir nöbet taslağı oluşturulmadı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Personel mazeretlerini ve dinlenme kurallarını dikkate alarak otomatik plan oluşturmak için yukarıdaki butona tıklayın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {bool isWarning = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isWarning ? AppColors.error : AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
