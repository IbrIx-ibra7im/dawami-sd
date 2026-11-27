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
  String _reportCategory = 'daily_attendance'; // 'daily_attendance', 'daily_departure', 'monthly', 'absence', 'late', 'currently_present', 'stay_duration'
  String _selectedMethod = 'الكل'; // 'الكل', 'fingerprint', 'face', 'mobile', 'barcode_qr', 'manual'
  String _selectedDepartment = 'الكل';
  String _selectedLevel = 'الكل';
  String _selectedDevice = 'الكل';
  bool _isExporting = false;

  List<AttendanceRecord> _getFilteredRecords(List<AttendanceRecord> allRecords, AppRepository repo) {
    return allRecords.where((r) {
      // 1. تصفية حسب نوع التقرير
      switch (_reportCategory) {
        case 'daily_attendance':
          if (r.status != 'حاضر' && r.status != 'متأخر' && r.status != 'منصرف') return false;
          break;
        case 'daily_departure':
          if (!r.hasDeparted) return false;
          break;
        case 'absence':
          if (r.status != 'غائب') return false;
          break;
        case 'late':
          if (r.status != 'متأخر' && r.delayMinutes <= 0) return false;
          break;
        case 'currently_present':
          if (r.hasDeparted || (r.status != 'حاضر' && r.status != 'متأخر')) return false;
          break;
        case 'stay_duration':
          if (!r.hasDeparted && r.durationMinutes <= 0) return false;
          break;
        case 'monthly':
        default:
          break;
      }

      // 2. تصفية حسب وسيلة الحضور
      if (_selectedMethod != 'الكل') {
        if (!r.method.toLowerCase().contains(_selectedMethod.toLowerCase())) return false;
      }

      // 3. تصفية حسب جهاز البصمة
      if (_selectedDevice != 'الكل') {
        if (r.deviceName != _selectedDevice && r.deviceId != _selectedDevice) return false;
      }

      // 4. تصفية حسب القسم والمستوى الدراسي
      if (_selectedDepartment != 'الكل' || _selectedLevel != 'الكل') {
        final matches = repo.students.where((s) => s.universityId == r.studentNumber || s.id == r.studentId);
        final student = matches.isNotEmpty ? matches.first : null;
        if (student != null) {
          if (_selectedDepartment != 'الكل' && student.department != _selectedDepartment) return false;
          if (_selectedLevel != 'الكل' && student.academicLevel != _selectedLevel) return false;
        }
      }

      return true;
    }).toList();
  }

  String _getReportTitle() {
    switch (_reportCategory) {
      case 'daily_attendance':
        return 'تقرير الحضور اليومي للطلاب';
      case 'daily_departure':
        return 'تقرير الانصراف اليومي للطلاب';
      case 'absence':
        return 'تقرير غياب الطلاب';
      case 'late':
        return 'تقرير تأخير الطلاب عن الدوام الجامعي';
      case 'currently_present':
        return 'تقرير الطلاب المتواجدين حالياً بالحرم الجامعي';
      case 'stay_duration':
        return 'تقرير عدد ساعات البقاء داخل الحرم الجامعي';
      case 'monthly':
      default:
        return 'تقرير الحضور والانصراف الشهري';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allRecords = repo.todayAttendance;
    final filteredRecords = _getFilteredRecords(allRecords, repo);
    final devices = repo.biometricDevices;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات الرسمية للجامعة'),
        backgroundColor: AppColors.darkBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filters Panel Card
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
                  const Text('خيارات وفلاتر التقارير المتقدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 14),

                  // 1. نوع التقرير
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCategoryChip('الحضور اليومي', 'daily_attendance'),
                      _buildCategoryChip('الانصراف اليومي', 'daily_departure'),
                      _buildCategoryChip('الموجودون حالياً', 'currently_present'),
                      _buildCategoryChip('تقرير التأخير', 'late'),
                      _buildCategoryChip('تقرير الغياب', 'absence'),
                      _buildCategoryChip('ساعات البقاء', 'stay_duration'),
                      _buildCategoryChip('التقرير الشهري', 'monthly'),
                    ],
                  ),
                  const Divider(height: 24),

                  // 2. الفلاتر المنسدلة
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMethod,
                          decoration: const InputDecoration(labelText: 'وسيلة التسجيل'),
                          items: const [
                            DropdownMenuItem(value: 'الكل', child: Text('كافة الوسائل')),
                            DropdownMenuItem(value: 'fingerprint', child: Text('بصمة الإصبع')),
                            DropdownMenuItem(value: 'face', child: Text('التعرف على الوجه')),
                            DropdownMenuItem(value: 'mobile', child: Text('هاتف الطالب GPS')),
                            DropdownMenuItem(value: 'barcode', child: Text('الباركود وQR')),
                            DropdownMenuItem(value: 'manual', child: Text('تسجيل إداري')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMethod = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDevice,
                          decoration: const InputDecoration(labelText: 'جهاز البصمة / المحطة'),
                          items: [
                            const DropdownMenuItem(value: 'الكل', child: Text('كافة الأجهزة')),
                            ...devices.map((d) => DropdownMenuItem(value: d.deviceName, child: Text(d.deviceName))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDevice = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDepartment,
                          decoration: const InputDecoration(labelText: 'القسم الأكاديمي'),
                          items: const [
                            DropdownMenuItem(value: 'الكل', child: Text('كافة الأقسام')),
                            DropdownMenuItem(value: 'علوم الحاسوب', child: Text('علوم الحاسوب')),
                            DropdownMenuItem(value: 'تقنية المعلومات', child: Text('تقنية المعلومات')),
                            DropdownMenuItem(value: 'نظم المعلومات', child: Text('نظم المعلومات')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDepartment = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedLevel,
                          decoration: const InputDecoration(labelText: 'المستوى الدراسي'),
                          items: const [
                            DropdownMenuItem(value: 'الكل', child: Text('كافة المستويات')),
                            DropdownMenuItem(value: 'المستوى الأول', child: Text('المستوى الأول')),
                            DropdownMenuItem(value: 'المستوى الثاني', child: Text('المستوى الثاني')),
                            DropdownMenuItem(value: 'المستوى الثالث', child: Text('المستوى الثالث')),
                            DropdownMenuItem(value: 'المستوى الرابع', child: Text('المستوى الرابع')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLevel = val);
                          },
                        ),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getReportTitle(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkBlue),
                      ),
                      const SizedBox(height: 4),
                      Text('الجامعة: ${repo.universityName} | التاريخ: ${DateTime.now().toString().substring(0, 10)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredRecords.length} سجل',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
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
                              reportTitle: _getReportTitle(),
                              records: filteredRecords,
                              subtitle: 'تاريخ الاستخراج: ${DateTime.now().toString().substring(0, 16)}',
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
                  label: const Text('تصدير كملف إكسل رسمي (.xlsx)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _exportAttendanceToDevice(context, filteredRecords, repo),
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

  Widget _buildCategoryChip(String title, String categoryKey) {
    final isSelected = _reportCategory == categoryKey;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      selectedColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _reportCategory = categoryKey);
      },
    );
  }

  Future<void> _exportAttendanceToDevice(
    BuildContext context,
    List<AttendanceRecord> records,
    AppRepository repo,
  ) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد سجلات لتصديرها وفق الفلاتر المحددة'), backgroundColor: AppColors.warning),
      );
      return;
    }

    try {
      final excelBytes = CsvReportHelper.exportAttendanceToExcel(records);
      final filename = 'Dawami_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final path = await FileSaver.saveFile(
        bytes: excelBytes,
        fileName: filename,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير ملف الإكسل بنجاح: $path'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تصدير الإكسل: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}
