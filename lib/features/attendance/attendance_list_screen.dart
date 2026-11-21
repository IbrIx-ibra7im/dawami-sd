import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/permissions/role_manager.dart';
import '../../core/utils/date_helper.dart';
import '../../data/models/attendance_record.dart';
import '../../data/repositories/app_repository.dart';
import '../../widgets/custom_widgets.dart';
import 'manual_attendance_dialog.dart';
import 'audit_logs_screen.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  String _selectedTab = 'اليوم'; // 'اليوم', 'الكل', 'البصمة', 'QR'
  final Set<String> _selectedRecordIds = {};

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = repo.todayAttendance;

    // Filter according to selected tab (اليوم / الكل / البصمة / QR)
    List<AttendanceRecord> displayedRecords = records;
    if (_selectedTab == 'البصمة') {
      displayedRecords = records.where((r) => r.method == 'fingerprint').toList();
    } else if (_selectedTab == 'QR') {
      displayedRecords = records.where((r) => r.method == 'qr').toList();
    }

    final canDelete = RoleManager.canDelete(repo.currentRole);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Column(
          children: [
            const Text('سجل الحضور والانصراف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              '${displayedRecords.length} سجل${_selectedRecordIds.isNotEmpty ? " • ${_selectedRecordIds.length} محدد" : ""}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.darkBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'سجل التعديلات (Audit Log)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Current Lecture Info Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.primaryBlue.withAlpha(20),
            child: Row(
              children: [
                const Icon(Icons.school, size: 20, color: AppColors.primaryBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'محاضرة: ${repo.activeSession?.lectureName ?? 'برمجة 1'} — ${repo.activeSession?.classroomName ?? 'قاعة 3'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'جارية',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Tabs (اليوم / الكل / البصمة / QR)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: Row(
              children: [
                _buildTabChip('اليوم'),
                const SizedBox(width: 8),
                _buildTabChip('الكل'),
                const SizedBox(width: 8),
                _buildTabChip('البصمة'),
                const SizedBox(width: 8),
                _buildTabChip('QR'),
              ],
            ),
          ),

          // Multi-Select Action Banner for Attendance Records
          if (_selectedRecordIds.isNotEmpty && canDelete)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.danger.withAlpha(25),
              child: Row(
                children: [
                  const Icon(Icons.check_box_rounded, color: AppColors.danger, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'تم تحديد ${_selectedRecordIds.length} من سجلات الحضور والانصراف',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.select_all_rounded, size: 16),
                    label: const Text('تحديد الكل', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _selectedRecordIds.addAll(displayedRecords.map((r) => r.id));
                      });
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.deselect_rounded, size: 16),
                    label: const Text('إلغاء التحديد', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _selectedRecordIds.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever_rounded, size: 16),
                    label: Text(
                      'حذف المحدد (${_selectedRecordIds.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmDeleteSelectedRecords(context, repo),
                  ),
                ],
              ),
            ),

          // Records List or Desktop DataTable
          Expanded(
            child: displayedRecords.isEmpty
                ? const Center(
                    child: Text('لا توجد سجلات حضور مسجلة حالياً', style: TextStyle(color: Colors.grey)),
                  )
                : (MediaQuery.of(context).size.width >= 800)
                    ? _buildDesktopDataTable(context, displayedRecords, repo, isDark, canDelete)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayedRecords.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final record = displayedRecords[index];
                          return _buildRecordTile(context, record, repo, isDark, canDelete);
                        },
                      ),
          ),

          // Bottom Action Buttons (+ حضور يدوي / سجل التعديلات)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Row(
              children: [
                if (RoleManager.canRecordAttendance(repo.currentRole))
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('+ حضور يدوي'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const ManualAttendanceDialog(),
                        );
                      },
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('سجل التعديلات'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label) {
    final isSelected = _selectedTab == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.primaryBlue,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedTab = label);
      },
    );
  }

  Widget _buildDesktopDataTable(
    BuildContext context,
    List<AttendanceRecord> records,
    AppRepository repo,
    bool isDark,
    bool canDelete,
  ) {
    final allSelected = records.isNotEmpty &&
        records.every((r) => _selectedRecordIds.contains(r.id));

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.primaryBlue.withAlpha(20)),
                columns: [
                  if (canDelete)
                    DataColumn(
                      label: Checkbox(
                        value: allSelected,
                        tristate: !allSelected && _selectedRecordIds.isNotEmpty,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedRecordIds.addAll(records.map((r) => r.id));
                            } else {
                              _selectedRecordIds.clear();
                            }
                          });
                        },
                      ),
                    ),
                  const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('اسم الطالب', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('الرقم الجامعي', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('طريقة الحضور', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('وقت الحضور', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('وقت الانصراف', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (canDelete)
                    const DataColumn(label: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List.generate(records.length, (index) {
                  final r = records[index];
                  final isSelected = _selectedRecordIds.contains(r.id);
                  final method = r.method == 'qr'
                      ? 'QR Code'
                      : (r.method == 'fingerprint' ? 'بصمة' : 'يدوي');
                  final inTime = DateHelper.formatTimeString(r.checkIn);
                  final outTime = r.checkOut != null ? DateHelper.formatTimeString(r.checkOut) : null;

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: canDelete
                        ? (val) {
                            setState(() {
                              if (val == true) {
                                _selectedRecordIds.add(r.id);
                              } else {
                                _selectedRecordIds.remove(r.id);
                              }
                            });
                          }
                        : null,
                    cells: [
                      if (canDelete)
                        DataCell(
                          Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedRecordIds.add(r.id);
                                } else {
                                  _selectedRecordIds.remove(r.id);
                                }
                              });
                            },
                          ),
                        ),
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(r.studentName ?? 'طالب', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(r.universityId ?? '-')),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            r.method == 'qr'
                                ? Icons.qr_code
                                : (r.method == 'fingerprint' ? Icons.fingerprint : Icons.edit_note),
                            size: 16,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(method),
                        ],
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.login_rounded, size: 15, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(inTime, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            outTime != null ? Icons.logout_rounded : Icons.timelapse_rounded,
                            size: 15,
                            color: outTime != null ? AppColors.primaryBlue : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            outTime ?? 'جاري الدوام',
                            style: TextStyle(
                              color: outTime != null ? AppColors.darkBlue : Colors.grey.shade600,
                              fontWeight: outTime != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      )),
                      DataCell(StatusBadge.fromStatus(r.status)),
                      if (canDelete)
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                            tooltip: 'حذف سجل الحضور والانصراف',
                            onPressed: () => _confirmDeleteSingleRecord(context, r, repo),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordTile(
    BuildContext context,
    AttendanceRecord record,
    AppRepository repo,
    bool isDark,
    bool canDelete,
  ) {
    final firstLetter = record.studentName != null && record.studentName!.isNotEmpty
        ? record.studentName![0]
        : 'ط';
    final isSelected = _selectedRecordIds.contains(record.id);

    String methodLabel = record.method == 'qr'
        ? 'QR'
        : (record.method == 'fingerprint' ? 'بصمة' : 'يدوي');

    IconData methodIcon = record.method == 'qr'
        ? Icons.qr_code
        : (record.method == 'fingerprint' ? Icons.fingerprint : Icons.edit_note);

    final inTime = DateHelper.formatTimeString(record.checkIn);
    final outTime = record.checkOut != null ? DateHelper.formatTimeString(record.checkOut) : null;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryBlue.withAlpha(20)
            : (isDark ? AppColors.surfaceDark : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryBlue
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                if (canDelete) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedRecordIds.add(record.id);
                        } else {
                          _selectedRecordIds.remove(record.id);
                        }
                      });
                    },
                  ),
                ],
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryBlue.withAlpha(20),
                  child: Text(
                    firstLetter,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.studentName ?? 'طالب غير معرّف',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            record.universityId ?? '-',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Icon(methodIcon, size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(
                            methodLabel,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            record.isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                            size: 14,
                            color: record.isSynced ? AppColors.turquoise : AppColors.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusBadge.fromStatus(record.status),
                if (canDelete) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                    tooltip: 'حذف السجل',
                    onPressed: () => _confirmDeleteSingleRecord(context, record, repo),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Two-column badges for Check-In and Check-Out times
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded, size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          'حضور: $inTime',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: outTime != null ? AppColors.primaryBlue.withAlpha(20) : Colors.grey.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: outTime != null ? AppColors.primaryBlue.withAlpha(60) : Colors.grey.withAlpha(40),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          outTime != null ? Icons.logout_rounded : Icons.timelapse_rounded,
                          size: 14,
                          color: outTime != null ? AppColors.primaryBlue : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          outTime != null ? 'انصراف: $outTime' : 'انصراف: لم يسجل',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: outTime != null ? AppColors.primaryBlue : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSelectedRecords(BuildContext context, AppRepository repo) {
    final count = _selectedRecordIds.length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: 10),
            Text(
              'تأكيد حذف سجلات الحضور المحددة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.danger),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من رغبتك في حذف $count من سجلات الحضور والانصراف المحددة؟',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ تنبيه: سيتم حذف هذه السجلات نهائياً من قاعدة البيانات المحلية وقائمة المزامنة ولا يمكن استرجاعها.',
              style: TextStyle(fontSize: 12, color: AppColors.danger, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء التراجع', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text('نعم، تأكيد حذف $count سجلات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final idsToDelete = _selectedRecordIds.toList();
                await repo.deleteMultipleAttendanceRecords(idsToDelete);
                setState(() {
                  _selectedRecordIds.clear();
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '🔔 تنبيه: تم حذف $count سجل حضور وانصراف بنجاح',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ أثناء حذف السجلات: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSingleRecord(BuildContext context, AttendanceRecord record, AppRepository repo) {
    final studentName = record.studentName ?? 'الطالب';
    final inTime = DateHelper.formatTimeString(record.checkIn);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: 10),
            Text(
              'تأكيد حذف سجل الحضور',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.danger),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من حذف سجل حضور $studentName؟',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'وقت الحضور: $inTime | الطريقة: ${record.method}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ تنبيه: سيتم حذف السجل نهائياً من قاعدة البيانات.',
              style: TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء التراجع'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('نعم، تأكيد الحذف'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await repo.deleteAttendanceRecord(record.id);
                setState(() {
                  _selectedRecordIds.remove(record.id);
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '🔔 تنبيه: تم حذف سجل حضور "$studentName" بنجاح',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ أثناء حذف السجل: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
