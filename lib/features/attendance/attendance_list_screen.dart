import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/permissions/role_manager.dart';
import '../../core/utils/date_helper.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/student.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/repositories/app_repository.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/sync_status_card.dart';
import 'audit_logs_screen.dart';
import '../face_attendance/face_attendance_screen.dart';
import '../dashboard/widgets/photo_verification_dialog.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  String _selectedTab = 'اليوم'; // 'اليوم', 'الكل', 'البصمة', 'QR'
  final Set<String> _selectedRecordIds = {};
  bool _isSyncing = false;
  bool _isTestingDb = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = repo.todayAttendance;

    // Filter according to selected tab (اليوم / الكل / البصمة / بصمة الوجه / QR)
    List<AttendanceRecord> displayedRecords = records;
    if (_selectedTab == 'البصمة') {
      displayedRecords = records.where((r) => r.method == 'fingerprint').toList();
    } else if (_selectedTab == 'بصمة الوجه') {
      displayedRecords = records.where((r) => r.method == 'face').toList();
    } else if (_selectedTab == 'QR') {
      displayedRecords = records.where((r) => r.method == 'qr' || r.method == 'barcode_qr').toList();
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
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'إعدادات الحضور والانصراف وقواعد البيانات',
            onPressed: () => _openAttendanceSettingsSheet(context),
          ),
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
          const SyncStatusCard(compact: true),
          // Attendance Session Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.primaryBlue.withAlpha(20),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, size: 20, color: AppColors.primaryBlue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'جلسة الحضور المباشرة • تسجيل الحضور والانصراف للطلاب',
                    style: TextStyle(
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
                    'نشطة',
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

          // Attendance & Database Settings Quick Panel (Primary: Supabase, Backup: Hive)
          _buildAttendanceSettingsBanner(context, repo, isDark),

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
                _buildTabChip('بصمة الوجه'),
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
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('سجل التعديلات والتحقق البيومتري'),
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
      floatingActionButton: repo.isFaceEnabled
          ? FloatingActionButton.extended(
              heroTag: 'face_attendance_btn',
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.face_rounded),
              label: const Text('تسجيل بالوجه', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FaceAttendanceScreen()),
                );
              },
            )
          : null,
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
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              Student? student;
                              for (final s in repo.students) {
                                if (s.id == r.studentId || (s.universityId.isNotEmpty && s.universityId == r.universityId)) {
                                  student = s;
                                  break;
                                }
                              }
                              final photo = (student?.photoUrl != null && student!.photoUrl!.isNotEmpty)
                                  ? student.photoUrl!
                                  : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(r.studentName ?? "Student")}&background=0D8ABC&color=fff&size=256';

                              PhotoVerificationDialog.show(
                                context,
                                photoUrl: photo,
                                studentName: r.studentName ?? 'طالب',
                                universityId: r.universityId ?? '-',
                                collegeName: student?.collegeName,
                                departmentName: student?.departmentName,
                                attendanceTime: inTime,
                                attendanceMethod: method,
                                actionType: r.status,
                                livenessScore: 0.98,
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Tooltip(
                              message: 'انقر لتكبير وفحص صحة وحيوية الصورة',
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: AppColors.primaryBlue.withAlpha(25),
                                    backgroundImage: NetworkImage(
                                      (repo.students.any((s) => (s.id == r.studentId || s.universityId == r.universityId) && s.photoUrl != null && s.photoUrl!.isNotEmpty))
                                          ? repo.students.firstWhere((s) => (s.id == r.studentId || s.universityId == r.universityId)).photoUrl!
                                          : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(r.studentName ?? "طالب")}&background=0D8ABC&color=fff&size=256',
                                    ),
                                  ),
                                  const Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Icon(Icons.check_circle, size: 10, color: AppColors.success),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(r.studentName ?? 'طالب', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      )),
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
                InkWell(
                  onTap: () {
                    Student? student;
                    for (final s in repo.students) {
                      if (s.id == record.studentId || (s.universityId.isNotEmpty && s.universityId == record.universityId)) {
                        student = s;
                        break;
                      }
                    }
                    final photo = (student?.photoUrl != null && student!.photoUrl!.isNotEmpty)
                        ? student.photoUrl!
                        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(record.studentName ?? "Student")}&background=0D8ABC&color=fff&size=256';

                    PhotoVerificationDialog.show(
                      context,
                      photoUrl: photo,
                      studentName: record.studentName ?? 'طالب',
                      universityId: record.universityId ?? '-',
                      collegeName: student?.collegeName,
                      departmentName: student?.departmentName,
                      attendanceTime: record.attendanceTime,
                      attendanceMethod: methodLabel,
                      actionType: record.status,
                      livenessScore: 0.98,
                    );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Tooltip(
                    message: 'انقر لتكبير وفحص صحة وحيوية الصورة',
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primaryBlue.withAlpha(25),
                          backgroundImage: NetworkImage(
                            (repo.students.any((s) => (s.id == record.studentId || s.universityId == record.universityId) && s.photoUrl != null && s.photoUrl!.isNotEmpty))
                                ? repo.students.firstWhere((s) => (s.id == record.studentId || s.universityId == record.universityId)).photoUrl!
                                : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(record.studentName ?? "طالب")}&background=0D8ABC&color=fff&size=256',
                          ),
                        ),
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: Icon(Icons.check_circle, size: 12, color: AppColors.success),
                        ),
                      ],
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

  // =========================================================================
  // --- ATTENDANCE & DATABASE SETTINGS UI (Primary: Supabase, Backup: Hive) ---
  // =========================================================================

  Widget _buildAttendanceSettingsBanner(BuildContext context, AppRepository repo, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 8),
              const Text(
                'إعدادات الحضور وقواعد البيانات',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              // Database Status Badges
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Supabase Primary DB Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: repo.isPrimaryConnected ? AppColors.success.withAlpha(20) : AppColors.warning.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: repo.isPrimaryConnected ? AppColors.success.withAlpha(60) : AppColors.warning.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          repo.isPrimaryConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          size: 13,
                          color: repo.isPrimaryConnected ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          repo.isPrimaryConnected ? 'Supabase: أساسية (متصل)' : 'Supabase: أوفلاين',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: repo.isPrimaryConnected ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Hive Backup DB Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save_rounded, size: 13, color: AppColors.primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          'Hive: احتياطية (${repo.backupAttendanceCount} سجل)',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              // Method status pills
              InkWell(
                onTap: () => _openAttendanceSettingsSheet(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: repo.isFingerprintEnabled ? AppColors.turquoise.withAlpha(20) : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 14, color: repo.isFingerprintEnabled ? AppColors.turquoise : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        repo.isFingerprintEnabled ? 'البصمة: مفعّلة' : 'البصمة: معطلة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: repo.isFingerprintEnabled ? AppColors.turquoise : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openAttendanceSettingsSheet(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: repo.isBarcodeEnabled ? Colors.purple.withAlpha(20) : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 14, color: repo.isBarcodeEnabled ? Colors.purple : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        repo.isBarcodeEnabled ? 'الباركود: مفعّل' : 'الباركود: معطّل',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: repo.isBarcodeEnabled ? Colors.purple : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openAttendanceSettingsSheet(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: repo.isFaceEnabled ? AppColors.primaryBlue.withAlpha(20) : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.face_rounded, size: 14, color: repo.isFaceEnabled ? AppColors.primaryBlue : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        repo.isFaceEnabled ? 'الوجه: مفعّل' : 'الوجه: معطّل',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: repo.isFaceEnabled ? AppColors.primaryBlue : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Sync Action Button
              OutlinedButton.icon(
                icon: _isSyncing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync_rounded, size: 14),
                label: Text(
                  _isSyncing ? 'مزامنة...' : 'مزامنة السجلات',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _isSyncing ? null : () => _syncDatabases(context, repo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _syncDatabases(BuildContext context, AppRepository repo) async {
    setState(() => _isSyncing = true);
    try {
      final count = await repo.syncDatabases();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت مزامنة البيانات بين Supabase الأساسية و Hive الاحتياطية بنجاح ($count عملية مزامنة).'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ملاحظة أثناء المزامنة: $e'), backgroundColor: AppColors.warning),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _openAttendanceSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<AppRepository>(
        builder: (ctx, repo, _) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle & Header
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(80),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.settings_suggest_rounded, color: AppColors.primaryBlue, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إعدادات قسم الحضور والانصراف',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              'إدارة وسائل التسجيل والربط بين Supabase الأساسية و Hive الاحتياطية',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Attendance Methods
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, color: AppColors.primaryBlue, size: 20),
                            SizedBox(width: 8),
                            Text('طرق تسجيل الحضور والانصراف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: repo.isFingerprintEnabled ? AppColors.turquoise.withAlpha(15) : Colors.grey.withAlpha(10),
                          secondary: Icon(Icons.fingerprint_rounded, color: repo.isFingerprintEnabled ? AppColors.turquoise : Colors.grey),
                          title: const Text('تسجيل الحضور بالبصمة الحيوية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            repo.isFingerprintEnabled ? 'مفعلة وتظهر في شاشة تسجيل الحضور' : 'معطلة ومخفية من شاشة تسجيل الحضور',
                            style: const TextStyle(fontSize: 11),
                          ),
                          value: repo.isFingerprintEnabled,
                          // ignore: deprecated_member_use
                          activeColor: AppColors.turquoise,
                          onChanged: (val) async {
                            try {
                              await repo.toggleFingerprintMethod(val);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: repo.isBarcodeEnabled ? Colors.purple.withAlpha(15) : Colors.grey.withAlpha(10),
                          secondary: Icon(Icons.qr_code_scanner_rounded, color: repo.isBarcodeEnabled ? Colors.purple : Colors.grey),
                          title: const Text('تسجيل الحضور بالباركود و QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            repo.isBarcodeEnabled ? 'مفعلة وتظهر في شاشة تسجيل الحضور والكاميرا' : 'معطلة ومخفية من شاشة تسجيل الحضور',
                            style: const TextStyle(fontSize: 11),
                          ),
                          value: repo.isBarcodeEnabled,
                          // ignore: deprecated_member_use
                          activeColor: Colors.purple,
                          onChanged: (val) async {
                            try {
                              await repo.toggleBarcodeMethod(val);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: repo.isFaceEnabled ? AppColors.primaryBlue.withAlpha(15) : Colors.grey.withAlpha(10),
                          secondary: Icon(Icons.face_rounded, color: repo.isFaceEnabled ? AppColors.primaryBlue : Colors.grey),
                          title: const Text('تسجيل الحضور ببصمة الوجه (الكاميرا)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            repo.isFaceEnabled ? 'مفعلة وتظهر في شاشة تسجيل الحضور والكاميرا' : 'معطلة ومخفية من شاشة تسجيل الحضور',
                            style: const TextStyle(fontSize: 11),
                          ),
                          value: repo.isFaceEnabled,
                          // ignore: deprecated_member_use
                          activeColor: AppColors.primaryBlue,
                          onChanged: (val) async {
                            try {
                              await repo.toggleFaceMethod(val);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 2: Databases Architecture (Primary Supabase, Backup Hive)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.storage_rounded, color: AppColors.primaryBlue, size: 20),
                            SizedBox(width: 8),
                            Text('ربط وتكامل قواعد البيانات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        const SyncStatusCard(compact: false, margin: EdgeInsets.only(bottom: 12)),

                        // Card: Primary Database - Supabase
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.cloud_done_rounded, color: AppColors.primaryBlue, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'قاعدة البيانات الأساسية (Primary): Supabase Cloud',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: repo.isPrimaryConnected ? AppColors.success.withAlpha(25) : AppColors.warning.withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      repo.isPrimaryConnected ? 'متصلة ونشطة' : 'أوفلاين',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: repo.isPrimaryConnected ? AppColors.success : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'معرّف المشروع: ${ApiConstants.defaultSupabaseUrl}',
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: _isTestingDb
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.network_check_rounded, size: 16),
                                  label: Text(_isTestingDb ? 'جاري فحص الاتصال...' : 'فحص اتصال قاعدة بيانات Supabase الأساسية'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _isTestingDb
                                      ? null
                                      : () async {
                                          setState(() => _isTestingDb = true);
                                          final res = await SupabaseService.instance.testConnection();
                                          setState(() => _isTestingDb = false);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('${res.statusTitle}: ${res.message}'),
                                                backgroundColor: res.isConnected ? AppColors.success : AppColors.danger,
                                              ),
                                            );
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Card: Backup Database - Hive
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.success.withAlpha(40)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.save_rounded, color: AppColors.success, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'قاعدة البيانات الاحتياطية (Backup): Hive Local DB',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    'نشطة محلياً',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'تخزين محلي فوري فائق السرعة يعمل بدون إنترنت كنسخة احتياطية لضمان استمرار الحضور دون توقف.\n'
                                '• سجلات الحضور الاحتياطية: ${repo.backupAttendanceCount} سجل\n'
                                '• الطلاب المحفوظون محلياً: ${repo.backupStudentsCount} طالب',
                                style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Trigger Manual Two-Way Sync Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.sync_alt_rounded, size: 18),
                            label: const Text('مزامنة السجلات بين Supabase و Hive الآن'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _syncDatabases(context, repo);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
