import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../local/hive_helper.dart';
import '../models/sync_and_auth_models.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/academic_models.dart';
import '../models/lecture.dart';

class SupabaseTestResult {
  final bool isConnected;
  final bool isPermissionDenied;
  final String statusTitle;
  final String message;
  final String? hint;
  final int? responseTimeMs;

  const SupabaseTestResult({
    required this.isConnected,
    this.isPermissionDenied = false,
    required this.statusTitle,
    required this.message,
    this.hint,
    this.responseTimeMs,
  });
}

class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  SupabaseClient? _client;
  bool _isConfigured = false;
  String _currentUrl = ApiConstants.defaultSupabaseUrl;
  String _currentKey = ApiConstants.defaultSupabaseAnonKey;

  SupabaseService._init();

  bool get isConfigured => _isConfigured;
  SupabaseClient? get client => _client;
  String get currentUrl => _currentUrl;
  String get currentKey => _currentKey;

  /// Complete SQL Script for Single-Table Design in Supabase
  static const String sqlPermissionFixScript =
      '''-- ============================================================
-- كود إنشاء الجدول الموحد الوحيد وتصحيح الصلاحيات في Supabase
-- انسخ هذا الكود والصقه في Supabase Dashboard -> SQL Editor ثم اضغط Run
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. إنشاء الجدول الموحد الوحيد لكافة بيانات تطبيق دوامي
CREATE TABLE IF NOT EXISTS public.dawami_records (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    record_type VARCHAR(50) NOT NULL,            -- 'student' أو 'attendance' أو 'setting'
    record_key VARCHAR(100) NOT NULL,           -- المفتاح الفريد (الرقم الجامعي أو معرّف الحضور)
    student_number VARCHAR(50),                 -- الرقم الجامعي
    full_name VARCHAR(255),                     -- اسم الطالب
    barcode_id VARCHAR(100),                    -- معرّف الباركود / QR
    record_date DATE DEFAULT CURRENT_DATE,      -- تاريخ الحضور
    record_time TIME DEFAULT CURRENT_TIME,      -- وقت الحضور
    method VARCHAR(50),                         -- 'fingerprint' أو 'barcode' أو 'manual'
    status VARCHAR(50) NOT NULL DEFAULT 'نشط',   -- 'نشط' / 'حاضر' / 'منصرف'
    sync_status VARCHAR(50) NOT NULL DEFAULT 'مزامنة',
    data JSONB NOT NULL DEFAULT '{}'::jsonb,    -- كائن JSON يحتوي على كافة التفاصيل
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT dawami_records_pkey PRIMARY KEY (id),
    CONSTRAINT dawami_records_type_key UNIQUE (record_type, record_key)
);

-- 2. منح الصلاحيات العامة لأدوار anon و authenticated و service_role
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- 3. إيقاف Row Level Security (RLS) للجدول الموحد
ALTER TABLE IF EXISTS public.dawami_records DISABLE ROW LEVEL SECURITY;

-- 4. فهارس سريعة للاستعلامات اليومية وعمليات المزامنة
CREATE INDEX IF NOT EXISTS idx_dawami_records_type ON public.dawami_records(record_type);
CREATE INDEX IF NOT EXISTS idx_dawami_records_key ON public.dawami_records(record_key);
CREATE INDEX IF NOT EXISTS idx_dawami_records_student_number ON public.dawami_records(student_number);
CREATE INDEX IF NOT EXISTS idx_dawami_records_barcode_id ON public.dawami_records(barcode_id);
CREATE INDEX IF NOT EXISTS idx_dawami_records_date ON public.dawami_records(record_date);
CREATE INDEX IF NOT EXISTS idx_dawami_records_sync_status ON public.dawami_records(sync_status);
''';

  /// Initializes Supabase, loading any custom saved URL and Key from Hive settings if available
  Future<bool> initDefault() async {
    String url = ApiConstants.defaultSupabaseUrl;
    String key = ApiConstants.defaultSupabaseAnonKey;

    try {
      if (HiveHelper.instance.isInitialized) {
        final savedUrl = await HiveHelper.instance.getSetting('supabase_url');
        final savedKey = await HiveHelper.instance.getSetting('supabase_key');
        if (savedUrl.isNotEmpty) url = savedUrl;
        if (savedKey.isNotEmpty && !savedKey.startsWith('sb_publishable')) {
          key = savedKey;
        } else {
          key = ApiConstants.defaultSupabaseAnonKey;
          await HiveHelper.instance.setSetting('supabase_key', key);
        }
      }
    } catch (_) {}

    return await initialize(url, key);
  }

  Future<bool> initialize(String rawUrl, String anonKey) async {
    final normalizedUrl = ApiConstants.normalizeSupabaseUrl(rawUrl);
    final cleanKey = anonKey.trim();

    if (normalizedUrl.isEmpty || cleanKey.isEmpty) {
      _isConfigured = false;
      return false;
    }

    _currentUrl = normalizedUrl;
    _currentKey = cleanKey;

    try {
      await Supabase.initialize(
        url: normalizedUrl,
        // ignore: deprecated_member_use
        anonKey: cleanKey,
      );
      _client = Supabase.instance.client;
      _isConfigured = true;
      if (kDebugMode) {
        print('Supabase connected successfully to: $normalizedUrl');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Supabase init notice (attempting direct client): $e');
      }
      // If already initialized or different instance, instantiate direct SupabaseClient
      try {
        _client = SupabaseClient(normalizedUrl, cleanKey);
        _isConfigured = true;
        return true;
      } catch (_) {
        _isConfigured = false;
        return false;
      }
    }
  }

  /// Update custom credentials and persist to Hive
  Future<bool> updateCredentials(String rawUrl, String anonKey) async {
    final ok = await initialize(rawUrl, anonKey);
    if (ok) {
      try {
        if (HiveHelper.instance.isInitialized) {
          await HiveHelper.instance.setSetting('supabase_url', _currentUrl);
          await HiveHelper.instance.setSetting('supabase_key', _currentKey);
        }
      } catch (_) {}
    }
    return ok;
  }

  /// Reset to factory default Supabase credentials
  Future<bool> resetToDefault() async {
    try {
      if (HiveHelper.instance.isInitialized) {
        await HiveHelper.instance.setSetting(
          'supabase_url',
          ApiConstants.defaultSupabaseUrl,
        );
        await HiveHelper.instance.setSetting(
          'supabase_key',
          ApiConstants.defaultSupabaseAnonKey,
        );
      }
    } catch (_) {}
    return await initialize(
      ApiConstants.defaultSupabaseUrl,
      ApiConstants.defaultSupabaseAnonKey,
    );
  }

  /// Live connection test diagnosing RLS / 42501 permission status
  Future<SupabaseTestResult> testConnection() async {
    if (!_isConfigured || _client == null) {
      return const SupabaseTestResult(
        isConnected: false,
        statusTitle: 'غير مهيأ',
        message: 'إعدادات الاتصال بـ Supabase غير مكتملة.',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      // Query single table dawami_records to verify read permissions
      await _client!.from('dawami_records').select('id').limit(1);
      stopwatch.stop();

      return SupabaseTestResult(
        isConnected: true,
        statusTitle: 'متصل ومصرح بالكامل',
        message:
            'تم الاتصال بالخادم بنجاح والجدول الموحد dawami_records مصرح له بالكامل.',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on PostgrestException catch (pe) {
      stopwatch.stop();
      if (pe.code == '42501' || pe.message.contains('permission denied')) {
        return SupabaseTestResult(
          isConnected: false,
          isPermissionDenied: true,
          statusTitle: 'تم رفض الصلاحيات (كود 42501)',
          message:
              'تم الاتصال بالخادم، لكن Supabase يرفض الوصول لجداول قاعدة البيانات بسبب قيود Row Level Security (RLS) أو عدم منح الصلاحيات لدور anon في PostgreSQL.',
          hint: 'قم بنسخ كود SQL المرفق وتشغيله في Supabase SQL Editor.',
          responseTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
      return SupabaseTestResult(
        isConnected: false,
        statusTitle: 'خطأ من Supabase (${pe.code ?? "مجهول"})',
        message: pe.message,
        hint: pe.hint,
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return SupabaseTestResult(
        isConnected: false,
        statusTitle: 'فشل الاتصال',
        message:
            'تعذر الوصول إلى الخادم. تأكد من توفر الإنترنت وصحة الرابط: $e',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // Auth
  Future<UserProfile?> signIn(String email, String password) async {
    if (!_isConfigured || _client == null) {
      return null;
    }
    try {
      final response = await _client!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        // Fetch profile
        final data = await _client!
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          return UserProfile.fromMap(data);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Supabase signIn error: $e');
      }
      rethrow;
    }
  }

  /// تنسيق حمولة الطالب لتطابق جدول dawami_records الموحد في Supabase
  static Map<String, dynamic> formatStudentPayload(dynamic source) {
    if (source is Student) {
      return source.toDawamiRecord();
    }
    final map = Map<String, dynamic>.from(source as Map);
    final student = Student.fromMap(map);
    return student.toDawamiRecord();
  }

  Future<void> _saveStudentRecord(
    Map<String, dynamic> record, {
    String? previousUniversityId,
  }) async {
    final oldKey = previousUniversityId?.trim();
    final newKey = record['record_key']?.toString();
    if (oldKey != null && oldKey.isNotEmpty && oldKey != newKey) {
      final oldRecord = await _client!
          .from('dawami_records')
          .select('id')
          .eq('record_type', 'student')
          .eq('record_key', oldKey)
          .maybeSingle();

      final newRecord = await _client!
          .from('dawami_records')
          .select('id,data')
          .eq('record_type', 'student')
          .eq('record_key', newKey ?? '')
          .maybeSingle();

      if (oldRecord != null) {
        if (newRecord != null && oldRecord['id'] != newRecord['id']) {
          throw StateError('الرقم الجامعي الجديد مسجل لطالب آخر في Supabase');
        }
        if (newRecord == null) {
          await _client!
              .from('dawami_records')
              .update(record)
              .eq('record_type', 'student')
              .eq('record_key', oldKey);
          return;
        }
      } else if (newRecord != null) {
        final data = newRecord['data'] is Map
            ? Map<String, dynamic>.from(newRecord['data'] as Map)
            : <String, dynamic>{};
        final expectedUuid = (record['data'] as Map<String, dynamic>?)?['uuid']
            ?.toString();
        final existingUuid = (newRecord['id'] ?? data['uuid'])?.toString();
        if (expectedUuid == null || expectedUuid != existingUuid) {
          throw StateError('الرقم الجامعي الجديد مسجل لطالب آخر في Supabase');
        }
      }
    }

    await _client!
        .from('dawami_records')
        .upsert(record, onConflict: 'record_type,record_key');
  }

  // Sync Queue Operation Handler
  Future<bool> syncOperation(SyncQueueItem item) async {
    if (!_isConfigured || _client == null) {
      return false;
    }

    try {
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;

      if (item.tableName == 'students') {
        final record = formatStudentPayload(payload);
        switch (item.operation.toUpperCase()) {
          case 'INSERT':
            await _client!
                .from('dawami_records')
                .upsert(record, onConflict: 'record_type,record_key');
            break;
          case 'UPDATE':
            await _saveStudentRecord(
              record,
              previousUniversityId: payload['previous_university_id']
                  ?.toString(),
            );
            break;
          case 'DELETE':
            final key =
                payload['record_key'] ??
                payload['university_id'] ??
                payload['student_number'] ??
                record['record_key'];
            if (key == null || key.toString().isEmpty) {
              throw StateError('Student deletion is missing its university ID');
            }
            await _client!
                .from('dawami_records')
                .delete()
                .eq('record_type', 'student')
                .eq('record_key', key.toString());
            await _client!
                .from('dawami_records')
                .delete()
                .eq('record_type', 'attendance')
                .eq('student_number', key.toString());
            break;
        }
        return true;
      } else if (item.tableName == 'attendance') {
        final attendanceRecord = AttendanceRecord.fromMap(payload);
        switch (item.operation.toUpperCase()) {
          case 'INSERT':
          case 'UPDATE':
            await _client!
                .from('dawami_records')
                .upsert(
                  attendanceRecord.toDawamiRecord(),
                  onConflict: 'record_type,record_key',
                );
            break;
          case 'DELETE':
            final key = attendanceRecord.id.isNotEmpty
                ? attendanceRecord.id
                : (payload['id'] ?? item.recordId);
            await _client!
                .from('dawami_records')
                .delete()
                .eq('record_type', 'attendance')
                .eq('record_key', key);
            break;
        }
        return true;
      }

      // Any other entities are stored flexibly into dawami_records
      switch (item.operation.toUpperCase()) {
        case 'INSERT':
        case 'UPDATE':
          final recKey = payload['id']?.toString() ?? item.recordId.toString();
          final genericRecord = {
            'record_type': item.tableName,
            'record_key': recKey,
            'sync_status': 'مزامنة',
            'data': payload,
            'updated_at': DateTime.now().toIso8601String(),
          };
          await _client!
              .from('dawami_records')
              .upsert(genericRecord, onConflict: 'record_type,record_key');
          break;
        case 'DELETE':
          final id = payload['id']?.toString() ?? item.recordId.toString();
          await _client!
              .from('dawami_records')
              .delete()
              .eq('record_type', item.tableName)
              .eq('record_key', id);
          break;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Supabase sync error on ${item.tableName}: $e');
      }
      rethrow;
    }
  }

  /// High-performance bulk student upsert directly to Supabase dawami_records
  Future<bool> batchUpsertStudents(List<Map<String, dynamic>> students) async {
    if (!_isConfigured || _client == null || students.isEmpty) return false;
    try {
      final cleanList = students.map((s) => formatStudentPayload(s)).toList();
      await _client!
          .from('dawami_records')
          .upsert(cleanList, onConflict: 'record_type,record_key');
      return true;
    } catch (e) {
      if (kDebugMode) print('Supabase batchUpsertStudents notice: $e');
      return false;
    }
  }

  // ============================================================
  // --- PRIMARY DATABASE OPERATIONS (SUPABASE dawami_records) ---
  // ============================================================

  /// Fetch students from single unified table (dawami_records)
  Future<List<Student>> getStudents({
    String? query,
    int? collegeId,
    String? status,
  }) async {
    if (!_isConfigured || _client == null) return [];
    try {
      var builder = _client!
          .from('dawami_records')
          .select()
          .eq('record_type', 'student');
      if (status != null && status != 'الكل') {
        builder = builder.eq('status', status);
      }
      final response = await builder.order('updated_at', ascending: false);
      final list = <Student>[];
      for (final item in response) {
        final map = Map<String, dynamic>.from(item);
        final student = Student.fromDawamiRecord(map);
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          final match =
              student.fullName.toLowerCase().contains(q) ||
              student.universityId.toLowerCase().contains(q) ||
              student.phone.contains(q);
          if (!match) continue;
        }
        list.add(student);
      }
      return list;
    } catch (e) {
      if (kDebugMode) print('Supabase getStudents error: $e');
      rethrow;
    }
  }

  /// Insert student into single unified table (dawami_records)
  Future<Student?> insertStudent(Student student) async {
    if (!_isConfigured || _client == null) return null;
    try {
      final payload = student.toDawamiRecord();
      final response = await _client!
          .from('dawami_records')
          .upsert(payload, onConflict: 'record_type,record_key')
          .select()
          .maybeSingle();
      if (response != null) {
        return Student.fromDawamiRecord(Map<String, dynamic>.from(response));
      }
      return student;
    } catch (e) {
      if (kDebugMode) print('Supabase insertStudent error: $e');
      rethrow;
    }
  }

  /// Update student in single unified table (dawami_records)
  Future<bool> updateStudent(
    Student student, {
    String? previousUniversityId,
  }) async {
    if (!_isConfigured || _client == null) return false;
    try {
      final payload = student.toDawamiRecord();
      await _saveStudentRecord(
        payload,
        previousUniversityId: previousUniversityId,
      );
      return true;
    } catch (e) {
      if (kDebugMode) print('Supabase updateStudent error: $e');
      rethrow;
    }
  }

  /// Delete student from single unified table (dawami_records)
  Future<bool> deleteStudent(int studentId, [String? universityId]) async {
    if (!_isConfigured || _client == null) return false;
    if (universityId == null || universityId.isEmpty) return false;
    try {
      await _client!
          .from('dawami_records')
          .delete()
          .eq('record_type', 'student')
          .eq('record_key', universityId);
      await _client!
          .from('dawami_records')
          .delete()
          .eq('record_type', 'attendance')
          .eq('student_number', universityId);
      return true;
    } catch (e) {
      if (kDebugMode) print('Supabase deleteStudent error: $e');
      rethrow;
    }
  }

  /// Delete multiple students from single unified table (dawami_records)
  Future<bool> deleteMultipleStudents(List<String> universityIds) async {
    final ids = universityIds.where((id) => id.isNotEmpty).toSet().toList();
    if (!_isConfigured || _client == null || ids.isEmpty) return false;
    try {
      await _client!
          .from('dawami_records')
          .delete()
          .eq('record_type', 'student')
          .inFilter('record_key', ids);
      await _client!
          .from('dawami_records')
          .delete()
          .eq('record_type', 'attendance')
          .inFilter('student_number', ids);
      return true;
    } catch (e) {
      if (kDebugMode) print('Supabase deleteMultipleStudents error: $e');
      rethrow;
    }
  }

  /// Fetch attendance records from single unified table (dawami_records)
  Future<List<AttendanceRecord>> getAttendanceRecords({
    int? sessionId,
    String? date,
    String? method,
  }) async {
    if (!_isConfigured || _client == null) return [];
    try {
      var builder = _client!
          .from('dawami_records')
          .select()
          .eq('record_type', 'attendance');
      if (method != null && method != 'الكل') {
        builder = builder.eq('method', method);
      }
      final response = await builder.order('record_date', ascending: false);
      final list = <AttendanceRecord>[];
      for (final item in response) {
        final map = Map<String, dynamic>.from(item);
        final record = AttendanceRecord.fromDawamiRecord(map);
        if (date != null && !record.checkIn.startsWith(date)) continue;
        list.add(record);
      }
      return list;
    } catch (e) {
      if (kDebugMode) print('Supabase getAttendanceRecords error: $e');
      return [];
    }
  }

  /// Record attendance directly into single unified table (dawami_records)
  Future<bool> recordAttendance({
    required String id,
    required int studentId,
    required int sessionId,
    required String method,
    required String status,
    required String deviceId,
    required String checkIn,
    String? checkOut,
    String? studentNumber,
    String? studentName,
    int? lectureId,
    String? attendanceDate,
    String? attendanceTime,
  }) async {
    if (!_isConfigured || _client == null) return false;
    try {
      final date =
          attendanceDate ??
          (checkIn.length >= 10 ? checkIn.substring(0, 10) : null);
      final time =
          attendanceTime ??
          (checkIn.length >= 16 ? checkIn.substring(11, 16) : null);
      final record = AttendanceRecord(
        id: id,
        studentId: studentId,
        sessionId: sessionId,
        method: method,
        status: status,
        deviceId: deviceId,
        checkIn: checkIn,
        checkOut: checkOut,
        createdAt: DateTime.now().toIso8601String(),
        studentName: studentName,
        universityId: studentNumber,
        isSynced: true,
      );
      final payload = record.toDawamiRecord();
      if (date != null) payload['record_date'] = date;
      if (time != null) payload['record_time'] = time;

      await _client!
          .from('dawami_records')
          .upsert(payload, onConflict: 'record_type,record_key');
      return true;
    } catch (e) {
      if (kDebugMode) print('Supabase recordAttendance error: $e');
      rethrow;
    }
  }

  /// Delete attendance record from single unified table (dawami_records)
  Future<bool> deleteAttendanceRecord(String id) async {
    if (!_isConfigured || _client == null) return false;
    try {
      await _client!
          .from('dawami_records')
          .delete()
          .eq('record_type', 'attendance')
          .eq('record_key', id);
      return true;
    } catch (e) {
      if (kDebugMode) print('Supabase deleteAttendanceRecord error: $e');
      rethrow;
    }
  }

  /// Delete multiple attendance records from single unified table (dawami_records)
  Future<bool> deleteMultipleAttendanceRecords(List<String> ids) async {
    if (!_isConfigured || _client == null || ids.isEmpty) return false;
    try {
      await _client!
          .from('dawami_records')
          .delete()
          .eq('record_type', 'attendance')
          .inFilter('record_key', ids);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Supabase deleteMultipleAttendanceRecords error: $e');
      }
      rethrow;
    }
  }

  /// Fetch lectures from primary database (Supabase)
  Future<List<Lecture>> getLectures() async {
    if (!_isConfigured || _client == null) return [];
    try {
      final response = await _client!.from('lectures').select();
      return (response as List)
          .map((i) => Lecture.fromMap(Map<String, dynamic>.from(i)))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Supabase getLectures error: $e');
      return [];
    }
  }

  /// Fetch colleges from primary database (Supabase)
  Future<List<College>> getColleges() async {
    if (!_isConfigured || _client == null) return [];
    try {
      final response = await _client!.from('colleges').select();
      return (response as List)
          .map((i) => College.fromMap(Map<String, dynamic>.from(i)))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Supabase getColleges error: $e');
      return [];
    }
  }

  /// Fetch departments from primary database (Supabase)
  Future<List<Department>> getDepartments({int? collegeId}) async {
    if (!_isConfigured || _client == null) return [];
    try {
      var builder = _client!.from('departments').select();
      if (collegeId != null) {
        builder = builder.eq('college_id', collegeId);
      }
      final response = await builder;
      return (response as List)
          .map((i) => Department.fromMap(Map<String, dynamic>.from(i)))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Supabase getDepartments error: $e');
      return [];
    }
  }

  /// Fetch academic levels from primary database (Supabase)
  Future<List<AcademicLevel>> getAcademicLevels() async {
    if (!_isConfigured || _client == null) return [];
    try {
      final response = await _client!
          .from('academic_levels')
          .select()
          .order('order_no', ascending: true);
      return (response as List)
          .map((i) => AcademicLevel.fromMap(Map<String, dynamic>.from(i)))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Supabase getAcademicLevels error: $e');
      return [];
    }
  }
}
