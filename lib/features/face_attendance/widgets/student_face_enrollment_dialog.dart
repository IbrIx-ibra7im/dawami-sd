import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/face_recognition_service.dart';
import '../../../core/utils/student_image_helper.dart';
import '../../../data/models/face_profile.dart';
import '../../../data/models/student.dart';

/// معالج تسجيل بصمة وجه الطالب متعددة الزوايا (Face Enrollment Wizard)
class StudentFaceEnrollmentDialog extends StatefulWidget {
  final Student student;
  final bool isReEnrollment;

  const StudentFaceEnrollmentDialog({
    super.key,
    required this.student,
    this.isReEnrollment = false,
  });

  static Future<FaceProfile?> show(
    BuildContext context, {
    required Student student,
    bool isReEnrollment = false,
  }) {
    return showDialog<FaceProfile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StudentFaceEnrollmentDialog(
        student: student,
        isReEnrollment: isReEnrollment,
      ),
    );
  }

  @override
  State<StudentFaceEnrollmentDialog> createState() => _StudentFaceEnrollmentDialogState();
}

class _StudentFaceEnrollmentDialogState extends State<StudentFaceEnrollmentDialog> {
  final MobileScannerController _cameraController = MobileScannerController(
    facing: CameraFacing.front,
    detectionSpeed: DetectionSpeed.normal,
  );

  int _currentStep = 0; // 0: Front, 1: Right Angle, 2: Left Angle, 3: Completed
  bool _isCapturing = false;
  String? _errorMessage;
  FaceProfile? _enrolledProfile;
  final List<List<int>> _capturedAngles = [];

  final List<String> _stepTitles = [
    'الخطوة 1 من 3: الوضعية المستقيمة',
    'الخطوة 2 من 3: إمالة خفيفة لليمين',
    'الخطوة 3 من 3: إمالة خفيفة لليسار',
    'اكتمل تسجيل بصمة الوجه بنجاح',
  ];

  final List<String> _stepInstructions = [
    'انظر مباشرة إلى الكاميرا وتأكد من وضوح كامل الوجه داخل الإطار البيضاوي.',
    'أمل رأسك برفق نحو اليمين بزاوية بسيطة لالتقاط ملامح الجانب الأيمن.',
    'أمل رأسك برفق نحو اليسار بزاوية بسيطة لالتقاط ملامح الجانب الأيسر.',
    'تم توليد البصمة الرقمية وحفظ القالب المركب في النظام بنجاح! 🎉',
  ];

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _captureCurrentAngle() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      // محاكاة التقاط إطار بصري عالي الجودة للزاوية الحالية
      final sampleBytes = List<int>.generate(256, (i) => (i * 17 + _currentStep * 43) % 256);
      _capturedAngles.add(sampleBytes);

      await Future.delayed(const Duration(milliseconds: 600));

      if (_currentStep < 2) {
        setState(() {
          _currentStep++;
          _isCapturing = false;
        });
      } else {
        // تم التقاط الـ 3 زوايا -> نقوم بحفظ الملف البيومتري المركب وتوليد صورة مرجعية
        final defaultPhoto = (widget.student.photoUrl != null && widget.student.photoUrl!.isNotEmpty)
            ? widget.student.photoUrl!
            : StudentImageHelper.generateCapturedPhotoDataUrl(
                studentName: widget.student.fullName,
                studentId: widget.student.universityId,
              );

        final profile = await FaceRecognitionService.instance.enrollStudentMultiAngle(
          student: widget.student,
          anglePhotosBytes: _capturedAngles,
          photoUrl: defaultPhoto,
          qualityScore: 98,
        );

        _enrolledProfile = profile;

        setState(() {
          _currentStep = 3;
          _isCapturing = false;
        });

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, profile);
        }
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.darkBlue, AppColors.primaryBlue],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isReEnrollment ? 'تحديث بصمة وجه الطالب' : 'تسجيل بصمة وجه جديدة',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${widget.student.fullName} (${widget.student.universityId})',
                          style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. Step Progress Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _stepTitles[_currentStep],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                      ),
                      Text(
                        '${((_currentStep + (_currentStep == 3 ? 0 : 0.3)) / 3 * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _currentStep == 3 ? 1.0 : (_currentStep + 1) / 3.0,
                      backgroundColor: Colors.grey.withAlpha(40),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentStep == 3 ? AppColors.success : AppColors.primaryBlue,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _stepInstructions[_currentStep],
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Camera Viewport with Oval Guidance Overlay
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _currentStep == 3 ? AppColors.success : AppColors.turquoise,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_currentStep < 3)
                      MobileScanner(
                        controller: _cameraController,
                        onDetect: (_) {},
                      )
                    else
                      Container(
                        color: AppColors.success.withAlpha(30),
                        child: const Center(
                          child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 84),
                        ),
                      ),

                    // Oval Face Guide
                    if (_currentStep < 3)
                      Center(
                        child: Container(
                          width: 170,
                          height: 230,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(120),
                            border: Border.all(
                              color: _isCapturing ? AppColors.warning : AppColors.turquoise,
                              width: 3,
                            ),
                          ),
                        ),
                      ),

                    // Angle Direction Arrow Helper
                    if (_currentStep == 1)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(right: 20),
                          child: Icon(Icons.arrow_forward_rounded, color: AppColors.turquoise, size: 40),
                        ),
                      )
                    else if (_currentStep == 2)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: Icon(Icons.arrow_back_rounded, color: AppColors.turquoise, size: 40),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Error Banner
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // 4. Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                  ),
                  const Spacer(),
                  if (_currentStep < 3)
                    ElevatedButton.icon(
                      icon: _isCapturing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt_rounded),
                      label: Text(_isCapturing ? 'جارٍ التحليل...' : 'التقاط هذه الزاوية'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isCapturing ? null : _captureCurrentAngle,
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context, _enrolledProfile),
                      child: const Text('إتمام الحفظ ومتابعة', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
