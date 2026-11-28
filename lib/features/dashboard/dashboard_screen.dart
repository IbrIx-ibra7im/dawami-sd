import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/permissions/role_manager.dart';
import '../../core/utils/student_image_helper.dart';
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
import '../biometric_devices/biometric_devices_screen.dart';
import '../face_attendance/face_attendance_screen.dart';
import '../mobile_attendance/mobile_attendance_screen.dart';
import '../computer_stations/computer_stations_screen.dart';
import '../qr_scanner/qr_terminal_screen.dart';
import 'widgets/photo_verification_dialog.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalStudents = repo.totalStudentsCount;
    final present = repo.presentCount;
    final departed = repo.departedCount;
    final currentlyPresent = repo.currentlyPresentCount;
    final absent = repo.absentCount;
    final late = repo.lateCount;
    final connectedDevices = repo.connectedDevicesCount;
    final disconnectedDevices = repo.disconnectedDevicesCount;
    final fingerprintCount = repo.fingerprintAttendanceCount;
    final faceCount = repo.faceAttendanceCount;
    final mobileCount = repo.mobileAttendanceCount;
    final qrCount = repo.qrAttendanceCount;
    final manualCount = repo.manualAttendanceCount;

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
                // 1. Top Metrics KPI Grid / Rows
                if (isDesktop) ...[
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
                          title: 'منصرف اليوم',
                          value: '$departed',
                          color: Colors.blueGrey,
                          icon: Icons.logout_rounded,
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
                          title: 'الموجودون حالياً',
                          value: '$currentlyPresent',
                          color: AppColors.turquoise,
                          icon: Icons.meeting_room_rounded,
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
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: StatCard(title: 'إجمالي الطلاب', value: '$totalStudents', color: AppColors.primaryBlue, icon: Icons.people_alt_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(title: 'حاضر اليوم', value: '$present', color: AppColors.success, icon: Icons.check_circle_outline)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: StatCard(title: 'الموجودون حالياً', value: '$currentlyPresent', color: AppColors.turquoise, icon: Icons.meeting_room_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(title: 'المنصرفون', value: '$departed', color: Colors.blueGrey, icon: Icons.logout_rounded)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: StatCard(title: 'متأخر', value: '$late', color: AppColors.warning, icon: Icons.access_time_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(title: 'غائب', value: '$absent', color: AppColors.danger, icon: Icons.cancel_outlined)),
                    ],
                  ),
                ],

                const SizedBox(height: 18),

                // Biometric Devices Status Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint_rounded, color: AppColors.primaryBlue, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'حالة أجهزة البصمة الحيوية:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BiometricDevicesScreen()),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
                            ),
                            const SizedBox(width: 6),
                            Text('$connectedDevices جهاز متصل', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 12)),
                            const SizedBox(width: 16),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger),
                            ),
                            const SizedBox(width: 6),
                            Text('$disconnectedDevices غير متصل', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 12)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

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
                        child: _buildMethodBreakdownCard(
                          fingerprintCount: fingerprintCount,
                          faceCount: faceCount,
                          mobileCount: mobileCount,
                          qrCount: qrCount,
                          manualCount: manualCount,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildMethodBreakdownCard(
                    fingerprintCount: fingerprintCount,
                    faceCount: faceCount,
                    mobileCount: mobileCount,
                    qrCount: qrCount,
                    manualCount: manualCount,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  _buildCollegeChartCard(isDark, repo),
                ],

                const SizedBox(height: 24),

                // 3. Live Attendance Photos & Liveness Verification Section
                _buildRecentAttendancePhotosSection(context, isDark, repo, isDesktop),

                const SizedBox(height: 28),

                // 4. Responsive Action Buttons (Desktop, Tablet & Mobile Optimized)
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
        title: 'إدارة أجهزة البصمة',
        subtitle: 'أجهزة ZKTeco و Anviz المتعددة',
        icon: Icons.settings_remote_rounded,
        color: AppColors.turquoise,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BiometricDevicesScreen()),
          );
        },
      ),
      _ActionData(
        title: 'الحضور بالكاميرا والوجه',
        subtitle: 'التعرف على الوجه مع كشف الحيوية',
        icon: Icons.face_retouching_natural_rounded,
        color: AppColors.primaryBlue,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FaceAttendanceScreen()),
          );
        },
      ),
      _ActionData(
        title: 'حضور هاتف الطالب',
        subtitle: 'اقتران الهاتف والنطاق الجغرافي GPS',
        icon: Icons.smartphone_rounded,
        color: Colors.green,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MobileAttendanceScreen()),
          );
        },
      ),
      _ActionData(
        title: 'محطة الباركود وQR',
        subtitle: 'مسح الكاميرا وقارئات USB السلكية',
        icon: Icons.qr_code_scanner_rounded,
        color: Colors.indigo,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QrTerminalScreen()),
          );
        },
      ),
      _ActionData(
        title: 'محطات الكمبيوتر',
        subtitle: 'ربط الحواسيب والملحقات بالكلية',
        icon: Icons.computer_rounded,
        color: Colors.deepOrange,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ComputerStationsScreen()),
          );
        },
      ),
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

  Widget _buildRecentAttendancePhotosSection(
    BuildContext context,
    bool isDark,
    AppRepository repo,
    bool isDesktop,
  ) {
    final recentRecords = repo.todayAttendance.take(8).toList();
    final studentsMap = {for (var s in repo.students) s.id: s};
    final studentsByUniId = {for (var s in repo.students) s.universityId: s};

    final hasRecords = recentRecords.isNotEmpty;
    final displayItemsCount = hasRecords ? recentRecords.length : math.min(6, repo.students.length);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.camera_front_rounded,
                      color: AppColors.primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'أحدث سجلات الحضور وفحص صحة وحيوية الصور',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'معاينة مصغرة للصور المعتمدة | انقر على أي صورة لتكبيرها وفحص حيوية الوجه والأصالة',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('كافة السجلات', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (displayItemsCount == 0)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.face_retouching_natural_rounded, size: 48, color: Colors.grey.withAlpha(100)),
                  const SizedBox(height: 10),
                  const Text(
                    'لا توجد سجلات حضور بالصور حتى الآن اليوم',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'قم بتسجيل حضور الطلاب عبر كاميرا الوجه أو البصمة لتظهر صورهم وتدقيق الحيوية هنا',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = isDesktop ? ((constraints.maxWidth - 42) / 4) : ((constraints.maxWidth - 14) / 2);

                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: List.generate(displayItemsCount, (index) {
                    final dynamic studentObj;
                    String studentName;
                    String uniId;
                    String time;
                    String method;
                    String status;

                    if (hasRecords) {
                      final r = recentRecords[index];
                      final s = studentsMap[r.studentId] ?? (r.universityId != null ? studentsByUniId[r.universityId] : null);
                      studentObj = s;
                      studentName = r.studentName ?? s?.fullName ?? 'طالب';
                      uniId = r.universityId ?? s?.universityId ?? '-';
                      time = r.attendanceTime.isNotEmpty ? r.attendanceTime : 'اليوم';
                      method = r.methodDisplayName;
                      status = r.status;
                    } else {
                      final s = repo.students[index];
                      studentObj = s;
                      studentName = s.fullName;
                      uniId = s.universityId;
                      time = 'ملف مسجل';
                      method = s.attendanceMethodDisplay;
                      status = s.status;
                    }

                    final photo = (studentObj?.photoUrl != null && (studentObj.photoUrl as String).isNotEmpty)
                        ? (studentObj.photoUrl as String)
                        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(studentName)}&background=0D8ABC&color=fff&size=256';

                    return SizedBox(
                      width: math.max(160, cardWidth),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            PhotoVerificationDialog.show(
                              context,
                              photoUrl: photo,
                              studentName: studentName,
                              universityId: uniId,
                              collegeName: studentObj?.collegeName,
                              departmentName: studentObj?.departmentName,
                              attendanceTime: time,
                              attendanceMethod: method,
                              actionType: status,
                              livenessScore: 0.98,
                              isEnrolledFace: studentObj?.faceRegistered ?? true,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBg : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Thumbnail with Verification Dot
                                Stack(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue.withAlpha(20),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primaryBlue, width: 2),
                                        image: StudentImageHelper.getImageProvider(photo, studentName: studentName) != null
                                            ? DecorationImage(
                                                image: StudentImageHelper.getImageProvider(photo, studentName: studentName)!,
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.verified_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  studentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  uniId,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                // Liveness verification pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withAlpha(15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.success.withAlpha(40)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 10, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text(
                                        'حقيقية وموثقة',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
        ],
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

  Widget _buildMethodBreakdownCard({
    required int fingerprintCount,
    required int faceCount,
    required int mobileCount,
    required int qrCount,
    required int manualCount,
    required bool isDark,
  }) {
    final total = fingerprintCount + faceCount + mobileCount + qrCount + manualCount;

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
            'وسائل تسجيل الحضور المعتمدة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'إجمالي الحركات اليوم: $total حركة حضور وانصراف',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          _buildMethodRowItem('بصمة الإصبع (أجهزة البصمة)', fingerprintCount, total, AppColors.turquoise, Icons.fingerprint_rounded),
          const SizedBox(height: 8),
          _buildMethodRowItem('التعرف على الوجه والكاميرا', faceCount, total, AppColors.primaryBlue, Icons.face_retouching_natural_rounded),
          const SizedBox(height: 8),
          _buildMethodRowItem('تطبيق هاتف الطالب (GPS)', mobileCount, total, Colors.green, Icons.smartphone_rounded),
          const SizedBox(height: 8),
          _buildMethodRowItem('الباركود ورموز QR الذكية', qrCount, total, Colors.indigo, Icons.qr_code_rounded),
          const SizedBox(height: 8),
          _buildMethodRowItem('تسجيل إداري استثنائي', manualCount, total, Colors.amber.shade800, Icons.admin_panel_settings_rounded),
        ],
      ),
    );
  }

  Widget _buildMethodRowItem(String title, int count, int total, Color color, IconData icon) {
    final pct = total > 0 ? ((count / total) * 100).toInt() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('$pct% من إجمالي الحركات', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            '$count',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
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
