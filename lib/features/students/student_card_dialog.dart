import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/pdf_report_helper.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';

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
                  const Text(
                    'امسح الرمز لتسجيل الحضور فورياً',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
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
          ],
        ),
      ),
    );
  }
}

