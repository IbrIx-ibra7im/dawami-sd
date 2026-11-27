import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/permissions/role_manager.dart';
import '../../core/services/update_service.dart';
import '../../data/models/update_info.dart';
import '../../data/repositories/app_repository.dart';
import '../authentication/login_screen.dart';
import 'widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _uniController;
  bool _isCheckingUpdate = false;
  bool _autoCheckUpdates = true;
  String _currentAppVersion = '1.1.0';

  @override
  void initState() {
    super.initState();
    final repo = context.read<AppRepository>();
    _uniController = TextEditingController(text: repo.universityName);
    _loadUpdatePreferences();
  }

  Future<void> _loadUpdatePreferences() async {
    final autoCheck = await UpdateService.instance.isAutoCheckEnabled();
    final version = await UpdateService.instance.getCurrentVersion();
    if (mounted) {
      setState(() {
        _autoCheckUpdates = autoCheck;
        _currentAppVersion = version;
      });
    }
  }

  Future<void> _checkUpdatesManually() async {
    setState(() {
      _isCheckingUpdate = true;
    });

    final result = await UpdateService.instance.checkForUpdate();

    if (!mounted) return;

    setState(() {
      _isCheckingUpdate = false;
    });

    if (result.status == UpdateCheckStatus.updateAvailable && result.releaseInfo != null) {
      UpdateDialog.show(
        context,
        currentVersion: result.currentVersion,
        releaseInfo: result.releaseInfo!,
      );
    } else if (result.status == UpdateCheckStatus.upToDate || result.status == UpdateCheckStatus.noReleases) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
              SizedBox(width: 8),
              Text('أنت تستخدم أحدث إصدار'),
            ],
          ),
          content: Text(
            'أنت تستخدم أحدث إصدار من تطبيق دوامي (الإصدار ${result.currentVersion}).\nلم يتم نشر أي تحديثات جديدة بعد على مستودع GitHub.',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.status == UpdateCheckStatus.offline ? AppColors.warning : AppColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _uniController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('إعدادات النظام'),
        backgroundColor: AppColors.darkBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // University Settings
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
                  const Text('بيانات المؤسسة الجامعية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _uniController,
                    decoration: const InputDecoration(labelText: 'اسم الجامعة / الكلية'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await repo.updateUniversityName(_uniController.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم حفظ اسم الجامعة بنجاح'), backgroundColor: AppColors.success),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                    child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Attendance Methods Configuration (Admin Control)
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppColors.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'إدارة وتفعيل وسائل الحضور (خاص بالمسؤول)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'يمكن للمدير تفعيل أو إيقاف أي طريقة لتسجيل الحضور، بحيث تختفي تماماً من شاشة تسجيل الحضور والانصراف عند إيقافها:',
                    style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: repo.isFingerprintEnabled ? AppColors.turquoise.withAlpha(15) : Colors.grey.withAlpha(15),
                    secondary: Icon(
                      Icons.fingerprint_rounded,
                      color: repo.isFingerprintEnabled ? AppColors.turquoise : Colors.grey,
                      size: 28,
                    ),
                    title: const Text(
                      'تسجيل الحضور بالبصمة الحيوية',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      repo.isFingerprintEnabled
                          ? 'مفعلة وتظهر في شاشة تسجيل الحضور والانصراف'
                          : 'معطلة ومخفية تماماً من شاشة الحضور',
                      style: TextStyle(
                        fontSize: 12,
                        color: repo.isFingerprintEnabled ? AppColors.turquoise : Colors.grey,
                      ),
                    ),
                    value: repo.isFingerprintEnabled,
                    // ignore: deprecated_member_use
                    activeColor: AppColors.turquoise,
                    onChanged: (val) async {
                      try {
                        await repo.toggleFingerprintMethod(val);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val ? 'تم تفعيل البصمة وإظهارها في شاشة الحضور' : 'تم إيقاف وإخفاء البصمة من شاشة الحضور'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: repo.isBarcodeEnabled ? Colors.purple.withAlpha(15) : Colors.grey.withAlpha(15),
                    secondary: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: repo.isBarcodeEnabled ? Colors.purple : Colors.grey,
                      size: 28,
                    ),
                    title: const Text(
                      'تسجيل الحضور بالباركود وبطاقة الطالب',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      repo.isBarcodeEnabled
                          ? 'مفعلة وتظهر في شاشة تسجيل الحضور والكاميرا'
                          : 'معطلة ومخفية تماماً من شاشة الحضور',
                      style: TextStyle(
                        fontSize: 12,
                        color: repo.isBarcodeEnabled ? Colors.purple : Colors.grey,
                      ),
                    ),
                    value: repo.isBarcodeEnabled,
                    // ignore: deprecated_member_use
                    activeColor: Colors.purple,
                    onChanged: (val) async {
                      try {
                        await repo.toggleBarcodeMethod(val);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val ? 'تم تفعيل الباركود وإظهاره في شاشة الحضور' : 'تم إيقاف وإخفاء الباركود من شاشة الحضور'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: repo.isFaceEnabled ? AppColors.darkBlue.withAlpha(15) : Colors.grey.withAlpha(15),
                    secondary: Icon(
                      Icons.face_rounded,
                      color: repo.isFaceEnabled ? AppColors.primaryBlue : Colors.grey,
                      size: 28,
                    ),
                    title: const Text(
                      'تسجيل الحضور بالتعرف على الوجه (بصمة الوجه)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      repo.isFaceEnabled
                          ? 'مفعلة وتظهر في شاشة تسجيل الحضور والكاميرا المباشرة'
                          : 'معطلة ومخفية تماماً من شاشة الحضور',
                      style: TextStyle(
                        fontSize: 12,
                        color: repo.isFaceEnabled ? AppColors.primaryBlue : Colors.grey,
                      ),
                    ),
                    value: repo.isFaceEnabled,
                    // ignore: deprecated_member_use
                    activeColor: AppColors.primaryBlue,
                    onChanged: (val) async {
                      try {
                        await repo.toggleFaceMethod(val);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val ? 'تم تفعيل بصمة الوجه وإظهارها في شاشة الحضور' : 'تم إيقاف وإخفاء بصمة الوجه من شاشة الحضور'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Supabase Cloud Built-in Integration Status (Permanently linked in code)
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.turquoise.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.cloud_done_rounded, color: AppColors.turquoise, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'الربط السحابي (Supabase)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success.withAlpha(60)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'مربوط برمجياً في الكود',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تم ربط وتضمين مشروع Supabase مباشرة في الكود المصدري للتطبيق، ويتم الاتصال تلقائياً عند الإقلاع دون الحاجة لأي مفاتيح أو إدخال يدوي داخل التطبيق.',
                    style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 18, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        const Text(
                          'معرّف المشروع: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            ApiConstants.defaultSupabaseUrl,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Backup Database info (Hive)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storage_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'قاعدة البيانات الاحتياطية: Hive Local DB',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                              ),
                              Text(
                                'نسخة احتياطية محلية فورية (${repo.backupAttendanceCount} سجل حضور • ${repo.backupStudentsCount} طالب)',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Theme Setting
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: SwitchListTile(
                title: const Text('الوضع الليلي (Dark Mode)'),
                value: repo.isDarkMode,
                onChanged: (val) => repo.toggleTheme(val),
              ),
            ),

            const SizedBox(height: 20),

            // GitHub Releases & In-App Updates Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.system_update_rounded, color: AppColors.primaryBlue, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'تحديثات التطبيق (GitHub)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.turquoise.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.turquoise.withAlpha(60)),
                        ),
                        child: Text(
                          'الإصدار المثبت: v$_currentAppVersion',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'التحقق المباشر من التحديثات والإصدارات الجديدة المنشورة على مستودع GitHub الرسمي مع إمكانية تنزيل وتثبيت أحدث حزمة APK مباشرة.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'التحقق التلقائي عند بدء التشغيل',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'تنبيهك بهدوء عند فتح التطبيق إذا كان هناك إصدار جديد متوفر',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: _autoCheckUpdates,
                    // ignore: deprecated_member_use
                    activeColor: AppColors.primaryBlue,
                    onChanged: (val) async {
                      setState(() {
                        _autoCheckUpdates = val;
                      });
                      await UpdateService.instance.setAutoCheckEnabled(val);
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isCheckingUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        _isCheckingUpdate ? 'جاري الفحص...' : 'البحث عن تحديثات الآن',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isCheckingUpdate ? null : _checkUpdatesManually,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Account & Session Control
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'حساب المستخدم والجلسة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
                        ),
                        child: Text(
                          RoleManager.getRoleDisplayName(repo.currentRole),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryBlue.withAlpha(25),
                        child: Text(
                          repo.currentUser.fullName.isNotEmpty ? repo.currentUser.fullName[0] : 'م',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repo.currentUser.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              repo.currentUser.email,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.primaryBlue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'كلمة المرور المعتمدة لحساب الإدارة: 00000',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                          label: const Text('تبديل الحساب'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('تسجيل الخروج'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _confirmLogout(context, repo),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppRepository repo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج من النظام والعودة لشاشة الدخول؟'),
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
