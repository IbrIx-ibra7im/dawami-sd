import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/permissions/role_manager.dart';
import '../../core/utils/csv_report_helper.dart';
import '../../core/utils/file_saver/file_saver.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';
import '../../widgets/custom_widgets.dart';
import 'add_edit_student_dialog.dart';
import 'student_card_dialog.dart';
import 'import_students_dialog.dart';
import '../fingerprint/fingerprint_enrollment_dialog.dart';
import '../face_attendance/widgets/student_face_enrollment_dialog.dart';
import '../dashboard/widgets/photo_verification_dialog.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'الكل';
  int? _selectedCollegeId;
  final Set<int> _selectedStudentIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    context.read<AppRepository>().refreshStudents(
      query: val,
      collegeId: _selectedCollegeId,
      status: _selectedStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = repo.students;
    final canManage = RoleManager.canManageStudents(repo.currentRole);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Column(
          children: [
            const Text('إدارة الطلاب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              '${students.length} طالباً${_selectedStudentIds.isNotEmpty ? " • ${_selectedStudentIds.length} محدد" : ""}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.darkBlue,
        actions: [
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.upload_file_rounded),
              tooltip: 'استيراد من إكسل',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const ImportStudentsDialog(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'إضافة طالب جديد',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const AddEditStudentDialog(),
                );
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الرقم الجامعي...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips & Excel Import Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('الكل'),
                            const SizedBox(width: 8),
                            _buildFilterChip('نشط'),
                            const SizedBox(width: 8),
                            _buildFilterChip('متوقف'),
                            const SizedBox(width: 8),
                            _buildFilterChip('متخرج'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('رفع ملف إكسل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const ImportStudentsDialog(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Multi-Select Action Banner
          if (_selectedStudentIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.danger.withAlpha(25),
              child: Row(
                children: [
                  const Icon(Icons.check_box_rounded, color: AppColors.danger, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'تم تحديد ${_selectedStudentIds.length} من الطلاب',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.select_all_rounded, size: 16),
                    label: const Text('تحديد الكل', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _selectedStudentIds.addAll(
                          students.where((s) => s.id != null).map((s) => s.id!),
                        );
                      });
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.deselect_rounded, size: 16),
                    label: const Text('إلغاء التحديد', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _selectedStudentIds.clear();
                      });
                    },
                  ),
                  if (_selectedStudentIds.length == 1) ...[
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text(
                        'تعديل الطالب المحدد',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final selectedId = _selectedStudentIds.first;
                        final student = students.firstWhere((s) => s.id == selectedId);
                        showDialog(
                          context: context,
                          builder: (_) => AddEditStudentDialog(student: student),
                        );
                      },
                    ),
                  ],
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever_rounded, size: 16),
                    label: Text(
                      'حذف المحدد (${_selectedStudentIds.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmDeleteSelectedStudents(context, repo),
                  ),
                ],
              ),
            ),

          // Students List or Desktop DataTable
          Expanded(
            child: students.isEmpty
                ? const Center(
                    child: Text('لا يوجد طلاب مطابقين للبحث', style: TextStyle(color: Colors.grey)),
                  )
                : (MediaQuery.of(context).size.width >= 800)
                    ? _buildDesktopDataTable(context, students, repo, isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: students.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final student = students[index];
                          return _buildStudentTile(context, student, repo, isDark);
                        },
                      ),
          ),

          // Import & Export CSV/Excel Bar
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
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('استيراد Excel/CSV'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ImportStudentsDialog(),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('تصدير إلى الجهاز (Excel/CSV)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _exportStudents(context, students),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              tooltip: 'إضافة طالب جديد',
              child: const Icon(Icons.add),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const AddEditStudentDialog(),
                );
              },
            )
          : null,
    );
  }

  Future<void> _exportStudents(BuildContext context, List<Student> students) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب للتصدير حالياً'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final format = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تصدير بيانات الطلاب وحفظها في جهازك',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر الصيغة المناسبة لحفظ الملف في مجلد التنزيلات بالجهاز:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.table_view_rounded, color: Colors.white),
                label: const Text('حفظ كملف إكسل رسمي (.xlsx) في الجهاز', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, 'xlsx'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined, color: AppColors.primaryBlue),
                label: const Text('حفظ كملف CSV مع ترميز UTF-8 في الجهاز', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, 'csv'),
              ),
            ],
          ),
        ),
      ),
    );

    if (format == null) return;

    try {
      final nowStr = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      String fileName;
      List<int> bytes;
      String mimeType;

      if (format == 'xlsx') {
        fileName = 'Dawami_Students_$nowStr.xlsx';
        bytes = CsvReportHelper.exportStudentsToExcel(students);
        mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      } else {
        fileName = 'Dawami_Students_$nowStr.csv';
        bytes = CsvReportHelper.exportStudentsToCsvBytes(students);
        mimeType = 'text/csv; charset=utf-8';
      }

      final savedPath = await FileSaver.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم تصدير وحفظ الملف بنجاح على جهازك:\n$savedPath',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
          SnackBar(content: Text('فشل تصدير الملف: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedStatus == label;
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
        if (selected) {
          setState(() {
            _selectedStatus = label;
          });
          _onSearchChanged(_searchController.text);
        }
      },
    );
  }

  Widget _buildDesktopDataTable(BuildContext context, List<Student> students, AppRepository repo, bool isDark) {
    final allSelected = students.isNotEmpty &&
        students.every((s) => s.id != null && _selectedStudentIds.contains(s.id));

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
                  DataColumn(
                    label: Checkbox(
                      value: allSelected,
                      tristate: !allSelected && _selectedStudentIds.isNotEmpty,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedStudentIds.addAll(
                              students.where((s) => s.id != null).map((s) => s.id!),
                            );
                          } else {
                            _selectedStudentIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('اسم الطالب', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('الرقم الجامعي', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('الكلية', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('الهاتف', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('نوع الحضور', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('حالة البصمة', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('بطاقة QR', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('الإجراءات والعمليات', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List.generate(students.length, (index) {
                  final s = students[index];
                  final isSelected = s.id != null && _selectedStudentIds.contains(s.id);

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (val) {
                      if (s.id == null) return;
                      setState(() {
                        if (val == true) {
                          _selectedStudentIds.add(s.id!);
                        } else {
                          _selectedStudentIds.remove(s.id!);
                        }
                      });
                    },
                    cells: [
                      DataCell(
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            if (s.id == null) return;
                            setState(() {
                              if (val == true) {
                                _selectedStudentIds.add(s.id!);
                              } else {
                                _selectedStudentIds.remove(s.id!);
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
                              final photo = (s.photoUrl != null && s.photoUrl!.isNotEmpty)
                                  ? s.photoUrl!
                                  : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(s.fullName)}&background=0D8ABC&color=fff&size=256';

                              PhotoVerificationDialog.show(
                                context,
                                photoUrl: photo,
                                studentName: s.fullName,
                                universityId: s.universityId,
                                collegeName: s.collegeName,
                                departmentName: s.departmentName,
                                attendanceMethod: s.attendanceMethodDisplay,
                                actionType: s.status,
                                livenessScore: 0.98,
                                isEnrolledFace: s.faceRegistered,
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Tooltip(
                              message: 'انقر لتكبير وفحص صحة وحيوية الصورة',
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primaryBlue.withAlpha(25),
                                    backgroundImage: NetworkImage(
                                      (s.photoUrl != null && s.photoUrl!.isNotEmpty)
                                          ? s.photoUrl!
                                          : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(s.fullName)}&background=0D8ABC&color=fff&size=256',
                                    ),
                                  ),
                                  if (s.faceRegistered)
                                    const Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Icon(Icons.verified, size: 10, color: AppColors.success),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      )),
                      DataCell(Text(s.universityId)),
                      DataCell(Text(s.collegeName ?? '-')),
                      DataCell(Text(s.phone)),
                      DataCell(StatusBadge.fromStatus(s.status)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.attendanceMethodDisplay,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
                      )),
                      DataCell(StatusBadge.fromFingerprintStatus(s.hasFingerprint)),
                      DataCell(IconButton(
                        icon: const Icon(Icons.qr_code, color: AppColors.primaryBlue),
                        tooltip: 'عرض بطاقة الطالب',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => StudentCardDialog(student: s),
                          );
                        },
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. زر التعديل (Edit Button)
                          Tooltip(
                            message: 'تعديل بيانات الطالب',
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit_rounded, size: 14),
                              label: const Text('تعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AddEditStudentDialog(student: s),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 2. زر الحذف (Delete Button)
                          Tooltip(
                            message: 'حذف الطالب نهائياً',
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.delete_outline_rounded, size: 14),
                              label: const Text('حذف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () => _confirmDeleteStudent(context, s, repo),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 3. زر البصمة (Fingerprint Enrollment Button)
                          OutlinedButton.icon(
                            icon: Icon(Icons.fingerprint_rounded, size: 14, color: s.hasFingerprint ? AppColors.turquoise : Colors.grey),
                            label: Text(
                              s.hasFingerprint ? 'مسجلة' : 'بصمة إصبع',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: s.hasFingerprint ? AppColors.turquoise : Colors.grey.shade700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                              side: BorderSide(color: s.hasFingerprint ? AppColors.turquoise.withAlpha(80) : Colors.grey.withAlpha(50)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => FingerprintEnrollmentDialog(
                                  student: s,
                                  isReEnrollment: s.hasFingerprint,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          // 4. زر بصمة الوجه (Face Profile Enrollment Button)
                          OutlinedButton.icon(
                            icon: Icon(Icons.camera_front_rounded, size: 14, color: s.faceRegistered ? Colors.teal : Colors.grey),
                            label: Text(
                              s.faceRegistered ? 'وجه مسجل' : 'بصمة وجه',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: s.faceRegistered ? Colors.teal : Colors.grey.shade700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                              side: BorderSide(color: s.faceRegistered ? Colors.teal.withAlpha(80) : Colors.grey.withAlpha(50)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => StudentFaceEnrollmentDialog(
                                  student: s,
                                  isReEnrollment: s.faceRegistered,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          // 5. زر البطاقة (Student Card Dialog)
                          IconButton(
                            icon: const Icon(Icons.badge_rounded, color: Colors.blueGrey),
                            tooltip: 'عرض وطباعة بطاقة الطالب',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => StudentCardDialog(student: s),
                              );
                            },
                          ),
                        ],
                      )),
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

  Widget _buildStudentTile(BuildContext context, Student student, AppRepository repo, bool isDark) {
    final isSelected = student.id != null && _selectedStudentIds.contains(student.id);

    return Container(
      padding: const EdgeInsets.all(16),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 10 : 5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Info Row with Selection Checkbox
          Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (val) {
                  if (student.id == null) return;
                  setState(() {
                    if (val == true) {
                      _selectedStudentIds.add(student.id!);
                    } else {
                      _selectedStudentIds.remove(student.id!);
                    }
                  });
                },
              ),
              InkWell(
                onTap: () {
                  final photo = (student.photoUrl != null && student.photoUrl!.isNotEmpty)
                      ? student.photoUrl!
                      : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(student.fullName)}&background=0D8ABC&color=fff&size=256';

                  PhotoVerificationDialog.show(
                    context,
                    photoUrl: photo,
                    studentName: student.fullName,
                    universityId: student.universityId,
                    collegeName: student.collegeName,
                    departmentName: student.departmentName,
                    attendanceMethod: student.attendanceMethodDisplay,
                    actionType: student.status,
                    livenessScore: 0.98,
                    isEnrolledFace: student.faceRegistered,
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Tooltip(
                  message: 'انقر لتكبير وفحص صحة وحيوية الصورة',
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryBlue.withAlpha(25),
                        backgroundImage: NetworkImage(
                          (student.photoUrl != null && student.photoUrl!.isNotEmpty)
                              ? student.photoUrl!
                              : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(student.fullName)}&background=0D8ABC&color=fff&size=256',
                        ),
                      ),
                      if (student.faceRegistered)
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: Icon(Icons.verified, size: 12, color: AppColors.success),
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
                      student.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الرقم: ${student.universityId} • ${student.collegeName ?? 'كلية'} • ${student.attendanceMethodDisplay}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge.fromStatus(student.status),
                  const SizedBox(height: 4),
                  StatusBadge.fromFingerprintStatus(student.hasFingerprint),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Prominent Action Buttons Bar (Edit, Delete with Alert, QR Card)
          Row(
            children: [
              // 1. زر التعديل (Edit Button)
              Expanded(
                flex: 3,
                child: Tooltip(
                  message: 'تعديل بيانات الطالب',
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 15),
                    label: const Text(
                      'تعديل',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AddEditStudentDialog(student: student),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 2. زر الحذف (Delete Button with Alert)
              Expanded(
                flex: 3,
                child: Tooltip(
                  message: 'حذف الطالب نهائياً',
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 15),
                    label: const Text(
                      'حذف',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _confirmDeleteStudent(context, student, repo),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3. زر البصمة (Fingerprint Enrollment Button)
              Tooltip(
                message: student.hasFingerprint ? 'بصمة الإصبع مسجلة' : 'تسجيل بصمة الإصبع',
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                    side: BorderSide(color: student.hasFingerprint ? AppColors.turquoise.withAlpha(80) : Colors.grey.withAlpha(60)),
                    backgroundColor: student.hasFingerprint ? AppColors.turquoise.withAlpha(12) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => FingerprintEnrollmentDialog(
                        student: student,
                        isReEnrollment: student.hasFingerprint,
                      ),
                    );
                  },
                  child: Icon(Icons.fingerprint_rounded, size: 18, color: student.hasFingerprint ? AppColors.turquoise : Colors.grey),
                ),
              ),
              const SizedBox(width: 6),

              // 4. زر بصمة الوجه (Face Profile Enrollment Button)
              Tooltip(
                message: student.faceRegistered ? 'بصمة الوجه مسجلة' : 'تسجيل بصمة الوجه بالكاميرا',
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                    side: BorderSide(color: student.faceRegistered ? Colors.teal.withAlpha(80) : Colors.grey.withAlpha(60)),
                    backgroundColor: student.faceRegistered ? Colors.teal.withAlpha(12) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => StudentFaceEnrollmentDialog(
                        student: student,
                        isReEnrollment: student.faceRegistered,
                      ),
                    );
                  },
                  child: Icon(Icons.camera_front_rounded, size: 18, color: student.faceRegistered ? Colors.teal : Colors.grey),
                ),
              ),
              const SizedBox(width: 6),

              // 5. زر البطاقة (Student Card Button)
              Tooltip(
                message: 'عرض بطاقة الطالب',
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                    side: BorderSide(color: Colors.blueGrey.withAlpha(80)),
                    backgroundColor: Colors.blueGrey.withAlpha(15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => StudentCardDialog(student: student),
                    );
                  },
                  child: const Icon(Icons.badge_rounded, size: 18, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelectedStudents(BuildContext context, AppRepository repo) {
    final count = _selectedStudentIds.length;
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
              'تأكيد حذف الطلاب المحددين',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.danger),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من رغبتك في حذف $count من الطلاب المحددين نهائياً؟',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ تنبيه: سيتم حذف كافة السجلات والبيانات والبصمات المرتبطة بهؤلاء الطلاب نهائياً من قاعدة البيانات ولا يمكن التراجع عن هذا الإجراء.',
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
            label: Text('نعم، تأكيد حذف $count طلاب'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final idsToDelete = _selectedStudentIds.toList();
                await repo.deleteMultipleStudents(idsToDelete);
                setState(() {
                  _selectedStudentIds.clear();
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
                              '🔔 تنبيه: تم حذف $count من الطلاب المحددين بنجاح من قاعدة البيانات',
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
                      content: Text('خطأ أثناء حذف الطلاب: $e'),
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

  void _confirmDeleteStudent(BuildContext context, Student student, AppRepository repo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
              SizedBox(width: 10),
              Text(
                'تنبيه: تأكيد حذف الطالب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.danger),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هل أنت متأكد من رغبتك في حذف هذا الطالب نهائياً؟',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ تنبيه: سيتم حذف بيانات الطالب وسجلاته وبصمته محلياً وسحابياً من النظام ولا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(fontSize: 12, color: AppColors.danger, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Text('اسم الطالب: ${student.fullName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('الرقم الجامعي: ${student.universityId}', style: const TextStyle(fontSize: 13)),
                  if (student.collegeName != null) ...[
                    const SizedBox(height: 4),
                    Text('الكلية: ${student.collegeName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ],
              ),
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
            label: const Text('نعم، تأكيد الحذف نهائياً'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await repo.deleteStudent(student.id!);
                if (student.id != null) {
                  setState(() {
                    _selectedStudentIds.remove(student.id!);
                  });
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '🔔 تنبيه: تم حذف الطالب "${student.fullName}" نهائياً من قاعدة البيانات',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ أثناء الحذف: $e'),
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
