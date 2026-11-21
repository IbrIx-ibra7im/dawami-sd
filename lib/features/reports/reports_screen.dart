import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/pdf_report_helper.dart';
import '../../core/utils/csv_report_helper.dart';
import '../../core/utils/file_saver/file_saver.dart';
import '../../data/models/attendance_record.dart';
import '../../data/repositories/app_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _reportType = 'يومي'; // 'يومي', 'أسبوعي', 'شهري'
  String _selectedMethod = 'الكل'; // 'الكل', 'بصمة', 'qr'
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = repo.todayAttendance;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات الرسمية'),
        backgroundColor: AppColors.darkBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filters Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إعدادات التقرير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 14),

                  // Report frequency
                  Row(
                    children: [
                      const Text('نوع التقرير: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _reportType,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'يومي', child: Text('تقرير يومي')),
                          DropdownMenuItem(value: 'أسبوعي', child: Text('تقرير أسبوعي')),
                          DropdownMenuItem(value: 'شهري', child: Text('تقرير شهري')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _reportType = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Attendance Method
                  Row(
                    children: [
                      const Text('وسيلة الحضور: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedMethod,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'الكل', child: Text('كافة الوسائل')),
                          DropdownMenuItem(value: 'fingerprint', child: Text('الحضور بالبصمة فقط')),
                          DropdownMenuItem(value: 'qr', child: Text('الحضور بالـ QR فقط')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMethod = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Summary Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'الجامعة: ${repo.universityName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkBlue),
                  ),
                  const SizedBox(height: 4),
                  Text('إجمالي السجلات المشمولة: ${records.length} سجل'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Export Actions (PDF & Excel/CSV)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;

                final pdfBtn = ElevatedButton.icon(
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_isExporting ? 'جارٍ إعداد التقرير...' : 'معاينة وطباعة تقرير PDF رسمي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isExporting
                      ? null
                      : () async {
                          setState(() => _isExporting = true);
                          try {
                            final pdfBytes = await PdfReportHelper.generateAttendanceReport(
                              universityName: repo.universityName,
                              reportTitle: 'تقرير حضور وغياب الطلاب ($_reportType)',
                              records: records,
                              subtitle: 'تاريخ: ${DateTime.now().toString().substring(0, 10)}',
                            );

                            await Printing.layoutPdf(
                              onLayout: (format) async => pdfBytes,
                              name: 'Dawami_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ في إعداد التقرير: $e'), backgroundColor: AppColors.danger),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isExporting = false);
                          }
                        },
                );

                final excelBtn = OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('تصدير إلى الجهاز (Excel / CSV / PDF)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _exportAttendanceToDevice(context, records, repo),
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: pdfBtn),
                      const SizedBox(width: 14),
                      Expanded(child: excelBtn),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    pdfBtn,
                    const SizedBox(height: 12),
                    excelBtn,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAttendanceToDevice(
    BuildContext context,
    List<AttendanceRecord> records,
    AppRepository repo,
  ) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد سجلات حضور لتصديرها حالياً'), backgroundColor: AppColors.warning),
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
                'تصدير سجلات الحضور وحفظها في جهازك',
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger),
                label: const Text('حفظ كملف تقرير PDF رسمي (.pdf) في الجهاز', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, 'pdf'),
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
        fileName = 'Dawami_Attendance_$nowStr.xlsx';
        bytes = CsvReportHelper.exportAttendanceToExcel(records);
        mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      } else if (format == 'csv') {
        fileName = 'Dawami_Attendance_$nowStr.csv';
        bytes = CsvReportHelper.exportAttendanceToCsvBytes(records);
        mimeType = 'text/csv; charset=utf-8';
      } else {
        fileName = 'Dawami_Attendance_$nowStr.pdf';
        bytes = await PdfReportHelper.generateAttendanceReport(
          universityName: repo.universityName,
          reportTitle: 'تقرير حضور وغياب الطلاب ($_reportType)',
          records: records,
          subtitle: 'تاريخ التصدير: ${DateTime.now().toString().substring(0, 10)}',
        );
        mimeType = 'application/pdf';
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
}

