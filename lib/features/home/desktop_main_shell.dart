import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/permissions/role_manager.dart';
import '../../data/repositories/app_repository.dart';

import 'desktop_home_content.dart';
import '../dashboard/dashboard_screen.dart';
import '../qr_scanner/qr_scanner_screen.dart';
import '../fingerprint/fingerprint_screen.dart';
import '../attendance/attendance_list_screen.dart';
import '../students/students_list_screen.dart';
import '../students/student_credentials_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../authentication/login_screen.dart';

class DesktopMainShell extends StatefulWidget {
  const DesktopMainShell({super.key});

  @override
  State<DesktopMainShell> createState() => _DesktopMainShellState();
}

class _DesktopMainShellState extends State<DesktopMainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    if (!repo.isLoggedIn) {
      return const LoginScreen();
    }

    final connectivity = context.watch<ConnectivityService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isOnline = connectivity.isOnline;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Row(
        children: [
          // 1. Right Desktop Sidebar (RTL Navigation)
          Container(
            width: 270,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              border: Border(
                left: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 10,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Brand Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.darkBlue, AppColors.primaryBlue],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '${AppStrings.appName} - ${AppStrings.systemTitle}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${repo.universityName} • ${AppStrings.systemSubtitle}',
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // System Status Indicator Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Connectivity
                      InkWell(
                        onTap: () => connectivity.setOnlineState(!connectivity.isOnline),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline ? AppColors.success : AppColors.danger,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? 'متصل' : 'أوفلاين',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOnline ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Auto-Sync Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.turquoise.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'مزامنة تلقائية نشطة',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.turquoise,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Navigation Items List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    children: [
                      _buildNavItem(0, 'الرئيسية', Icons.home_rounded),
                      _buildNavItem(1, 'لوحة التحكم والإحصائيات', Icons.dashboard_rounded),
                      _buildNavItem(2, 'تسجيل الحضور بـ QR', Icons.qr_code_scanner_rounded),
                      _buildNavItem(3, 'تسجيل الحضور بالبصمة', Icons.fingerprint_rounded),
                      _buildNavItem(4, 'سجل الحضور', Icons.list_alt_rounded),
                      _buildNavItem(5, 'إدارة الطلاب', Icons.people_alt_rounded),
                      _buildNavItem(6, 'بصمات وبطاقات الطلاب (QR)', Icons.badge_rounded),
                      _buildNavItem(7, 'التقارير الرسمية والطباعة', Icons.picture_as_pdf_rounded),
                      _buildNavItem(8, 'الإعدادات العامة', Icons.settings_rounded),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Footer Profile Card
                Container(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryBlue.withAlpha(25),
                        child: Text(
                          repo.currentUser.fullName.isNotEmpty ? repo.currentUser.fullName[0] : 'م',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repo.currentUser.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              repo.currentUser.email,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<UserRole>(
                        icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.primaryBlue),
                        tooltip: 'تبديل الدور (مدير / مسجل / مشرف)',
                        onSelected: (role) {
                          repo.switchUserRole(role);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم تبديل المستخدم الحالي إلى: ${RoleManager.getRoleDisplayName(role)}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: UserRole.superAdmin,
                            child: Row(
                              children: [
                                Icon(Icons.admin_panel_settings_rounded, color: AppColors.primaryBlue, size: 18),
                                SizedBox(width: 8),
                                Text('مدير (كامل الصلاحيات)'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: UserRole.registrationStaff,
                            child: Row(
                              children: [
                                Icon(Icons.app_registration_rounded, color: AppColors.primaryBlue, size: 18),
                                SizedBox(width: 8),
                                Text('مسجل (إدارة وتسجيل الطلاب)'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: UserRole.supervisor,
                            child: Row(
                              children: [
                                Icon(Icons.visibility_rounded, color: AppColors.primaryBlue, size: 18),
                                SizedBox(width: 8),
                                Text('مشرف (متابعة الحضور والتقارير)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.manage_accounts_outlined, size: 20),
                        tooltip: 'تغيير الدور / تسجيل الدخول',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
                        tooltip: 'تسجيل الخروج',
                        onPressed: () => _confirmLogout(context, repo),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Desktop Canvas View
          Expanded(
            child: _buildCurrentDesktopView(_selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, {int? badgeCount}) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedIndex = index);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryBlue.withAlpha(25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: AppColors.primaryBlue.withAlpha(60))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryBlue
                          : (isDark ? Colors.white : AppColors.textPrimaryLight),
                    ),
                  ),
                ),
                if (badgeCount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentDesktopView(int index) {
    switch (index) {
      case 0:
        return DesktopHomeContent(
          onNavigate: (newIndex) {
            setState(() => _selectedIndex = newIndex);
          },
        );
      case 1:
        return const DashboardScreen();
      case 2:
        return const QrScannerScreen();
      case 3:
        return const FingerprintScreen();
      case 4:
        return const AttendanceListScreen();
      case 5:
        return const StudentsListScreen();
      case 6:
        return const StudentCredentialsScreen();
      case 7:
        return const ReportsScreen();
      case 8:
        return const SettingsScreen();
      default:
        return DesktopHomeContent(
          onNavigate: (newIndex) {
            setState(() => _selectedIndex = newIndex);
          },
        );
    }
  }

  void _confirmLogout(BuildContext context, AppRepository repo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج من النظام؟'),
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
                MaterialPageRoute(builder: (_) => const FingerprintScreen(isInitialScreen: true)),
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
