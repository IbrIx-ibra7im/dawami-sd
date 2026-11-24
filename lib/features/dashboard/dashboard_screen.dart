import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/permissions/role_manager.dart';
import '../../data/repositories/app_repository.dart';
import '../../widgets/custom_widgets.dart';

import '../students/students_list_screen.dart';
import '../students/student_credentials_screen.dart';
import '../students/import_students_dialog.dart';
import '../attendance/attendance_list_screen.dart';
import '../reports/reports_screen.dart';
import '../attendance/audit_logs_screen.dart';
import '../authentication/login_screen.dart';
import '../fingerprint/fingerprint_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalStudents = repo.totalStudentsCount;
    final present = repo.presentCount;
    final absent = repo.absentCount;
    final late = repo.lateCount;
    final fingerprintCount = repo.fingerprintAttendanceCount;
    final qrCount = repo.qrAttendanceCount;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('لوحة التحكم والإحصائيات'),
        backgroundColor: AppColors.darkBlue,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.turquoise.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  RoleManager.getRoleDisplayName(repo.currentRole),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _confirmLogout(context, repo),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 28 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Metrics KPI Row (Responsive: 4 columns on Desktop, 2x2 on Mobile/Tablet)
                if (isDesktop)
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'إجمالي الطلاب',
                          value: '$totalStudents',
                          color: AppColors.primaryBlue,
                          icon: Icons.people_alt_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StudentsListScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: StatCard(
                          title: 'حاضر اليوم',
                          value: '$present',
                          color: AppColors.success,
                          icon: Icons.check_circle_outline,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: StatCard(
                          title: 'متأخر اليوم',
                          value: '$late',
                          color: AppColors.warning,
                          icon: Icons.access_time_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: StatCard(
                          title: 'غائب اليوم',
                          value: '$absent',
                          color: AppColors.danger,
                          icon: Icons.cancel_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'إجمالي الطلاب',
                          value: '$totalStudents',
                          color: AppColors.primaryBlue,
                          icon: Icons.people_alt_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StudentsListScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'حاضر',
                          value: '$present',
                          color: AppColors.success,
                          icon: Icons.check_circle_outline,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'متأخر',
                          value: '$late',
                          color: AppColors.warning,
                          icon: Icons.access_time_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'غائب',
                          value: '$absent',
                          color: AppColors.danger,
                          icon: Icons.cancel_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // 2. Statistics & Analytics (Bar Chart & Comparison)
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bar Chart: Attendance by Department (Flex 3)
                      Expanded(
                        flex: 3,
                        child: _buildCollegeChartCard(isDark, repo),
                      ),
                      const SizedBox(width: 20),
                      // Attendance Method Breakdown Panel (Flex 2)
                      Expanded(
                        flex: 2,
                        child: _buildMethodBreakdownCard(fingerprintCount, qrCount, isDark),
                      ),
                    ],
                  )
                else ...[
                  // Comparison row on mobile
                  Row(
                    children: [
                      Expanded(child: _buildMethodChip('بالبصمة', fingerprintCount, AppColors.turquoise, Icons.fingerprint, isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMethodChip('بالباركود / QR', qrCount, AppColors.primaryBlue, Icons.qr_code, isDark)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildCollegeChartCard(isDark, repo),
                ],

                const SizedBox(height: 28),

                // 3. Responsive Action Buttons (Desktop, Tablet & Mobile Optimized)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الإدارة والعمليات السريعة',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    Text(
                      'متوافق بالكامل مع شاشات الكمبيوتر والأجهزة اللوحية',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // The Action Grid with fixed mainAxisExtent: 84px to prevent oversized balloon buttons
                _buildResponsiveActionGrid(context, constraints.maxWidth, isDark, repo),

                const SizedBox(height: 28),

                // 4. Logout / Session Actions Bar (Cleanly centered & constrained on PC)
                Center(
                  child: SizedBox(
                    width: isDesktop ? 340 : double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text('تسجيل الخروج من لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1,
                      ),
                      onPressed: () => _confirmLogout(context, repo),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveActionGrid(BuildContext context, double maxWidth, bool isDark, AppRepository repo) {
    final int crossAxisCount = maxWidth >= 1150
        ? 4
        : (maxWidth >= 750 ? 3 : 2);

    final actions = [
      _ActionData(
        title: 'إدارة الطلاب',
        subtitle: 'عرض وتعديل وحذف الطلاب',
        icon: Icons.people_alt_outlined,
        color: AppColors.primaryBlue,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentsListScreen()),
          );
        },
      ),
      _ActionData(
        title: 'بصمات وبطاقات QR',
        subtitle: 'طباعة البطاقات وتوليد الأكواد',
        icon: Icons.badge_outlined,
        color: Colors.indigo,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentCredentialsScreen()),
          );
        },
      ),
      _ActionData(
        title: 'تسجيل البصمة الحيوية',
        subtitle: 'أجهزة ZK والبصمة المعتمدة',
        icon: Icons.fingerprint_rounded,
        color: AppColors.turquoise,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FingerprintScreen()),
          );
        },
      ),
      _ActionData(
        title: 'سجل الحضور والانصراف',
        subtitle: 'متابعة أوقات الحضور والانصراف',
        icon: Icons.list_alt_rounded,
        color: Colors.teal,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
          );
        },
      ),
      _ActionData(
        title: 'التقارير الرسمية والطباعة',
        subtitle: 'تصدير مستندات PDF و Excel',
        icon: Icons.picture_as_pdf_outlined,
        color: AppColors.success,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsScreen()),
          );
        },
      ),
      _ActionData(
        title: 'سجل التعديلات (Audit)',
        subtitle: 'تتبع كافة الحركات بأمان',
        icon: Icons.history_rounded,
        color: Colors.purple,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
          );
        },
      ),
      _ActionData(
        title: 'رفع ملف إكسل للطلاب',
        subtitle: 'استيراد سريع وفوري للبيانات',
        icon: Icons.upload_file_rounded,
        color: Colors.blueGrey,
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => const ImportStudentsDialog(),
          );
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 84, // FIXED HEIGHT: Stops buttons from growing to 400px!
      ),
      itemBuilder: (context, index) {
        final a = actions[index];
        return _buildActionTile(
          title: a.title,
          subtitle: a.subtitle,
          icon: a.icon,
          color: a.color,
          onTap: a.onTap,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: color.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : color.withAlpha(50),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : AppColors.darkBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: color.withAlpha(140),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollegeChartCard(bool isDark, AppRepository repo) {
    // 5 Departments of the Faculty of Computer Science & Human Development
    // 1: علوم الحاسوب, 2: تقنية المعلومات, 3: نظم المعلومات, 4: التنمية البشرية وتطبيقات الحاسوب, 5: هندسة البرمجيات
    final attendedIds = repo.todayAttendance
        .where((a) => a.status == 'حاضر' || a.status == 'متأخر' || a.status == 'تم الانصراف')
        .map((a) => a.studentId)
        .toSet();

    final pcts = <double>[];
    for (int deptId = 1; deptId <= 5; deptId++) {
      final deptStudents = repo.students.where((s) => s.departmentId == deptId).toList();
      if (deptStudents.isNotEmpty && attendedIds.isNotEmpty) {
        final presentCount = deptStudents.where((s) => attendedIds.contains(s.id)).length;
        final pct = (presentCount / deptStudents.length * 100);
        pcts.add(pct);
      } else {
        pcts.add(0.0);
      }
    }

    return Container(
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
          const Text(
            'الحضور حسب الأقسام الأكاديمية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'نسب الحضور المسجلة للطلاب في أقسام كلية علوم الحاسوب والتنمية البشرية',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}%',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        switch (val.toInt()) {
                          case 0:
                            return const Text('علوم الحاسوب', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
                          case 1:
                            return const Text('تقنية معلومات', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
                          case 2:
                            return const Text('نظم معلومات', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
                          case 3:
                            return const Text('تنمية بشرية', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
                          case 4:
                            return const Text('هندسة برمجيات', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _buildBarGroup(0, pcts[0], AppColors.primaryBlue),
                  _buildBarGroup(1, pcts[1], AppColors.turquoise),
                  _buildBarGroup(2, pcts[2], AppColors.success),
                  _buildBarGroup(3, pcts[3], AppColors.warning),
                  _buildBarGroup(4, pcts[4], AppColors.primaryBlueLight),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodBreakdownCard(int fingerprintCount, int qrCount, bool isDark) {
    final total = fingerprintCount + qrCount;
    final fpPercent = total > 0 ? ((fingerprintCount / total) * 100).toInt() : 0;
    final qrPercent = total > 0 ? ((qrCount / total) * 100).toInt() : 0;

    return Container(
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
          const Text(
            'وسائل تسجيل الحضور',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'إجمالي الحركات اليوم: $total حركة حضور',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Fingerprint channel
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.turquoise.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.turquoise.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint, color: AppColors.turquoise, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بالبصمة الحيوية (ZKTeco)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('$fpPercent% من إجمالي الحضور اليوم', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  '$fingerprintCount',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.turquoise),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // QR Code channel
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code, color: AppColors.primaryBlue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بالباركود وبطاقة الطالب (QR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('$qrPercent% من إجمالي الحضور اليوم', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  '$qrCount',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodChip(String title, int count, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 20,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, AppRepository repo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج من لوحة التحكم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              repo.logout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تسجيل الخروج بنجاح'),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
