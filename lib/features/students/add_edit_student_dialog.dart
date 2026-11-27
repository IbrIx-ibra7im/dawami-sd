import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/face_recognition_service.dart';
import '../../data/local/hive_helper.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/face_profile.dart';
import '../../data/models/student.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/repositories/app_repository.dart';
import '../fingerprint/fingerprint_enrollment_dialog.dart';
import '../face_attendance/widgets/student_face_enrollment_dialog.dart';

class AddEditStudentDialog extends StatefulWidget {
  final Student? student;

  const AddEditStudentDialog({super.key, this.student});

  @override
  State<AddEditStudentDialog> createState() => _AddEditStudentDialogState();
}

class _AddEditStudentDialogState extends State<AddEditStudentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _idController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _fpIdController;
  late TextEditingController _photoController;

  int _selectedCollegeId = 1;
  int _selectedDepartmentId = 1;
  int _selectedLevelId = 1;
  int _selectedSemesterId = 1;
  String _status = 'نشط';
  String _selectedAttendanceMethod = 'all';
  bool _isSaving = false;
  FaceProfile? _enrolledFaceProfile;
  bool _faceEnrolledLocally = false;
  String? _enrolledFaceEmbedding;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s?.fullName ?? '');
    _idController = TextEditingController(text: s?.universityId ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '09');
    _emailController = TextEditingController(text: s?.email ?? '');
    _fpIdController = TextEditingController(text: s?.fingerprintId ?? '');
    _photoController = TextEditingController(text: s?.photoUrl ?? '');

    if (s != null) {
      _selectedCollegeId = s.collegeId;
      _selectedDepartmentId = s.departmentId;
      _selectedLevelId = s.levelId;
      _selectedSemesterId = s.semesterId;
      _status = s.status;
      _selectedAttendanceMethod = s.attendanceMethod;
      _faceEnrolledLocally = s.faceRegistered;
      _enrolledFaceEmbedding = s.faceEmbedding;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _fpIdController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = context.read<AppRepository>();
      final uniId = _idController.text.trim();
      final cleanUniId = uniId.toLowerCase();

      // 1. التحقق من فرادة الرقم الجامعي (Unique student number validation)
      final isDuplicateUniId = repo.students.any((s) =>
          s.id != widget.student?.id &&
          (s.universityId.toLowerCase() == cleanUniId || s.studentNumber.toLowerCase() == cleanUniId));

      if (isDuplicateUniId) {
        throw Exception('الرقم الجامعي "$uniId" مسجل مسبقاً لطالب آخر. يجب أن يكون الرقم الجامعي فريداً.');
      }

      // 2. التحقق من تسجيل البصمة وفرادتها
      final fpId = _fpIdController.text.trim();
      final keepsStudentIdentity =
          widget.student != null &&
          widget.student!.universityId == uniId;
      if (fpId.isNotEmpty && keepsStudentIdentity) {
        final isDuplicateFp = await repo.isFingerprintDuplicate(
          fpId,
          excludeStudentId: widget.student?.id,
        );
        if (isDuplicateFp) {
          throw Exception(
            'معرف البصمة "$fpId" مسجل مسبقاً لطالب آخر. لا يمكن تكرار البصمة.',
          );
        }
      }

      String collegeName = 'كلية علوم الحاسوب والتنمية البشرية';
      for (final c in repo.colleges) {
        if (c.id == _selectedCollegeId) {
          collegeName = c.name;
          break;
        }
      }

      String deptName = 'علوم الحاسوب';
      for (final d in repo.departments) {
        if (d.id == _selectedDepartmentId) {
          deptName = d.name;
          break;
        }
      }

      String levelName = 'المستوى الأول';
      for (final l in repo.levels) {
        if (l.id == _selectedLevelId) {
          levelName = l.name;
          break;
        }
      }

      final student = Student(
        id: widget.student?.id,
        uuid: widget.student?.uuid,
        universityId: uniId,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : '0000000000',
        email: _emailController.text.trim(),
        collegeId: _selectedCollegeId,
        departmentId: _selectedDepartmentId,
        levelId: _selectedLevelId,
        semesterId: _selectedSemesterId,
        status: _status,
        qrCode: 'DAWAMI:STUDENT:$uniId',
        fingerprintId: keepsStudentIdentity && fpId.isNotEmpty ? fpId : null,
        fingerprintStatus: keepsStudentIdentity && fpId.isNotEmpty
            ? 'مسجلة'
            : 'غير مسجلة',
        fingerprintQuality:
            keepsStudentIdentity && fpId.isNotEmpty
                ? widget.student?.fingerprintQuality
                : null,
        fingerprintEnrolledAt:
            keepsStudentIdentity && fpId.isNotEmpty
                ? widget.student?.fingerprintEnrolledAt
                : null,
        photoUrl: _photoController.text.trim().isNotEmpty ? _photoController.text.trim() : null,
        faceRegistered: _faceEnrolledLocally || (_enrolledFaceProfile != null) || (widget.student?.faceRegistered ?? false),
        faceEnrolledAt: _enrolledFaceProfile?.enrolledAt ?? widget.student?.faceEnrolledAt ?? (_faceEnrolledLocally ? DateTime.now().toIso8601String() : null),
        faceEmbedding: _enrolledFaceEmbedding ?? _enrolledFaceProfile?.faceEmbeddingHash ?? widget.student?.faceEmbedding,
        attendanceMethod: _selectedAttendanceMethod,
        collegeName: collegeName,
        departmentName: deptName,
        levelName: levelName,
      );

      var isSyncedToSupabase = false;
      if (widget.student == null) {
        isSyncedToSupabase = await repo.addStudent(student);
      } else {
        isSyncedToSupabase = await repo.updateStudent(student);
      }

      // إذا تم تسجيل أو تحديث بصمة الوجه، نضمن حفظ الملف ومزامنته في Hive وSupabase
      if (_enrolledFaceProfile != null) {
        try {
          final profileToSave = _enrolledFaceProfile!.copyWith(
            studentId: uniId,
            universityId: uniId,
            referencePhotoUrl: student.photoUrl ?? _enrolledFaceProfile!.referencePhotoUrl,
          );
          await HiveHelper.instance.saveFaceProfile(profileToSave);
          if (SupabaseService.instance.isConfigured && SupabaseService.instance.client != null) {
            try {
              await SupabaseService.instance.client!
                  .from('dawami_records')
                  .upsert(profileToSave.toDawamiRecord(), onConflict: 'record_type,record_key');
            } catch (_) {}
          }
          FaceRecognitionService.instance.notifyProfileUpdate();
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: !isSyncedToSupabase
                ? AppColors.warning
                : AppColors.success,
            content: Row(
              children: [
                Icon(
                  !isSyncedToSupabase
                      ? Icons.cloud_off_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.student == null
                        ? isSyncedToSupabase
                            ? 'تمت إضافة الطالب "${student.fullName}" ومزامنته مع Supabase.'
                            : 'تم حفظ الطالب "${student.fullName}" محلياً؛ لم تتأكد مزامنته مع Supabase بعد.'
                        : isSyncedToSupabase
                            ? 'تم تعديل بيانات الطالب "${student.fullName}" ومزامنتها مع Supabase.'
                            : 'تم حفظ تعديلات "${student.fullName}" محلياً؛ لم تتأكد مزامنتها مع Supabase بعد.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.student != null;

    final colleges = repo.colleges.isNotEmpty
        ? repo.colleges
        : [
            College(id: 1, name: 'كلية علوم الحاسوب والتنمية البشرية', createdAt: DateTime.now().toIso8601String()),
          ];
    final validCollegeIds = colleges.map((c) => c.id).whereType<int>().toSet();
    final effectiveCollegeId = validCollegeIds.contains(_selectedCollegeId)
        ? _selectedCollegeId
        : (validCollegeIds.isNotEmpty ? validCollegeIds.first : 1);

    final departments = repo.departments.where((d) => d.collegeId == effectiveCollegeId).isNotEmpty
        ? repo.departments.where((d) => d.collegeId == effectiveCollegeId).toList()
        : (repo.departments.isNotEmpty
            ? repo.departments
            : [Department(id: 1, collegeId: 1, name: 'علوم الحاسوب')]);
    final validDeptIds = departments.map((d) => d.id).toSet();
    final effectiveDeptId = validDeptIds.contains(_selectedDepartmentId)
        ? _selectedDepartmentId
        : (validDeptIds.isNotEmpty ? validDeptIds.first : 1);

    final levels = repo.levels.isNotEmpty
        ? repo.levels
        : [
            AcademicLevel(id: 1, name: 'المستوى الأول', orderNo: 1),
            AcademicLevel(id: 2, name: 'المستوى الثاني', orderNo: 2),
            AcademicLevel(id: 3, name: 'المستوى الثالث', orderNo: 3),
            AcademicLevel(id: 4, name: 'المستوى الرابع', orderNo: 4),
          ];
    final validLevelIds = levels.map((l) => l.id).toSet();
    final effectiveLevelId = validLevelIds.contains(_selectedLevelId)
        ? _selectedLevelId
        : (validLevelIds.isNotEmpty ? validLevelIds.first : 1);

    const validStatuses = ['نشط', 'متوقف', 'متخرج'];
    final effectiveStatus = validStatuses.contains(_status) ? _status : 'نشط';

    return AlertDialog(
      title: Text(isEdit ? 'تعديل بيانات الطالب' : 'إضافة طالب جديد'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الرباعي *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الطالب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'الرقم الجامعي * (مثال: 2023-1590)',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال الرقم الجامعي' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: effectiveCollegeId,
                        decoration: const InputDecoration(labelText: 'الكلية'),
                        items: colleges.map((c) {
                          return DropdownMenuItem<int>(value: c.id, child: Text(c.name));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCollegeId = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: effectiveStatus,
                        decoration: const InputDecoration(labelText: 'الحالة'),
                        items: const [
                          DropdownMenuItem(value: 'نشط', child: Text('نشط')),
                          DropdownMenuItem(value: 'متوقف', child: Text('متوقف')),
                          DropdownMenuItem(value: 'متخرج', child: Text('متخرج')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: effectiveDeptId,
                        decoration: const InputDecoration(labelText: 'القسم الأكاديمي'),
                        items: departments.map((d) {
                          return DropdownMenuItem<int>(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDepartmentId = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: effectiveLevelId,
                        decoration: const InputDecoration(labelText: 'المستوى الدراسي'),
                        items: levels.map((l) {
                          return DropdownMenuItem<int>(value: l.id, child: Text(l.name));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLevelId = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Attendance Method Selector (نوع الحضور المعتمد: بصمة، باركود، وجه، الكل)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: AppColors.primaryBlue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'وسيلة تسجيل الحضور المعتمدة للطالب *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'حدد طريقة الحضور المصرح بها لهذا الطالب (بصمة، باركود، بصمة وجه، أو الكل):',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.all_inclusive_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('كافة الوسائل'),
                                ],
                              ),
                              selected: _selectedAttendanceMethod == 'all',
                              selectedColor: AppColors.primaryBlue,
                              labelStyle: TextStyle(
                                color: _selectedAttendanceMethod == 'all' ? Colors.white : null,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _selectedAttendanceMethod = 'all'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fingerprint_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('بصمة إصبع'),
                                ],
                              ),
                              selected: _selectedAttendanceMethod == 'fingerprint',
                              selectedColor: AppColors.turquoise,
                              labelStyle: TextStyle(
                                color: _selectedAttendanceMethod == 'fingerprint' ? Colors.white : null,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _selectedAttendanceMethod = 'fingerprint'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.qr_code_scanner_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('باركود / QR'),
                                ],
                              ),
                              selected: _selectedAttendanceMethod == 'barcode',
                              selectedColor: Colors.purple,
                              labelStyle: TextStyle(
                                color: _selectedAttendanceMethod == 'barcode' ? Colors.white : null,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _selectedAttendanceMethod = 'barcode'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.face_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('بصمة وجه'),
                                ],
                              ),
                              selected: _selectedAttendanceMethod == 'face',
                              selectedColor: Colors.teal,
                              labelStyle: TextStyle(
                                color: _selectedAttendanceMethod == 'face' ? Colors.white : null,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _selectedAttendanceMethod = 'face'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Biometric Fingerprint Registration Section (Show if fingerprint or all)
                if (_selectedAttendanceMethod == 'fingerprint' || _selectedAttendanceMethod == 'all')
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _fpIdController.text.isNotEmpty
                        ? AppColors.turquoise.withAlpha(15)
                        : (isDark ? AppColors.surfaceDark : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _fpIdController.text.isNotEmpty
                          ? AppColors.turquoise
                          : (isDark ? AppColors.borderDark : AppColors.borderLight),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _fpIdController.text.isNotEmpty
                              ? AppColors.turquoise.withAlpha(25)
                              : Colors.grey.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: _fpIdController.text.isNotEmpty ? AppColors.turquoise : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'بصمة الطالب الحيوية (مطلوبة)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fpIdController.text.isNotEmpty
                                  ? 'معرف البصمة المرتبط: ${_fpIdController.text}'
                                  : 'ضع إصبع الطالب على المستشعر لتسجيل البصمة',
                              style: TextStyle(
                                fontSize: 11,
                                color: _fpIdController.text.isNotEmpty ? AppColors.turquoise : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.touch_app_rounded, size: 16),
                        label: Text(_fpIdController.text.isNotEmpty ? 'إعادة التسجيل' : 'تسجيل البصمة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.turquoise,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final currentStudent = widget.student;
                          if (currentStudent == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'احفظ بيانات الطالب أولاً، ثم فعّل البصمة من سجل الطلاب.',
                                ),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }

                          final name = _nameController.text.trim();
                          final uniId = _idController.text.trim();
                          if (name.isEmpty || uniId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى إدخال اسم الطالب والرقم الجامعي أولاً قبل تسجيل البصمة'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }

                          final hasUnsavedChanges =
                              name != currentStudent.fullName ||
                              uniId != currentStudent.universityId ||
                              _phoneController.text.trim() != currentStudent.phone ||
                              _emailController.text.trim() != currentStudent.email ||
                              _selectedCollegeId != currentStudent.collegeId ||
                              _selectedDepartmentId != currentStudent.departmentId ||
                              _selectedLevelId != currentStudent.levelId ||
                              _selectedSemesterId != currentStudent.semesterId ||
                              _status != currentStudent.status ||
                              _photoController.text.trim() !=
                                  (currentStudent.photoUrl ?? '');
                          if (hasUnsavedChanges) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'احفظ تعديلات الطالب أولاً قبل إعادة تسجيل بصمته.',
                                ),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }

                          final enrolledFp = await showDialog<String>(
                            context: context,
                            builder: (_) => FingerprintEnrollmentDialog(
                              student: currentStudent,
                              isReEnrollment: widget.student?.hasFingerprint ?? false,
                            ),
                          );

                          if (enrolledFp != null && enrolledFp.isNotEmpty) {
                            setState(() {
                              _fpIdController.text = enrolledFp;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Live Camera Face Recognition Enrollment Section (Show if face or all)
                if (_selectedAttendanceMethod == 'face' || _selectedAttendanceMethod == 'all') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ((widget.student?.faceRegistered ?? false) || _faceEnrolledLocally)
                          ? Colors.teal.withAlpha(15)
                          : (isDark ? AppColors.surfaceDark : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ((widget.student?.faceRegistered ?? false) || _faceEnrolledLocally)
                            ? Colors.teal
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ((widget.student?.faceRegistered ?? false) || _faceEnrolledLocally)
                                ? Colors.teal.withAlpha(25)
                                : Colors.grey.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.face_rounded,
                            color: ((widget.student?.faceRegistered ?? false) || _faceEnrolledLocally) ? Colors.teal : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'بصمة الوجه الرقمية بالكاميرا',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ((widget.student?.faceRegistered ?? false) || _faceEnrolledLocally)
                                    ? 'تم التقاط بصمة الوجه بنجاح وجاهزة للحفظ مع بيانات الطالب'
                                    : 'قم بتوجيه الطالب أمام الكاميرا لالتقاط الوجه واستخراج القالب',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ((widget.student?.faceRegistered ?? false) || _faceEnrolledLocally) ? Colors.teal : Colors.grey,
                                  fontWeight: ((widget.student?.faceRegistered ?? false) || _faceEnrolledLocally) ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.camera_front_rounded, size: 16),
                          label: Text(((widget.student?.faceRegistered ?? false) || _faceEnrolledLocally) ? 'إعادة مسح' : 'مسح الوجه'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final uniId = _idController.text.trim();
                            final name = _nameController.text.trim();

                            if (uniId.isEmpty || name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('يرجى إدخال اسم الطالب والرقم الجامعي أولاً لتسجيل بصمة وجهه بالكاميرا.'),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                              return;
                            }

                            final studentForEnrollment = widget.student ?? Student(
                              universityId: uniId,
                              fullName: name,
                              phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : '0000000000',
                              email: _emailController.text.trim(),
                              collegeId: _selectedCollegeId,
                              departmentId: _selectedDepartmentId,
                              levelId: _selectedLevelId,
                              semesterId: _selectedSemesterId,
                              status: _status,
                              qrCode: 'DAWAMI:STUDENT:$uniId',
                              attendanceMethod: _selectedAttendanceMethod,
                              photoUrl: _photoController.text.trim().isNotEmpty ? _photoController.text.trim() : null,
                            );

                            final result = await showDialog<FaceProfile>(
                              context: context,
                              builder: (_) => StudentFaceEnrollmentDialog(
                                student: studentForEnrollment,
                                isReEnrollment: _faceEnrolledLocally || (widget.student?.faceRegistered ?? false),
                              ),
                            );

                            if (result != null) {
                              setState(() {
                                _enrolledFaceProfile = result;
                                _faceEnrolledLocally = true;
                                _enrolledFaceEmbedding = result.faceEmbeddingHash;
                                if (_photoController.text.trim().isEmpty) {
                                  _photoController.text = result.referencePhotoUrl ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=008080&color=fff&size=256';
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // معاينة والتقاط صورة الطالب (Photo Preview & Quick Generator)
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
                        image: _photoController.text.trim().isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_photoController.text.trim()),
                                fit: BoxFit.cover,
                                onError: (err, stack) {},
                              )
                            : null,
                      ),
                      child: _photoController.text.trim().isEmpty
                          ? const Icon(Icons.person_outline_rounded, color: AppColors.primaryBlue, size: 26)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _photoController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'رابط صورة الطالب (اختياري)',
                          prefixIcon: Icon(Icons.photo_camera_outlined),
                          hintText: 'https://...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'توليد صورة الهوية الشخصية',
                      child: IconButton.filledTonal(
                        icon: const Icon(Icons.add_a_photo_outlined),
                        onPressed: () {
                          final name = _nameController.text.trim();
                          final effectiveName = name.isNotEmpty ? name : 'Student';
                          setState(() {
                            _photoController.text = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(effectiveName)}&background=0D8ABC&color=fff&size=256';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Generated Barcode / QR Code preview info (Show if barcode or all)
                if (_selectedAttendanceMethod == 'barcode' || _selectedAttendanceMethod == 'all')
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryBlue.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'معرّف الباركود الفريد: ${_idController.text.trim().isEmpty ? "يتم توليده تلقائياً من الرقم الجامعي" : "DAWAMI:STUDENT:${_idController.text.trim()}"}',
                          style: const TextStyle(fontSize: 11, color: AppColors.darkBlue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(isEdit ? 'حفظ التعديلات' : 'إضافة', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

