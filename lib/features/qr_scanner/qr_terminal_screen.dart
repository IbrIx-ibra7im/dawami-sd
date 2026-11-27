import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/attendance_service.dart';
import '../../core/services/qr_code_service.dart';
import '../../data/repositories/app_repository.dart';

class QrTerminalScreen extends StatefulWidget {
  const QrTerminalScreen({super.key});

  @override
  State<QrTerminalScreen> createState() => _QrTerminalScreenState();
}

class _QrTerminalScreenState extends State<QrTerminalScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final AttendanceService _attendanceService = AttendanceService.instance;
  final QrCodeService _qrService = QrCodeService.instance;

  final FocusNode _keyboardFocusNode = FocusNode();
  final StringBuffer _keyBuffer = StringBuffer();
  DateTime? _lastKeyTime;

  AttendanceActionType _selectedAction = AttendanceActionType.auto;
  bool _isProcessing = false;
  String _statusMessage = 'جاهز لمسح رموز QR عبر الكاميرا أو قارئ الباركود USB';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final now = DateTime.now();
    if (_lastKeyTime != null && now.difference(_lastKeyTime!).inMilliseconds > 300) {
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
        _processScannedCode(scanned);
      }
    }
  }

  Future<void> _processScannedCode(String code) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'جارٍ التحقق من الرمز ($code)...';
    });

    try {
      final isValid = _qrService.validateDynamicQr(code);
      if (!isValid) {
        throw Exception('رمز QR منتهي الصلاحية أو غير صالح لمنع تصوير الشاشة');
      }

      final record = await _attendanceService.recordAttendanceByBarcode(
        barcode: code,
        actionType: _selectedAction,
        deviceName: 'محطة مسح QR والباركود',
      );

      setState(() {
        _statusMessage = record.hasDeparted
            ? 'تم تسجيل الانصراف بنجاح للطالب: ${record.studentName} عند ${record.checkOutTime}'
            : 'تم تسجيل الحضور بنجاح للطالب: ${record.studentName} (${record.status})';
      });

      await context.read<AppRepository>().refreshAttendance();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_statusMessage),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ: ${e.toString().replaceAll('Exception: ', '')}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_statusMessage),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        _keyboardFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleHardwareKey,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          title: const Text('محطة مسح الباركود ورموز QR الذكية'),
          backgroundColor: AppColors.darkBlue,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Scanner View
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryBlue, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null) {
                              _processScannedCode(barcode.rawValue!);
                              break;
                            }
                          }
                        },
                      ),
                      Center(
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.turquoise, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Settings & Action Panel
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('نوع العملية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      SegmentedButton<AttendanceActionType>(
                        segments: const [
                          ButtonSegment(value: AttendanceActionType.auto, label: Text('تلقائي')),
                          ButtonSegment(value: AttendanceActionType.checkIn, label: Text('حضور')),
                          ButtonSegment(value: AttendanceActionType.checkOut, label: Text('انصراف')),
                        ],
                        selected: {_selectedAction},
                        onSelectionChanged: (val) => setState(() => _selectedAction = val.first),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.usb_rounded, color: AppColors.primaryBlue),
                                SizedBox(width: 8),
                                Text('دعم قارئ الباركود USB', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            SizedBox(height: 6),
                            Text('القارئات السلكية واللاسلكية تعمل مباشرة دون الحاجة لأي تعريفات.'),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
