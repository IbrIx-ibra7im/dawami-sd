import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/academic_models.dart';
import '../models/lecture.dart';
import '../models/sync_and_auth_models.dart';
import '../models/biometric_models.dart';
import '../remote/supabase_service.dart';
import '../../core/utils/date_helper.dart';

class HiveHelper {
  static final HiveHelper instance = HiveHelper._init();
  static const _uuid = Uuid();

  late Box<Map> _studentsBox;
  late Box<Map> _attendanceBox;
  late Box<Map> _sessionsBox;
  late Box<Map> _lecturesBox;
  late Box<Map> _collegesBox;
  late Box<Map> _departmentsBox;
  late Box<Map> _levelsBox;
  late Box<Map> _semestersBox;
  late Box<Map> _classroomsBox;
  late Box<Map> _syncQueueBox;
  late Box<Map> _auditLogsBox;
  late Box<String> _settingsBox;
  late Box<Map> _fingerprintsBox;
  late Box<Map> _verificationLogsBox;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  HiveHelper._init();

  /// Initialize Hive and open all boxes
  Future<void> init([String? customDir]) async {
    if (_isInitialized) return;

    if (customDir != null && customDir.isNotEmpty) {
      try {
        Hive.init(customDir);
      } catch (_) {}
    } else {
      try {
        await Hive.initFlutter();
      } catch (_) {
        try {
          Hive.init(Directory.systemTemp.path);
        } catch (_) {}
      }
    }

    _studentsBox = await Hive.openBox<Map>('students_box');
    _attendanceBox = await Hive.openBox<Map>('attendance_box');
    _sessionsBox = await Hive.openBox<Map>('sessions_box');
    _lecturesBox = await Hive.openBox<Map>('lectures_box');
    _collegesBox = await Hive.openBox<Map>('colleges_box');
    _departmentsBox = await Hive.openBox<Map>('departments_box');
    _levelsBox = await Hive.openBox<Map>('levels_box');
    _semestersBox = await Hive.openBox<Map>('semesters_box');
    _classroomsBox = await Hive.openBox<Map>('classrooms_box');
    _syncQueueBox = await Hive.openBox<Map>('sync_queue_box');
    _auditLogsBox = await Hive.openBox<Map>('audit_logs_box');
    _settingsBox = await Hive.openBox<String>('settings_box');
    _fingerprintsBox = await Hive.openBox<Map>('fingerprints_box');
    _verificationLogsBox = await Hive.openBox<Map>('verification_logs_box');

    _isInitialized = true;

    // Ensure only Faculty of Computer Science & Human Development exists in colleges
    for (var key in _collegesBox.keys.toList()) {
      if (key != 1) {
        await _collegesBox.delete(key);
      }
    }

    // Seed default data if empty or needs update to Dongola Faculty of Computer Science
    final firstCollege = _collegesBox.get(1);
    if (_collegesBox.isEmpty || _studentsBox.isEmpty || firstCollege?['name'] != 'كلية علوم الحاسوب والتنمية البشرية') {
      await _seedDefaultData();
    }

    // Ensure university name is University of Dongola
    final currentUni = _settingsBox.get('university_name', defaultValue: '');
    if (currentUni == null || currentUni.isEmpty || currentUni.contains('الخرطوم')) {
      await _settingsBox.put('university_name', 'جامعة دنقلا - كلية علوم الحاسوب والتنمية البشرية');
    }

    // ملاحظة: تم إيقاف المزامنة السحابية التلقائية عند بدء التشغيل
    // لتفادي أخطاء صلاحيات Supabase (42501). المزامنة المحلية هي الافتراضية.
    // يمكن للمستخدم تفعيل المزامنة السحابية يدوياً من شاشة الإعدادات.
  }

