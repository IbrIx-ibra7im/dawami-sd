import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/remote/supabase_service.dart';

/// خدمة إدارة وتخزين صور وجوه الطلاب الدائمة محلياً وسحابياً (Face Storage Service)
/// يمنع تخزين نصوص Base64 الضخمة في Hive، ويعتمد على مسارات ملفات حقيقية ودائمة
class FaceStorageService {
  static final FaceStorageService instance = FaceStorageService._init();
  FaceStorageService._init();

  Directory? _cachedFacesDir;

  /// مجلد التخزين الدائم لصور وجوه الطلاب داخل التطبيق
  Future<Directory?> getPermanentFacesDirectory() async {
    if (kIsWeb) return null;

    if (_cachedFacesDir != null && _cachedFacesDir!.existsSync()) {
      return _cachedFacesDir;
    }

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final facesDir = Directory(p.join(appDocDir.path, 'DawamiFaces'));
      if (!facesDir.existsSync()) {
        await facesDir.create(recursive: true);
      }
      _cachedFacesDir = facesDir;
      return facesDir;
    } catch (e) {
      if (kDebugMode) print('خطأ إنشاء مجلد وجوه الطلاب: $e');
      return null;
    }
  }

  /// حفظ صورة وجه الطالب محلياً بشكل دائم وربطها برقمه الجامعي
  /// تُرجع المسار المحلي الدائم للملف على القرص (Permanent Local File Path)
  Future<String> saveStudentFacePermanently({
    required String universityId,
    required List<int> imageBytes,
    String extension = 'jpg',
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('بيانات صورة الوجه فارغة');
    }

    // تنظيف المعرف الجامعي ليكون اسم ملف صالح
    final safeId = universityId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

    if (kIsWeb) {
      // في بيئة المتصفح: استخدام Data URL نظراً لعدم توفر نظام ملفات محلي مباشر
      final mime = extension.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(imageBytes)}';
    }

    final dir = await getPermanentFacesDirectory();
    if (dir == null) {
      // احتياطي في حال تعذر الوصول للمجلد
      return 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    }

    final targetPath = p.join(dir.path, 'student_face_$safeId.$extension');
    final file = File(targetPath);

    // كتابة الملف مع التأكد من إتمام التدفق إلى القرص (flush: true)
    await file.writeAsBytes(imageBytes, flush: true);

    if (kDebugMode) {
      print('تم حفظ صورة وجه الطالب دائمياً: ${file.path} (${imageBytes.length} بايت)');
    }

    return file.path;
  }

  /// فحص وجود الصورة الدائمة للطالب محلياً
  Future<File?> getLocalFaceFile(String universityId, {String extension = 'jpg'}) async {
    if (kIsWeb) return null;
    final dir = await getPermanentFacesDirectory();
    if (dir == null) return null;

    final safeId = universityId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final file = File(p.join(dir.path, 'student_face_$safeId.$extension'));
    return file.existsSync() ? file : null;
  }

  /// رفع صورة وجه الطالب إلى Supabase Storage السحابي في دلو 'student_faces'
  /// تُرجع رابط التخزين السحابي العام عند نجاح الرفع، أو null عند عدم الاتصال
  Future<String?> uploadFaceToCloudStorage({
    required String universityId,
    required List<int> imageBytes,
    String extension = 'jpg',
  }) async {
    try {
      final supabase = SupabaseService.instance;
      if (!supabase.isConfigured || supabase.client == null) {
        return null;
      }

      final safeId = universityId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = 'face_$safeId.$extension';
      final mimeType = extension.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';

      // محاولة الرفع إلى حاوية student_faces مع دعم upsert
      await supabase.client!.storage.from('student_faces').uploadBinary(
            fileName,
            Uint8List.fromList(imageBytes),
            fileOptions: FileOptions(upsert: true, contentType: mimeType),
          );

      final publicUrl = supabase.client!.storage.from('student_faces').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      if (kDebugMode) print('ملاحظة رفع صورة الوجه سحابياً (أوفلاين أو Bucket غير منشأ): $e');
      return null;
    }
  }

  /// حذف صورة وجه الطالب محلياً (عند حذف الطالب فقط، وليس عند الحضور)
  Future<bool> deleteStudentFacePermanently(String universityId, {String extension = 'jpg'}) async {
    if (kIsWeb) return true;
    try {
      final file = await getLocalFaceFile(universityId, extension: extension);
      if (file != null && file.existsSync()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
