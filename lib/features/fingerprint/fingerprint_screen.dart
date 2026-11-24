import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../data/models/student.dart';
import '../../data/models/attendance_record.dart';
import '../../data/repositories/app_repository.dart';
import '../authentication/login_screen.dart';
import '../fingerprint/fingerprint_provider.dart';
import '../qr_scanner/barcode_camera_dialog.dart';
import '../../core/services/update_service.dart';
import '../../data/models/update_info.dart';
import '../settings/widgets/update_dialog.dart';
import '../attendance/attendance_list_screen.dart';
import '../../widgets/sync_status_card.dart';

import '../../data/models/biometric_models.dart';

enum AttendanceInputMode { dual, fingerprint, barcode }

class FingerprintScreen extends StatefulWidget {
  final bool isInitialScreen;
  const FingerprintScreen({super.key, this.isInitialScreen = false});

  @override
  State<FingerprintScreen> createState() => _FingerprintScreenState();
}

class _FingerprintScreenState extends State<FingerprintScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  final FocusNode _keyboardFocusNode = FocusNode();
  final StringBuffer _keyBuffer = StringBuffer();
  DateTime? _lastKeyTime;

  AttendanceInputMode _currentMode = AttendanceInputMode.dual;
  Student? _attendedStudent;
  AttendanceRecord? _lastAttendanceRecord;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pulse animation for Fingerprint
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Laser sweep animation for Barcode / QR scanner
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
        _checkUpdatesSilently();
      }
    });
  }

  Future<void> _checkUpdatesSilently() async {
    try {
      final updateService = UpdateService.instance;
      final autoCheck = await updateService.isAutoCheckEnabled();
      if (!autoCheck || !mounted) return;

      final result = await updateService.checkForUpdate();
      if (result.status == UpdateCheckStatus.updateAvailable &&
          result.releaseInfo != null &&
          mounted) {
        UpdateDialog.show(
          context,
          currentVersion: result.currentVersion,
          releaseInfo: result.releaseInfo!,
        );
      }
    } catch (_) {
      // التحقق التلقائي عند بدء التشغيل يكون صامتاً ولا يزعج المستخدم بأي أخطاء شبكة
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _laserAnimController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // Handle hardware USB/Bluetooth barcode guns
  void _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final now = DateTime.now();
    if (_lastKeyTime != null &&
        now.difference(_lastKeyTime!).inMilliseconds > 250) {
      _keyBuffer.clear();
    }
    _lastKeyTime = now;

    final char = event.character;
    if (char != null && char.isNotEmpty && char != '\n' && char != '\r') {
      _keyBuffer.write(char);
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final scanned = _keyBuffer.toString().trim();
      _keyBuffer.clear();
      if (scanned.isNotEmpty) {
        _scanBarcode(scanned);
      }
    }
  }

  Future<void> _scanFingerprint({
    Student? specificStudent,
    bool useDeviceBiometrics = true,
  }) async {
    setState(() {
      _errorMessage = null;
      _attendedStudent = null;
      _lastAttendanceRecord = null;
    });

    final fpProvider = context.read<FingerprintProvider>();
    final repo = context.read<AppRepository>();

    final matchedStudent = await fpProvider.triggerFingerprintScan(
      forcedStudent: specificStudent,
    );

    if (matchedStudent != null) {
      try {
        final record = await repo.registerAttendance(
          student: matchedStudent,
          method: 'fingerprint',
        );
        // تسجيل عملية تحقق بيومتري ناجحة
        await repo.logBiometricVerification(
          BiometricVerificationLog(
            studentId: matchedStudent.id!,
            method: 'fingerprint_1_N',
            status: 'success',
            reason: 'تم تطابق البصمة وتسجيل الحضور بنجاح',
            timestamp: DateTime.now().toIso8601String(),
            deviceModel: fpProvider.selectedDeviceModel,
          ),
        );
        setState(() {
          _attendedStudent = matchedStudent;
          _lastAttendanceRecord = record;
        });
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } else {
      // تسجيل عملية تحقق بيومتري فاشلة
      await repo.logBiometricVerification(
        BiometricVerificationLog(
          studentId: 0,
          method: 'fingerprint_1_N',
          status: 'failed',
          reason: 'لم يتم التحقق من البصمة أو تم إلغاء المسح',
          timestamp: DateTime.now().toIso8601String(),
          deviceModel: fpProvider.selectedDeviceModel,
        ),
      );
      setState(() {
        _errorMessage = 'لم يتم التحقق من البصمة أو تم إلغاء المسح';
      });
    }
  }

  Future<void> _scanBarcode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    setState(() {
      _errorMessage = null;
      _attendedStudent = null;
      _lastAttendanceRecord = null;
    });

    final repo = context.read<AppRepository>();
    final student = await repo.getStudentByCode(cleanCode);

    if (student == null) {
      setState(() {
        _errorMessage =
            'الرمز غير مسجّل: لم يتم العثور على طالب بالرمز ($cleanCode)';
      });
      return;
    }

    if (student.status != 'نشط') {
      setState(() {
        _errorMessage =
            'عذراً، الطالب ${student.fullName} حالته غير نشطة (${student.status})';
      });
      return;
    }

    try {
      final record = await repo.registerAttendance(
        student: student,
        method: 'qr',
      );
      // تسجيل عملية تحقق ناجحة بالباركود
      await repo.logBiometricVerification(
        BiometricVerificationLog(
          studentId: student.id!,
          method: 'barcode',
          status: 'success',
          reason: 'تم التعرف على الطالب وتسجيل الحضور عبر الباركود',
          timestamp: DateTime.now().toIso8601String(),
          deviceModel: 'USB Barcode Reader',
        ),
      );
      setState(() {
        _attendedStudent = student;
        _lastAttendanceRecord = record;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _openCameraBarcodeScanner() async {
    final scannedCode = await showDialog<String>(
      context: context,
      builder: (_) => const BarcodeCameraDialog(),
    );

    if (scannedCode != null && scannedCode.trim().isNotEmpty) {
      _scanBarcode(scannedCode.trim());
    }
  }

  void _showHardwareSpecsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text(
              'مواصفات قارئ البصمة والـ SDK',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تنبيه فني هام:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                FingerprintProvider.mobileBiometricNotice,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              Divider(height: 24),
              Text(
                'الأجهزة المتوافقة المعتمدة:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                FingerprintProvider.requiredDeviceSpecs,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              Divider(height: 24),
              Text(
                'حزم التطوير (SDK) وقوالب البصمة:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                FingerprintProvider.requiredSdkSpecs,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fpProvider = context.watch<FingerprintProvider>();
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fpEnabled = repo.isFingerprintEnabled;
    final bcEnabled = repo.isBarcodeEnabled;

    // تكييف الوضع التلقائي إذا تم تعطيل إحدى الوسيلتين بواسطة الإدارة
    AttendanceInputMode activeMode = _currentMode;
    if (!fpEnabled && bcEnabled) {
      activeMode = AttendanceInputMode.barcode;
    } else if (fpEnabled && !bcEnabled) {
      activeMode = AttendanceInputMode.fingerprint;
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleHardwareKey,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fpEnabled) ...[
                const Icon(Icons.fingerprint_rounded, size: 22),
                const SizedBox(width: 4),
              ],
              if (bcEnabled) ...[
                const Icon(Icons.qr_code_2_rounded, size: 22),
                const SizedBox(width: 6),
              ],
              Text(
                (fpEnabled && bcEnabled)
                    ? 'تسجيل الحضور بالبصمة الحيوية والباركود'
                    : (fpEnabled
                          ? 'تسجيل الحضور بالبصمة الحيوية'
                          : 'تسجيل الحضور ببطاقة الباركود الذكية'),
              ),
            ],
          ),
          backgroundColor: AppColors.darkBlue,
          leading: widget.isInitialScreen
              ? null
              : (Navigator.canPop(context)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null),
          actions: [
            // شارة حالة الجهاز (تتكيف حسب تفعيل البصمة أو الباركود)
            if (fpEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.turquoise.withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.turquoise),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          fpProvider.isDeviceBiometricsSupported
                              ? 'البصمة جاهزة'
                              : '${fpProvider.selectedDeviceModel}: متصل',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (bcEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withAlpha(35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.purpleAccent),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 14,
                          color: Colors.purpleAccent,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'الباركود نشط',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Prominent Button at Top: Enter Dashboard via Login
            if (widget.isInitialScreen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 16,
                  ),
                  label: const Text(
                    'لوحة التحكم (تسجيل الدخول)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    repo.logout();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
              tooltip: 'مواصفات قارئ البصمة البيومتري والـ SDK',
              onPressed: () => _showHardwareSpecsDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'إعدادات الحضور والانصراف وقواعد البيانات',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendanceListScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Welcome / Control Panel Access Banner
              if (widget.isInitialScreen)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppColors.primaryBlue.withAlpha(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final title = Row(
                        children: [
                          if (fpEnabled) ...[
                            const Icon(
                              Icons.fingerprint_rounded,
                              color: AppColors.primaryBlue,
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (bcEnabled) ...[
                            const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.purple,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              (fpEnabled && bcEnabled)
                                  ? 'نظام تسجيل الحضور والانصراف المباشر للطلاب (بصمة حيوية • بطاقة باركود ذكية)'
                                  : (fpEnabled
                                        ? 'نظام تسجيل الحضور والانصراف المباشر للطلاب (البصمة الحيوية)'
                                        : 'نظام تسجيل الحضور والانصراف المباشر للطلاب (بطاقة الباركود الذكية)'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      );

                      final loginButton = ElevatedButton.icon(
                        icon: const Icon(Icons.login_rounded, size: 15),
                        label: const Text(
                          'دخول لوحة التحكم',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          repo.logout();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                      );

                      if (constraints.maxWidth < 600) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 8),
                            loginButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: 12),
                          loginButton,
                        ],
                      );
                    },
                  ),
                ),

              const SyncStatusCard(compact: true),

              // 2. Attendance Mode Switcher (يظهر فقط في حال تفعيل كلتا الوسيلتين معاً بواسطة الإدارة)
              if (fpEnabled && bcEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final segmentedButton =
                          SegmentedButton<AttendanceInputMode>(
                            segments: const [
                              ButtonSegment(
                                value: AttendanceInputMode.dual,
                                icon: Icon(Icons.hub_rounded, size: 16),
                                label: Text(
                                  'المزدوج (بصمة + باركود)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              ButtonSegment(
                                value: AttendanceInputMode.fingerprint,
                                icon: Icon(Icons.fingerprint_rounded, size: 16),
                                label: Text(
                                  'بصمة فقط',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              ButtonSegment(
                                value: AttendanceInputMode.barcode,
                                icon: Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  'باركود فقط',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                            selected: {activeMode},
                            onSelectionChanged: (newSelection) {
                              setState(() {
                                _currentMode = newSelection.first;
                              });
                            },
                          );

                      const header = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 18,
                            color: AppColors.primaryBlue,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'طريقة التسجيل الحالية:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );

                      if (constraints.maxWidth < 700) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            header,
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: segmentedButton,
                            ),
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          header,
                          const SizedBox(width: 12),
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: segmentedButton,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              const Divider(height: 1),

              // 3. Main Attendance Scanning Area (Clean & Focused)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: _buildMainInteractiveArea(
                        fpProvider,
                        repo,
                        isDark,
                        fpEnabled,
                        bcEnabled,
                        activeMode,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainInteractiveArea(
    FingerprintProvider fpProvider,
    AppRepository repo,
    bool isDark,
    bool fpEnabled,
    bool bcEnabled,
    AttendanceInputMode activeMode,
  ) {
    return Column(
      children: [
        // Error Message Banner
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.danger.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Scanning Zones (يتم إظهار وإخفاء المناطق بحسب تفعيل الإدارة للبصمة والباركود)
        if (fpEnabled && bcEnabled) ...[
          if (activeMode == AttendanceInputMode.dual)
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 650) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSensorArea(fpProvider, isDark)),
                      Container(
                        height: 380,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                      Expanded(child: _buildBarcodeArea(repo, isDark)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildSensorArea(fpProvider, isDark),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      _buildBarcodeArea(repo, isDark),
                    ],
                  );
                }
              },
            )
          else if (activeMode == AttendanceInputMode.fingerprint)
            _buildSensorArea(fpProvider, isDark)
          else
            _buildBarcodeArea(repo, isDark),
        ] else if (fpEnabled) ...[
          _buildSensorArea(fpProvider, isDark),
        ] else if (bcEnabled) ...[
          _buildBarcodeArea(repo, isDark),
        ],

        // Matched Attendance Result Card (Common for Fingerprint & Barcode)
        _buildAttendanceResultCard(isDark),
      ],
    );
  }

  // Fingerprint Biometric Sensor Area
  Widget _buildSensorArea(FingerprintProvider fpProvider, bool isDark) {
    final isScanning = fpProvider.status == BiometricDeviceStatus.scanning;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Mode indicator pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.turquoise.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.turquoise.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                fpProvider.isDeviceBiometricsSupported
                    ? Icons.fingerprint
                    : Icons.devices_rounded,
                color: AppColors.turquoise,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'الوضع: ${fpProvider.selectedDeviceModel}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Big Fingerprint Touch Target
        GestureDetector(
          onTap: () => _scanFingerprint(useDeviceBiometrics: true),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border.all(
                  color: isScanning
                      ? AppColors.warning
                      : (_attendedStudent != null &&
                                _lastAttendanceRecord?.method == 'fingerprint'
                            ? AppColors.success
                            : AppColors.turquoise),
                  width: 6,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_attendedStudent != null &&
                                    _lastAttendanceRecord?.method ==
                                        'fingerprint'
                                ? AppColors.success
                                : AppColors.turquoise)
                            .withAlpha(60),
                    blurRadius: 24,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Center(
                child: isScanning
                    ? const CircularProgressIndicator(
                        color: AppColors.turquoise,
                        strokeWidth: 4,
                      )
                    : Icon(
                        Icons.fingerprint_rounded,
                        size: 96,
                        color:
                            _attendedStudent != null &&
                                _lastAttendanceRecord?.method == 'fingerprint'
                            ? AppColors.success
                            : AppColors.turquoise,
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Action Scan Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.fingerprint, size: 18),
              label: const Text('بصمة الجهاز'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.turquoise,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _scanFingerprint(useDeviceBiometrics: true),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.touch_app, size: 18),
              label: const Text('لمس / USB'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _scanFingerprint(useDeviceBiometrics: false),
            ),
          ],
        ),

        const SizedBox(height: 12),

        const Text(
          'المس مستشعر البصمة أو اضغط على الدائرة للمسح',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          fpProvider.statusMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // Barcode & QR Scanner Viewfinder Area
  Widget _buildBarcodeArea(AppRepository repo, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Mode indicator pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.purple.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.withAlpha(80)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.purple,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'قارئ الباركود والبطاقات الجامعية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Animated Barcode Scanner Viewfinder Box with Laser (Clickable to open camera)
        GestureDetector(
          onTap: _openCameraBarcodeScanner,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        _attendedStudent != null &&
                            _lastAttendanceRecord?.method == 'qr'
                        ? AppColors.success
                        : Colors.purple.withAlpha(140),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_attendedStudent != null &&
                                      _lastAttendanceRecord?.method == 'qr'
                                  ? AppColors.success
                                  : Colors.purple)
                              .withAlpha(40),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 80,
                      color:
                          _attendedStudent != null &&
                              _lastAttendanceRecord?.method == 'qr'
                          ? AppColors.success
                          : Colors.purple,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'مرر بطاقة الطالب هنا',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Animated Scanning Laser Line
              AnimatedBuilder(
                animation: _laserAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: 15 + (_laserAnimation.value * 160),
                    child: Container(
                      width: 170,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.redAccent,
                            Colors.red,
                            Colors.redAccent,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withAlpha(200),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Action Scan Button for Barcode (Opens Camera)
        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt_rounded, size: 20),
          label: const Text(
            'قراءة الباركود (فتح الكاميرا)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          onPressed: _openCameraBarcodeScanner,
        ),

        const SizedBox(height: 12),

        const Text(
          'اضغط على الزر لفتح الكاميرا أو مرر بطاقة الطالب',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'متوافق مع قارئ الباركود USB والمسح المباشر',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Common Attendance Result Card
  Widget _buildAttendanceResultCard(bool isDark) {
    if (_attendedStudent == null) return const SizedBox.shrink();
    final isCheckOut = _lastAttendanceRecord?.checkOut != null;
    final isQr = _lastAttendanceRecord?.method == 'qr';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCheckOut ? AppColors.primaryBlue : AppColors.success,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCheckOut ? AppColors.primaryBlue : AppColors.success)
                .withAlpha(30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor:
                (isCheckOut ? AppColors.primaryBlue : AppColors.success)
                    .withAlpha(30),
            child: Icon(
              isCheckOut ? Icons.logout_rounded : Icons.check_circle_rounded,
              color: isCheckOut ? AppColors.primaryBlue : AppColors.success,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _attendedStudent!.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isQr
                            ? Colors.purple.withAlpha(20)
                            : AppColors.turquoise.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isQr ? Colors.purple : AppColors.turquoise,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isQr
                                ? Icons.qr_code_2_rounded
                                : Icons.fingerprint_rounded,
                            size: 14,
                            color: isQr ? Colors.purple : AppColors.turquoise,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isQr ? 'تم عبر الباركود' : 'تم عبر البصمة',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isQr ? Colors.purple : AppColors.turquoise,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isCheckOut
                                    ? AppColors.primaryBlue
                                    : AppColors.success)
                                .withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCheckOut ? 'تم تسجيل الانصراف' : 'تم تسجيل الحضور',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCheckOut
                              ? AppColors.primaryBlue
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'الرقم الجامعي: ${_attendedStudent!.universityId} • ${_attendedStudent!.collegeName ?? 'كلية علوم الحاسوب'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'وقت الحضور: ${DateHelper.formatTimeString(_lastAttendanceRecord?.checkIn)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCheckOut
                            ? AppColors.primaryBlue.withAlpha(20)
                            : Colors.grey.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCheckOut
                            ? 'وقت الانصراف: ${DateHelper.formatTimeString(_lastAttendanceRecord?.checkOut)}'
                            : 'الانصراف: في انتظار التسجيل لاحقاً',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCheckOut
                              ? AppColors.primaryBlue
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
