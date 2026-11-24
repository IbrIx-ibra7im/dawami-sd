import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';
import 'fingerprint_provider.dart';

/// معالج تسجيل وقراءة بصمة الطالب الحيوية لأول مرة والتحقق من الجودة والتفرد
class FingerprintEnrollmentDialog extends StatefulWidget {
  final Student student;
  final bool isReEnrollment;

  const FingerprintEnrollmentDialog({
    super.key,
    required this.student,
    this.isReEnrollment = false,
  });

  @override
  State<FingerprintEnrollmentDialog> createState() => _FingerprintEnrollmentDialogState();
}

class _FingerprintEnrollmentDialogState extends State<FingerprintEnrollmentDialog>
    with SingleTickerProviderStateMixin {
  int _currentStep = 1; // 1: وضع الإصبع, 2: التحقق من الجودة, 3: اكتمال التسجيل
  int _qualityScore = 0;
  bool _isScanning = false;
  String? _errorMessage;
  String? _enrolledFpId;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startCapture() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      if (widget.student.id == null) {
        throw Exception('احفظ بيانات الطالب أولاً قبل تفعيل البصمة.');
      }

      final provider = context.read<FingerprintProvider>();
      if (!provider.canEnrollFingerprints) {
        throw Exception(
          'لا يمكن تسجيل بصمة فعلية حالياً: لم يتم ربط قارئ بصمة حقيقي وSDK معتمد.',
        );
      }

      final capture = await provider.captureFingerprint(widget.student);
      if (capture == null ||
          capture.fingerprintId.trim().isEmpty ||
          capture.templateHash.trim().isEmpty) {
        throw Exception('لم يستطع قارئ البصمة التقاط قالب صالح. أعد المحاولة.');
      }

      if (capture.qualityScore < 75) {
        throw Exception(
          'جودة البصمة منخفضة (${capture.qualityScore}%). يرجى إعادة وضع الإصبع بثبات على المستشعر.',
        );
      }

      if (!mounted) return;
      setState(() {
        _qualityScore = capture.qualityScore;
        _currentStep = 2;
      });

      final repo = context.read<AppRepository>();
      final isDuplicate = await repo.isFingerprintDuplicate(
        capture.fingerprintId,
        excludeStudentId: widget.student.id,
      );

      if (isDuplicate) {
        throw Exception('عذراً، هذه البصمة مسجلة مسبقاً في النظام لطالب آخر ولا يمكن تكرارها.');
      }

      await repo.enrollStudentFingerprint(
        student: widget.student,
        fingerprintId: capture.fingerprintId,
        templateHash: capture.templateHash,
        quality: capture.qualityScore,
      );

      if (!mounted) return;
      setState(() {
        _currentStep = 3;
        _enrolledFpId = capture.fingerprintId;
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isScanning = false;
        _currentStep = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.student;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.turquoise.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fingerprint_rounded, color: AppColors.turquoise, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isReEnrollment ? 'إعادة تسجيل بصمة الطالب' : 'تسجيل بصمة حيوية جديدة',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // بيانات الطالب المستهدف
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primaryBlue.withAlpha(25),
                      child: const Icon(Icons.person, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'الرقم الجامعي: ${s.universityId} • ${s.departmentName ?? "علوم الحاسوب"}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Visual Fingerprint Touch Target
              ScaleTransition(
                scale: _isScanning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentStep == 3
                        ? AppColors.success.withAlpha(20)
                        : (_errorMessage != null
                            ? AppColors.danger.withAlpha(20)
                            : AppColors.turquoise.withAlpha(20)),
                    border: Border.all(
                      color: _currentStep == 3
                          ? AppColors.success
                          : (_errorMessage != null ? AppColors.danger : AppColors.turquoise),
                      width: 5,
                    ),
                  ),
                  child: Center(
                    child: _isScanning
                        ? const CircularProgressIndicator(color: AppColors.turquoise, strokeWidth: 4)
                        : Icon(
                            _currentStep == 3
                                ? Icons.check_circle_rounded
                                : (_errorMessage != null
                                    ? Icons.error_outline_rounded
                                    : Icons.fingerprint_rounded),
                            size: 80,
                            color: _currentStep == 3
                                ? AppColors.success
                                : (_errorMessage != null ? AppColors.danger : AppColors.turquoise),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status Title & Message
              if (_currentStep == 3) ...[
                const Text(
                  'تم التقاط وحفظ البصمة بنجاح! 🎉',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
                ),
                const SizedBox(height: 6),
                Text(
                  'معرّف البصمة المسجل: $_enrolledFpId • درجة الجودة: $_qualityScore%',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ] else if (_isScanning) ...[
                const Text(
                  'جاري قراءة البصمة والتحقق من الجودة...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.turquoise),
                ),
                const SizedBox(height: 4),
                const Text(
                  'يرجى إبقاء إصبع الطالب ثابتاً على المستشعر',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                const Text(
                  'ضع إصبع الطالب على قارئ البصمة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'سيتم التحقق من جودة البصمة ومطابقتها وتفردها آلياً',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],

              // Error Banner
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _enrolledFpId),
          child: Text(_currentStep == 3 ? 'إغلاق' : 'إلغاء'),
        ),
        if (_currentStep == 3)
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('اعتماد البصمة ومتابعة الحفظ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, _enrolledFpId),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.fingerprint_rounded, size: 18),
            label: Text(_errorMessage != null ? 'إعادة المحاولة' : 'بدء المسح الآن'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.turquoise,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _isScanning ? null : _startCapture,
          ),
      ],
    );
  }
}
