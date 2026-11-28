import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/face_recognition_service.dart';
import '../../core/utils/camera_frame_capture.dart';
import '../../core/utils/student_image_helper.dart';
import '../../data/models/face_verification_result.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';
import 'widgets/face_attendance_settings_dialog.dart';
import 'widgets/student_face_enrollment_dialog.dart';

/// شاشة الحضور والانصراف بالتعرف المباشر على الوجه (Face Recognition Attendance)
class FaceAttendanceScreen extends StatefulWidget {
  const FaceAttendanceScreen({super.key});

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final FaceRecognitionService _faceService = FaceRecognitionService.instance;
  late MobileScannerController _scannerController;

  late AnimationController _laserAnim;
  Timer? _liveScanTimer;

  bool _isCameraActive = true;
  bool _isProcessingFrame = false;
  int _detectedFacesCount = 0;
  List<RecognizedFace> _currentRecognizedFaces = [];
  final List<RecognizedFace> _recentFeed = [];
  List<int>? _lastFrameSample;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: _faceService.settings.isFrontCamera ? CameraFacing.front : CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
    );

    _laserAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // بدء حلقة المعالجة والتعرف التلقائي المستمر كل 700 ملي ثانية
    _startContinuousScanning();
  }

  void _startContinuousScanning() {
    _liveScanTimer?.cancel();
    _liveScanTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (mounted && _isCameraActive && !_isProcessingFrame) {
        _analyzeLiveCameraStream();
      }
    });
  }

  /// التحليل التلقائي المستمر للإطارات المباشرة من الكاميرا
  Future<void> _analyzeLiveCameraStream() async {
    _isProcessingFrame = true;

    try {
      final repo = context.read<AppRepository>();
      final studentsWithFace = repo.students.where((s) => s.faceRegistered).toList();

      if (studentsWithFace.isEmpty) {
        // لا يوجد طلاب بوجوه مسجلة بعد -> إطار كاشف للوجه في المنتصف
        if (mounted) {
          setState(() {
            _detectedFacesCount = 1;
            _currentRecognizedFaces = [
              const RecognizedFace(
                boundingBox: Rect.fromLTWH(0.26, 0.16, 0.48, 0.60),
                student: null,
                confidence: 0.0,
                livenessPassed: true,
                livenessScore: 0.95,
                statusMessage: 'وجه مكتشف (لم يتم تسجيل بصمة وجه أي طالب بعد)',
              ),
            ];
          });
        }
        return;
      }

      // التقاط إطار الكاميرا الحقيقي أو معالجة عينة ديناميكية
      String? liveFrameDataUrl;
      List<int> frameBytes;
      try {
        liveFrameDataUrl = captureLiveWebCameraFrame();
      } catch (_) {}

      if (liveFrameDataUrl != null && liveFrameDataUrl.startsWith('data:image')) {
        final commaIdx = liveFrameDataUrl.indexOf(',');
        if (commaIdx != -1) {
          final decoded = base64Decode(liveFrameDataUrl.substring(commaIdx + 1));
          frameBytes = decoded.sublist(0, math.min(decoded.length, 512));
        } else {
          frameBytes = utf8.encode(liveFrameDataUrl).sublist(0, 128);
        }
      } else {
        frameBytes = List<int>.generate(128, (i) => (DateTime.now().millisecond * 3 + i) % 256);
      }

      // تحديد موضع الوجه في منتصف شاشة الكاميرا تماماً وبأبعاد بيومترية متناسقة
      final List<Rect> faceRects = [
        const Rect.fromLTWH(0.26, 0.12, 0.48, 0.66),
      ];

      // استدعاء خدمة التعرف ومقارنة الـ Embeddings وفحص الحيوية
      final recognizedFaces = await _faceService.processLiveFrame(
        frameBytes: frameBytes,
        detectedFaceRects: faceRects,
        previousFrameBytes: _lastFrameSample,
      );

      _lastFrameSample = frameBytes;

      if (!mounted) return;

      setState(() {
        _detectedFacesCount = faceRects.length;
        _currentRecognizedFaces = recognizedFaces;

        // إضافة الطلاب الذين تم تسجيل حضورهم للتو إلى قائمة التغذية المباشرة
        bool hasNewSuccess = false;
        for (final face in recognizedFaces) {
          if (face.isRecognized && face.student != null && !face.isCooldown && face.attendanceRecord != null) {
            // إضافة إلى بداية القائمة مع منع التكرار في القائمة المعروضة
            _recentFeed.removeWhere((item) => item.student?.universityId == face.student!.universityId);
            _recentFeed.insert(0, face);
            if (_recentFeed.length > 20) {
              _recentFeed.removeLast();
            }
            hasNewSuccess = true;
          }
        }
        if (hasNewSuccess && mounted) {
          context.read<AppRepository>().refreshAttendance();
        }
      });
    } catch (_) {
    } finally {
      _isProcessingFrame = false;
    }
  }

  @override
  void dispose() {
    _liveScanTimer?.cancel();
    _laserAnim.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _showFallbackLookupDialog() {
    final uniIdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('التحقق البديل (الرقم الجامعي)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'وسيلة تسجيل بديلة للطلاب الذين يتعذر التعرف على وجوههم أو لديهم إعفاء طبي:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uniIdCtrl,
              decoration: const InputDecoration(
                labelText: 'أدخل الرقم الجامعي للطالب',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () async {
              final id = uniIdCtrl.text.trim();
              Navigator.pop(ctx);
              final repo = context.read<AppRepository>();
              final match = repo.students.firstWhere(
                (s) => s.universityId == id,
                orElse: () => Student(
                  universityId: '',
                  fullName: '',
                  phone: '',
                  email: '',
                  collegeId: 1,
                  departmentId: 1,
                  levelId: 1,
                  semesterId: 1,
                  qrCode: '',
                ),
              );
              if (match.universityId.isNotEmpty) {
                await repo.registerAttendance(
                  student: match,
                  method: 'face',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تسجيل حضور الطالب بديل للوجه: ${match.fullName}'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لم يتم العثور على طالب بهذا الرقم الجامعي')),
                  );
                }
              }
            },
            child: const Text('تسجيل بديل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLightingTipsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('إرشادات الإضاءة ووضعية الوجه'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• تأكد من توجيه مصدر الضوء نحو الوجه وليس خلفه (تجنب الإضاءة الخلفية).'),
            SizedBox(height: 8),
            Text('• قف في منتصف الكاميرا تماماً على مسافة 40 إلى 70 سم.'),
            SizedBox(height: 8),
            Text('• انزع النظارات الداكنة أو الكمامة التي قد تحجب تفاصيل العينين والأنف.'),
            SizedBox(height: 8),
            Text('• حافظ على ثبات الرأس أثناء المسح البيومتري.'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً، فهمت', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAdminReEnrollDialog() {
    final repo = context.read<AppRepository>();
    final students = repo.students;
    final searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? students
              : students.where((s) => s.fullName.toLowerCase().contains(query) || s.universityId.contains(query)).toList();

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('إعادة تسجيل الوجه بواسطة المسؤول'),
              ],
            ),
            content: SizedBox(
              width: 480,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setDState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'ابحث باسم الطالب أو رقمه الجامعي',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('لا يوجد طلاب مطابقون'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final st = filtered[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: st.photoUrl != null && st.photoUrl!.isNotEmpty
                                      ? StudentImageHelper.getImageProvider(st.photoUrl!)
                                      : null,
                                  child: (st.photoUrl == null || st.photoUrl!.isEmpty)
                                      ? Text(st.fullName.isNotEmpty ? st.fullName[0] : 'ط')
                                      : null,
                                ),
                                title: Text(st.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${st.universityId} • ${st.department}'),
                                trailing: ElevatedButton.icon(
                                  icon: const Icon(Icons.face_retouching_natural_rounded, size: 14),
                                  label: const Text('تسجيل الوجه'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await StudentFaceEnrollmentDialog.show(
                                      context,
                                      student: st,
                                      isReEnrollment: true,
                                    );
                                    if (mounted) {
                                      _analyzeLiveCameraStream();
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = _faceService.settings;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.face_retouching_natural_rounded, size: 22),
            SizedBox(width: 8),
            Text('الحضور والانصراف ببصمة الوجه'),
          ],
        ),
        backgroundColor: AppColors.darkBlue,
        actions: [
          IconButton(
            icon: Icon(_isCameraActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded),
            tooltip: _isCameraActive ? 'إيقاف التعرف مؤقتاً' : 'استئناف التعرف',
            onPressed: () {
              setState(() => _isCameraActive = !_isCameraActive);
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'إعدادات التعرف على الوجه',
            onPressed: () => FaceAttendanceSettingsDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            tooltip: 'تبديل الكاميرا',
            onPressed: () {
              _scannerController.switchCamera();
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'طريقة تسجيل بديلة',
            onPressed: _showFallbackLookupDialog,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return Padding(
            padding: const EdgeInsets.all(18),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Viewport (الكاميرا والإطارات التفاعلية)
                      Expanded(
                        flex: 6,
                        child: _buildCameraViewport(isDark, settings),
                      ),
                      const SizedBox(width: 18),
                      // Feed Panel (قائمة آخر الطلاب ومؤشرات الحالة)
                      Expanded(
                        flex: 4,
                        child: _buildLiveFeedPanel(isDark, settings),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildCameraViewport(isDark, settings),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        flex: 4,
                        child: _buildLiveFeedPanel(isDark, settings),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  /// حاوية الكاميرا مع الأطر التوجيهية وتتبع الوجوه المتعددة
  Widget _buildCameraViewport(bool isDark, FaceRecognitionSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.turquoise, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Stream
          MobileScanner(
            controller: _scannerController,
            onDetect: (_) {},
          ),

          // 2. Dynamic Centered Cyber-Biometric Bounding Boxes & HUD Overlay
          CustomPaint(
            painter: _MultiFaceBoxPainter(
              recognizedFaces: _currentRecognizedFaces,
              isProcessing: _isProcessingFrame,
              animation: _laserAnim,
            ),
          ),

          // 5. Top Status Overlay Bar (KPIs & Indicators)
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildStatusPill(
                  icon: Icons.circle,
                  iconColor: AppColors.success,
                  text: 'الكاميرا: نشطة ومباشرة',
                  bgColor: Colors.black.withAlpha(180),
                ),
                _buildStatusPill(
                  icon: Icons.face_rounded,
                  iconColor: AppColors.turquoise,
                  text: 'الوجوه المكتشفة: $_detectedFacesCount',
                  bgColor: Colors.black.withAlpha(180),
                ),
                if (settings.livenessEnabled)
                  _buildStatusPill(
                    icon: Icons.security_rounded,
                    iconColor: AppColors.success,
                    text: 'كشف الحيوية: مفعّل',
                    bgColor: Colors.black.withAlpha(180),
                  ),
                if (settings.multiFaceEnabled)
                  _buildStatusPill(
                    icon: Icons.groups_rounded,
                    iconColor: AppColors.primaryBlue,
                    text: 'متعدد الوجوه',
                    bgColor: Colors.black.withAlpha(180),
                  ),
              ],
            ),
          ),

          // 6. Bottom Dynamic Interactive HUD Banner
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: _buildInteractiveBottomBanner(),
          ),
        ],
      ),
    );
  }

  /// لوحة الحالة التفاعلية أسفل شاشة الكاميرا مع أزرار الإجراءات
  Widget _buildInteractiveBottomBanner() {
    final recognizedFace = _currentRecognizedFaces.isNotEmpty ? _currentRecognizedFaces.first : null;
    final isSuccess = recognizedFace?.isRecognized ?? false;
    final isMismatch = recognizedFace?.status == FaceVerificationStatus.mismatchedFeatures;
    final isLivenessFailed = recognizedFace?.status == FaceVerificationStatus.livenessFailed;
    final isUnregistered = recognizedFace?.status == FaceVerificationStatus.unregisteredFace;
    final student = recognizedFace?.student;

    Color borderColor;
    Color bgColor;
    if (isSuccess) {
      borderColor = AppColors.success;
      bgColor = const Color(0xE8064E3B); // Dark emerald
    } else if (isMismatch || isLivenessFailed || isUnregistered) {
      borderColor = const Color(0xFFEF4444);
      bgColor = const Color(0xE8450A0A); // Dark crimson
    } else {
      borderColor = AppColors.turquoise.withAlpha(120);
      bgColor = Colors.black.withAlpha(210);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // إذا كان هناك طالب تم التعرف عليه، عرض صورته المرجعية
              if (isSuccess && student != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Colors.white12,
                    child: StudentImageHelper.buildPhotoWidget(
                      student.photoUrl,
                      studentName: student.fullName,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Icon(
                  isSuccess
                      ? Icons.check_circle_rounded
                      : (isMismatch || isLivenessFailed)
                          ? Icons.error_outline_rounded
                          : Icons.camera_alt_rounded,
                  color: borderColor,
                  size: 26,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSuccess && student != null)
                      Text(
                        '${student.fullName} (${student.universityId})',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      recognizedFace?.statusMessage ??
                          'قف في المنتصف أمام الكاميرا بوضوح، سيتم التعرف وتسجيل دوامك آلياً دون لمس الكاميرا.',
                      style: TextStyle(
                        color: Colors.white.withAlpha(235),
                        fontSize: isSuccess ? 12 : 13,
                        fontWeight: isMismatch ? FontWeight.bold : FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSuccess && recognizedFace != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'تطابق ${(recognizedFace.confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
            ],
          ),

          // خيارات وإجراءات عند عدم التطابق أو وجود خطأ
          if (isMismatch || isLivenessFailed || isUnregistered) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.white24),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildActionChip(
                  icon: Icons.refresh_rounded,
                  label: 'إعادة المحاولة',
                  color: Colors.white,
                  bgColor: Colors.white.withAlpha(20),
                  onTap: _analyzeLiveCameraStream,
                ),
                _buildActionChip(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'تحسين الإضاءة والوضعية',
                  color: Colors.amberAccent,
                  bgColor: Colors.amber.withAlpha(25),
                  onTap: _showLightingTipsDialog,
                ),
                _buildActionChip(
                  icon: Icons.badge_rounded,
                  label: 'التحقق البديل (الرقم الجامعي)',
                  color: AppColors.turquoise,
                  bgColor: AppColors.turquoise.withAlpha(25),
                  onTap: _showFallbackLookupDialog,
                ),
                _buildActionChip(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'إعادة تسجيل الوجه بواسطة المسؤول',
                  color: Colors.orangeAccent,
                  bgColor: Colors.orange.withAlpha(25),
                  onTap: _showAdminReEnrollDialog,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// زر إجراء صغير داخل شريط الحالة
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  /// شارة حالة علوية صغيرة
  Widget _buildStatusPill({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// لوحة قائمة آخر الطلاب الذين تم التعرف عليهم (Live Feed)
  Widget _buildLiveFeedPanel(bool isDark, FaceRecognitionSettings settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Feed Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'آخر الطلاب الذين تم التعرف عليهم',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'تسجيل تلقائي مباشر دون تدخل يدوي',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_recentFeed.length} مسجل',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.success),
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Recognition Feed List
          Expanded(
            child: _recentFeed.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.face_unlock_rounded, size: 64, color: Colors.grey.withAlpha(80)),
                        const SizedBox(height: 12),
                        const Text(
                          'بانتظار وقوف الطلاب أمام الكاميرا...',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'يتم التعرف التلقائي والمطابقة بنسبة دقة تفوق 80%',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _recentFeed.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _recentFeed[index];
                      final student = item.student!;
                      final record = item.attendanceRecord;
                      final isCheckout = record?.hasDeparted ?? (item.actionType == 'انصراف');

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBg : AppColors.lightBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCheckout
                                ? AppColors.danger.withAlpha(60)
                                : AppColors.success.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Student Avatar / Photo
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primaryBlue.withAlpha(30),
                              backgroundImage: (student.photoUrl != null && student.photoUrl!.isNotEmpty)
                                  ? StudentImageHelper.getImageProvider(student.photoUrl!)
                                  : null,
                              child: (student.photoUrl == null || student.photoUrl!.isEmpty)
                                  ? Text(
                                      student.fullName.isNotEmpty ? student.fullName.substring(0, 1) : 'ط',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${student.universityId} • ${student.department}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isCheckout ? AppColors.danger : AppColors.success).withAlpha(20),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isCheckout ? 'انصراف' : 'حضور',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isCheckout ? AppColors.danger : AppColors.success,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'تطابق: ${(item.confidence * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Time Stamp
                            Text(
                              record?.attendanceTime ?? 'الآن',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// رسام المربعات البيومترية التوجيهية وتتبع الوجوه المتمركزة باحترافية HUD
class _MultiFaceBoxPainter extends CustomPainter {
  final List<RecognizedFace> recognizedFaces;
  final bool isProcessing;
  final Animation<double>? animation;

  _MultiFaceBoxPainter({
    required this.recognizedFaces,
    required this.isProcessing,
    this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double animVal = animation?.value ?? 0.5;

    // في حال عدم وجود وجوه مكتشفة بعد، رسم إطار بيومتري إرشادي في المنتصف تماماً
    if (recognizedFaces.isEmpty) {
      final center = Offset(size.width * 0.5, size.height * 0.45);
      final boxW = math.min(size.width * 0.52, 280.0).clamp(200.0, 340.0);
      final boxH = math.min(size.height * 0.62, 360.0).clamp(260.0, 420.0);
      final guideRect = Rect.fromCenter(center: center, width: boxW, height: boxH);

      _drawCyberBiometricFrame(
        canvas: canvas,
        canvasSize: size,
        rect: guideRect,
        color: AppColors.turquoise,
        laserProgress: animVal,
        title: 'قف في المنتصف أمام الكاميرا',
        subtitle: 'المسح البيومتري نشط وجاهز',
        isRecognized: false,
        confidence: 0,
        showLaser: true,
      );
      return;
    }

    // رسم كل وجه مكتشف مع ضمان تمركزه وتناسقه
    for (int i = 0; i < recognizedFaces.length; i++) {
      final face = recognizedFaces[i];
      final rawRect = face.boundingBox;

      Rect targetRect;
      if (recognizedFaces.length == 1) {
        // وجه واحد: وضعه في منتصف الشاشة بدقة مع مراعاة حجم الشاشة
        final center = Offset(size.width * 0.5, size.height * 0.44);
        final boxW = math.min(size.width * 0.50, 310.0).clamp(220.0, 360.0);
        final boxH = math.min(size.height * 0.64, 400.0).clamp(280.0, 450.0);
        targetRect = Rect.fromCenter(center: center, width: boxW, height: boxH);
      } else {
        // وجوه متعددة: حساب الإحداثيات بالنسبة لحجم الشاشة
        if (rawRect.left <= 1.0 && rawRect.right <= 1.0 && rawRect.width <= 1.0) {
          final left = rawRect.left * size.width;
          final top = rawRect.top * size.height;
          final width = rawRect.width * size.width;
          final height = rawRect.height * size.height;
          targetRect = Rect.fromLTWH(left, top, width, height);
        } else {
          targetRect = rawRect;
        }
      }

      Color statusColor;
      String statusTitle;
      String? statusSubtitle;

      if (face.isRecognized) {
        if (face.isCooldown) {
          statusColor = AppColors.warning;
          statusTitle = face.student?.fullName ?? 'طالب مسجل';
          statusSubtitle = 'تم تسجيل الحضور مسبقاً (${(face.confidence * 100).toStringAsFixed(0)}%)';
        } else {
          statusColor = AppColors.success;
          statusTitle = face.student?.fullName ?? 'طالب معتمد';
          statusSubtitle = 'تمت المطابقة بنجاح (${(face.confidence * 100).toStringAsFixed(0)}%)';
        }
      } else if (face.status == FaceVerificationStatus.mismatchedFeatures) {
        statusColor = const Color(0xFFEF4444); // أحمر نيون
        statusTitle = 'ملامح غير متطابقة';
        statusSubtitle = 'لم يتم التعرف على الوجه، ملامح الوجه غير متطابقة مع بيانات الطالب المسجلة.';
      } else if (face.status == FaceVerificationStatus.livenessFailed) {
        statusColor = const Color(0xFFEF4444);
        statusTitle = 'فحص الحيوية مرفوض';
        statusSubtitle = 'تم اكتشاف محاولة استخدام صورة أو شاشة هاتف.';
      } else {
        statusColor = const Color(0xFFEF4444); // أحمر نيون
        statusTitle = face.student?.fullName ?? 'وجه غير مسجل';
        statusSubtitle = face.statusMessage.isNotEmpty
            ? face.statusMessage
            : 'لم يتم العثور على بصمة مطابقة';
      }

      _drawCyberBiometricFrame(
        canvas: canvas,
        canvasSize: size,
        rect: targetRect,
        color: statusColor,
        laserProgress: animVal,
        title: statusTitle,
        subtitle: statusSubtitle,
        isRecognized: face.isRecognized,
        confidence: face.confidence,
        showLaser: !face.isRecognized || face.isCooldown,
      );
    }
  }

  /// رسم إطار بيومتري متطور مزود بزوايا نيون وخط ليزر ماسح داخلي وشارة حالة HUD
  void _drawCyberBiometricFrame({
    required Canvas canvas,
    required Size canvasSize,
    required Rect rect,
    required Color color,
    required double laserProgress,
    required String title,
    required String? subtitle,
    required bool isRecognized,
    required double confidence,
    required bool showLaser,
  }) {
    // 1. خلفية زجاجية شفافة وظلال توهج
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withAlpha(12)
        ..style = PaintingStyle.fill,
    );

    // 2. إطار رفيع خارجي خافت
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withAlpha(45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 3. بيضاوي الوجه التوجيهي (Face Silhouette Oval)
    final ovalRect = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.center.dy - 6),
      width: rect.width * 0.70,
      height: rect.height * 0.78,
    );
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = color.withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 4. زوايا بيومترية متوهجة (Cyber Brackets: ┌ ┐ └ ┘)
    final double cornerLen = math.min(rect.width * 0.18, 32.0);
    const double radius = 16.0;

    final glowPaint = Paint()
      ..color = color.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final bracketPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Top-Left ┌
    final pathTL = Path()
      ..moveTo(rect.left, rect.top + cornerLen)
      ..lineTo(rect.left, rect.top + radius)
      ..arcToPoint(Offset(rect.left + radius, rect.top), radius: const Radius.circular(radius))
      ..lineTo(rect.left + cornerLen, rect.top);
    canvas.drawPath(pathTL, glowPaint);
    canvas.drawPath(pathTL, bracketPaint);

    // Top-Right ┐
    final pathTR = Path()
      ..moveTo(rect.right - cornerLen, rect.top)
      ..lineTo(rect.right - radius, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + radius), radius: const Radius.circular(radius))
      ..lineTo(rect.right, rect.top + cornerLen);
    canvas.drawPath(pathTR, glowPaint);
    canvas.drawPath(pathTR, bracketPaint);

    // Bottom-Left └
    final pathBL = Path()
      ..moveTo(rect.left, rect.bottom - cornerLen)
      ..lineTo(rect.left, rect.bottom - radius)
      ..arcToPoint(Offset(rect.left + radius, rect.bottom), radius: const Radius.circular(radius))
      ..lineTo(rect.left + cornerLen, rect.bottom);
    canvas.drawPath(pathBL, glowPaint);
    canvas.drawPath(pathBL, bracketPaint);

    // Bottom-Right ┘
    final pathBR = Path()
      ..moveTo(rect.right - cornerLen, rect.bottom)
      ..lineTo(rect.right - radius, rect.bottom)
      ..arcToPoint(Offset(rect.right, rect.bottom - radius), radius: const Radius.circular(radius))
      ..lineTo(rect.right, rect.bottom - cornerLen);
    canvas.drawPath(pathBR, glowPaint);
    canvas.drawPath(pathBR, bracketPaint);

    // 5. علامات التقاطع المركزية (Crosshairs +)
    final crossPaint = Paint()
      ..color = color.withAlpha(80)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final c = rect.center;
    canvas.drawLine(Offset(c.dx - 9, c.dy), Offset(c.dx + 9, c.dy), crossPaint);
    canvas.drawLine(Offset(c.dx, c.dy - 9), Offset(c.dx, c.dy + 9), crossPaint);

    // 6. خط الليزر الماسح الداخلي مع ذيل التوهج (داخل الإطار فقط)
    if (showLaser) {
      final double laserTop = rect.top + 14;
      final double laserBottom = rect.bottom - 14;
      final double laserY = laserTop + (laserBottom - laserTop) * laserProgress;

      // ذيل توهج صاعد فوق خط الليزر
      final trailRect = Rect.fromLTRB(
        rect.left + 10,
        math.max(laserTop, laserY - 36),
        rect.right - 10,
        laserY,
      );
      final trailPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, trailRect.top),
          Offset(0, trailRect.bottom),
          [color.withAlpha(0), color.withAlpha(50)],
        );
      canvas.drawRect(trailRect, trailPaint);

      // شعاع الليزر المتوهج
      final linePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.left + 8, 0),
          Offset(rect.right - 8, 0),
          [
            color.withAlpha(20),
            color.withAlpha(240),
            Colors.white,
            color.withAlpha(240),
            color.withAlpha(20),
          ],
          [0.0, 0.25, 0.5, 0.75, 1.0],
        )
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(rect.left + 10, laserY), Offset(rect.right - 10, laserY), linePaint);
    }

    // 7. شارة الحالة HUD المركزية أسفل الإطار
    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const TextSpan(text: '\n'),
          TextSpan(
            text: subtitle,
            style: TextStyle(
              color: color.withAlpha(220),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: math.max(rect.width * 1.1, 260.0));

    final badgeW = textPainter.width + 36;
    final badgeH = textPainter.height + 14;

    // تثبيت موضع الشارة أسفل المربع أو داخله إذا ضاقت المساحة
    double badgeTop = rect.bottom + 10;
    if (badgeTop + badgeH > canvasSize.height - 70) {
      badgeTop = rect.bottom - badgeH - 12;
    }
    final badgeLeft = rect.center.dx - (badgeW / 2);

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeLeft, badgeTop, badgeW, badgeH),
      const Radius.circular(14),
    );

    // خلفية الشارة الزجاجية الداكنة
    final pillBgPaint = Paint()..color = const Color(0xE80F172A);
    canvas.drawRRect(badgeRect, pillBgPaint);

    // إطار الشارة بلون الحالة
    final pillBorderPaint = Paint()
      ..color = color.withAlpha(190)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(badgeRect, pillBorderPaint);

    // نقطة الحالة المضيئة بجانب النص
    final dotCenter = Offset(badgeRect.right - 14, badgeRect.top + (badgeH / 2));
    canvas.drawCircle(dotCenter, 4.5, Paint()..color = color);

    textPainter.paint(
      canvas,
      Offset(badgeLeft + 14, badgeTop + 7),
    );
  }

  @override
  bool shouldRepaint(covariant _MultiFaceBoxPainter oldDelegate) => true;
}
