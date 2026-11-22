import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../data/models/student.dart';
import '../../data/repositories/app_repository.dart';
import '../attendance/attendance_list_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  final _manualCodeController = TextEditingController();
  final _focusNode = FocusNode();
  final StringBuffer _keyBuffer = StringBuffer();
  DateTime? _lastKeyTime;

  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  String? _successMessage;
  String? _errorMessage;
  String? _unmatchedCode;
  bool _isProcessing = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _focusNode.dispose();
    _laserAnimController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Normalize code (converts Arabic numbers to Western, strips prefixes, trims)
  String _normalizeCode(String input) {
    var code = input.trim();
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < 10; i++) {
      code = code.replaceAll(arabicDigits[i], '$i');
    }
    if (code.contains('DAWAMI:STUDENT:')) {
      code = code.replaceAll('DAWAMI:STUDENT:', '').trim();
    }
    if (code.toUpperCase().startsWith('STUDENT:')) {
      code = code.substring(8).trim();
    }
    return code;
  }

  Future<void> _processScanCode(String rawCode) async {
    final cleanCode = _normalizeCode(rawCode);
    if (cleanCode.isEmpty || _isProcessing) return;

    // Prevent duplicate rapid scan of identical code within 1.5 seconds
    final now = DateTime.now();
    if (_lastScannedCode == cleanCode && _lastScanTime != null && now.difference(_lastScanTime!).inMilliseconds < 1500) {
      return;
    }
    _lastScannedCode = cleanCode;
    _lastScanTime = now;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
      _unmatchedCode = null;
    });

    try {
      final repo = context.read<AppRepository>();

      // 1. Search in local database
      final student = await repo.getStudentByCode(cleanCode);
      if (student == null) {
        setState(() {
          _errorMessage = 'الرمز غير مسجّل: لم يتم العثور على طالب مقترن بهذا الرمز ($cleanCode)';
          _unmatchedCode = cleanCode;
        });
        return;
      }

      // 2. Check student status
      if (student.status != 'نشط') {
        setState(() {
          _errorMessage = 'الطالب ${student.fullName} حالته غير نشطة (${student.status})';
        });
        return;
      }

      // 3. Register attendance in local DB + queue for sync
      final record = await repo.registerAttendance(
        student: student,
        method: 'qr',
      );

      final inTime = DateHelper.formatTimeString(record.checkIn);
      final isCheckOut = record.checkOut != null;
      final outTime = isCheckOut ? DateHelper.formatTimeString(record.checkOut) : null;

      setState(() {
        if (isCheckOut) {
          _successMessage = 'تم تسجيل الانصراف بنجاح! 👋\n${student.fullName} • ${student.universityId}\nوقت الحضور: $inTime | وقت الانصراف: $outTime';
        } else {
          _successMessage = 'تم تسجيل الحضور بنجاح! ⏱️\n${student.fullName} • ${student.universityId}\nوقت الحضور: $inTime (في انتظار تسجيل الانصراف لاحقاً)';
        }
      });

      _manualCodeController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _focusNode.requestFocus();
      }
    }
  }

  // Handle hardware keyboard input from physical USB/Bluetooth Barcode Guns
  void _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final now = DateTime.now();
    if (_lastKeyTime != null && now.difference(_lastKeyTime!).inMilliseconds > 200) {
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
        _processScanCode(scanned);
      }
    }
  }

  void _showLinkStudentDialog(String code) {
    final repo = context.read<AppRepository>();
    final activeStudents = repo.students.where((s) => s.status == 'نشط').toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ربط الباركود بطالب'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الرمز الممسوح: $code', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              const SizedBox(height: 12),
              const Text('اختر الطالب الذي ترغب في ربط هذا الرمز ببطاقته الجامعية:'),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: activeStudents.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final st = activeStudents[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryBlue,
                        child: Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                      title: Text(st.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('الرقم: ${st.universityId} • ${st.collegeName ?? ''}'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        await repo.linkBarcodeToStudent(st.id!, code);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('تم ربط الرمز بنجاح بالطالب ${st.fullName}، جاري تسجيل الحضور...'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        if (!mounted) return;
                        await _processScanCode(code);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final students = repo.students.where((s) => s.status == 'نشط').toList();
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: _handleHardwareKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('مسح بطاقة الطالب وقارئ الباركود (QR & Barcode)'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: repo.isPrimaryConnected ? AppColors.success.withAlpha(25) : AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: repo.isPrimaryConnected ? AppColors.success : AppColors.warning),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    repo.isPrimaryConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    size: 13,
                    color: repo.isPrimaryConnected ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    repo.isPrimaryConnected ? 'Supabase متصل' : 'Hive احتياطي',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: repo.isPrimaryConnected ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.turquoise.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.turquoise),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt, size: 14, color: AppColors.turquoise),
                  SizedBox(width: 4),
                  Text('القارئ نشط', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'إعدادات الحضور والانصراف',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: isDesktop
              ? Row(
                  children: [
                    // Desktop Left: Scanner Viewport with Live Animation
                    Expanded(
                      flex: 3,
                      child: _buildScannerViewport(),
                    ),
                    // Desktop Right: Control Panel
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: _buildControlPanel(students, repo),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildScannerViewport(),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: _buildControlPanel(students, repo),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildScannerViewport() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera live simulation background with grid
        Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF0F172A),
          child: CustomPaint(
            painter: _ScannerGridPainter(),
          ),
        ),

        // Scanning Reticle / Framing Target
        AnimatedBuilder(
          animation: _laserAnimation,
          builder: (context, child) {
            return Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _errorMessage != null
                      ? AppColors.danger
                      : (_successMessage != null ? AppColors.success : AppColors.turquoise),
                  width: 3.5,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (_errorMessage != null
                            ? AppColors.danger
                            : (_successMessage != null ? AppColors.success : AppColors.turquoise))
                        .withAlpha(40),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        size: 160,
                        color: Colors.white.withAlpha(25),
                      ),
                    ),
                    // Animated Laser Scanning Line
                    Positioned(
                      top: _laserAnimation.value * 280,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: _errorMessage != null
                              ? AppColors.danger
                              : (_successMessage != null ? AppColors.success : AppColors.turquoise),
                          boxShadow: [
                            BoxShadow(
                              color: (_errorMessage != null
                                      ? AppColors.danger
                                      : (_successMessage != null ? AppColors.success : AppColors.turquoise))
                                  .withAlpha(180),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isProcessing)
                      const Center(
                        child: CircularProgressIndicator(color: AppColors.turquoise, strokeWidth: 4),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // Top Instruction
        Positioned(
          top: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner, color: AppColors.turquoise, size: 18),
                SizedBox(width: 8),
                Text(
                  'قارئ الباركود نشط: وجّه الكود نحو الكاميرا أو امسح بالمسدس',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Success Pop-up Card
        if (_successMessage != null)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(
                        color: AppColors.darkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Error Pop-up Card with Link Option
        if (_errorMessage != null)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7F1D1D),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (_unmatchedCode != null) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.link, color: AppColors.darkBlue, size: 18),
                      label: Text('ربط الرمز ($_unmatchedCode) بطالب الآن وتسجيل حضوره', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.darkBlue,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      onPressed: () => _showLinkStudentDialog(_unmatchedCode!),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlPanel(List<Student> students, AppRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'تسجيل الحضور عبر الباركود أو مسدس القراءة:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkBlue),
        ),
        const SizedBox(height: 12),

        // Input Field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manualCodeController,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'امسح بمسدس الباركود أو أدخل الرقم...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryBlue),
                ),
                onSubmitted: (val) {
                  _processScanCode(val);
                },
                onChanged: (val) {
                  // Instant auto-submit if barcode gun pasted with newline or completed code
                  if (val.contains('\n') || val.contains('\r')) {
                    _processScanCode(val);
                  } else if (val.trim().length >= 8) {
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
                      _processScanCode(val);
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _processScanCode(_manualCodeController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('معالجة', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Quick Student Barcode Simulation
        const Text(
          'محاكاة مسح باركود بطاقة سريعة للطلاب المسجلين:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: students.map((s) {
            return ActionChip(
              avatar: const Icon(Icons.qr_code, size: 16, color: AppColors.primaryBlue),
              label: Text('${s.fullName.split(' ').first} (${s.universityId})'),
              onPressed: () => _processScanCode(s.universityId),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Active Session Badge
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'الجلسة: ${repo.activeSession?.lectureName ?? 'محاضرة نشطة'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkBlue),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'القاعة: ${repo.activeSession?.classroomName ?? '-'} • المحاضر: ${repo.activeSession?.instructor ?? '-'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom Painter for scanning grid effect
class _ScannerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(8)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
