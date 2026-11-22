import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/student.dart';
import '../../data/models/attendance_record.dart';
import '../../data/remote/supabase_service.dart';
import '../../core/utils/date_helper.dart';
import 'local_storage_service.dart';

/// خدمة تسجيل الحضور (AttendanceService)
/// مسؤولة عن:
/// 1. التحقق من أن الطالب مسجل في النظام.
/// 2. استخراج اسم الطالب ورقمه الجامعي.
/// 3. تسجيل حضور الطالب بالبصمة الحيوية أو الباركود مع تحديد التاريخ والوقت بدقة.
/// 4. منع تكرار تسجيل الحضور في نفس المحاضرة أو الفترة الزمنية.
/// 5. الحفظ الفوري في Hive ومحاولة المزامنة مع Supabase دون فقدان أي سجل.
class AttendanceService {
  static final AttendanceService instance = AttendanceService._init();
  static const _uuid = Uuid();

  final LocalStorageService _localStorage = LocalStorageService.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  AttendanceService._init();

  /// تسجيل الحضور لطالب مسجل
  Future<AttendanceRecord> recordAttendance({
    required Student student,
    required String method, // 'fingerprint' أو 'barcode' أو 'qr'
    int? sessionId,
    int? lectureId,
    String? lectureName,
    String? classroomName,
    String? deviceId,
  }) async {
    // 1. التحقق من أن الطالب مسجل ونشط
    if (student.status != 'نشط') {
      throw Exception('عذراً، الطالب غير نشط وحالته الحالية: (${student.status})');
    }

    final targetSessionId = sessionId ?? lectureId ?? 1;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final nowIso = now.toIso8601String();

    // 2. فحص ومنع تكرار الحضور في نفس المحاضرة أو اليوم
    final existingRecords = await _localStorage.getAttendanceRecords(
      sessionId: targetSessionId,
      date: todayStr,
    );

    for (final rec in existingRecords) {
      if (rec.studentId == student.id ||
          (rec.universityId != null && rec.universityId == student.universityId)) {
        if (rec.checkOut == null) {
          // إذا كان قد سجل حضوراً ولم ينصرف، نسجل له الانصراف
          final updated = AttendanceRecord(
            id: rec.id,
            studentId: rec.studentId,
            sessionId: rec.sessionId,
            checkIn: rec.checkIn,
            checkOut: nowIso,
            method: method,
            status: 'تم الانصراف',
            deviceId: deviceId ?? 'ZK-F18',
            createdAt: rec.createdAt,
            studentName: student.fullName,
            universityId: student.universityId,
            lectureName: lectureName ?? rec.lectureName,
            classroomName: classroomName ?? rec.classroomName,
            isSynced: false,
          );
          await _localStorage.saveAttendance(
            studentId: student.id!,
            sessionId: targetSessionId,
            method: method,
            status: 'تم الانصراف',
            deviceId: deviceId,
          );
          return updated;
        } else {
          final inFormatted = DateHelper.formatTimeString(rec.checkIn);
          final outFormatted = DateHelper.formatTimeString(rec.checkOut!);
          throw Exception(
            'تم تسجيل حضور الطالب (${student.fullName}) مسبقاً في هذه المحاضرة عند ($inFormatted) والانصراف ($outFormatted)',
          );
        }
      }
    }

    // 3. إنشاء معرف فريد للعملية UUID لمنع التكرار نهائياً
    final recordId = _uuid.v4();

    // 4. الحفظ المحلي الفوري في قاعدة بيانات Hive (Offline-First)
    await _localStorage.saveAttendance(
      studentId: student.id!,
      sessionId: targetSessionId,
      method: method,
      status: 'حاضر',
      deviceId: deviceId,
    );

    final record = AttendanceRecord(
      id: recordId,
      studentId: student.id!,
      sessionId: targetSessionId,
      checkIn: nowIso,
      method: method,
      status: 'حاضر',
      deviceId: deviceId ?? 'ZK-F18',
      createdAt: nowIso,
      studentName: student.fullName,
      universityId: student.universityId,
      lectureName: lectureName ?? 'هياكل البيانات والخوارزميات',
      classroomName: classroomName ?? 'قاعة الخوارزمي',
      isSynced: false,
    );

    // 5. محاولة الرفع الفوري إلى Supabase إذا كان الإنترنت متوفراً
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.recordAttendance(
          id: recordId,
          studentId: student.id!,
          sessionId: targetSessionId,
          method: method,
          status: 'حاضر',
          deviceId: deviceId ?? 'ZK-F18',
          checkIn: nowIso,
        );
        // تم الرفع بنجاح -> تعليم السجل كـ مزامن
        await _localStorage.markAttendanceSynced(recordId);
      } catch (e) {
        if (kDebugMode) {
          print('ملاحظة: تعذر الرفع المباشر إلى Supabase، تم حفظ الحضور محلياً بنجاح في Hive: $e');
        }
      }
    }

    return record;
  }

  /// تسجيل الحضور بواسطة مسح الباركود
  Future<AttendanceRecord> recordAttendanceByBarcode({
    required String barcode,
    int? sessionId,
    String? lectureName,
    String? classroomName,
  }) async {
    final student = await _localStorage.getStudentByBarcode(barcode);
    if (student == null) {
      throw Exception('لم يتم العثور على طالب مسجل بهذا الباركود');
    }
    return await recordAttendance(
      student: student,
      method: 'barcode',
      sessionId: sessionId,
      lectureName: lectureName,
      classroomName: classroomName,
    );
  }

  /// تسجيل الحضور بواسطة قارئ البصمة البيومترية
  Future<AttendanceRecord> recordAttendanceByFingerprint({
    required Student student,
    int? sessionId,
    String? lectureName,
    String? classroomName,
  }) async {
    return await recordAttendance(
      student: student,
      method: 'fingerprint',
      sessionId: sessionId,
      lectureName: lectureName,
      classroomName: classroomName,
    );
  }
}
