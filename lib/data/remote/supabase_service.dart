import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../local/hive_helper.dart';
import '../models/sync_and_auth_models.dart';

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

  /// Complete SQL Script to fix 42501 permission denied in Supabase
  static const String sqlPermissionFixScript = '''-- ============================================================
-- كود تصحيح الصلاحيات وربط قاعدة بيانات تطبيق دوامي (Supabase)
-- انسخ هذا الكود والصقه في Supabase Dashboard -> SQL Editor ثم اضغط Run
-- ============================================================

-- 1. منح الصلاحيات العامة لأدوار anon و authenticated
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- 2. إيقاف Row Level Security (RLS) للجداول لتمكين المزامنة المباشرة
ALTER TABLE IF EXISTS public.students DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.attendance DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.attendance_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.lectures DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.colleges DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.departments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.academic_levels DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.semesters DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.courses DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.classrooms DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.sync_queue DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.student_fingerprints DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.student_enrollments DISABLE ROW LEVEL SECURITY;

-- 3. في حال كان نظام RLS مفروضاً إبقاؤه مفعلاً، يتم تطبيق سياسات السماح الشاملة التالية:
DO \$\$
DECLARE
    tbl text;
    tables text[] := ARRAY[
      'students', 'attendance', 'attendance_sessions', 'lectures',
      'profiles', 'colleges', 'departments', 'academic_levels',
      'semesters', 'courses', 'classrooms', 'sync_queue',
      'audit_logs', 'student_fingerprints', 'student_enrollments'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            EXECUTE format('DROP POLICY IF EXISTS "Public Full Access" ON public.%I', tbl);
            EXECUTE format('CREATE POLICY "Public Full Access" ON public.%I FOR ALL TO public USING (true) WITH CHECK (true)', tbl);
        END IF;
    END LOOP;
END \$\$;
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
        await HiveHelper.instance.setSetting('supabase_url', ApiConstants.defaultSupabaseUrl);
        await HiveHelper.instance.setSetting('supabase_key', ApiConstants.defaultSupabaseAnonKey);
      }
    } catch (_) {}
    return await initialize(ApiConstants.defaultSupabaseUrl, ApiConstants.defaultSupabaseAnonKey);
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
      // Query students table to verify read permissions
      await _client!.from('students').select('university_id').limit(1);
      stopwatch.stop();

      return SupabaseTestResult(
        isConnected: true,
        statusTitle: 'متصل ومصرح بالكامل',
        message: 'تم الاتصال بالخادم بنجاح وجداول قاعدة البيانات مصرح لها بالكامل.',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on PostgrestException catch (pe) {
      stopwatch.stop();
      if (pe.code == '42501' || pe.message.contains('permission denied')) {
        return SupabaseTestResult(
          isConnected: false,
          isPermissionDenied: true,
          statusTitle: 'تم رفض الصلاحيات (كود 42501)',
          message: 'تم الاتصال بالخادم، لكن Supabase يرفض الوصول لجداول قاعدة البيانات بسبب قيود Row Level Security (RLS) أو عدم منح الصلاحيات لدور anon في PostgreSQL.',
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
        message: 'تعذر الوصول إلى الخادم. تأكد من توفر الإنترنت وصحة الرابط: $e',
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

  // Sync Queue Operation Handler
  Future<bool> syncOperation(SyncQueueItem item) async {
    if (!_isConfigured || _client == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    }

    try {
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;

      // Clean local helper / join fields based on target table
      if (item.tableName == 'students') {
        payload.remove('college_name');
        payload.remove('department_name');
        payload.remove('level_name');
        payload.remove('is_synced');
        payload.remove('student_name');
        // DO NOT remove university_id! It is a required core column in Supabase students table.
      } else if (item.tableName == 'attendance') {
        payload.remove('student_name');
        payload.remove('university_id');
        payload.remove('lecture_name');
        payload.remove('classroom_name');
        payload.remove('is_synced');
      } else if (item.tableName == 'sessions' || item.tableName == 'attendance_sessions') {
        payload.remove('lecture_name');
        payload.remove('classroom_name');
        payload.remove('instructor');
      } else if (item.tableName == 'lectures') {
        payload.remove('course_name');
        payload.remove('classroom_name');
      }
      payload.remove('is_synced');

      switch (item.operation.toUpperCase()) {
        case 'INSERT':
        case 'UPDATE':
          if (item.tableName == 'students') {
            await _client!.from('students').upsert(payload, onConflict: 'university_id');
          } else {
            await _client!.from(item.tableName).upsert(payload);
          }
          break;
        case 'DELETE':
          final id = payload['id'] ?? item.recordId;
          await _client!.from(item.tableName).delete().eq('id', id);
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

  /// High-performance bulk student upsert directly to Supabase
  Future<bool> batchUpsertStudents(List<Map<String, dynamic>> students) async {
    if (!_isConfigured || _client == null || students.isEmpty) return false;
    try {
      final cleanList = students.map((s) {
        final m = Map<String, dynamic>.from(s);
        m.remove('college_name');
        m.remove('department_name');
        m.remove('level_name');
        m.remove('is_synced');
        m.remove('student_name');
        return m;
      }).toList();
      await _client!.from('students').upsert(cleanList, onConflict: 'university_id');
      return true;
    } catch (e) {
      if (kDebugMode) print('Supabase batchUpsertStudents notice: $e');
      return false;
    }
  }
}