  Future<void> _seedDefaultData() async {
    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    // 1. College (Dongola University - Faculty of Computer Science & Human Development)
    final colleges = [
      {'id': 1, 'name': 'كلية علوم الحاسوب والتنمية البشرية', 'created_at': now},
    ];
    await _collegesBox.clear();
    for (var c in colleges) {
      await _collegesBox.put(c['id'], c);
    }

    // 2. Departments of Faculty of Computer Science & Human Development
    final departments = [
      {'id': 1, 'college_id': 1, 'name': 'علوم الحاسوب'},
      {'id': 2, 'college_id': 1, 'name': 'تقنية المعلومات'},
      {'id': 3, 'college_id': 1, 'name': 'نظم المعلومات'},
      {'id': 4, 'college_id': 1, 'name': 'التنمية البشرية وتطبيقات الحاسوب'},
      {'id': 5, 'college_id': 1, 'name': 'هندسة البرمجيات'},
    ];
    for (var d in departments) {
      await _departmentsBox.put(d['id'], d);
    }

    // 3. Academic Levels
    final levels = [
      {'id': 1, 'name': 'المستوى الأول', 'order_no': 1},
      {'id': 2, 'name': 'المستوى الثاني', 'order_no': 2},
      {'id': 3, 'name': 'المستوى الثالث', 'order_no': 3},
      {'id': 4, 'name': 'المستوى الرابع', 'order_no': 4},
    ];
    for (var l in levels) {
      await _levelsBox.put(l['id'], l);
    }

    // 4. Semesters
    final semesters = [
      {'id': 1, 'name': 'الفصل الدراسي الأول 2026/2027', 'start_date': '2026-09-01', 'end_date': '2027-01-31'},
    ];
    for (var s in semesters) {
      await _semestersBox.put(s['id'], s);
    }

    // 5. Classrooms
    final classrooms = [
      {'id': 1, 'name': 'قاعة الخوارزمي', 'building': 'مبنى أ', 'floor': 'الطابق الأول', 'capacity': 80},
      {'id': 2, 'name': 'مختبر الشبكات', 'building': 'مبنى الحاسوب', 'floor': 'الطابق الأرضي', 'capacity': 40},
      {'id': 3, 'name': 'مدرج ابن سينا', 'building': 'مبنى العلوم', 'floor': 'الطابق الثاني', 'capacity': 150},
    ];
    for (var cr in classrooms) {
      await _classroomsBox.put(cr['id'], cr);
    }

    // 6. Lectures
    final lectures = [
      {
        'id': 1,
        'course_id': 1,
        'classroom_id': 1,
        'instructor': 'د. عبدالله أحمد',
        'day_of_week': 'السبت',
        'start_time': '08:00',
        'end_time': '10:00',
        'course_name': 'هياكل البيانات والخوارزميات',
        'classroom_name': 'قاعة الخوارزمي',
      },
      {
        'id': 2,
        'course_id': 2,
        'classroom_id': 2,
        'instructor': 'د. مريم حسين',
        'day_of_week': 'الأحد',
        'start_time': '10:00',
        'end_time': '12:00',
        'course_name': 'أنظمة قواعد البيانات',
        'classroom_name': 'مختبر الشبكات',
      },
    ];
    for (var lec in lectures) {
      await _lecturesBox.put(lec['id'], lec);
    }

    // 7. Active Session
    await _sessionsBox.put(1, {
      'id': 1,
      'lecture_id': 1,
      'session_date': today,
      'status': 'نشطة',
      'lecture_name': 'هياكل البيانات والخوارزميات',
      'classroom_name': 'قاعة الخوارزمي',
      'instructor': 'د. عبدالله أحمد',
    });

    // تبدأ صناديق Hive فارغة من الطلاب وسجلات الحضور لتمكين المستخدم من إضافة بياناته الحقيقية
  }

  /// تفريغ وحذف جميع الطلاب وسجلات الحضور وطابور المزامنة نهائياً
  Future<void> clearAllStudentsAndAttendance() async {
    if (!_isInitialized) return;
    await _studentsBox.clear();
    await _attendanceBox.clear();
    await _syncQueueBox.clear();
  }

