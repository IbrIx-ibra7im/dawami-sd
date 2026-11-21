import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/excel_student_importer.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';

class ImportStudentsDialog extends StatefulWidget {
  const ImportStudentsDialog({super.key});

  @override
  State<ImportStudentsDialog> createState() => _ImportStudentsDialogState();
}

class _ImportStudentsDialogState extends State<ImportStudentsDialog> {
  String? _selectedFileName;
  List<Student> _parsedStudents = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = files.first;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر قراءة محتوى الملف المختار أو الملف فارغ';
        });
        return;
      }

      final students = await ExcelStudentImporter.parseStudentsFile(
        bytes: bytes,
        fileName: file.name,
      );

      setState(() {
        _isLoading = false;
        _selectedFileName = file.name;
        _parsedStudents = students;
        if (students.isEmpty) {
          _errorMessage = 'لم يتم العثور على أي سجلات طلاب صالحة داخل الملف. تأكد من تطابق عناوين الأعمدة مع النموذج.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء قراءة الملف: $e';
      });
    }
  }

  Future<void> _downloadSampleTemplate() async {
    try {
      final templateBytes = ExcelStudentImporter.generateTemplateExcel();
      await Printing.sharePdf(
        bytes: templateBytes,
        filename: 'نموذج_استيراد_الطلاب_دوامي.xlsx',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل النموذج: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _confirmImport() async {
    if (_parsedStudents.isEmpty) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<AppRepository>();
      final count = await repo.importStudents(_parsedStudents);

      setState(() {
        _isSaving = false;
        _successMessage = 'تم استيراد وحفظ $count طالباً بنجاح في قاعدة البيانات!';
      });

      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        Navigator.pop(context, count);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'فشل في حفظ بيانات الطلاب: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      child: Container(
        width: isDesktop ? 750 : double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: AppColors.success, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'استيراد بيانات الطلاب من ملف إكسل',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkBlue),
                      ),
                      Text(
                        'يدعم ملفات Microsoft Excel (.xlsx / .xls) وملفات CSV',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Download Template Button Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'للحصول على أفضل نتيجة، يمكنك تحميل نموذج إكسل الجاهز وتعبئته.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('تحميل النموذج التجريبي'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
                    onPressed: _downloadSampleTemplate,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // File Pick Area
            InkWell(
              onTap: _isLoading ? null : _pickFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedFileName != null ? AppColors.success : AppColors.primaryBlue.withAlpha(80),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  children: [
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Icon(
                        _selectedFileName != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                        size: 48,
                        color: _selectedFileName != null ? AppColors.success : AppColors.primaryBlue,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFileName != null
                          ? 'الملف المحدد: $_selectedFileName'
                          : 'اضغط هنا لاختيار ملف إكسل من جهازك (.xlsx, .xls, .csv)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _selectedFileName != null ? AppColors.success : AppColors.darkBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _parsedStudents.isNotEmpty
                          ? 'تم التعرف وقراءة ${_parsedStudents.length} طالباً بنجاح'
                          : 'يقوم النظام تلقائياً بتحديد الأعمدة وتوليد رموز QR والباركود',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // Error Banner
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],

            // Success Banner
            if (_successMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success),
                ),
                child: Text(_successMessage!, style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],

            // Data Preview Table (when parsed)
            if (_parsedStudents.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('معاينة عينة من الطلاب المستخرجين:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
                    child: Text('${_parsedStudents.length} طالباً', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    itemCount: _parsedStudents.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = _parsedStudents[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primaryBlue.withAlpha(30),
                          child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                        ),
                        title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${s.universityId} • ${s.collegeName ?? ''} • ${s.phone}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.success.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                          child: Text(s.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_isSaving ? 'جاري الاستيراد...' : 'تأكيد وحفظ ${_parsedStudents.length} طالباً'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: (_parsedStudents.isEmpty || _isSaving) ? null : _confirmImport,
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
