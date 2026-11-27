import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/pdf_report_helper.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';
import '../face_attendance/widgets/student_face_enrollment_dialog.dart';
import 'add_edit_student_dialog.dart';

class StudentCardDialog extends StatelessWidget {
  final Student student;

  const StudentCardDialog({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'بطاقة الطالب الجامعية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // University ID Card Container
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.darkBlue, AppColors.primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'جامعة دنقلا - كلية علوم الحاسوب والتنمية البشرية',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.turquoise,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          student.status,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Student Details
                  Text(
                    student.fullName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الرقم الجامعي: ${student.universityId}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (student.collegeName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      student.collegeName!,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: student.qrCode.isNotEmpty ? student.qrCode : student.universityId,
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: student.hasFingerprint ? AppColors.success.withAlpha(40) : Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fingerprint, size: 14, color: student.hasFingerprint ? AppColors.success : Colors.white60),
                            const SizedBox(width: 4),
                            Text(student.hasFingerprint ? 'بصمة مسجلة' : 'بدون بصمة', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: student.faceRegistered ? AppColors.turquoise.withAlpha(40) : Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.face, size: 14, color: student.faceRegistered ? AppColors.turquoise : Colors.white60),
                            const SizedBox(width: 4),
                            Text(student.faceRegistered ? 'بصمة وجه مفعلة' : 'بدون وجه', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'طريقة الحضور المعتمدة: ${student.attendanceMethodDisplay}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'امسح الرمز لتسجيل الحضور فورياً',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: Icon(
                student.faceRegistered ? Icons.face_retouching_natural_rounded : Icons.face_rounded,
                color: student.faceRegistered ? AppColors.success : AppColors.turquoise,
              ),
              label: Text(
                student.faceRegistered ? 'تحديث بصمة الوجه بالكاميرا' : 'تسجيل بصمة الوجه بالكاميرا',
                style: TextStyle(
                  color: student.faceRegistered ? AppColors.success : AppColors.turquoise,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(
                  color: student.faceRegistered ? AppColors.success : AppColors.turquoise,
                ),
              ),
              onPressed: () async {
                final profile = await StudentFaceEnrollmentDialog.show(
                  context,
                  student: student,
                  isReEnrollment: student.faceRegistered,
                );
                if (profile != null && context.mounted) {
                  Navigator.pop(context);
                  await context.read<AppRepository>().refreshStudents();
                }
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: const Text('طباعة البطاقة الرسمية (PDF)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () async {
                final repo = context.read<AppRepository>();
                try {
                  await Printing.layoutPdf(
                    name: 'Student_Card_${student.universityId}',
                    onLayout: (format) => PdfReportHelper.generateStudentCardPdf(
                      student: student,
                      universityName: repo.universityName,
                    ),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر فتح نافذة الطباعة: $e'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 10),

            // زري التعديل والحذف معاً في مكان واحد
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('تعديل البيانات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => AddEditStudentDialog(student: student),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('حذف الطالب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                              SizedBox(width: 8),
                              Text('تأكيد حذف الطالب'),
                            ],
                          ),
                          content: Text(
                            'هل أنت متأكد من رغبتك في حذف الطالب "${student.fullName}" نهائياً من قاعدة البيانات؟',
                            style: const TextStyle(fontSize: 13),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('نعم، تأكيد الحذف', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        Navigator.pop(context);
                        final repo = context.read<AppRepository>();
                        final target = repo.students.firstWhere(
                          (s) => s.universityId == student.universityId,
                          orElse: () => student,
                        );
                        if (target.id != null) {
                          await repo.deleteStudent(target.id!);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم حذف الطالب "${student.fullName}" بنجاح'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

