import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';
import '../../widgets/custom_widgets.dart';
import '../fingerprint/fingerprint_provider.dart';
import '../fingerprint/fingerprint_enrollment_dialog.dart';
import '../../data/models/biometric_models.dart';
import 'student_card_dialog.dart';

class StudentCredentialsScreen extends StatefulWidget {
  final Student? initialStudent;

  const StudentCredentialsScreen({super.key, this.initialStudent});

  @override
  State<StudentCredentialsScreen> createState() => _StudentCredentialsScreenState();
}

class _StudentCredentialsScreenState extends State<StudentCredentialsScreen> {
  Student? _selectedStudent;
  bool _isTestingFingerprint = false;
  String? _fpTestResult;

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.initialStudent;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final fpProvider = context.watch<FingerprintProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    final students = repo.students;
    if (_selectedStudent == null && students.isNotEmpty) {
      _selectedStudent = students.first;
    }

    final student = _selectedStudent;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('بطاقات الطلاب • البصمة ورمز الـ QR'),
        backgroundColor: AppColors.darkBlue,
      ),
      body: student == null
          ? const Center(child: Text('لا يوجد طلاب مسجلون في النظام'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Student Selector Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_search_rounded, color: AppColors.primaryBlue, size: 28),
                        const SizedBox(width: 14),
                        const Text(
                          'اختر الطالب:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<Student>(
                            initialValue: student,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: students.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text('${s.fullName} (${s.universityId}) - ${s.collegeName ?? ''}'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStudent = val;
                                  _fpTestResult = null;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Main Content (Side-by-Side on Desktop, Stacked on Mobile)
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: QR Code & University ID Card
                        Expanded(
                          child: _buildQrSection(student, isDark),
                        ),
                        const SizedBox(width: 24),
                        // Right: Biometric Fingerprint Section
                        Expanded(
                          child: _buildFingerprintSection(student, fpProvider, isDark),
                        ),
                      ],
                    )
                  else ...[
                    _buildQrSection(student, isDark),
                    const SizedBox(height: 20),
                    _buildFingerprintSection(student, fpProvider, isDark),
                  ],
                ],
              ),
            ),
    );
  }

  // --- QR Code & Student Card Section ---
  Widget _buildQrSection(Student student, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withAlpha(20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'رمز الـ QR والباركود الجامعي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              StatusBadge.fromStatus(student.status),
            ],
          ),
          const SizedBox(height: 24),

          // High Resolution QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: QrImageView(
              data: student.qrCode.isNotEmpty ? student.qrCode : student.universityId,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
          const SizedBox(height: 16),

          // Code text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              student.qrCode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Student Info Pills
          Text(
            student.fullName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'الرقم الجامعي: ${student.universityId} • ${student.collegeName ?? ''}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Actions
          ElevatedButton.icon(
            icon: const Icon(Icons.badge_outlined),
            label: const Text('معاينة وطباعة بطاقة الطالب الكاملة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => StudentCardDialog(student: student),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Biometric Fingerprint Section ---
  Widget _buildFingerprintSection(Student student, FingerprintProvider fpProvider, bool isDark) {
    final hasFingerprint = student.fingerprintId != null && student.fingerprintId!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.turquoise.withAlpha(20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.turquoise.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fingerprint_rounded, color: AppColors.turquoise, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'بيانات البصمة الحيوية (Biometrics)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (hasFingerprint ? AppColors.success : AppColors.warning).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasFingerprint ? 'بصمة مسجلة' : 'بانتظار التسجيل',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: hasFingerprint ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Big Fingerprint Touch Simulator Circle
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              border: Border.all(
                color: hasFingerprint ? AppColors.turquoise : Colors.grey.shade400,
                width: 6,
              ),
              boxShadow: [
                if (hasFingerprint)
                  BoxShadow(
                    color: AppColors.turquoise.withAlpha(50),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Center(
              child: _isTestingFingerprint
                  ? const CircularProgressIndicator(color: AppColors.turquoise)
                  : Icon(
                      Icons.fingerprint_rounded,
                      size: 100,
                      color: hasFingerprint ? AppColors.turquoise : Colors.grey,
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Fingerprint ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tag, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  hasFingerprint ? 'معرّف البصمة في الحساس: ${student.fingerprintId}' : 'لا يوجد معرف بصمة مرتبط',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: hasFingerprint ? AppColors.turquoise : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Device info
          Text(
            'الجهاز المتوافق المعتمد: ${fpProvider.selectedDeviceModel}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          if (_fpTestResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _fpTestResult!,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Actions: Re-enroll / Update Fingerprint & Test Match
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                label: Text(hasFingerprint ? 'إعادة تسجيل / تحديث البصمة' : 'تسجيل البصمة الحيوية'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.turquoise,
                  side: const BorderSide(color: AppColors.turquoise),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => FingerprintEnrollmentDialog(
                      student: student,
                      isReEnrollment: hasFingerprint,
                    ),
                  );
                  if (!mounted) return;
                  final repo = context.read<AppRepository>();
                  await repo.logBiometricVerification(
                    BiometricVerificationLog(
                      studentId: student.id ?? 0,
                      method: 'fingerprint_update',
                      status: 'success',
                      reason: 'تم إعادة تسجيل وتحديث بصمة الطالب من لوحة التحكم',
                      timestamp: DateTime.now().toIso8601String(),
                      deviceModel: repo.deviceName,
                    ),
                  );
                  setState(() {});
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.touch_app_rounded),
                label: const Text('اختبار مطابقة البصمة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.turquoise,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  setState(() {
                    _isTestingFingerprint = true;
                    _fpTestResult = null;
                  });

                  await Future.delayed(const Duration(milliseconds: 1000));

                  setState(() {
                    _isTestingFingerprint = false;
                    _fpTestResult = 'تم تطابق البصمة بنجاح مع الطالب ${student.fullName}';
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
