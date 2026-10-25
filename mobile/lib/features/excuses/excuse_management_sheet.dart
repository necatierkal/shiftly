import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/shift_models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_colors.dart';

class ExcuseManagementSheet extends StatefulWidget {
  const ExcuseManagementSheet({super.key});

  @override
  State<ExcuseManagementSheet> createState() => _ExcuseManagementSheetState();
}

class _ExcuseManagementSheetState extends State<ExcuseManagementSheet> {
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShiftProvider>().fetchExcuses();
    });
  }

  void _showReviewDialog(DutyExcuseModel excuse, String action) {
    final noteController = TextEditingController();
    final isApprove = action == 'APPROVED';
    final isReject = action == 'REJECTED';
    final actionTitle = isApprove
        ? 'Mazereti Onayla'
        : isReject
            ? 'Mazereti Reddet'
            : 'Bilgi İste';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${excuse.user?.fullName ?? 'Personel'}: ${excuse.typeDisplay}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tarih: ${DateFormat('dd.MM.yyyy').format(excuse.startDate)} - ${DateFormat('dd.MM.yyyy').format(excuse.endDate)}',
              style: const TextStyle(fontSize: 13),
            ),
            if (excuse.reason != null && excuse.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Gerekçe: "${excuse.reason}"',
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Yönetici Notu (İsteğe bağlı)',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove
                  ? AppColors.secondary
                  : isReject
                      ? AppColors.error
                      : AppColors.primary,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ShiftProvider>().reviewExcuse(
                    excuse.id,
                    action,
                    adminNote: noteController.text.trim().isNotEmpty
                        ? noteController.text.trim()
                        : null,
                  );
            },
            child: Text(isApprove ? 'Onayla' : isReject ? 'Reddet' : 'Gönder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shiftProv = context.watch<ShiftProvider>();
    final isManager = auth.isManager;
    var list = shiftProv.excuses;

    if (_selectedFilter != 'ALL') {
      list = list.where((e) => e.status == _selectedFilter).toList();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isManager ? 'Personel Mazeretleri' : 'Mazeret Bildirimlerim',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Tümü (${shiftProv.excuses.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('PENDING', 'Bekleyen (${shiftProv.pendingExcusesCount})'),
                const SizedBox(width: 8),
                _buildFilterChip('APPROVED', 'Onaylanan'),
                const SizedBox(width: 8),
                _buildFilterChip('REJECTED', 'Reddedilen'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Kayıtlı mazeret bulunmuyor.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final excuse = list[index];
                      final dateRange = excuse.startDate.isAtSameMomentAs(excuse.endDate)
                          ? DateFormat('dd.MM.yyyy').format(excuse.startDate)
                          : '${DateFormat('dd.MM.yyyy').format(excuse.startDate)} - ${DateFormat('dd.MM.yyyy').format(excuse.endDate)}';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    excuse.user?.fullName ?? (isManager ? 'Personel' : 'Ben'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: excuse.statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      excuse.statusDisplay,
                                      style: TextStyle(
                                        color: excuse.statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.label_outline,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    excuse.typeDisplay,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateRange,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              if (excuse.reason != null && excuse.reason!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    excuse.reason!,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                              if (excuse.adminNote != null && excuse.adminNote!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Yönetici Notu: ${excuse.adminNote}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (isManager && excuse.status == 'PENDING') ...[
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(color: AppColors.error),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _showReviewDialog(excuse, 'REJECTED'),
                                      child: const Text('Reddet'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.secondary,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _showReviewDialog(excuse, 'APPROVED'),
                                      child: const Text('Onayla'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = filterKey);
      },
    );
  }
}
