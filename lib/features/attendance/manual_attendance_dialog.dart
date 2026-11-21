import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';

class ManualAttendanceDialog extends StatefulWidget {
  const ManualAttendanceDialog({super.key});

  @override
  State<ManualAttendanceDialog> createState() => _ManualAttendanceDialogState();
}

class _ManualAttendanceDialogState extends State<ManualAttendanceDialog> {
  int? _selectedStudentId;
  String _status = 'حاضر'; // 'حاضر', 'متأخر', 'غائب'
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final students = repo.students.where((s) => s.status == 'نشط').toList();
    final validIds = students.map((s) => s.id).whereType<int>().toSet();
    final effectiveStudentId = validIds.contains(_selectedStudentId) ? _selectedStudentId : null;

    return AlertDialog(
      title: const Text('تسجيل حضور يدوي'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر الطالب لتسجيل حضوره أو غيابه يدوياً بواسطة الموظف المخوّل:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Select Student Dropdown
            DropdownButtonFormField<int>(
              initialValue: effectiveStudentId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اسم الطالب *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: students.map((s) {
                return DropdownMenuItem<int>(
                  value: s.id,
                  child: Text('${s.fullName} (${s.universityId})', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedStudentId = val);
              },
            ),

            const SizedBox(height: 16),

            // Select Status
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'الحالة',
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
              items: const [
                DropdownMenuItem(value: 'حاضر', child: Text('حاضر (تسجيل حضور)')),
                DropdownMenuItem(value: 'انصراف', child: Text('انصراف (تسجيل انصراف)')),
                DropdownMenuItem(value: 'متأخر', child: Text('متأخر')),
                DropdownMenuItem(value: 'غائب', child: Text('غائب (غير حاضر)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: effectiveStudentId == null || _isSaving
              ? null
              : () => _submit(students.firstWhere((s) => s.id == effectiveStudentId)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('تسجيل الآن', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _submit(Student targetStudent) async {
    setState(() => _isSaving = true);
    try {
      final repo = context.read<AppRepository>();
      final record = await repo.registerAttendance(
        student: targetStudent,
        method: 'manual',
        customStatus: _status,
      );

      final inTime = DateHelper.formatTimeString(record.checkIn);
      final outTime = record.checkOut != null ? DateHelper.formatTimeString(record.checkOut) : null;
      final msg = record.checkOut != null
          ? 'تم تسجيل انصراف الطالب ${targetStudent.fullName} (حضور: $inTime | انصراف: $outTime)'
          : 'تم تسجيل حضور الطالب ${targetStudent.fullName} (في تمام $inTime)';

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

