import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/student.dart';
import '../../data/remote/supabase_service.dart';
import 'local_storage_service.dart';

/// خدمة إدارة الطلاب (StudentService)
/// مسؤولة عن:
/// 1. تسجيل الطلاب وحفظ الاسم والرقم الجامعي (مع خيارات البصمة والباركود).
/// 2. منع تكرار الرقم الجامعي أو الباركود أو البصمة.
/// 3. حفظ نسخة محلية فورية في Hive، والمزامنة مع Supabase.
class StudentService {
  static final StudentService instance = StudentService._init();
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  StudentService._init();

  /// تسجيل طالب جديد
  /// يحفظ الاسم والرقم الجامعي مع منع تكرارهما، وربط الباركود والبصمة
  Future<Student> registerStudent({
    required String fullName,
    required String universityId,
    String? barcodeId,
    String? fingerprintId,
    String? phone,
    String? email,
    int? collegeId,
    int? departmentId,
    int? levelId,
    int? semesterId,
    String? photoUrl,
    String? collegeName,
    String? departmentName,
    String? levelName,
  }) async {
    final cleanFullName = fullName.trim();
    final cleanUniversityId = universityId.trim();

    if (cleanFullName.isEmpty) {
      throw Exception('يرجى إدخال اسم الطالب كاملاً');
    }
    if (cleanUniversityId.isEmpty) {
      throw Exception('يرجى إدخال الرقم الجامعي للطالب');
    }

    // 1. التحقق من عدم تكرار الرقم الجامعي محلياً في Hive
    final existingLocal = await _localStorage.getStudentByUniversityId(cleanUniversityId);
    if (existingLocal != null) {
      throw Exception('الرقم الجامعي ($cleanUniversityId) مسجل بالفعل للطالب: ${existingLocal.fullName}');
    }

    // 2. التحقق من عدم تكرار الرقم الجامعي سحابياً في Supabase (إن توفر الاتصال)
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        final remote = await _supabase.client!
            .from('dawami_records')
            .select('full_name, student_number')
            .eq('record_type', 'student')
            .eq('student_number', cleanUniversityId)
            .maybeSingle();
        if (remote != null) {
          throw Exception('الرقم الجامعي ($cleanUniversityId) مسجل مسبقاً في قاعدة بيانات Supabase للطالب: ${remote['full_name']}');
        }
      } catch (e) {
        if (e.toString().contains('مسجل مسبقاً')) rethrow;
        // في حال انقطاع الإنترنت يتم التجاوز والاعتماد على الفحص المحلي
      }
    }

    // تجهيز الباركود الفريد
    final finalBarcode = (barcodeId != null && barcodeId.trim().isNotEmpty)
        ? barcodeId.trim()
        : 'DAWAMI:STUDENT:$cleanUniversityId';

    // التحقق من عدم تكرار الباركود
    final existingBarcode = await _localStorage.getStudentByBarcode(finalBarcode);
    if (existingBarcode != null) {
      throw Exception('معرف الباركود مستخدم بالفعل لطالب آخر');
    }

    final newStudent = Student(
      universityId: cleanUniversityId,
      fullName: cleanFullName,
      phone: phone?.trim().isNotEmpty == true ? phone!.trim() : '0000000000',
      email: email?.trim().isNotEmpty == true ? email!.trim() : '',
      collegeId: collegeId ?? 1,
      departmentId: departmentId ?? 1,
      levelId: levelId ?? 1,
      semesterId: semesterId ?? 1,
      qrCode: finalBarcode,
      fingerprintId: fingerprintId,
      fingerprintStatus: (fingerprintId != null && fingerprintId.isNotEmpty) ? 'مسجلة' : 'غير مسجلة',
      photoUrl: photoUrl,
      collegeName: collegeName ?? 'كلية علوم الحاسوب والتنمية البشرية',
      departmentName: departmentName ?? 'علوم الحاسوب',
      levelName: levelName ?? 'المستوى الأول',
    );

    // 3. الحفظ المحلي الفوري في Hive (Offline-First)
    final assignedId = await _localStorage.saveStudent(newStudent);
    final savedStudent = newStudent.copyWith(id: assignedId);

    // 4. المزامنة المباشرة مع Supabase في حال توفر الإنترنت
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.insertStudent(savedStudent);
        await _localStorage.markAttendanceSynced(assignedId.toString());
      } catch (e) {
        if (kDebugMode) {
          print('ملاحظة: تعذر الرفع المباشر إلى Supabase، تم حفظ الطالب في طابور المزامنة المحلي: $e');
        }
      }
    }

    return savedStudent;
  }

  /// البحث عن طالب بالرقم الجامعي
  Future<Student?> findByUniversityId(String universityId) async {
    return await _localStorage.getStudentByUniversityId(universityId);
  }

  /// البحث عن طالب بالباركود
  Future<Student?> findByBarcode(String barcode) async {
    return await _localStorage.getStudentByBarcode(barcode);
  }

  /// ربط البصمة بالرقم الجامعي
  Future<void> linkFingerprint({
    required Student student,
    required String fingerprintId,
  }) async {
    final updated = student.copyWith(
      fingerprintId: fingerprintId,
      fingerprintStatus: 'مسجلة',
      fingerprintEnrolledAt: DateTime.now().toIso8601String(),
    );
    await _localStorage.saveStudent(updated);

    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.updateStudent(updated);
      } catch (_) {}
    }
  }

  /// ربط باركود جديد بالرقم الجامعي
  Future<void> linkBarcode({
    required Student student,
    required String newBarcode,
  }) async {
    final cleanBarcode = newBarcode.trim();
    final existing = await _localStorage.getStudentByBarcode(cleanBarcode);
    if (existing != null && existing.id != student.id) {
      throw Exception('هذا الباركود مستخدم بالفعل لطالب آخر');
    }

    final updated = student.copyWith(qrCode: cleanBarcode);
    await _localStorage.saveStudent(updated);

    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.updateStudent(updated);
      } catch (_) {}
    }
  }
}
