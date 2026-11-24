import 'dart:async';
import '../../data/local/hive_helper.dart';
import '../../data/models/student.dart';
import '../../data/models/attendance_record.dart';

/// خدمة التخزين المحلي (LocalStorageService)
/// مسؤولة عن إدارة التخزين المحلي الآمن والسريع باستخدام Hive
/// لحفظ بيانات الطلاب وسجلات الحضور محلياً وضمان استمرار العمل دون إنترنت (Offline-First)
class LocalStorageService {
  static final LocalStorageService instance = LocalStorageService._init();
  final HiveHelper _hive = HiveHelper.instance;

  LocalStorageService._init();

  /// تهيئة صناديق Hive
  Future<void> init([String? customDir]) async {
    await _hive.init(customDir);
  }

  bool get isInitialized => _hive.isInitialized;
  int get studentsCount => _hive.studentsCount;
  int get attendanceCount => _hive.attendanceCount;

  // ==========================================
  // --- إدارة الطلاب محلياً في Hive ---
  // ==========================================

  /// جلب جميع الطلاب المحفوظين محلياً
  Future<List<Student>> getStudents({String? query, int? collegeId, String? status}) async {
    return await _hive.getStudents(query: query, collegeId: collegeId, status: status);
  }

  /// البحث عن طالب بواسطة الرقم الجامعي
  Future<Student?> getStudentByUniversityId(String universityId) async {
    return await _hive.getStudentByUniversityId(universityId);
  }

  /// البحث عن طالب بواسطة الباركود أو رمز QR
  Future<Student?> getStudentByBarcode(String barcode) async {
    return await _hive.getStudentByQrOrBarcode(barcode);
  }

  Future<bool> hasActiveFingerprintForStudent(Student student) async {
    return await _hive.hasActiveFingerprintForStudent(student);
  }

  /// حفظ أو تحديث طالب محلياً
  Future<int> saveStudent(Student student) async {
    if (student.id != null) {
      await _hive.updateStudent(student);
      return student.id!;
    } else {
      return await _hive.insertStudent(student);
    }
  }

  /// حذف طالب محلياً
  Future<int> deleteStudent(int id) async {
    return await _hive.deleteStudent(id);
  }

  // ==========================================
  // --- إدارة سجلات الحضور محلياً في Hive ---
  // ==========================================

  /// حفظ سجل حضور محلياً في Hive وضمه لطابور المزامنة
  Future<String> saveAttendance({
    required int studentId,
    required int sessionId,
    required String method,
    required String status,
    String? deviceId,
  }) async {
    return await _hive.recordAttendance(
      studentId: studentId,
      sessionId: sessionId,
      method: method,
      status: status,
      deviceId: deviceId,
    );
  }

  /// جلب سجلات الحضور المحفوظة محلياً
  Future<List<AttendanceRecord>> getAttendanceRecords({
    int? sessionId,
    String? date,
    String? method,
  }) async {
    return await _hive.getAttendanceRecords(
      sessionId: sessionId,
      date: date,
      method: method,
    );
  }

  /// جلب السجلات غير المزامنة (التي تنتظر الرفع إلى Supabase)
  Future<List<AttendanceRecord>> getPendingAttendanceRecords() async {
    final all = await _hive.getAttendanceRecords();
    return all.where((r) => !r.isSynced).toList();
  }

  /// عدد سجلات الحضور التي تنتظر المزامنة
  Future<int> getPendingAttendanceCount() async {
    final pending = await getPendingAttendanceRecords();
    return pending.length;
  }

  /// تعليم سجل كـ "تمت المزامنة" بعد التأكد من نجاح رفعه إلى Supabase
  Future<void> markAttendanceSynced(String recordId) async {
    await _hive.markRecordAsSynced('attendance', recordId);
  }

  Future<void> markStudentSynced(String recordId) async {
    await _hive.markRecordAsSynced('students', recordId);
  }

  /// تعليم جميع عناصر طابور المزامنة كمزامنة
  Future<int> markAllQueueItemsAsSynced() async {
    return await _hive.markAllQueueItemsAsSynced();
  }

  /// جلب إعداد محلي
  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    return await _hive.getSetting(key, defaultValue: defaultValue);
  }

  /// حفظ إعداد محلي
  Future<void> setSetting(String key, String value) async {
    await _hive.setSetting(key, value);
  }
}
