import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';

/// نافذة فتح الكاميرا التفاعلية لمسح وقراءة الباركود ورمز الاستجابة السريعة (QR)
class BarcodeCameraDialog extends StatefulWidget {
  const BarcodeCameraDialog({super.key});

  @override
  State<BarcodeCameraDialog> createState() => _BarcodeCameraDialogState();
}

class _BarcodeCameraDialogState extends State<BarcodeCameraDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isDisposed = false;
  bool _hasScanned = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned || _isDisposed) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        _hasScanned = true;
        Navigator.of(context).pop(code);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 640),
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
          children: [
            // 1. Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.purple.withAlpha(25),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.purple, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مسح بطاقة الطالب عبر الكاميرا',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'وجّه الكاميرا نحو باركود أو QR بطاقة الطالب',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),

            // 2. Camera Preview Area with Viewfinder
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 320,
                  width: double.infinity,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'تعذر فتح الكاميرا على هذا الجهاز',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'يرجى التأكد من توصيل الكاميرا ومنح الإذن، أو استخدام قارئ الباركود (USB) أو الإدخال اليدوي أدناه.',
                                    style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Transparent Viewfinder Overlay Frame
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.purpleAccent, width: 3),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withAlpha(40),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      // Top Control Bar (Torch + Switch Camera)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          children: [
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: Colors.black45),
                              icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                              tooltip: 'تشغيل الفلاش',
                              onPressed: () => _controller.toggleTorch(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: Colors.black45),
                              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                              tooltip: 'تبديل الكاميرا',
                              onPressed: () => _controller.switchCamera(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Fallback / Manual input option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'أو اكتب رقم البطاقة / الرقم الجامعي...',
                        prefixIcon: const Icon(Icons.keyboard_alt_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onSubmitted: (val) {
                        final code = val.trim();
                        if (code.isNotEmpty) {
                          Navigator.of(context).pop(code);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final code = _manualController.text.trim();
                      if (code.isNotEmpty) {
                        Navigator.of(context).pop(code);
                      }
                    },
                    child: const Text('تسجيل'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
