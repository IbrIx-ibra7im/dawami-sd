import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:uuid/uuid.dart';

import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/academic_models.dart';
import '../models/lecture.dart';
import '../models/sync_and_auth_models.dart';
import '../models/biometric_models.dart';
import '../../core/utils/date_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const _uuid = Uuid();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dawami_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactoryFfiWeb.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createDB,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      String path;
      try {
        final dbPath = await getApplicationDocumentsDirectory();
        path = join(dbPath.path, filePath);
      } catch (_) {
        try {
          final dir = await databaseFactoryFfi.getDatabasesPath();
          path = join(dir, filePath);
        } catch (_) {
          path = inMemoryDatabasePath;
        }
      }
      return await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createDB,
        ),
      );
    } else {
      // Android / iOS Mobile platforms
      String path;
      try {
        final dbPath = await getApplicationDocumentsDirectory();
        path = join(dbPath.path, filePath);
      } catch (_) {
        path = inMemoryDatabasePath;
      }
      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
      );
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 16 tables specified in PDF page 10 + sync_queue from page 9

    // 1. colleges
    await db.execute('''
      CREATE TABLE colleges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. departments
    await db.execute('''
      CREATE TABLE departments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        college_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (college_id) REFERENCES colleges (id) ON DELETE CASCADE
      )
    ''');

    // 3. academic_levels
    await db.execute('''
      CREATE TABLE academic_levels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        order_no INTEGER NOT NULL
      )
    ''');

    // 4. semesters
    await db.execute('''
      CREATE TABLE semesters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL
      )
    ''');

    // 5. courses
    await db.execute('''
      CREATE TABLE courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        department_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        FOREIGN KEY (department_id) REFERENCES departments (id) ON DELETE CASCADE
      )
    ''');

    // 6. classrooms
    await db.execute('''
      CREATE TABLE classrooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        capacity INTEGER NOT NULL
      )
    ''');

    // 7. lectures
    await db.execute('''
      CREATE TABLE lectures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        classroom_id INTEGER NOT NULL,
        instructor TEXT NOT NULL,
        day TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        grace_minutes INTEGER NOT NULL DEFAULT 15,
        late_after TEXT NOT NULL,
        close_at TEXT NOT NULL,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE,
        FOREIGN KEY (classroom_id) REFERENCES classrooms (id) ON DELETE CASCADE
      )
    ''');

    // 8. attendance_sessions
    await db.execute('''
      CREATE TABLE attendance_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lecture_id INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'نشطة',
        FOREIGN KEY (lecture_id) REFERENCES lectures (id) ON DELETE CASCADE
      )
    ''');

    // 9. students
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        university_id TEXT UNIQUE NOT NULL,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        college_id INTEGER NOT NULL,
        department_id INTEGER NOT NULL,
        level_id INTEGER NOT NULL,
        semester_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'نشط',
        qr_code TEXT NOT NULL,
        fingerprint_id TEXT,
        photo_url TEXT,
        FOREIGN KEY (college_id) REFERENCES colleges (id),
        FOREIGN KEY (department_id) REFERENCES departments (id),
        FOREIGN KEY (level_id) REFERENCES academic_levels (id),
        FOREIGN KEY (semester_id) REFERENCES semesters (id)
      )
    ''');

    // 10. attendance (UNIQUE constraint on student_id, session_id for idempotency)
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        student_id INTEGER NOT NULL,
        session_id INTEGER NOT NULL,
        check_in TEXT NOT NULL,
        check_out TEXT,
        method TEXT NOT NULL,
        status TEXT NOT NULL,
        device_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (session_id) REFERENCES attendance_sessions (id) ON DELETE CASCADE,
        UNIQUE (student_id, session_id)
      )
    ''');

    // 11. profiles
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        email TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 12. admins
    await db.execute('''
      CREATE TABLE admins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id TEXT NOT NULL,
        permissions TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (profile_id) REFERENCES profiles (id) ON DELETE CASCADE
      )
    ''');

    // 13. devices
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        last_seen TEXT NOT NULL
      )
    ''');

    // 14. sync_logs
    await db.execute('''
      CREATE TABLE sync_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT,
        result TEXT NOT NULL,
        error TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 15. audit_logs
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        old_data TEXT,
        new_data TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 16. app_settings
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 17. sync_queue (PDF page 9)
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'انتظار',
        error TEXT
      )
    ''');

    // 18. student_fingerprints
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_fingerprints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        university_id TEXT NOT NULL,
        fingerprint_id TEXT UNIQUE NOT NULL,
        template_hash TEXT NOT NULL,
        quality_score INTEGER NOT NULL DEFAULT 90,
        enrolled_at TEXT NOT NULL,
        device_model TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // 19. biometric_verification_logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS biometric_verification_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        method TEXT NOT NULL,
        student_id INTEGER,
        student_name TEXT,
        university_id TEXT,
        status TEXT NOT NULL,
        reason TEXT NOT NULL,
        device_model TEXT NOT NULL
      )
    ''');

    // Seed initial data
    await _seedDatabase(db);
  }

  Future<void> _seedDatabase(Database db) async {
    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    // College (Dongola University - Faculty of Computer Science & Human Development)
    await db.insert('colleges', {'id': 1, 'name': 'كلية علوم الحاسوب والتنمية البشرية', 'created_at': now});

    // Departments (Faculty of Computer Science & Human Development)
    await db.insert('departments', {'id': 1, 'college_id': 1, 'name': 'علوم الحاسوب'});
    await db.insert('departments', {'id': 2, 'college_id': 1, 'name': 'تقنية المعلومات'});
    await db.insert('departments', {'id': 3, 'college_id': 1, 'name': 'نظم المعلومات'});
    await db.insert('departments', {'id': 4, 'college_id': 1, 'name': 'التنمية البشرية وتطبيقات الحاسوب'});
    await db.insert('departments', {'id': 5, 'college_id': 1, 'name': 'هندسة البرمجيات'});

    // Academic levels
    await db.insert('academic_levels', {'id': 1, 'name': 'المستوى الأول', 'order_no': 1});
    await db.insert('academic_levels', {'id': 2, 'name': 'المستوى الثاني', 'order_no': 2});
    await db.insert('academic_levels', {'id': 3, 'name': 'المستوى الثالث', 'order_no': 3});
    await db.insert('academic_levels', {'id': 4, 'name': 'المستوى الرابع', 'order_no': 4});

    // Semesters
    await db.insert('semesters', {
      'id': 1,
      'name': 'الفصل الدراسي الأول 2026/2027',
      'start_date': '2026-09-01',
      'end_date': '2027-01-31'
    });

    // Classrooms
    await db.insert('classrooms', {'id': 1, 'name': 'قاعة 3', 'capacity': 60});
    await db.insert('classrooms', {'id': 2, 'name': 'قاعة 5', 'capacity': 80});
    await db.insert('classrooms', {'id': 3, 'name': 'المدرج الرئيسي', 'capacity': 250});

    // Courses
    await db.insert('courses', {'id': 1, 'department_id': 5, 'name': 'برمجة 1', 'code': 'CS101'});
    await db.insert('courses', {'id': 2, 'department_id': 5, 'name': 'قواعد البيانات', 'code': 'CS202'});
    await db.insert('courses', {'id': 3, 'department_id': 1, 'name': 'دوائر كهربية', 'code': 'EE102'});

    // Lectures
    await db.insert('lectures', {
      'id': 1,
      'course_id': 1,
      'classroom_id': 1,
      'instructor': 'د. عبدالله النور',
      'day': 'الجمعة',
      'start_time': '08:00',
      'end_time': '10:00',
      'grace_minutes': 15,
      'late_after': '08:15',
      'close_at': '09:00',
    });

    // Attendance Session for today
    await db.insert('attendance_sessions', {
      'id': 1,
      'lecture_id': 1,
      'session_date': today,
      'status': 'نشطة',
    });

    // تبدأ قاعدة البيانات بدون طلاب أو سجلات تجريبية وهمية (جاهزة لإدخال بيانات الطلاب الحقيقية)

    // Profiles & Users
    final adminProfileId = _uuid.v4();
    await db.insert('profiles', {
      'id': adminProfileId,
      'full_name': 'مدير النظام الرئيسي',
      'role': 'super_admin',
      'email': 'admin@dawami.edu',
      'created_at': now,
    });

    await db.insert('admins', {
      'profile_id': adminProfileId,
      'permissions': 'all',
      'is_active': 1,
    });

    // Devices
    await db.insert('devices', {
      'id': 1,
      'name': 'جهاز المدخل الرئيسي (ZK-F18)',
      'type': 'fingerprint_scanner',
      'last_seen': now,
    });

    // App Settings
    await db.insert('app_settings', {
      'key': 'university_name',
      'value': 'جامعة دنقلا - كلية علوم الحاسوب والتنمية البشرية',
    });
    await db.insert('app_settings', {
      'key': 'device_name',
      'value': 'ZK-F18',
    });
    await db.insert('app_settings', {
      'key': 'supabase_url',
      'value': 'https://lhvhjslwvoengoyjngcd.supabase.co',
    });
    await db.insert('app_settings', {
      'key': 'supabase_anon_key',
      'value': 'sb_publishable_hn1Y_SZMxqAlhKfF1LtBvw_cI_ePvuJ',
    });
  }

  // --- Student operations ---
  /// حذف جميع الطلاب وسجلات الحضور والبيانات المؤقتة لبدء نظام نظيف تماماً
  Future<void> clearAllStudentsAndAttendance() async {
    final db = await database;
    await db.delete('attendance');
    await db.delete('sync_queue');
    await db.delete('biometric_logs');
    await db.delete('students');
  }

  Future<List<Student>> getStudents({String? query, int? collegeId, String? status}) async {
    final db = await database;
    String sql = '''
      SELECT s.*, c.name as college_name, d.name as department_name, l.name as level_name
      FROM students s
      LEFT JOIN colleges c ON s.college_id = c.id
      LEFT JOIN departments d ON s.department_id = d.id
      LEFT JOIN academic_levels l ON s.level_id = l.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (s.full_name LIKE ? OR s.university_id LIKE ?)';
      args.add('%${query.trim()}%');
      args.add('%${query.trim()}%');
    }
    if (collegeId != null && collegeId > 0) {
      sql += ' AND s.college_id = ?';
      args.add(collegeId);
    }
    if (status != null && status.isNotEmpty && status != 'الكل') {
      sql += ' AND s.status = ?';
      args.add(status);
    }
    sql += ' ORDER BY s.id DESC';

    final res = await db.rawQuery(sql, args);
    return res.map((m) => Student.fromMap(m)).toList();
  }

  Future<Student?> getStudentByUniversityId(String universityId) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT s.*, c.name as college_name, d.name as department_name, l.name as level_name
      FROM students s
      LEFT JOIN colleges c ON s.college_id = c.id
      LEFT JOIN departments d ON s.department_id = d.id
      LEFT JOIN academic_levels l ON s.level_id = l.id
      WHERE s.university_id = ?
    ''', [universityId]);

    if (res.isNotEmpty) {
      return Student.fromMap(res.first);
    }
    return null;
  }

  Future<Student?> getStudentByQrOrBarcode(String rawCode) async {
    final db = await database;
    var code = rawCode.trim();
    
    // 1. Convert Eastern Arabic numerals (٠-٩) to Western (0-9)
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < 10; i++) {
      code = code.replaceAll(arabicDigits[i], '$i');
    }

    // 2. Strip standard prefixes
    if (code.contains('DAWAMI:STUDENT:')) {
      code = code.replaceAll('DAWAMI:STUDENT:', '').trim();
    }
    if (code.toUpperCase().startsWith('STUDENT:')) {
      code = code.substring(8).trim();
    }

    // 3. Extract digits only for robust comparison (ignoring dashes and spaces)
    final digitsOnly = code.replaceAll(RegExp(r'[^0-9]'), '');

    final res = await db.rawQuery('''
      SELECT s.*, c.name as college_name, d.name as department_name, l.name as level_name
      FROM students s
      LEFT JOIN colleges c ON s.college_id = c.id
      LEFT JOIN departments d ON s.department_id = d.id
      LEFT JOIN academic_levels l ON s.level_id = l.id
      WHERE s.qr_code = ? 
         OR s.university_id = ? 
         OR s.qr_code LIKE ? 
         OR s.university_id LIKE ?
         OR REPLACE(REPLACE(s.university_id, '-', ''), ' ', '') = ?
         OR (? != '' AND s.qr_code LIKE ?)
         OR s.phone LIKE ?
    ''', [
      rawCode.trim(),
      code,
      '%$code%',
      '%$code%',
      digitsOnly.isNotEmpty ? digitsOnly : code,
      digitsOnly,
      '%$digitsOnly%',
      '%$code%'
    ]);

    if (res.isNotEmpty) {
      return Student.fromMap(res.first);
    }
    return null;
  }

  Future<bool> linkBarcodeToStudent(int studentId, String newBarcode) async {
    final db = await database;
    final res = await db.update(
      'students',
      {'qr_code': newBarcode.trim()},
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return res > 0;
  }

  Future<Student?> getStudentByFingerprintId(String fpId) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT s.*, c.name as college_name, d.name as department_name, l.name as level_name
      FROM students s
      LEFT JOIN colleges c ON s.college_id = c.id
      LEFT JOIN departments d ON s.department_id = d.id
      LEFT JOIN academic_levels l ON s.level_id = l.id
      WHERE s.fingerprint_id = ?
    ''', [fpId]);

    if (res.isNotEmpty) {
      return Student.fromMap(res.first);
    }
    return null;
  }

  Future<int> insertStudent(Student student) async {
    final db = await database;
    final id = await db.insert(
      'students',
      student.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Register into Sync Queue
    await queueSyncItem(
      operation: 'INSERT',
      tableName: 'students',
      recordId: id.toString(),
      payload: student.copyWith(id: id).toMap(),
    );

    return id;
  }

  Future<int> batchInsertOrUpdateStudents(List<Student> students) async {
    final db = await database;
    int count = 0;
    for (final s in students) {
      final existing = await getStudentByUniversityId(s.universityId);
      if (existing != null) {
        await db.update(
          'students',
          s.toDbMap(),
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        await queueSyncItem(
          operation: 'UPDATE',
          tableName: 'students',
          recordId: existing.id.toString(),
          payload: s.copyWith(id: existing.id).toMap(),
        );
      } else {
        await insertStudent(s);
      }
      count++;
    }
    return count;
  }

  Future<int> updateStudent(Student student) async {
    final db = await database;
    final res = await db.update(
      'students',
      student.toDbMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );

    await queueSyncItem(
      operation: 'UPDATE',
      tableName: 'students',
      recordId: student.id.toString(),
      payload: student.toMap(),
    );

    return res;
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    final res = await db.delete('students', where: 'id = ?', whereArgs: [id]);

    await queueSyncItem(
      operation: 'DELETE',
      tableName: 'students',
      recordId: id.toString(),
      payload: {'id': id},
    );

    return res;
  }

  Future<int> deleteMultipleStudents(List<int> ids) async {
    int count = 0;
    for (final id in ids) {
      count += await deleteStudent(id);
    }
    return count;
  }

  Future<int> deleteAttendanceRecord(String id) async {
    final db = await database;
    final res = await db.delete('attendance', where: 'id = ?', whereArgs: [id]);
    await queueSyncItem(
      operation: 'DELETE',
      tableName: 'attendance',
      recordId: id,
      payload: {'id': id},
    );
    return res;
  }

  Future<int> deleteMultipleAttendanceRecords(List<String> ids) async {
    int count = 0;
    for (final id in ids) {
      count += await deleteAttendanceRecord(id);
    }
    return count;
  }

  // --- Attendance Operations ---
  Future<List<AttendanceRecord>> getAttendanceRecords({
    int? sessionId,
    String? date,
    String? method,
  }) async {
    final db = await database;
    String sql = '''
      SELECT a.*, s.full_name as student_name, s.university_id,
             c.name as lecture_name, cr.name as classroom_name
      FROM attendance a
      JOIN students s ON a.student_id = s.id
      JOIN attendance_sessions ses ON a.session_id = ses.id
      JOIN lectures l ON ses.lecture_id = l.id
      JOIN courses c ON l.course_id = c.id
      JOIN classrooms cr ON l.classroom_id = cr.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (sessionId != null) {
      sql += ' AND a.session_id = ?';
      args.add(sessionId);
    }
    if (date != null) {
      sql += ' AND ses.session_date = ?';
      args.add(date);
    }
    if (method != null && method != 'الكل') {
      sql += ' AND a.method = ?';
      args.add(method);
    }

    sql += ' ORDER BY a.check_in DESC';

    final res = await db.rawQuery(sql, args);
    return res.map((m) => AttendanceRecord.fromMap(m)).toList();
  }

  Future<AttendanceRecord?> getAttendanceForStudentInSession(int studentId, int sessionId) async {
    final db = await database;
    final res = await db.query(
      'attendance',
      where: 'student_id = ? AND session_id = ?',
      whereArgs: [studentId, sessionId],
    );
    if (res.isNotEmpty) {
      return AttendanceRecord.fromMap(res.first);
    }
    return null;
  }

  Future<String> recordAttendance({
    required int studentId,
    required int sessionId,
    required String method,
    required String status,
    String? deviceId,
  }) async {
    final db = await database;
    final existing = await getAttendanceForStudentInSession(studentId, sessionId);
    if (existing != null) {
      if (existing.checkOut == null) {
        final now = DateTime.now().toIso8601String();
        await db.update(
          'attendance',
          {
            'check_out': now,
            'status': 'تم الانصراف',
            'is_synced': 0,
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        await queueSyncItem(
          operation: 'UPDATE',
          tableName: 'attendance',
          recordId: existing.id,
          payload: {
            'id': existing.id,
            'student_id': studentId,
            'session_id': sessionId,
            'check_in': existing.checkIn,
            'check_out': now,
            'status': 'تم الانصراف',
            'method': method,
            'device_id': deviceId ?? existing.deviceId,
            'created_at': existing.createdAt,
          },
        );
        return existing.id;
      } else {
        final inStr = DateHelper.formatTimeString(existing.checkIn);
        final outStr = DateHelper.formatTimeString(existing.checkOut);
        throw Exception('تم تسجيل الحضور ($inStr) والانصراف ($outStr) مسبقاً لهذا اليوم');
      }
    }

    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final record = {
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
    };

    await db.insert('attendance', record);

    // Queue for sync
    await queueSyncItem(
      operation: 'INSERT',
      tableName: 'attendance',
      recordId: id,
      payload: record,
    );

    return id;
  }

  // --- Sync Queue Operations (PDF Page 9) ---
  Future<void> queueSyncItem({
    required String operation,
    required String tableName,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'operation': operation,
      'table_name': tableName,
      'record_id': recordId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'status': 'انتظار',
      'error': null,
    });
  }

  Future<List<SyncQueueItem>> getSyncQueueItems() async {
    final db = await database;
    final res = await db.query('sync_queue', orderBy: 'id DESC');
    return res.map((m) => SyncQueueItem.fromMap(m)).toList();
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM sync_queue WHERE status != 'تمت'"
    );
    return (res.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<void> updateSyncItemStatus(int id, String status, {String? error, int? attempts}) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'status': status,
        'error': ?error,
        'attempts': ?attempts,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markRecordAsSynced(String tableName, String recordId) async {
    final db = await database;
    if (tableName == 'attendance') {
      await db.update(
        'attendance',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [recordId],
      );
    }
  }

  Future<int> markAllQueueItemsAsSynced() async {
    final db = await database;
    final res = await db.update(
      'sync_queue',
      {'status': 'تمت', 'error': null},
    );
    await db.update('attendance', {'is_synced': 1});
    return res;
  }

  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue');
  }

  // --- Academic & Session Helpers ---
  Future<List<College>> getColleges() async {
    final db = await database;
    final res = await db.query('colleges');
    return res.map((m) => College.fromMap(m)).toList();
  }

  Future<List<Department>> getDepartments({int? collegeId}) async {
    final db = await database;
    final res = collegeId != null
        ? await db.query('departments', where: 'college_id = ?', whereArgs: [collegeId])
        : await db.query('departments');
    return res.map((m) => Department.fromMap(m)).toList();
  }

  Future<List<AcademicLevel>> getAcademicLevels() async {
    final db = await database;
    final res = await db.query('academic_levels', orderBy: 'order_no ASC');
    return res.map((m) => AcademicLevel.fromMap(m)).toList();
  }

  Future<List<Semester>> getSemesters() async {
    final db = await database;
    final res = await db.query('semesters');
    return res.map((m) => Semester.fromMap(m)).toList();
  }

  Future<List<Course>> getCourses() async {
    final db = await database;
    final res = await db.query('courses');
    return res.map((m) => Course.fromMap(m)).toList();
  }

  Future<List<Classroom>> getClassrooms() async {
    final db = await database;
    final res = await db.query('classrooms');
    return res.map((m) => Classroom.fromMap(m)).toList();
  }

  Future<List<Lecture>> getLectures() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT l.*, c.name as course_name, c.code as course_code, cr.name as classroom_name
      FROM lectures l
      JOIN courses c ON l.course_id = c.id
      JOIN classrooms cr ON l.classroom_id = cr.id
    ''');
    return res.map((m) => Lecture.fromMap(m)).toList();
  }

  Future<AttendanceSession?> getActiveSession() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT ses.*, c.name as lecture_name, cr.name as classroom_name, l.instructor
      FROM attendance_sessions ses
      JOIN lectures l ON ses.lecture_id = l.id
      JOIN courses c ON l.course_id = c.id
      JOIN classrooms cr ON l.classroom_id = cr.id
      WHERE ses.status = 'نشطة'
      ORDER BY ses.id DESC LIMIT 1
    ''');
    if (res.isNotEmpty) {
      return AttendanceSession.fromMap(res.first);
    }
    return null;
  }

  // --- Audit Logs ---
  Future<void> addAuditLog({
    required String userId,
    required String action,
    required String tableName,
    String? oldData,
    String? newData,
  }) async {
    final db = await database;
    await db.insert('audit_logs', {
      'user_id': userId,
      'action': action,
      'table_name': tableName,
      'old_data': oldData,
      'new_data': newData,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<AuditLog>> getAuditLogs() async {
    final db = await database;
    final res = await db.query('audit_logs', orderBy: 'id DESC', limit: 100);
    return res.map((m) => AuditLog.fromMap(m)).toList();
  }

  // --- Settings ---
  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final db = await database;
    final res = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Biometric Fingerprint Methods ---
  Future<bool> isFingerprintDuplicate(String fingerprintId, {int? excludeStudentId}) async {
    final db = await database;
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS student_fingerprints (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          university_id TEXT NOT NULL,
          fingerprint_id TEXT UNIQUE NOT NULL,
          template_hash TEXT NOT NULL,
          quality_score INTEGER NOT NULL DEFAULT 90,
          enrolled_at TEXT NOT NULL,
          device_model TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
        )
      ''');
      String where = 'fingerprint_id = ? AND is_active = 1';
      List<dynamic> args = [fingerprintId];
      if (excludeStudentId != null) {
        where += ' AND student_id != ?';
        args.add(excludeStudentId);
      }
      final res = await db.query('student_fingerprints', where: where, whereArgs: args);
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<int> saveStudentFingerprint(StudentFingerprint fp) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_fingerprints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        university_id TEXT NOT NULL,
        fingerprint_id TEXT UNIQUE NOT NULL,
        template_hash TEXT NOT NULL,
        quality_score INTEGER NOT NULL DEFAULT 90,
        enrolled_at TEXT NOT NULL,
        device_model TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // Deactivate any old fingerprint for this student
    await db.update(
      'student_fingerprints',
      {'is_active': 0},
      where: 'student_id = ?',
      whereArgs: [fp.studentId],
    );

    // Insert new active fingerprint
    final id = await db.insert(
      'student_fingerprints',
      fp.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update student table
    await db.update(
      'students',
      {
        'fingerprint_id': fp.fingerprintId,
      },
      where: 'id = ?',
      whereArgs: [fp.studentId],
    );

    return id;
  }

  Future<void> deleteStudentFingerprint(int studentId) async {
    final db = await database;
    try {
      await db.delete(
        'student_fingerprints',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      await db.update(
        'students',
        {'fingerprint_id': null},
        where: 'id = ?',
        whereArgs: [studentId],
      );
    } catch (_) {}
  }

  Future<StudentFingerprint?> getStudentFingerprint(int studentId) async {
    final db = await database;
    try {
      final res = await db.query(
        'student_fingerprints',
        where: 'student_id = ? AND is_active = 1',
        whereArgs: [studentId],
        limit: 1,
      );
      if (res.isNotEmpty) return StudentFingerprint.fromMap(res.first);
    } catch (_) {}
    return null;
  }

  Future<List<StudentFingerprint>> getStudentFingerprints() async {
    final db = await database;
    try {
      final res = await db.query(
        'student_fingerprints',
        where: 'is_active = 1',
        orderBy: 'enrolled_at DESC',
      );
      return res.map((m) => StudentFingerprint.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> logBiometricVerification(BiometricVerificationLog log) async {
    final db = await database;
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS biometric_verification_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          method TEXT NOT NULL,
          student_id INTEGER,
          student_name TEXT,
          university_id TEXT,
          status TEXT NOT NULL,
          reason TEXT NOT NULL,
          device_model TEXT NOT NULL
        )
      ''');
      return await db.insert('biometric_verification_logs', log.toMap());
    } catch (_) {
      return 0;
    }
  }

  Future<List<BiometricVerificationLog>> getBiometricVerificationLogs({
    bool onlyFailed = false,
    int limit = 100,
  }) async {
    final db = await database;
    try {
      String? where = onlyFailed ? "status = 'فشل'" : null;
      final res = await db.query(
        'biometric_verification_logs',
        where: where,
        orderBy: 'id DESC',
        limit: limit,
      );
      return res.map((m) => BiometricVerificationLog.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }
}

