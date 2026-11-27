import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/attendance_service.dart';
import '../../../core/services/face_recognition_service.dart';

/// نافذة إعدادات التعرف المباشر على الوجه ومستوى الحساسية
class FaceAttendanceSettingsDialog extends StatefulWidget {
  const FaceAttendanceSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const FaceAttendanceSettingsDialog(),
    );
  }

  @override
  State<FaceAttendanceSettingsDialog> createState() => _FaceAttendanceSettingsDialogState();
}

class _FaceAttendanceSettingsDialogState extends State<FaceAttendanceSettingsDialog> {
  final _service = FaceRecognitionService.instance;
  late double _matchThreshold;
  late int _cooldownMinutes;
  late bool _multiFaceEnabled;
  late bool _livenessEnabled;
  late AttendanceActionType _attendanceMode;

  @override
  void initState() {
    super.initState();
    final s = _service.settings;
    _matchThreshold = s.matchThreshold;
    _cooldownMinutes = s.cooldownMinutes;
    _multiFaceEnabled = s.multiFaceEnabled;
    _livenessEnabled = s.livenessEnabled;
    _attendanceMode = s.attendanceMode;
  }

  Future<void> _saveSettings() async {
    final updated = FaceRecognitionSettings(
      matchThreshold: _matchThreshold,
      cooldownMinutes: _cooldownMinutes,
      multiFaceEnabled: _multiFaceEnabled,
      livenessEnabled: _livenessEnabled,
      attendanceMode: _attendanceMode,
      isFrontCamera: _service.settings.isFrontCamera,
    );
    await _service.updateSettings(updated);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ إعدادات التعرف على الوجه بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppColors.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إعدادات التعرف المباشر على الوجه',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'ضبط حساسية المطابقة، كشف الحيوية، ومنع التكرار',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const Divider(height: 28),

              // 1. Match Threshold Slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'مستوى حساسية التطابق (Match Threshold):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(_matchThreshold * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _matchThreshold,
                    min: 0.70,
                    max: 0.95,
                    divisions: 25,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (val) => setState(() => _matchThreshold = val),
                  ),
                  const Text(
                    'النسبة الموصى بها هي 80% لموازنة الدقة وسرعة التعرف في مختلف ظروف الإضاءة.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Cooldown Duration Dropdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'فترة منع تكرار التسجيل لنفس الطالب:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  DropdownButton<int>(
                    value: _cooldownMinutes,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 دقائق')),
                      DropdownMenuItem(value: 10, child: Text('10 دقائق')),
                      DropdownMenuItem(value: 15, child: Text('15 دقيقة (موصى به)')),
                      DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
                      DropdownMenuItem(value: 60, child: Text('ساعة واحدة')),
                      DropdownMenuItem(value: 720, child: Text('مرة واحدة يومياً')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _cooldownMinutes = val);
                    },
                  ),
                ],
              ),

              const Divider(height: 24),

              // 3. Multi-Face Detection Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'التعرف على عدة طلاب في نفس الوقت (Multi-Face)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: const Text(
                  'اكتشاف ومعالجة جميع الوجوه الظاهرة في كادر الكاميرا معاً',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                value: _multiFaceEnabled,
                // ignore: deprecated_member_use
                activeColor: AppColors.primaryBlue,
                onChanged: (val) => setState(() => _multiFaceEnabled = val),
              ),

              // 4. Liveness Detection Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'فحص الحيوية ومقاومة الاحتيال (Liveness Anti-Spoofing)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: const Text(
                  'منع تسجيل الحضور عبر الصور المطبوعة أو شاشات الهواتف والفيديوهات',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                value: _livenessEnabled,
                // ignore: deprecated_member_use
                activeColor: AppColors.success,
                onChanged: (val) => setState(() => _livenessEnabled = val),
              ),

              const Divider(height: 24),

              // 5. Attendance Action Mode
              const Text(
                'وضع تسجيل الحضور والانصراف:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SegmentedButton<AttendanceActionType>(
                segments: const [
                  ButtonSegment(
                    value: AttendanceActionType.auto,
                    label: Text('تلقائي ذكي'),
                    icon: Icon(Icons.auto_mode_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: AttendanceActionType.checkIn,
                    label: Text('حضور فقط'),
                    icon: Icon(Icons.login_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: AttendanceActionType.checkOut,
                    label: Text('انصراف فقط'),
                    icon: Icon(Icons.logout_rounded, size: 16),
                  ),
                ],
                selected: {_attendanceMode},
                onSelectionChanged: (val) => setState(() => _attendanceMode = val.first),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('حفظ التفضيلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
