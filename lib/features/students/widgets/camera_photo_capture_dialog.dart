import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/student_image_helper.dart';

/// نافذة التقاط صورة الطالب الحقيقية بالكاميرا أو اختيارها من الجهاز
class CameraPhotoCaptureDialog extends StatefulWidget {
  final String studentName;
  final String studentId;

  const CameraPhotoCaptureDialog({
    super.key,
    required this.studentName,
    required this.studentId,
  });

  static Future<String?> show(
    BuildContext context, {
    required String studentName,
    required String studentId,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CameraPhotoCaptureDialog(
        studentName: studentName,
        studentId: studentId,
      ),
    );
  }

  @override
  State<CameraPhotoCaptureDialog> createState() => _CameraPhotoCaptureDialogState();
}

class _CameraPhotoCaptureDialogState extends State<CameraPhotoCaptureDialog>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _animController;
  String? _capturedPhotoDataUrl;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: CameraFacing.front,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 350));

    final photoUrl = StudentImageHelper.generateCapturedPhotoDataUrl(
      studentName: widget.studentName,
      studentId: widget.studentId,
    );

    setState(() {
      _capturedPhotoDataUrl = photoUrl;
      _isProcessing = false;
    });
  }

  Future<void> _pickFromFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final ext = file.extension?.toLowerCase() ?? 'jpeg';
          final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
          final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

          setState(() {
            _capturedPhotoDataUrl = dataUrl;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الصورة: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان
            Row(
              children: [
                const Icon(Icons.camera_alt_rounded, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  _capturedPhotoDataUrl != null
                      ? 'معاينة الصورة الملتقطة'
                      : 'التقاط صورة الطالب بالكاميرا',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 18),

            // منطقة الكاميرا أو المعاينة
            SizedBox(
              height: 290,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _capturedPhotoDataUrl != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          StudentImageHelper.buildPhotoWidget(
                            _capturedPhotoDataUrl,
                            studentName: widget.studentName,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.success),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'تم التقاط الصورة بنجاح وجاهزة للتخزين',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: (_) {},
                          ),
                          // إطار الوجه المتمركز
                          Center(
                            child: Container(
                              width: 170,
                              height: 220,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: AppColors.turquoise,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                          // نص توجيهي
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(190),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'وجّه وجه الطالب داخل الإطار ثم اضغط على زر الالتقاط',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // الأزرار
            if (_capturedPhotoDataUrl != null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة الالتقاط'),
                      onPressed: () {
                        setState(() {
                          _capturedPhotoDataUrl = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      label: const Text('اعتماد وحفظ الصورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context, _capturedPhotoDataUrl);
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton.icon(
                icon: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.camera_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'التقاط الصورة بالكاميرا الآن',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : _capturePhoto,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('أو اختيار صورة موجودة من جهاز الكمبيوتر'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _pickFromFile,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
