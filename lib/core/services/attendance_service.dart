import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/student.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/biometric_models.dart';
import '../../data/remote/supabase_service.dart';
import '../../core/utils/date_helper.dart';
import 'local_storage_service.dart';
import 'mobile_attendance_service.dart';
import 'qr_code_service.dart';

enum AttendanceActionType {
  auto,
  checkIn,
  checkOut,
}

class AttendanceService {
  static final AttendanceService instance = AttendanceService._init();
  static const _uuid = Uuid();

  final LocalStorageService _localStorage = LocalStorageService.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  AttendanceService._init();

  int calculateDelayMinutes(DateTime checkInTime, {int startHour = 8, int startMinute = 30}) {
    final scheduledStart = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      startHour,
      startMinute,
    );

    if (checkInTime.isAfter(scheduledStart)) {
      return checkInTime.difference(scheduledStart).inMinutes;
    }
    return 0;
  }

  Future<AttendanceRecord> recordAttendanceOrDeparture({
    required Student student,
    required String method, // 'fingerprint', 'face', 'mobile', 'barcode_qr', 'manual'
    AttendanceActionType actionType = AttendanceActionType.auto,
    String? deviceId,
    String? deviceName,
    String? locationName,
    double? latitude,
    double? longitude,
    String? notes,
    String? verifiedFingerprintId,
  }) async {
    // 1. التحقق من حالة الطالب
    if (student.status != 'نشط') {
      throw Exception('عذراً، الطالب غير نشط وحالته الحالية في النظام: (${student.status})');
    }

    // 1.1 التحقق من توافق وسيلة تسجيل الحضور مع الوسيلة المعتمدة للطالب
    if (!student.allowsAttendanceMethod(method)) {
      throw Exception(
        'عذراً، وسيلة الحضور المستخدمة غير مصرح بها لهذا الطالب. '
        'الوسيلة المعتمدة للطالب هي: (${student.attendanceMethodDisplay})',
      );
    }

    // 2. التحقق من وسيلة البصمة
    if (method.trim().toLowerCase().startsWith('fingerprint')) {
      final isVerified = (verifiedFingerprintId == null || verifiedFingerprintId == student.fingerprintId) &&
          await _localStorage.hasActiveFingerprintForStudent(student);
      if (!isVerified) {
        throw Exception(fingerprintNotActivatedMessage);
      }
    }

    // 3. التحقق من وسيلة الوجه
    if (method.trim().toLowerCase() == 'face') {
      if (!student.faceRegistered) {
        throw Exception('عذراً، الطالب ليس لديه بصمة وجه مسجلة في النظام');
      }
    }

    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final nowIso = now.toIso8601String();

    // 4. استرجاع سجلات الحضور الخاصة باليوم
    final todayRecords = await _localStorage.getAttendanceRecords(date: todayStr);
    AttendanceRecord? studentTodayRecord;

    for (final rec in todayRecords) {
      if (rec.studentId == student.id ||
          (rec.universityId != null && rec.universityId == student.universityId)) {
        studentTodayRecord = rec;
        break;
      }
    }

    // --- حالة الانصراف (Check-Out) ---
    final bool shouldCheckOut = (actionType == AttendanceActionType.checkOut) ||
        (actionType == AttendanceActionType.auto &&
            studentTodayRecord != null &&
            studentTodayRecord.checkOut == null);

    if (shouldCheckOut) {
      if (studentTodayRecord == null) {
        throw Exception('لا يمكن تسجيل الانصراف للطالب (${student.fullName}) لعدم وجود تسجيل حضور سابق في هذا اليوم');
      }

      if (studentTodayRecord.checkOut != null) {
        final outTime = DateHelper.formatTimeString(studentTodayRecord.checkOut!);
        throw Exception('تم تسجيل انصراف الطالب (${student.fullName}) مسبقاً اليوم عند ($outTime)');
      }

      int stayMinutes = 0;
      try {
        final inTime = DateTime.parse(studentTodayRecord.checkIn);
        stayMinutes = now.difference(inTime).inMinutes;
        if (stayMinutes < 0) stayMinutes = 0;
      } catch (_) {}

      final updatedRecord = studentTodayRecord.copyWith(
        checkOut: nowIso,
        status: 'تم الانصراف',
        durationMinutes: stayMinutes,
        notes: notes ?? studentTodayRecord.notes ?? 'انصراف نظامي',
        isSynced: false,
      );

      // حفظ التحديث محلياً في Hive
      await _localStorage.saveAttendanceRecordDirect(updatedRecord);

      // مزامنة مع Supabase إذا توفر الإنترنت
      if (_supabase.isConfigured && _supabase.client != null) {
        try {
          await _supabase.client!
              .from('dawami_records')
              .upsert(updatedRecord.toDawamiRecord(), onConflict: 'record_type,record_key');
          await _localStorage.markAttendanceSynced(updatedRecord.id);
        } catch (_) {}
      }

      return updatedRecord;
    }

    // --- حالة الحضور (Check-In) ---
    if (studentTodayRecord != null) {
      if (studentTodayRecord.checkOut == null) {
        final inTime = DateHelper.formatTimeString(studentTodayRecord.checkIn);
        throw Exception('الطالب (${student.fullName}) مسجل حضور بالفعل اليوم عند ($inTime) وهو متواجد داخل الحرم الجامعي');
      } else {
        final inTime = DateHelper.formatTimeString(studentTodayRecord.checkIn);
        final outTime = DateHelper.formatTimeString(studentTodayRecord.checkOut!);
        throw Exception('أتم الطالب (${student.fullName}) الحضور والانصراف لهذا اليوم (دخول: $inTime | خروج: $outTime)');
      }
    }

    // احتساب التأخير الصباحي (الافتراضي: 08:30 صباحاً)
    final delayMinutes = calculateDelayMinutes(now);
    final status = 'حاضر';

    final recordId = _uuid.v4();

    final newRecord = AttendanceRecord(
      id: recordId,
      studentId: student.id ?? 0,
      sessionId: 1,
      checkIn: nowIso,
      method: method,
      status: status,
      deviceId: deviceId ?? 'TERMINAL-01',
      deviceName: deviceName ?? 'محطة الحضور الجامعية',
      locationName: locationName ?? 'الحرم الجامعي الرئيسي',
      latitude: latitude,
      longitude: longitude,
      durationMinutes: 0,
      delayMinutes: delayMinutes,
      notes: notes,
      createdAt: nowIso,
      studentName: student.fullName,
      universityId: student.universityId,
      classroomName: locationName ?? 'البوابة الجامعية',
      isSynced: false,
    );

    // الحفظ المحلي الفوري في Hive
    await _localStorage.saveAttendanceRecordDirect(newRecord);

    // محاولة الرفع السحابي لـ Supabase
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.client!
            .from('dawami_records')
            .upsert(newRecord.toDawamiRecord(), onConflict: 'record_type,record_key');
        await _localStorage.markAttendanceSynced(recordId);
      } catch (e) {
        if (kDebugMode) print('ملاحظة: تم الحفظ محلياً في Hive وسيرفع لاحقاً لـ Supabase: $e');
      }
    }

    return newRecord;
  }

  // --- دوال مساعدة وتوافق كامل مع النظام ---

  Future<AttendanceRecord> recordAttendance({
    required Student student,
    required String method,
    AttendanceActionType actionType = AttendanceActionType.auto,
    int? sessionId,
    int? lectureId,
    String? lectureName,
    String? classroomName,
    String? deviceId,
    String? deviceName,
    String? locationName,
    String? verifiedFingerprintId,
  }) async {
    return await recordAttendanceOrDeparture(
      student: student,
      method: method,
      actionType: actionType,
      deviceId: deviceId,
      deviceName: deviceName,
      locationName: locationName ?? classroomName ?? lectureName,
      verifiedFingerprintId: verifiedFingerprintId,
    );
  }

  Future<AttendanceRecord> recordAttendanceByBarcode({
    required String barcode,
    AttendanceActionType actionType = AttendanceActionType.auto,
    int? sessionId,
    String? lectureName,
    String? classroomName,
    String? deviceId,
    String? deviceName,
    String? locationName,
  }) async {
    final cleanCode = QrCodeService.instance.extractUniversityId(barcode);
    final student = await _localStorage.getStudentByBarcode(cleanCode) ??
        await _localStorage.getStudentByUniversityId(cleanCode);

    if (student == null) {
      throw Exception('لم يتم العثور على طالب مسجل بهذا الباركود أو الرمز: $cleanCode');
    }

    return await recordAttendanceOrDeparture(
      student: student,
      method: 'barcode',
      actionType: actionType,
      deviceId: deviceId ?? 'BARCODE-SCANNER',
      deviceName: deviceName ?? 'قارئ الباركود USB',
      locationName: locationName ?? classroomName ?? lectureName ?? 'مدخل الكلية',
    );
  }

  Future<AttendanceRecord> recordAttendanceByFingerprint({
    required Student student,
    required String verifiedFingerprintId,
    AttendanceActionType actionType = AttendanceActionType.auto,
    int? sessionId,
    String? lectureName,
    String? classroomName,
    String? deviceId,
    String? deviceName,
    String? locationName,
  }) async {
    return await recordAttendanceOrDeparture(
      student: student,
      method: 'fingerprint',
      verifiedFingerprintId: verifiedFingerprintId,
      actionType: actionType,
      deviceId: deviceId ?? 'ZK-F18',
      deviceName: deviceName ?? 'جهاز بصمة ZKTeco F18',
      locationName: locationName ?? classroomName ?? lectureName ?? 'البوابة الرئيسية',
    );
  }

  Future<AttendanceRecord> recordAttendanceByFace({
    required Student student,
    AttendanceActionType actionType = AttendanceActionType.auto,
    String? deviceId,
    String? deviceName,
    String? locationName,
  }) async {
    return await recordAttendanceOrDeparture(
      student: student,
      method: 'face',
      actionType: actionType,
      deviceId: deviceId ?? 'CAMERA-KIOSK',
      deviceName: deviceName ?? 'كاميرا التعرف على الوجه',
      locationName: locationName ?? 'صالة الكلية',
    );
  }

  Future<AttendanceRecord> recordAttendanceByMobile({
    required Student student,
    required String deviceUuid,
    AttendanceActionType actionType = AttendanceActionType.auto,
    String? deviceModel,
  }) async {
    // 1. التحقق من اقتران الهاتف
    final isAuthorized = await MobileAttendanceService.instance.isDeviceAuthorized(student.universityId, deviceUuid);
    if (!isAuthorized) {
      throw Exception('هذا الهاتف غير مصرح له بتسجيل الحضور لحساب الطالب (${student.fullName})');
    }

    // 2. التحقق من النطاق الجغرافي GPS وكشف التلاعب
    final geoResult = await MobileAttendanceService.instance.verifyStudentLocation();
    if (!geoResult.isInsidePerimeter) {
      throw Exception(geoResult.message);
    }

    return await recordAttendanceOrDeparture(
      student: student,
      method: 'mobile',
      actionType: actionType,
      deviceId: 'MOB-$deviceUuid',
      deviceName: deviceModel ?? 'هاتف الطالب المحمول',
      locationName: geoResult.nearestLocation?.locationName ?? 'النطاق الجغرافي للجامعة',
      notes: 'تم التحقق من GPS - المسافة: ${geoResult.distanceMeters.round()} م',
    );
  }

  Future<AttendanceRecord> recordManualAttendanceOverride({
    required Student student,
    required String status, // 'حاضر', 'متأخر', 'غائب', 'منصرف'
    required String adminUserName,
    String? notes,
  }) async {
    return await recordAttendanceOrDeparture(
      student: student,
      method: 'manual',
      actionType: status == 'منصرف' ? AttendanceActionType.checkOut : AttendanceActionType.checkIn,
      deviceId: 'ADMIN-OVERRIDE',
      deviceName: 'تعديل إداري استثنائي',
      locationName: 'شؤون الطلاب',
      notes: 'تعديل بواسطة: $adminUserName | $notes',
    );
  }
}
