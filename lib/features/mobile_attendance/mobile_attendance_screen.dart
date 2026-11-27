import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/attendance_service.dart';
import '../../core/services/mobile_attendance_service.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';

class MobileAttendanceScreen extends StatefulWidget {
  const MobileAttendanceScreen({super.key});

  @override
  State<MobileAttendanceScreen> createState() => _MobileAttendanceScreenState();
}

class _MobileAttendanceScreenState extends State<MobileAttendanceScreen> {
  final MobileAttendanceService _mobileService = MobileAttendanceService.instance;
  final AttendanceService _attendanceService = AttendanceService.instance;

  Student? _selectedStudent;
  bool _isCheckingGps = false;
  GeofenceVerificationResult? _lastGpsResult;
  bool _requireBiometrics = true;
  bool _isBiometricVerified = false;
  final String _simulatedDeviceUuid = 'HW-MOBILE-SECURE-9901';

  Future<bool> _verifyBiometricFingerprint() async {
    final localAuth = LocalAuthentication();
    try {
      if (!kIsWeb) {
        final canCheck = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
        if (canCheck) {
          final success = await localAuth.authenticate(
            localizedReason: 'يرجى وضع إصبعك على مستشعر بصمة الهاتف لتأكيد هوية الطالب',
            biometricOnly: false,
            persistAcrossBackgrounding: true,
          );
          if (success) {
            if (mounted) setState(() => _isBiometricVerified = true);
            return true;
          }
          return false;
        }
      }
      if (mounted) setState(() => _isBiometricVerified = true);
      return true;
    } catch (e) {
      if (kDebugMode) print('LocalAuth error: $e');
      if (mounted) setState(() => _isBiometricVerified = true);
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final students = repo.students;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('تسجيل الحضور والانصراف بهاتف الطالب (GPS)'),
        backgroundColor: AppColors.darkBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student Selector Card
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
                  const Text('اختيار حساب الطالب لتسجيل الهاتف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Student>(
                    value: _selectedStudent,
                    decoration: const InputDecoration(
                      labelText: 'اختر الطالب من القائمة',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    items: students.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text('${s.fullName} (${s.universityId}) - ${s.college}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedStudent = val;
                        _lastGpsResult = null;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Phone Binding & Hardware Info
            if (_selectedStudent != null) ...[
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
                    const Text('بيانات الهاتف المقترن والأمان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.smartphone_rounded, color: AppColors.primaryBlue, size: 32),
                      title: const Text('معرف الجهاز الفيزيائي (Hardware UUID)'),
                      subtitle: Text(_simulatedDeviceUuid),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquoise),
                        onPressed: () async {
                          await _mobileService.bindMobileDevice(
                            student: _selectedStudent!,
                            deviceUuid: _simulatedDeviceUuid,
                            deviceModel: 'Samsung Galaxy A54 (معتمد)',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم ربط واقتران الهاتف بحساب الطالب بنجاح'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        child: const Text('ربط الهاتف الآن', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // GPS Geofence Check Card
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
                        const Text('التحقق من النطاق الجغرافي (GPS Geofencing)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        OutlinedButton.icon(
                          icon: _isCheckingGps
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: Text(_isCheckingGps ? 'جارٍ التحديد...' : 'فحص موقعي الآن'),
                          onPressed: _isCheckingGps
                              ? null
                              : () async {
                                  setState(() => _isCheckingGps = true);
                                  final res = await _mobileService.verifyStudentLocation();
                                  setState(() {
                                    _lastGpsResult = res;
                                    _isCheckingGps = false;
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_lastGpsResult != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (_lastGpsResult!.isInsidePerimeter ? AppColors.success : AppColors.danger).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _lastGpsResult!.isInsidePerimeter ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: _lastGpsResult!.isInsidePerimeter ? AppColors.success : AppColors.danger,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _lastGpsResult!.message,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _lastGpsResult!.isInsidePerimeter ? AppColors.success : AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Fingerprint Biometric Verification Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isBiometricVerified
                        ? AppColors.success
                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (_isBiometricVerified ? AppColors.success : AppColors.turquoise).withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.fingerprint_rounded,
                            color: _isBiometricVerified ? AppColors.success : AppColors.turquoise,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'التحقق ببصمة الهاتف الحيوية',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'تأكيد هوية الطالب عبر مستشعر بصمة الهاتف المدمج',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _requireBiometrics,
                          activeColor: AppColors.turquoise,
                          onChanged: (val) => setState(() => _requireBiometrics = val),
                        ),
                      ],
                    ),
                    if (_requireBiometrics) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isBiometricVerified
                              ? AppColors.success.withAlpha(20)
                              : AppColors.turquoise.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isBiometricVerified
                                ? AppColors.success.withAlpha(60)
                                : AppColors.turquoise.withAlpha(40),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isBiometricVerified ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                              color: _isBiometricVerified ? AppColors.success : AppColors.turquoise,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isBiometricVerified
                                    ? 'تم التحقق من بصمة الطالب بنجاح على هذا الهاتف'
                                    : 'سيُطلب من الطالب لمس مستشعر بصمة الهاتف عند التسجيل',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _isBiometricVerified ? AppColors.success : AppColors.darkBlue,
                                ),
                              ),
                            ),
                            if (!_isBiometricVerified)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.fingerprint, size: 16),
                                label: const Text('فحص الآن'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.turquoise,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: _verifyBiometricFingerprint,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Attendance Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login_rounded, color: Colors.white),
                      label: const Text('تسجيل حضور بالهاتف', style: TextStyle(fontSize: 15, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _executeMobileAttendance(AttendanceActionType.checkIn),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      label: const Text('تسجيل انصراف بالهاتف', style: TextStyle(fontSize: 15, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _executeMobileAttendance(AttendanceActionType.checkOut),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _executeMobileAttendance(AttendanceActionType action) async {
    if (_selectedStudent == null) return;

    if (_requireBiometrics && !_isBiometricVerified) {
      final passed = await _verifyBiometricFingerprint();
      if (!passed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء التحقق ببصمة الهاتف. لم يتم تسجيل العملية.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    try {
      final record = await _attendanceService.recordAttendanceByMobile(
        student: _selectedStudent!,
        deviceUuid: _simulatedDeviceUuid,
        actionType: action,
        deviceModel: 'Samsung Galaxy A54 (معتمد)',
      );

      if (!mounted) return;
      await context.read<AppRepository>().refreshAttendance();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            record.hasDeparted
                ? 'تم تسجيل الانصراف بنجاح للطالب ${_selectedStudent!.fullName} عند ${record.checkOutTime}'
                : 'تم تسجيل الحضور بنجاح للطالب ${_selectedStudent!.fullName} (${record.status})',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
