import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';
import '../fingerprint/fingerprint_enrollment_dialog.dart';

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
  bool _isSaving = false;

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

  /// فتح نافذة مخصصة لتعديل وتفصيل أجزاء الاسم (الاسم الأول، الأب، الجد، اللقب)
  void _openNameEditorDialog() {
    final currentText = _nameController.text.trim();
    final parts = currentText.isNotEmpty ? currentText.split(RegExp(r'\s+')) : <String>[];

    final firstNameCtrl = TextEditingController(text: parts.isNotEmpty ? parts[0] : '');
    final fatherNameCtrl = TextEditingController(text: parts.length > 1 ? parts[1] : '');
    final grandFatherCtrl = TextEditingController(text: parts.length > 2 ? parts[2] : '');
    final familyNameCtrl = TextEditingController(text: parts.length > 3 ? parts.sublist(3).join(' ') : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final repo = context.watch<AppRepository>();
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('تعديل وتفصيل الاسم الرباعي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'قم بتعديل وتنسيق أجزاء الاسم بشكل منفصل لضمان الدقة وتفادي الأخطاء الإملائية:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الأول (اسم الطالب) *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: fatherNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الأب *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: grandFatherCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الجد *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: familyNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اللقب / اسم العائلة / القبيلة',
                        prefixIcon: Icon(Icons.family_restroom_outlined, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // زر التنسيق التلقائي وإزالة المسافات
                    OutlinedButton.icon(
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('تنسيق وتنظيف المسافات الزائدة', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setDialogState(() {
                          firstNameCtrl.text = firstNameCtrl.text.trim();
                          fatherNameCtrl.text = fatherNameCtrl.text.trim();
                          grandFatherCtrl.text = grandFatherCtrl.text.trim();
                          familyNameCtrl.text = familyNameCtrl.text.trim();
                        });
                      },
                    ),
                    if (repo.students.isNotEmpty && widget.student == null) ...[
                      const Divider(height: 24),
                      const Text(
                        'أو اختر طالباً مسجلاً لتعديل اسمه مباشرة:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Student>(
                            isExpanded: true,
                            hint: const Text('اختر طالباً من القائمة لتحميل بياناته', style: TextStyle(fontSize: 12)),
                            items: repo.students.take(50).map((s) {
                              return DropdownMenuItem<Student>(
                                value: s,
                                child: Text('${s.fullName} (${s.studentNumber})', style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (selected) {
                              if (selected != null) {
                                final sParts = selected.fullName.trim().split(RegExp(r'\s+'));
                                setDialogState(() {
                                  firstNameCtrl.text = sParts.isNotEmpty ? sParts[0] : '';
                                  fatherNameCtrl.text = sParts.length > 1 ? sParts[1] : '';
                                  grandFatherCtrl.text = sParts.length > 2 ? sParts[2] : '';
                                  familyNameCtrl.text = sParts.length > 3 ? sParts.sublist(3).join(' ') : '';
                                });
                                setState(() {
                                  _idController.text = selected.studentNumber;
                                  _phoneController.text = selected.phone;
                                  _emailController.text = selected.email;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('تطبيق وتحديث الاسم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final combined = [
                    firstNameCtrl.text.trim(),
                    fatherNameCtrl.text.trim(),
                    grandFatherCtrl.text.trim(),
                    familyNameCtrl.text.trim(),
                  ].where((p) => p.isNotEmpty).join(' ');

                  if (combined.isNotEmpty) {
                    setState(() {
                      _nameController.text = combined;
                    });
                  }
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
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

      // 2. التحقق من فرادة معرف البصمة إن وجد
      final fpId = _fpIdController.text.trim();
      if (fpId.isNotEmpty) {
        final isDuplicateFp = await repo.isFingerprintDuplicate(fpId, excludeStudentId: widget.student?.id);
        if (isDuplicateFp) {
          throw Exception('معرف البصمة "$fpId" مسجل مسبقاً لطالب آخر. لا يمكن تكرار البصمة.');
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
        fingerprintId: fpId.isNotEmpty ? fpId : null,
        fingerprintStatus: fpId.isNotEmpty
            ? (widget.student?.fingerprintStatus ?? 'مسجلة')
            : 'غير مسجلة',
        fingerprintQuality: widget.student?.fingerprintQuality,
        fingerprintEnrolledAt: widget.student?.fingerprintEnrolledAt,
        photoUrl: _photoController.text.trim().isNotEmpty ? _photoController.text.trim() : null,
        collegeName: collegeName,
        departmentName: deptName,
        levelName: levelName,
      );

      if (widget.student == null) {
        await repo.addStudent(student);
      } else {
        await repo.updateStudent(student);
      }

      if (mounted) {
        Navigator.pop(context);
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
                    widget.student == null
                        ? '🔔 تنبيه: تمت إضافة الطالب "${student.fullName}" بنجاح إلى قاعدة البيانات'
                        : '🔔 تنبيه: تم حفظ وتعديل بيانات الطالب "${student.fullName}" بنجاح',
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الرباعي *',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الطالب' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text('تعديل الأسماء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          side: const BorderSide(color: AppColors.primaryBlue),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        ),
                        onPressed: _openNameEditorDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(labelText: 'الرقم الجامعي * (مثال: 2023-1590)'),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fpIdController,
                        decoration: const InputDecoration(
                          labelText: 'معرّف البصمة في الجهاز (مثال: FP-1045)',
                          prefixIcon: Icon(Icons.fingerprint),
                        ),
                      ),
                    ),
                    if (widget.student != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.touch_app, size: 16),
                        label: const Text('تسجيل البصمة', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final repo = context.read<AppRepository>();
                          await showDialog(
                            context: context,
                            builder: (_) => FingerprintEnrollmentDialog(
                              student: widget.student!,
                              isReEnrollment: widget.student!.hasFingerprint,
                            ),
                          );
                          if (!mounted) return;
                          final updated = repo.students.firstWhere(
                            (s) => s.id == widget.student!.id,
                            orElse: () => widget.student!,
                          );
                          if (updated.fingerprintId != null) {
                            setState(() {
                              _fpIdController.text = updated.fingerprintId!;
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _photoController,
                  decoration: const InputDecoration(
                    labelText: 'رابط صورة الطالب (اختياري)',
                    prefixIcon: Icon(Icons.photo_camera_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                // Generated Barcode / QR Code preview info
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

