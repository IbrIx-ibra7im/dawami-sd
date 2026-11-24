import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_helper.dart';
import '../../data/repositories/app_repository.dart';
import '../../widgets/custom_widgets.dart';

import '../fingerprint/fingerprint_screen.dart';

class DesktopHomeContent extends StatelessWidget {
  final Function(int) onNavigate;

  const DesktopHomeContent({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recentRecords = repo.todayAttendance.take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Desktop Welcome & University Banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.darkBlue, AppColors.primaryBlue],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBlue.withAlpha(50),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, size: 44, color: Colors.white),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحباً بك في ${AppStrings.appName} - ${AppStrings.systemTitle}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${repo.universityName} • ${AppStrings.systemSubtitle}',
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Today's Live Date Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        DateHelper.formatFullDate(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Desktop 4-Column KPI Stats Grid
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'إجمالي الطلاب المسجلين',
                  value: '${repo.totalStudentsCount}',
                  color: AppColors.primaryBlue,
                  icon: Icons.people_alt_rounded,
                  onTap: () => onNavigate(4), // Students
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'الحاضرون اليوم',
                  value: '${repo.presentCount}',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                  onTap: () => onNavigate(3), // Attendance
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'المتأخرون اليوم',
                  value: '${repo.lateCount}',
                  color: AppColors.warning,
                  icon: Icons.access_time_rounded,
                  onTap: () => onNavigate(3), // Attendance
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'الغائبون اليوم',
                  value: '${repo.absentCount}',
                  color: AppColors.danger,
                  icon: Icons.cancel_outlined,
                  onTap: () => onNavigate(3), // Attendance
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Large Action Hero Card (Desktop Fingerprint Attendance)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.turquoise.withAlpha(20),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.turquoise.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.fingerprint_rounded, color: AppColors.turquoise, size: 40),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تسجيل الحضور بالبصمة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'جهاز البصمة المتصل: ${repo.deviceName} • متوافق مع أجهزة ZKTeco وأجهزة البصمة المعتمدة مع مطابقة المعرف الرقمي للبصمة مباشرة.',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.touch_app),
                  label: const Text('فتح واجهة قراءة البصمة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.turquoise,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FingerprintScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Active Lecture Banner & Manual Attendance Trigger
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, color: AppColors.primaryBlue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'جلسة المحاضرة النشطة حالياً:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${repo.activeSession?.lectureName ?? 'برمجة 1'} — ${repo.activeSession?.classroomName ?? 'قاعة 3'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      if (repo.activeSession?.instructor != null)
                        Text(
                          'المحاضر: ${repo.activeSession!.instructor}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.list_alt),
                  label: const Text('عرض السجل الكامل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () => onNavigate(3),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 5. Recent Attendance Records Table (Desktop View)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'آخر عمليات الحضور المسجلة اليوم',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('عرض جميع السجلات'),
                      onPressed: () => onNavigate(3),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (recentRecords.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('لا توجد عمليات حضور مسجلة اليوم حتى الآن'),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 800),
                      child: DataTable(
                        columnSpacing: 28,
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.primaryBlue.withAlpha(15),
                        ),
                        columns: const [
                          DataColumn(label: Text('اسم الطالب', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الرقم الجامعي', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('طريقة الحضور', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('وقت الحضور', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('وقت الانصراف', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: recentRecords.map((r) {
                          final method = r.method == 'qr'
                              ? 'QR Code'
                              : (r.method == 'fingerprint' ? 'بصمة' : 'يدوي');
                          final inTime = DateHelper.formatTimeString(r.checkIn);
                          final outTime = r.checkOut != null ? DateHelper.formatTimeString(r.checkOut) : null;
                          return DataRow(cells: [
                            DataCell(Text(r.studentName ?? 'طالب')),
                            DataCell(Text(r.universityId ?? '-')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  r.method == 'qr' ? Icons.qr_code : (r.method == 'fingerprint' ? Icons.fingerprint : Icons.edit_note),
                                  size: 16,
                                  color: AppColors.primaryBlue,
                                ),
                                const SizedBox(width: 6),
                                Text(method),
                              ],
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.login_rounded, size: 14, color: AppColors.success),
                                const SizedBox(width: 4),
                                Text(inTime, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  outTime != null ? Icons.logout_rounded : Icons.timelapse_rounded,
                                  size: 14,
                                  color: outTime != null ? AppColors.primaryBlue : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  outTime ?? 'جاري الدوام',
                                  style: TextStyle(
                                    color: outTime != null ? AppColors.darkBlue : Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: outTime != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            )),
                            DataCell(StatusBadge.fromStatus(r.status)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