  // ==========================================
  // --- STUDENTS OPERATIONS (Hive + Supabase) ---
  // ==========================================

  Future<List<Student>> getStudents({String? query, int? collegeId, String? status}) async {
    if (!_isInitialized) return [];
    final list = <Student>[];

    for (var key in _studentsBox.keys) {
      final raw = _studentsBox.get(key);
      if (raw == null) continue;
      final map = Map<String, dynamic>.from(raw);
      final student = Student.fromMap(map);

      if (collegeId != null && student.collegeId != collegeId) continue;
      if (status != null && status != 'الكل' && student.status != status) continue;

      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final match = student.fullName.toLowerCase().contains(q) ||
            student.universityId.toLowerCase().contains(q) ||
            student.phone.contains(q);
        if (!match) continue;
      }

      list.add(student);
    }

    list.sort((a, b) => b.id?.compareTo(a.id ?? 0) ?? 0);
    return list;
  }

  Future<Student?> getStudentById(int id) async {
    final raw = _studentsBox.get(id) ?? _studentsBox.get(id.toString());
    if (raw != null) return Student.fromMap(Map<String, dynamic>.from(raw));
    for (var key in _studentsBox.keys) {
      final item = _studentsBox.get(key);
      if (item != null && (item['id'] == id || item['id']?.toString() == id.toString())) {
        return Student.fromMap(Map<String, dynamic>.from(item));
      }
    }
    return null;
  }

  Future<Student?> getStudentByUniversityId(String universityId) async {
    final clean = universityId.trim().toLowerCase();
    for (var key in _studentsBox.keys) {
      final raw = _studentsBox.get(key);
      if (raw == null) continue;
      final map = Map<String, dynamic>.from(raw);
      if (map['university_id']?.toString().trim().toLowerCase() == clean) {
        return Student.fromMap(map);
      }
    }
    return null;
  }

  Future<Student?> getStudentByQrOrBarcode(String rawCode) async {
    var code = rawCode.trim();
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < 10; i++) {
      code = code.replaceAll(arabicDigits[i], '$i');
    }
    if (code.contains('DAWAMI:STUDENT:')) {
      code = code.replaceAll('DAWAMI:STUDENT:', '').trim();
    }
    final digitsOnly = code.replaceAll(RegExp(r'[^0-9]'), '');

    for (var key in _studentsBox.keys) {
      final raw = _studentsBox.get(key);
      if (raw == null) continue;
      final map = Map<String, dynamic>.from(raw);
      final s = Student.fromMap(map);

      final uniId = s.universityId.trim();
      final uniDigits = uniId.replaceAll(RegExp(r'[^0-9]'), '');

      if (s.qrCode == rawCode.trim() ||
          s.qrCode.contains(code) ||
          uniId == code ||
          (digitsOnly.isNotEmpty && uniDigits == digitsOnly) ||
          s.phone.contains(code)) {
        return s;
      }
    }
    return null;
  }

  Future<int> insertStudent(Student student) async {
    // Determine next integer ID safely across int and String keys
    int nextId = 1;
    for (var key in _studentsBox.keys) {
      if (key is int && key >= nextId) {
        nextId = key + 1;
      }
      final raw = _studentsBox.get(key);
      if (raw != null && raw['id'] is num) {
        final val = (raw['id'] as num).toInt();
        if (val >= nextId) nextId = val + 1;
      }
    }

    final assignedId = student.id ?? nextId;
    final newStudent = student.copyWith(id: assignedId);
    final map = newStudent.toMap();
    map['id'] = assignedId;
    await _studentsBox.put(assignedId, map);

    // Queue and push to Supabase
    await _queueSyncItem(
      operation: 'INSERT',
      tableName: 'students',
      recordId: assignedId.toString(),
      payload: map,
    );

    return assignedId;
  }

  Future<int> updateStudent(Student student) async {
    if (student.id == null) return 0;
    final map = student.toMap();
    map['id'] = student.id;
    await _studentsBox.put(student.id, map);
    // Remove duplicate string key if it exists
    await _studentsBox.delete(student.id.toString());

    await _queueSyncItem(
      operation: 'UPDATE',
      tableName: 'students',
      recordId: student.id.toString(),
      payload: map,
    );
    return 1;
  }

  Future<int> deleteStudent(int id) async {
    await _studentsBox.delete(id);
    await _studentsBox.delete(id.toString());
    for (var key in _studentsBox.keys.toList()) {
      final raw = _studentsBox.get(key);
      if (raw != null && (raw['id'] == id || raw['id']?.toString() == id.toString())) {
        await _studentsBox.delete(key);
      }
    }
    await _queueSyncItem(
      operation: 'DELETE',
      tableName: 'students',
      recordId: id.toString(),
      payload: {'id': id},
    );
    return 1;
  }

  Future<bool> linkBarcodeToStudent(int studentId, String newBarcode) async {
    final raw = _studentsBox.get(studentId);
    if (raw == null) return false;
    final map = Map<String, dynamic>.from(raw);
    map['qr_code'] = newBarcode.trim();
    await _studentsBox.put(studentId, map);

    await _queueSyncItem(
      operation: 'UPDATE',
      tableName: 'students',
      recordId: studentId.toString(),
      payload: map,
    );
    return true;
  }

  /// High-performance bulk student insert / update into Hive and Supabase
  Future<int> batchInsertOrUpdateStudents(List<Student> students) async {
    if (students.isEmpty) return 0;
    if (!_isInitialized) return 0;

    // 1. Index existing students in memory O(N) safely
    final existingMap = <String, int>{};
    int maxId = 0;
    for (var key in _studentsBox.keys) {
      final raw = _studentsBox.get(key);
      if (raw != null) {
        final uId = raw['university_id']?.toString().trim().toLowerCase();
        int? intKey;
        if (key is int) {
          intKey = key;
        } else if (raw['id'] is num) {
          intKey = (raw['id'] as num).toInt();
        } else {
          intKey = int.tryParse(key.toString());
        }
        if (intKey != null && intKey > maxId) {
          maxId = intKey;
        }
        if (uId != null && uId.isNotEmpty && intKey != null) {
          existingMap[uId] = intKey;
        }
      }
    }

    // 2. Prepare single batch map for putAll
    final batchMap = <int, Map>{};
    final syncList = <Map<String, dynamic>>[];

    for (final s in students) {
      final cleanUniId = s.universityId.trim().toLowerCase();
      final existingId = existingMap[cleanUniId];
      final targetId = existingId ?? (++maxId);
      final finalStudent = s.copyWith(id: targetId);
      final map = finalStudent.toMap();
      map['id'] = targetId;
      batchMap[targetId] = map;
      syncList.add(map);
      existingMap[cleanUniId] = targetId;
    }

    // 3. Single instant disk transaction in Hive
    await _studentsBox.putAll(batchMap);

    // 4. Batch push to Supabase in background without blocking UI
    if (SupabaseService.instance.isConfigured) {
      SupabaseService.instance.batchUpsertStudents(syncList).catchError((_) => false);
    }

    return students.length;
  }

  // ==========================================
  // --- ATTENDANCE OPERATIONS ---
  // ==========================================

  Future<String> recordAttendance({
    required int studentId,
    required int sessionId,
    required String method,
    required String status,
    String? deviceId,
  }) async {
    // 1. Idempotency Check & Check-out handling
    for (var key in _attendanceBox.keys) {
      final raw = _attendanceBox.get(key);
      if (raw == null) continue;
      final map = Map<String, dynamic>.from(raw);
      if (map['student_id'] == studentId && map['session_id'] == sessionId) {
        if (map['check_out'] == null) {
          final now = DateTime.now().toIso8601String();
          map['check_out'] = now;
          map['status'] = 'تم الانصراف';
          map['is_synced'] = 0;
          await _attendanceBox.put(key, map);

          await _queueSyncItem(
            operation: 'UPDATE',
            tableName: 'attendance',
            recordId: key.toString(),
            payload: map,
          );
          return key.toString();
        } else {
          final checkIn = map['check_in']?.toString() ?? '';
          final checkOut = map['check_out']?.toString() ?? '';
          final inStr = DateHelper.formatTimeString(checkIn);
          final outStr = DateHelper.formatTimeString(checkOut);
          throw Exception('تم تسجيل الحضور ($inStr) والانصراف ($outStr) مسبقاً لهذا اليوم');
        }
      }
    }

    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final student = await getStudentById(studentId);
    final sessionRaw = _sessionsBox.get(sessionId);
    final sessionMap = sessionRaw != null ? Map<String, dynamic>.from(sessionRaw) : {};

    final recordMap = {
      'id': id,
      'student_id': studentId,
      'session_id': sessionId,
      'check_in': now,
      'check_out': null,
      'method': method,
      'status': status,
      'device_id': deviceId ?? 'ZK-F18',
      'created_at': now,
      'is_synced': 0,
      'student_name': student?.fullName ?? '',
      'university_id': student?.universityId ?? '',
      'lecture_name': sessionMap['lecture_name'] ?? 'محاضرة',
      'classroom_name': sessionMap['classroom_name'] ?? 'قاعة عامة',
    };

    await _attendanceBox.put(id, recordMap);

    // Queue sync for Supabase
    await _queueSyncItem(
      operation: 'INSERT',
      tableName: 'attendance',
      recordId: id,
      payload: recordMap,
    );

    return id;
  }

  Future<List<AttendanceRecord>> getAttendanceRecords({
    int? sessionId,
    String? date,
    String? method,
  }) async {
    if (!_isInitialized) return [];
    final list = <AttendanceRecord>[];

    for (var key in _attendanceBox.keys) {
      final raw = _attendanceBox.get(key);
      if (raw == null) continue;
      final map = Map<String, dynamic>.from(raw);
      final r = AttendanceRecord.fromMap(map);

      if (sessionId != null && r.sessionId != sessionId) continue;
      if (date != null && !r.checkIn.startsWith(date)) continue;
      if (method != null && method != 'الكل' && r.method != method) continue;

      list.add(r);
    }

    list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
    return list;
  }

  Future<int> deleteMultipleStudents(List<int> ids) async {
    int count = 0;
    for (final id in ids) {
      count += await deleteStudent(id);
    }
    return count;
  }

  Future<int> deleteAttendanceRecord(String id) async {
    await _attendanceBox.delete(id);
    for (var key in _attendanceBox.keys.toList()) {
      final raw = _attendanceBox.get(key);
      if (raw != null && raw['id']?.toString() == id) {
        await _attendanceBox.delete(key);
      }
    }
    await _queueSyncItem(
      operation: 'DELETE',
      tableName: 'attendance',
      recordId: id,
      payload: {'id': id},
    );
    return 1;
  }

  Future<int> deleteMultipleAttendanceRecords(List<String> ids) async {
    int count = 0;
    for (final id in ids) {
      count += await deleteAttendanceRecord(id);
    }
    return count;
  }

  // ==========================================
  // --- ACADEMIC & SESSIONS HELPERS ---
  // ==========================================

  Future<List<College>> getColleges() async {
    if (!_isInitialized) return [];
    return _collegesBox.values.map((v) => College.fromMap(Map<String, dynamic>.from(v))).toList();
  }

  Future<List<Department>> getDepartments({int? collegeId}) async {
    if (!_isInitialized) return [];
    final list = _departmentsBox.values.map((v) => Department.fromMap(Map<String, dynamic>.from(v))).toList();
    if (collegeId != null) {
      return list.where((d) => d.collegeId == collegeId).toList();
    }
    return list;
  }

  Future<List<AcademicLevel>> getAcademicLevels() async {
    if (!_isInitialized) return [];
    return _levelsBox.values.map((v) => AcademicLevel.fromMap(Map<String, dynamic>.from(v))).toList();
  }

  Future<List<Semester>> getSemesters() async {
    if (!_isInitialized) return [];
    return _semestersBox.values.map((v) => Semester.fromMap(Map<String, dynamic>.from(v))).toList();
  }

  Future<List<Lecture>> getLectures() async {
    if (!_isInitialized) return [];
    return _lecturesBox.values.map((v) => Lecture.fromMap(Map<String, dynamic>.from(v))).toList();
  }

  Future<AttendanceSession?> getActiveSession() async {
    if (!_isInitialized || _sessionsBox.isEmpty) return null;
    final map = Map<String, dynamic>.from(_sessionsBox.values.first);
    return AttendanceSession.fromMap(map);
  }

  Future<void> saveSession(Map<String, dynamic> sessionMap) async {
    if (!_isInitialized) return;
    final id = (sessionMap['id'] as num?)?.toInt() ?? 1;
    await _sessionsBox.put(id, sessionMap);
  }

  // ==========================================
  // --- SYNC QUEUE & SUPABASE SYNCHRONIZATION ---
  // ==========================================

  Future<void> _queueSyncItem({
    required String operation,
    required String tableName,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    final nextId = _syncQueueBox.length + 1;
    final item = {
      'id': nextId,
      'operation': operation,
      'table_name': tableName,
      'record_id': recordId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'status': 'انتظار',
      'error': null,
    };
    await _syncQueueBox.put(nextId, item);

    // Try auto-syncing with Supabase immediately if connected
    if (SupabaseService.instance.isConfigured) {
      _processSingleSyncItem(SyncQueueItem.fromMap(item)).catchError((_) {});
    }
  }

  Future<void> _processSingleSyncItem(SyncQueueItem item) async {
    try {
      final success = await SupabaseService.instance.syncOperation(item);
      if (success) {
        final raw = _syncQueueBox.get(item.id);
        if (raw != null) {
          final map = Map<String, dynamic>.from(raw);
          map['status'] = 'تمت';
          map['attempts'] = (map['attempts'] ?? 0) + 1;
          await _syncQueueBox.put(item.id, map);
        }
      }
    } catch (_) {}
  }

  Future<List<SyncQueueItem>> getSyncQueueItems() async {
    final list = _syncQueueBox.values.map((v) => SyncQueueItem.fromMap(Map<String, dynamic>.from(v))).toList();
    list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return list;
  }

  Future<int> getPendingSyncCount() async {
    return _syncQueueBox.values.where((v) => v['status'] != 'تمت').length;
  }

  Future<void> updateSyncItemStatus(int id, String status, {String? error, int? attempts}) async {
    final raw = _syncQueueBox.get(id);
    if (raw != null) {
      final map = Map<String, dynamic>.from(raw);
      map['status'] = status;
      if (error != null) map['error'] = error;
      if (attempts != null) map['attempts'] = attempts;
      await _syncQueueBox.put(id, map);
    }
  }

  Future<void> markRecordAsSynced(String tableName, String recordId) async {
    if (tableName == 'attendance') {
      final raw = _attendanceBox.get(recordId);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw);
        map['is_synced'] = 1;
        await _attendanceBox.put(recordId, map);
      }
    }
  }

  Future<int> markAllQueueItemsAsSynced() async {
    int count = 0;
    for (var key in _syncQueueBox.keys.toList()) {
      final raw = _syncQueueBox.get(key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw);
        map['status'] = 'تمت';
        map['error'] = null;
        await _syncQueueBox.put(key, map);

        final tableName = map['table_name'] as String?;
        final recordId = map['record_id'] as String?;
        if (tableName != null && recordId != null) {
          await markRecordAsSynced(tableName, recordId);
        }
        count++;
      }
    }
    return count;
  }

  Future<void> clearSyncQueue() async {
    await _syncQueueBox.clear();
  }

  /// Full Two-Way Synchronization with Supabase
  Future<int> syncWithSupabase() async {
    if (!SupabaseService.instance.isConfigured || SupabaseService.instance.client == null) {
      return 0;
    }

    int syncedCount = 0;
    final client = SupabaseService.instance.client!;

    try {
      // 1. Push pending local Hive items to Supabase
      final pending = (await getSyncQueueItems()).where((i) => i.status != 'تمت').toList();
      for (final item in pending) {
        try {
          final ok = await SupabaseService.instance.syncOperation(item);
          if (ok) {
            await updateSyncItemStatus(item.id!, 'تمت', attempts: item.attempts + 1);
            await markRecordAsSynced(item.tableName, item.recordId);
            syncedCount++;
          }
        } catch (e) {
          String errStr = e.toString();
          if (errStr.contains('42501') || errStr.toLowerCase().contains('permission denied')) {
            errStr = 'رفض الصلاحية (42501): يجب تفعيل أذونات RLS في Supabase';
          }
          await updateSyncItemStatus(item.id!, 'فشل', error: errStr, attempts: item.attempts + 1);
        }
      }

      // 2. Pull latest students from Supabase into Hive
      try {
        final remoteStudents = await client.from('students').select();
        for (final r in remoteStudents) {
          final map = Map<String, dynamic>.from(r);
          final id = map['id'] as int?;
          if (id != null) {
            await _studentsBox.put(id, map);
          }
        }
      } catch (e) {
        if (kDebugMode) print('Pull remote students error: $e');
      }

      // 3. Pull latest attendance records from Supabase into Hive
      try {
        final remoteAttendance = await client.from('attendance').select();
        for (final r in remoteAttendance) {
          final map = Map<String, dynamic>.from(r);
          final id = map['id']?.toString();
          if (id != null && !_attendanceBox.containsKey(id)) {
            map['is_synced'] = 1;
            await _attendanceBox.put(id, map);
          }
        }
      } catch (e) {
        if (kDebugMode) print('Pull remote attendance error: $e');
      }

      return syncedCount;
    } catch (e) {
      if (kDebugMode) print('Full Supabase sync error: $e');
      return syncedCount;
    }
  }

  // Settings & Audit Logs
  Future<void> addAuditLog(AuditLog log) async {
    if (!_isInitialized) return;
    final nextId = _auditLogsBox.length + 1;
    await _auditLogsBox.put(nextId, log.toMap());
  }

  Future<List<AuditLog>> getAuditLogs() async {
    if (!_isInitialized) return [];
    final list = _auditLogsBox.values.map((v) => AuditLog.fromMap(Map<String, dynamic>.from(v))).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    if (!_isInitialized) return defaultValue;
    return _settingsBox.get(key, defaultValue: defaultValue) ?? defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    if (!_isInitialized) return;
    await _settingsBox.put(key, value);
  }

  // --- Biometric Fingerprint Methods ---
  Future<bool> isFingerprintDuplicate(String fingerprintId, {int? excludeStudentId}) async {
    if (!_isInitialized) return false;
    for (final val in _fingerprintsBox.values) {
      final map = Map<dynamic, dynamic>.from(val);
      final fpId = map['fingerprint_id']?.toString();
      final sId = (map['student_id'] as num?)?.toInt();
      final isActive = (map['is_active'] == 1 || map['is_active'] == true);
      if (isActive && fpId == fingerprintId) {
        if (excludeStudentId != null && sId == excludeStudentId) {
          continue;
        }
        return true;
      }
    }
    return false;
  }

  Future<void> saveStudentFingerprint(StudentFingerprint fp) async {
    if (!_isInitialized) return;
    // Deactivate old fingerprints for this student
    for (final key in _fingerprintsBox.keys) {
      final val = _fingerprintsBox.get(key);
      if (val != null && (val['student_id'] as num?)?.toInt() == fp.studentId) {
        final updated = Map<String, dynamic>.from(val);
        updated['is_active'] = 0;
        await _fingerprintsBox.put(key, updated);
      }
    }

    // Save active fingerprint
    final nextId = _fingerprintsBox.length + 1;
    await _fingerprintsBox.put(nextId, fp.toMap());

    // Update student in students box
    for (final key in _studentsBox.keys) {
      final val = _studentsBox.get(key);
      if (val != null && ((val['id'] as num?)?.toInt() == fp.studentId || val['university_id'] == fp.universityId)) {
        final updated = Map<String, dynamic>.from(val);
        updated['fingerprint_id'] = fp.fingerprintId;
        updated['fingerprint_status'] = 'مسجلة';
        updated['fingerprint_quality'] = fp.qualityScore;
        updated['fingerprint_enrolled_at'] = fp.enrolledAt;
        await _studentsBox.put(key, updated);
        break;
      }
    }
  }

  Future<void> deleteStudentFingerprint(int studentId) async {
    if (!_isInitialized) return;
    for (final key in _fingerprintsBox.keys.toList()) {
      final val = _fingerprintsBox.get(key);
      if (val != null && (val['student_id'] as num?)?.toInt() == studentId) {
        await _fingerprintsBox.delete(key);
      }
    }
    for (final key in _studentsBox.keys.toList()) {
      final val = _studentsBox.get(key);
      if (val != null && (val['id'] as num?)?.toInt() == studentId) {
        final updated = Map<String, dynamic>.from(val);
        updated['fingerprint_id'] = null;
        updated['fingerprint_status'] = 'غير مسجلة';
        updated['fingerprint_quality'] = null;
        updated['fingerprint_enrolled_at'] = null;
        await _studentsBox.put(key, updated);
        break;
      }
    }
  }

  Future<StudentFingerprint?> getStudentFingerprint(int studentId) async {
    if (!_isInitialized) return null;
    for (final val in _fingerprintsBox.values) {
      final map = Map<dynamic, dynamic>.from(val);
      if ((map['student_id'] as num?)?.toInt() == studentId &&
          (map['is_active'] == 1 || map['is_active'] == true)) {
        return StudentFingerprint.fromMap(map);
      }
    }
    return null;
  }

  Future<List<StudentFingerprint>> getStudentFingerprints() async {
    if (!_isInitialized) return [];
    final list = <StudentFingerprint>[];
    for (final val in _fingerprintsBox.values) {
      final map = Map<dynamic, dynamic>.from(val);
      if (map['is_active'] == 1 || map['is_active'] == true) {
        list.add(StudentFingerprint.fromMap(map));
      }
    }
    list.sort((a, b) => b.enrolledAt.compareTo(a.enrolledAt));
    return list;
  }

  Future<void> logBiometricVerification(BiometricVerificationLog log) async {
    if (!_isInitialized) return;
    final nextId = _verificationLogsBox.length + 1;
    await _verificationLogsBox.put(nextId, log.toMap());
  }

  Future<List<BiometricVerificationLog>> getBiometricVerificationLogs({
    bool onlyFailed = false,
    int limit = 100,
  }) async {
    if (!_isInitialized) return [];
    final list = <BiometricVerificationLog>[];
    for (final val in _verificationLogsBox.values) {
      final map = Map<dynamic, dynamic>.from(val);
      final log = BiometricVerificationLog.fromMap(map);
      if (!onlyFailed || log.status == 'فشل') {
        list.add(log);
      }
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }
}
