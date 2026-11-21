import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/local/database_helper.dart';

class LecturesListScreen extends StatelessWidget {
  const LecturesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lectures = repo.lectures;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('إدارة المحاضرات والجلسات'),
        backgroundColor: AppColors.darkBlue,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: lectures.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final l = lectures[index];
          final isActive = repo.activeSession?.lectureId == l.id;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? AppColors.primaryBlue : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l.courseName ?? 'مقرر'} (${l.courseCode ?? ''})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'جلسة نشطة',
                          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('المحاضر: ${l.instructor} • القاعة: ${l.classroomName ?? 'قاعة'}'),
                const SizedBox(height: 4),
                Text(
                  'اليوم: ${l.day} • التوقيت: ${l.startTime} إلى ${l.endTime} (السماح: ${l.graceMinutes} دقيقة)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                if (!isActive)
                  ElevatedButton(
                    onPressed: () async {
                      final db = await DatabaseHelper.instance.database;
                      await db.insert('attendance_sessions', {
                        'lecture_id': l.id,
                        'session_date': DateTime.now().toIso8601String().substring(0, 10),
                        'status': 'نشطة',
                      });
                      await repo.loadInitialData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم بدء جلسة حضور جديدة لمحاضرة: ${l.courseName}')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('بدء جلسة حضور لهذه المحاضرة'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

