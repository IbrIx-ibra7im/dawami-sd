import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/update_service.dart';
import '../../data/models/update_info.dart';
import '../settings/widgets/update_dialog.dart';
import '../../data/repositories/app_repository.dart';
import 'fingerprint_provider.dart';
import 'fingerprint_screen.dart';

/// نافذة إعدادات الحضور الخاصة بتحديث النظام وتفعيل/ضبط الباركود والبصمة فقط
class AttendanceSettingsDialog extends StatefulWidget {
  final AttendanceInputMode currentMode;
  final ValueChanged<AttendanceInputMode> onModeChanged;

  const AttendanceSettingsDialog({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required AttendanceInputMode currentMode,
    required ValueChanged<AttendanceInputMode> onModeChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AttendanceSettingsDialog(
        currentMode: currentMode,
        onModeChanged: onModeChanged,
      ),
    );
  }

  @override
  State<AttendanceSettingsDialog> createState() => _AttendanceSettingsDialogState();
}

class _AttendanceSettingsDialogState extends State<AttendanceSettingsDialog> {
  final UpdateService _updateService = UpdateService.instance;
  String _currentVersion = '1.1.0';
  bool _autoCheckUpdates = true;
  bool _isCheckingUpdate = false;
  late AttendanceInputMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.currentMode;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final ver = await _updateService.getCurrentVersion();
    final autoCheck = await _updateService.isAutoCheckEnabled();
    if (mounted) {
      setState(() {
        _currentVersion = ver;
        _autoCheckUpdates = autoCheck;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    final result = await _updateService.checkForUpdate();
    if (!mounted) return;

    setState(() => _isCheckingUpdate = false);

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
              SizedBox(width: 8),
              Text('أحدث إصدار'),
            ],
          ),
          content: Text(
            'أنت تستخدم بالفعل أحدث إصدار من تطبيق دوامي (الإصدار $_currentVersion).\nلم يتم نشر أي تحديثات جديدة بعد على مستودع GitHub.',
            style: const TextStyle(fontSize: 13, height: 1.5),
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
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fpProvider = context.watch<FingerprintProvider>();
    final repo = context.watch<AppRepository>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.darkBlue, AppColors.primaryBlue],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'إعدادات التحديث وتفعيل البصمة والباركود',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: تفعيل وضبط الباركود والبصمة
                    const Row(
                      children: [
                        Icon(Icons.fingerprint_rounded, size: 20, color: AppColors.turquoise),
                        SizedBox(width: 8),
                        Text(
                          'تفعيل وضبط الباركود والبصمة',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Attendance Input Mode Selector
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBg : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'طريقة تسجيل الحضور المعتمدة:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          _buildModeOption(
                            mode: AttendanceInputMode.dual,
                            title: 'كلاهما معاً (بصمة الإصبع + باركود/QR)',
                            subtitle: 'استقبال الحضور بالبصمة الحيوية وبطاقات الباركود معاً',
                            icon: Icons.all_inclusive_rounded,
                            activeColor: AppColors.primaryBlue,
                          ),
                          const Divider(height: 1),
                          _buildModeOption(
                            mode: AttendanceInputMode.fingerprint,
                            title: 'بصمة الإصبع فقط (Fingerprint Only)',
                            subtitle: 'اعتماد البصمة الحيوية حصرياً لتسجيل الحضور والانصراف',
                            icon: Icons.fingerprint_rounded,
                            activeColor: AppColors.turquoise,
                          ),
                          const Divider(height: 1),
                          _buildModeOption(
                            mode: AttendanceInputMode.barcode,
                            title: 'الباركود والبطاقات فقط (Barcode/QR Only)',
                            subtitle: 'المسح عبر قارئ الباركود الضوئي USB أو الكاميرا',
                            icon: Icons.qr_code_scanner_rounded,
                            activeColor: AppColors.primaryBlue,
                          ),
                          if (repo.isFaceEnabled) ...[
                            const Divider(height: 1),
                            _buildModeOption(
                              mode: AttendanceInputMode.face,
                              title: 'بصمة الوجه بالكاميرا (Face Recognition)',
                              subtitle: 'التعرف المباشر على ملامح وجه الطالب بالكاميرا وتسجيل الحضور آلياً',
                              icon: Icons.face_rounded,
                              activeColor: Colors.teal,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Active Methods Toggles
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBg : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تفعيل/تعطيل وسائل تسجيل الحضور:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('بصمة الإصبع الحيوية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            value: repo.isFingerprintEnabled,
                            // ignore: deprecated_member_use
                            activeColor: AppColors.turquoise,
                            onChanged: (val) async {
                              try {
                                await repo.toggleFingerprintMethod(val);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                                  );
                                }
                              }
                            },
                          ),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('بطاقة الباركود و QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            value: repo.isBarcodeEnabled,
                            // ignore: deprecated_member_use
                            activeColor: Colors.purple,
                            onChanged: (val) async {
                              try {
                                await repo.toggleBarcodeMethod(val);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                                  );
                                }
                              }
                            },
                          ),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('بصمة الوجه بالكاميرا', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            value: repo.isFaceEnabled,
                            // ignore: deprecated_member_use
                            activeColor: AppColors.primaryBlue,
                            onChanged: (val) async {
                              try {
                                await repo.toggleFaceMethod(val);
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

                    const SizedBox(height: 14),

                    // Connected Device Name
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBg : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.usb_rounded, color: AppColors.turquoise, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('قارئ البصمة المعتمد:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(
                                  fpProvider.selectedDeviceModel,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // Section 2: تحديثات التطبيق وفحص الإصدار الجديد
                    const Row(
                      children: [
                        Icon(Icons.system_update_rounded, size: 20, color: AppColors.primaryBlue),
                        SizedBox(width: 8),
                        Text(
                          'تحديثات النظام وفحص الإصدار',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBg : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('الإصدار الحالي المثبت:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'v$_currentVersion',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                icon: _isCheckingUpdate
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.sync_rounded, size: 16),
                                label: Text(_isCheckingUpdate ? 'جاري الفحص...' : 'البحث عن تحديثات الآن'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _isCheckingUpdate ? null : _checkForUpdates,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('التحقق التلقائي عند بدء التشغيل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('تنبيهك بهدوء عند توفر إصدار جديد على GitHub', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            value: _autoCheckUpdates,
                            activeThumbColor: AppColors.primaryBlue,
                            onChanged: (val) async {
                              setState(() => _autoCheckUpdates = val);
                              await _updateService.setAutoCheckEnabled(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('حفظ وإغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required AttendanceInputMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() => _selectedMode = mode);
        widget.onModeChanged(mode);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? activeColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? activeColor : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
