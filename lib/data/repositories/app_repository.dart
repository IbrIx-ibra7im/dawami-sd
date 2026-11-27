import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/hive_helper.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/models/student.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/lecture.dart';
import '../../data/models/sync_and_auth_models.dart';
import '../../data/models/biometric_models.dart';
import '../../data/models/biometric_device.dart';
import '../../core/permissions/role_manager.dart';
import '../../core/services/sync_service.dart';

class AppRepository extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final HiveHelper _hive = HiveHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  // University & App Config
  String _universityName = 'جامعة دنقلا - كلية علوم الحاسوب والتنمية البشرية';
  bool _isDarkMode = false;
  String _deviceName = 'ZK-F18';
  bool _isFingerprintEnabled = true;
  bool _isBarcodeEnabled = true;
  bool _isFaceEnabled = true;

  // Current logged in user (Requires authentication before entering control panel)
  bool _isLoggedIn = false;
  bool _isPrimaryConnected = false;
  UserProfile _currentUser = UserProfile(
    id: 'kiosk-user',
    fullName: 'محطة تسجيل الحضور',
    role: 'attendance_officer',
    email: 'attendance@dawami.edu',
    createdAt: DateTime.now().toIso8601String(),
  );

  // Active Data Cache
  AttendanceSession? _activeSession;
  List<Student> _students = [];
  List<AttendanceRecord> _todayAttendance = [];
  List<College> _colleges = [];
  List<Department> _departments = [];
  List<AcademicLevel> _levels = [];
  List<Lecture> _lectures = [];
  List<StudentFingerprint> _fingerprints = [];
  final List<BiometricVerificationLog> _biometricLogs = [];
  List<BiometricDevice> _biometricDevices = [];

  // Getters
  String get universityName => _universityName;
  bool get isDarkMode => _isDarkMode;
  bool get isFingerprintEnabled => _isFingerprintEnabled;
  bool get isBarcodeEnabled => _isBarcodeEnabled;
  bool get isFaceEnabled => _isFaceEnabled;
  String get deviceName => _deviceName;
  bool get isLoggedIn => _isLoggedIn;
  UserProfile get currentUser => _currentUser;
  UserRole get currentRole => RoleManager.fromString(_currentUser.role);
  AttendanceSession? get activeSession => _activeSession;
  List<Student> get students => _students;
  List<AttendanceRecord> get todayAttendance => _todayAttendance;
  List<College> get colleges => _colleges;
  List<Department> get departments => _departments;
  List<AcademicLevel> get levels => _levels;
  List<Lecture> get lectures => _lectures;
  List<StudentFingerprint> get fingerprints => _fingerprints;
  List<BiometricVerificationLog> get biometricLogs => _biometricLogs;
  List<BiometricDevice> get biometricDevices => _biometricDevices;
  List<Student> get studentsWithoutFingerprints => _students.where((s) => !s.hasFingerprint).toList();
  List<Student> get studentsWithFingerprints => _students.where((s) => s.hasFingerprint).toList();
  int get enrolledFingerprintsCount => _students.where((s) => s.hasFingerprint).length;
  int get missingFingerprintsCount => _students.where((s) => !s.hasFingerprint).length;

  // Primary (Supabase) and Backup (Hive) Database Information
  bool get isPrimaryConnected => _isPrimaryConnected;
  String get primaryDbName => 'Supabase (قاعدة البيانات الأساسية)';
  String get backupDbName => 'Hive (قاعدة البيانات الاحتياطية)';
  String get primaryDbStatusText => _isPrimaryConnected ? 'متصلة ونشطة' : 'أوفلاين (الاعتماد على النسخة الاحتياطية)';
  String get backupDbStatusText => 'نشطة وجاهزة (حفظ محلي فوري)';
  int get backupAttendanceCount => _hive.attendanceCount;
  int get backupStudentsCount => _hive.studentsCount;

  // Statistics
  int get totalStudentsCount => _students.length;
  int get presentCount => _todayAttendance.where((a) => a.status == 'حاضر' || a.status == 'متأخر').length;
  int get departedCount => _todayAttendance.where((a) => a.checkOut != null && a.checkOut!.isNotEmpty).length;
  int get currentlyPresentCount => _todayAttendance.where((a) => (a.status == 'حاضر' || a.status == 'متأخر') && (a.checkOut == null || a.checkOut!.isEmpty)).length;
  int get lateCount => _todayAttendance.where((a) => a.status == 'متأخر' || a.delayMinutes > 0).length;
  int get absentCount {
    final diff = _students.length - presentCount;
    return diff > 0 ? diff : 0;
  }
  int get connectedDevicesCount => _biometricDevices.where((d) => d.isConnected).length;
  int get disconnectedDevicesCount => _biometricDevices.where((d) => !d.isConnected).length;

  int get fingerprintAttendanceCount => _todayAttendance.where((a) => a.method.toLowerCase().startsWith('fingerprint')).length;
  int get faceAttendanceCount => _todayAttendance.where((a) => a.method.toLowerCase() == 'face').length;
  int get mobileAttendanceCount => _todayAttendance.where((a) => a.method.toLowerCase() == 'mobile').length;
  int get qrAttendanceCount => _todayAttendance.where((a) => a.method.toLowerCase() == 'qr' || a.method.toLowerCase() == 'barcode_qr' || a.method.toLowerCase() == 'barcode').length;
  int get manualAttendanceCount => _todayAttendance.where((a) => a.method.toLowerCase() == 'manual').length;

  Future<Set<String>> _pendingStudentDeletions() async {
    final pending = <String>{};
    if (!_hive.isInitialized) return pending;
    for (final item in await _hive.getSyncQueueItems()) {
      if (item.tableName != 'students' ||
          item.operation.toUpperCase() != 'DELETE' ||
          item.status == 'تمت') {
        continue;
      }
      final payload = jsonDecode(item.payload);
      if (payload is Map) {
        final universityId =
            payload['university_id'] ??
            payload['student_number'] ??
            payload['record_key'];
        if (universityId != null && universityId.toString().isNotEmpty) {
          pending.add(universityId.toString());
        }
      }
    }
    return pending;
  }

  AppRepository() {
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      try {
        _universityName = await _hive.getSetting(
          'university_name',
          defaultValue: 'جامعة دنقلا - كلية علوم الحاسوب والتنمية البشرية',
        );
        if (_universityName.contains('الخرطوم') || _universityName.isEmpty) {
          _universityName = 'جامعة دنقلا - كلية علوم الحاسوب والتنمية البشرية';
          await _hive.setSetting('university_name', _universityName);
        }
      } catch (_) {}

      try {
        await _db.setSetting('university_name', _universityName);
      } catch (_) {}

      try {
        _deviceName = await _hive.getSetting('device_name', defaultValue: 'ZK-F18');
      } catch (_) {}

      try {
        final fpSetting = await _hive.getSetting('enable_fingerprint', defaultValue: 'true');
        _isFingerprintEnabled = fpSetting != 'false';
      } catch (_) {}

      try {
        final bcSetting = await _hive.getSetting('enable_barcode', defaultValue: 'true');
        _isBarcodeEnabled = bcSetting != 'false';
      } catch (_) {}

      try {
        final faceSetting = await _hive.getSetting('enable_face', defaultValue: 'true');
        _isFaceEnabled = faceSetting != 'false';
      } catch (_) {}

      try {
        _colleges = await _hive.getColleges();
      } catch (_) {}
      if (_colleges.isEmpty) {
        try {
          _colleges = await _db.getColleges();
        } catch (_) {}
      }

      try {
        _departments = await _hive.getDepartments();
      } catch (_) {}
      if (_departments.isEmpty) {
        try {
          _departments = await _db.getDepartments();
        } catch (_) {}
      }

      try {
        _levels = await _hive.getAcademicLevels();
      } catch (_) {}
      if (_levels.isEmpty) {
        try {
          _levels = await _db.getAcademicLevels();
        } catch (_) {}
      }

      try {
        _lectures = await _hive.getLectures();
      } catch (_) {}
      if (_lectures.isEmpty) {
        try {
          _lectures = await _db.getLectures();
        } catch (_) {}
      }

      try {
        _activeSession = await _hive.getActiveSession();
      } catch (_) {}
      if (_activeSession == null) {
        try {
          _activeSession = await _db.getActiveSession();
        } catch (_) {}
      }

      try {
        final savedLoginState = await _hive.getSetting('is_logged_in', defaultValue: 'false');
        _isLoggedIn = savedLoginState == 'true';
        final savedRole = await _hive.getSetting('current_user_role', defaultValue: 'super_admin');
        if (!_isLoggedIn) {
          _currentUser = UserProfile(
            id: 'kiosk-user',
            fullName: 'محطة تسجيل الحضور',
            role: 'attendance_officer',
            email: 'attendance@dawami.edu',
            createdAt: DateTime.now().toIso8601String(),
          );
        } else {
          _currentUser = UserProfile(
            id: 'mock-$savedRole',
            fullName: RoleManager.getRoleDisplayName(RoleManager.fromString(savedRole)),
            role: savedRole,
            email: '$savedRole@dawami.edu',
            createdAt: DateTime.now().toIso8601String(),
          );
        }
      } catch (_) {}

      // تفريغ الأسماء والسجلات الوهمية السابقة نهائياً لبدء النظام بنظافة تامة
      try {
        final purged = await _hive.getSetting('mock_names_purged_v1', defaultValue: 'false');
        if (purged != 'true') {
          await _hive.clearAllStudentsAndAttendance();
          await _db.clearAllStudentsAndAttendance();
          await _hive.setSetting('mock_names_purged_v1', 'true');
          try {
            await _db.setSetting('mock_names_purged_v1', 'true');
          } catch (_) {}
        }
      } catch (_) {}

      await checkPrimaryConnection();
      await refreshStudents();
      await refreshAttendance();
      await refreshFingerprints();
      await refreshBiometricDevices();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading data: $e');
      notifyListeners();
    }
  }

  Future<void> refreshBiometricDevices() async {
    try {
      if (_hive.isInitialized) {
        _biometricDevices = await _hive.getBiometricDevices();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshStudents({String? query, int? collegeId, String? status}) async {
    bool loadedFromPrimary = false;

    // 1. Try Primary Database: Supabase
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        final remoteStudents = await _supabase.getStudents(
          query: query,
          collegeId: collegeId,
          status: status,
        );
        if (remoteStudents.isNotEmpty || query != null || collegeId != null) {
          final pendingDeletes = await _pendingStudentDeletions();
          _students = remoteStudents
              .where((student) => !pendingDeletes.contains(student.universityId))
              .toList();
          _isPrimaryConnected = true;
          loadedFromPrimary = true;
          // Mirror/Backup into local Hive storage
          if (_hive.isInitialized) {
            await _hive.batchInsertOrUpdateStudents(_students);
          }
        }
      } catch (e) {
        if (kDebugMode) print('Primary DB (Supabase) load students failed, using backup Hive: $e');
        _isPrimaryConnected = false;
      }
    }

    // 2. Backup Database: Hive (offline or primary fallback)
    if (!loadedFromPrimary) {
      try {
        if (_hive.isInitialized) {
          _students = await _hive.getStudents(query: query, collegeId: collegeId, status: status);
          if (_students.isEmpty && (query == null || query.isEmpty) && collegeId == null && (status == null || status == 'الكل')) {
            try {
              final dbList = await _db.getStudents(query: query, collegeId: collegeId, status: status);
              if (dbList.isNotEmpty) {
                _students = dbList;
                for (final s in dbList) {
                  await _hive.insertStudent(s);
                }
              }
            } catch (_) {}
          }
        } else {
          try {
            _students = await _db.getStudents(query: query, collegeId: collegeId, status: status);
          } catch (_) {}
        }
      } catch (_) {
        try {
          _students = await _db.getStudents(query: query, collegeId: collegeId, status: status);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<void> refreshAttendance({String? method}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    bool loadedFromPrimary = false;

    // 1. Try Primary Database: Supabase
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        final remoteRecords = await _supabase.getAttendanceRecords(
          sessionId: _activeSession?.id,
          date: _activeSession == null ? today : null,
          method: method,
        );
        if (remoteRecords.isNotEmpty) {
          final pendingDeletes = await _pendingStudentDeletions();
          _todayAttendance = remoteRecords
              .where((record) => !pendingDeletes.contains(record.universityId))
              .toList();
          _isPrimaryConnected = true;
          loadedFromPrimary = true;
          // Mirror/Backup into local Hive storage
          if (_hive.isInitialized) {
            await _hive.saveAttendanceRecords(_todayAttendance);
          }
        }
      } catch (e) {
        if (kDebugMode) print('Primary DB (Supabase) load attendance failed, using backup Hive: $e');
        _isPrimaryConnected = false;
      }
    }

    // 2. Backup Database: Hive (offline or primary fallback)
    if (!loadedFromPrimary) {
      try {
        if (_hive.isInitialized) {
          _todayAttendance = await _hive.getAttendanceRecords(
            sessionId: _activeSession?.id,
            date: _activeSession == null ? today : null,
            method: method,
          );
          if (_todayAttendance.isEmpty && (method == null || method == 'الكل')) {
            try {
              final dbAtt = await _db.getAttendanceRecords(
                sessionId: _activeSession?.id,
                date: _activeSession == null ? today : null,
                method: method,
              );
              if (dbAtt.isNotEmpty) {
                _todayAttendance = dbAtt;
              }
            } catch (_) {}
          }
        } else {
          _todayAttendance = await _db.getAttendanceRecords(
            sessionId: _activeSession?.id,
            date: _activeSession == null ? today : null,
            method: method,
          );
        }
      } catch (_) {
        try {
          _todayAttendance = await _db.getAttendanceRecords(
            sessionId: _activeSession?.id,
            date: _activeSession == null ? today : null,
            method: method,
          );
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  // --- Auth & Role Switching ---
  void switchUserRole(UserRole role) {
    _isLoggedIn = true;
    _currentUser = UserProfile(
      id: 'mock-${RoleManager.toRoleString(role)}',
      fullName: RoleManager.getRoleDisplayName(role),
      role: RoleManager.toRoleString(role),
      email: '${RoleManager.toRoleString(role)}@dawami.edu',
      createdAt: DateTime.now().toIso8601String(),
    );
    _hive.setSetting('is_logged_in', 'true');
    _hive.setSetting('current_user_role', RoleManager.toRoleString(role));
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _currentUser = UserProfile(
      id: 'kiosk-user',
      fullName: 'محطة تسجيل الحضور',
      role: 'attendance_officer',
      email: 'attendance@dawami.edu',
      createdAt: DateTime.now().toIso8601String(),
    );
    _hive.setSetting('is_logged_in', 'false');
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty) {
      throw Exception('يرجى إدخال البريد الإلكتروني أو اسم المستخدم');
    }
    if (cleanPassword.isEmpty) {
      throw Exception('يرجى إدخال كلمة المرور');
    }

    // 1. Check Supabase Cloud Authentication (if configured and online)
    if (_supabase.isConfigured) {
      try {
        final profile = await _supabase.signIn(cleanEmail, cleanPassword);
        if (profile != null) {
          _currentUser = profile;
          _isLoggedIn = true;
          await _hive.setSetting('is_logged_in', 'true');
          notifyListeners();
          return true;
        }
      } catch (_) {
        // Fall back to local validation
      }
    }

    // 2. Strict Administration Authentication: Password MUST strictly be 00000
    final isAdmin = cleanEmail.contains('admin') ||
        cleanEmail == 'super_admin' ||
        cleanEmail == 'مدير' ||
        cleanEmail == '00000';

    if (isAdmin) {
      if (cleanPassword != '00000') {
        throw Exception('كلمة المرور غير صحيحة للإدارة. كلمة المرور المعتمدة هي: 00000');
      }

      _isLoggedIn = true;
      _currentUser = UserProfile(
        id: 'user-admin-01',
        fullName: 'مدير',
        role: 'super_admin',
        email: cleanEmail.contains('@') ? cleanEmail : 'admin@dawami.edu',
        createdAt: DateTime.now().toIso8601String(),
      );
      await _hive.setSetting('is_logged_in', 'true');
      await _hive.setSetting('current_user_role', 'super_admin');
      notifyListeners();
      return true;
    }

    // 3. Other Staff Roles (attendance officer, registration staff, supervisor, viewer)
    if (cleanPassword != '00000' && cleanPassword != '123456') {
      throw Exception('كلمة المرور غير صحيحة. كلمة المرور المعتمدة هي: 00000');
    }

    if (cleanEmail.contains('staff') || cleanEmail.contains('reg') || cleanEmail.contains('مسجل')) {
      switchUserRole(UserRole.registrationStaff);
    } else if (cleanEmail.contains('supervisor') || cleanEmail.contains('مشرف')) {
      switchUserRole(UserRole.supervisor);
    } else if (cleanEmail.contains('officer') || cleanEmail.contains('attendance')) {
      switchUserRole(UserRole.attendanceOfficer);
    } else {
      switchUserRole(UserRole.viewer);
    }

    _isLoggedIn = true;
    await _hive.setSetting('is_logged_in', 'true');
    notifyListeners();
    return true;
  }

  // --- Record Attendance (Online & Offline) ---
  Future<AttendanceRecord> registerAttendance({
    required Student student,
    required String method, // 'qr', 'fingerprint', 'manual'
    String? customStatus,
    String? verifiedFingerprintId,
  }) async {
    if (student.status != 'نشط') {
      throw Exception('عذراً، الطالب غير نشط وحالته الحالية: (${student.status})');
    }

    if (method.trim().toLowerCase().startsWith('fingerprint')) {
      final isActivated =
          verifiedFingerprintId == student.fingerprintId &&
          await _hive.hasActiveFingerprintForStudent(student);
      if (!isActivated) {
        throw Exception(fingerprintNotActivatedMessage);
      }
    }

    if (_activeSession == null) {
      Lecture? defaultLecture;
      if (_lectures.isNotEmpty) {
        defaultLecture = _lectures.first;
      } else {
        final hiveLectures = await _hive.getLectures();
        if (hiveLectures.isNotEmpty) {
          defaultLecture = hiveLectures.first;
        } else {
          try {
            final dbLectures = await _db.getLectures();
            if (dbLectures.isNotEmpty) defaultLecture = dbLectures.first;
          } catch (_) {}
        }
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final sessionMap = {
        'id': 1,
        'lecture_id': defaultLecture?.id ?? 1,
        'session_date': today,
        'status': 'نشطة',
        'lecture_name': defaultLecture?.courseName ?? 'هياكل البيانات والخوارزميات',
        'classroom_name': defaultLecture?.classroomName ?? 'قاعة الخوارزمي',
        'instructor': defaultLecture?.instructor ?? 'د. عبدالله أحمد',
      };

      await _hive.saveSession(sessionMap);
      try {
        final db = await _db.database;
        await db.insert(
          'attendance_sessions',
          {
            'id': 1,
            'lecture_id': defaultLecture?.id ?? 1,
            'session_date': today,
            'status': 'نشطة',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}

      _activeSession = AttendanceSession.fromMap(sessionMap);
    }

    // Determine status (حاضر / متأخر) based on time rules
    String status = customStatus ?? 'حاضر';
    final nowTime = DateTime.now().toIso8601String();
    
    // 1. Save to Backup Database: Hive (Primary local safety with zero-lock instant storage)
    final recordId = await _hive.recordAttendance(
      studentId: student.id!,
      sessionId: _activeSession!.id!,
      method: method,
      status: status,
      deviceId: _deviceName,
    );

    try {
      await _db.recordAttendance(
        studentId: student.id!,
        sessionId: _activeSession!.id!,
        method: method,
        status: status,
        deviceId: _deviceName,
      );
    } catch (_) {}

    // 2. Direct Sync to Primary Database: Supabase
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.recordAttendance(
          id: recordId,
          studentId: student.id!,
          sessionId: _activeSession!.id!,
          method: method,
          status: status,
          deviceId: _deviceName,
          checkIn: nowTime,
          studentNumber: student.universityId,
          studentName: student.fullName,
          lectureId: _activeSession!.id,
        );
        _isPrimaryConnected = true;
        await _hive.markRecordAsSynced('attendance', recordId);
      } catch (e) {
        if (kDebugMode) print('Direct primary DB attendance sync notice (safely backed up in Hive): $e');
      }
    }

    _triggerAutoSync();
    SyncService.instance.refreshPendingCount();

    await refreshAttendance();
    return _todayAttendance.firstWhere(
      (a) => a.id == recordId,
      orElse: () => AttendanceRecord(
        id: recordId,
        studentId: student.id!,
        sessionId: _activeSession!.id!,
        checkIn: DateTime.now().toIso8601String(),
        method: method,
        status: status,
        deviceId: _deviceName,
        createdAt: DateTime.now().toIso8601String(),
        studentName: student.fullName,
        universityId: student.universityId,
        lectureName: _activeSession?.lectureName,
        classroomName: _activeSession?.classroomName,
      ),
    );
  }

  // --- Student Lookup ---
  Future<Student?> getStudentByCode(String code) async {
    final sHive = await _hive.getStudentByQrOrBarcode(code);
    if (sHive != null) return sHive;
    try {
      final sDb = await _db.getStudentByQrOrBarcode(code);
      if (sDb != null) return sDb;
      return await _db.getStudentByUniversityId(code);
    } catch (_) {
      return null;
    }
  }

  // --- Student CRUD ---
  Future<bool> addStudent(Student student) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      throw Exception('ليس لديك صلاحية لإضافة طالب');
    }
    final normalizedId = student.universityId.trim().toLowerCase();
    if (normalizedId.isEmpty) {
      throw Exception('الرقم الجامعي مطلوب لإضافة الطالب');
    }
    final localStudents = await _hive.getStudents();
    if ([..._students, ...localStudents].any(
      (existing) =>
          existing.universityId.trim().toLowerCase() == normalizedId,
    )) {
      throw Exception('الرقم الجامعي مسجل مسبقاً لطالب آخر');
    }

    // 1. Save to Backup Database (Hive)
    final studentToAdd = student.copyWith(
      universityId: student.universityId.trim(),
      clearFingerprint: true,
    );
    final id = await _hive.insertStudent(studentToAdd);
    try {
      await _db.insertStudent(studentToAdd.copyWith(id: id));
    } catch (_) {}

    // 2. Direct Sync to Primary Database (Supabase)
    var syncedToSupabase = false;
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        final saved = await _supabase.insertStudent(
          studentToAdd.copyWith(id: id),
        );
        syncedToSupabase = saved != null;
        _isPrimaryConnected = syncedToSupabase;
        if (syncedToSupabase) {
          await _hive.markRecordAsSynced('students', id.toString());
        }
      } catch (e) {
        _isPrimaryConnected = false;
        if (kDebugMode) print('Direct primary DB addStudent notice (backed up in Hive): $e');
      }
    } else {
      _isPrimaryConnected = false;
    }
    await refreshStudents();
    SyncService.instance.refreshPendingCount();
    return syncedToSupabase;
  }

  Future<int> importStudents(List<Student> students) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      throw Exception('ليس لديك صلاحية لإضافة أو استيراد الطلاب');
    }
    final safeStudents = <Student>[];
    final importedIds = <String>{};
    for (final importedStudent in students) {
      final normalizedId = importedStudent.universityId.trim().toLowerCase();
      if (normalizedId.isEmpty || !importedIds.add(normalizedId)) {
        throw Exception(
          'الملف يحتوي على رقم جامعي فارغ أو مكرر: ${importedStudent.universityId}',
        );
      }

      final existing = await _hive.getStudentByUniversityId(
        importedStudent.universityId,
      );
      if (existing != null &&
          await _hive.hasActiveFingerprintForStudent(existing)) {
        safeStudents.add(
          importedStudent.copyWith(
            id: existing.id,
            fingerprintId: existing.fingerprintId,
            fingerprintStatus: 'مسجلة',
            fingerprintQuality: existing.fingerprintQuality,
            fingerprintEnrolledAt: existing.fingerprintEnrolledAt,
          ),
        );
      } else {
        safeStudents.add(importedStudent.copyWith(clearFingerprint: true));
      }
    }

    // Batch Insert to Backup Database (Hive)
    final count = await _hive.batchInsertOrUpdateStudents(safeStudents);
    try {
      await _db.batchInsertOrUpdateStudents(safeStudents);
    } catch (_) {}

    // Batch Insert to Primary Database (Supabase)
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.batchUpsertStudents(
          safeStudents.map((s) => s.toMap()).toList(),
        );
        _isPrimaryConnected = true;
      } catch (e) {
        if (kDebugMode) print('Direct primary DB batchUpsertStudents notice (backed up in Hive): $e');
      }
    }
    await refreshStudents();
    return count;
  }

  Future<void> linkBarcodeToStudent(int studentId, String newBarcode) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      throw Exception('ليس لديك صلاحية لتعديل بيانات الطالب');
    }
    await _hive.linkBarcodeToStudent(studentId, newBarcode);
    try {
      await _db.linkBarcodeToStudent(studentId, newBarcode);
    } catch (_) {}
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        final s = await _hive.getStudentById(studentId);
        if (s != null) {
          await _supabase.updateStudent(s);
          _isPrimaryConnected = true;
        }
      } catch (_) {}
    }
    await refreshStudents();
  }

  Future<bool> updateStudent(Student student) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      throw Exception('ليس لديك صلاحية لتعديل بيانات الطالب');
    }
    if (student.id == null || student.universityId.trim().isEmpty) {
      throw Exception('معرّف الطالب والرقم الجامعي مطلوبان للتعديل');
    }

    Student? previousStudent = await _hive.getStudentById(student.id!);
    if (previousStudent == null) {
      for (final existing in _students) {
        if (existing.id == student.id) {
          previousStudent = existing;
          break;
        }
      }
    }
    if (previousStudent == null) {
      throw Exception('تعذر العثور على الطالب المطلوب تعديله');
    }

    final normalizedId = student.universityId.trim().toLowerCase();
    final localStudents = await _hive.getStudents();
    final duplicate = [..._students, ...localStudents].any(
      (existing) =>
          existing.id != student.id &&
          existing.universityId.trim().toLowerCase() == normalizedId,
    );
    if (duplicate) {
      throw Exception('الرقم الجامعي مسجل مسبقاً لطالب آخر');
    }

    var updatedStudent = student.copyWith(
      universityId: student.universityId.trim(),
    );
    final universityIdChanged =
        previousStudent.universityId != updatedStudent.universityId;
    if (universityIdChanged) {
      // تغيير الرقم الجامعي يبطل ربط البصمة القديمة بهوية الطالب السابقة.
      await _hive.deleteStudentFingerprint(student.id!);
      try {
        await _db.deleteStudentFingerprint(student.id!);
      } catch (e) {
        if (kDebugMode) {
          print('Local SQLite fingerprint cleanup notice: $e');
        }
      }
      updatedStudent = updatedStudent.copyWith(
        clearFingerprint: true,
      );
    }

    // 1. Update in Backup Database (Hive)
    await _hive.updateStudent(
      updatedStudent,
      previousUniversityId: previousStudent.universityId,
    );
    try {
      await _db.updateStudent(updatedStudent);
    } catch (e) {
      if (kDebugMode) print('Local SQLite updateStudent notice: $e');
    }

    var syncedToSupabase = false;
    // 2. Update in Primary Database (Supabase)
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        syncedToSupabase = await _supabase.updateStudent(
          updatedStudent,
          previousUniversityId: previousStudent.universityId,
        );
        _isPrimaryConnected = syncedToSupabase;
        if (syncedToSupabase) {
          await _hive.markRecordAsSynced(
            'students',
            updatedStudent.id.toString(),
          );
        }
      } catch (e) {
        _isPrimaryConnected = false;
        if (kDebugMode) print('Direct primary DB updateStudent notice (backed up in Hive): $e');
      }
    } else {
      _isPrimaryConnected = false;
    }
    final existingIndex = _students.indexWhere(
      (existing) =>
          existing.id == updatedStudent.id ||
          existing.universityId == previousStudent?.universityId,
    );
    if (existingIndex == -1) {
      _students.add(updatedStudent);
    } else {
      _students[existingIndex] = updatedStudent;
    }
    notifyListeners();
    _triggerAutoSync();
    SyncService.instance.refreshPendingCount();
    return syncedToSupabase;
  }

  Future<void> deleteStudent(int studentId) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      throw Exception('ليس لديك صلاحية لحذف الطالب');
    }

    Student? targetStudent;
    try {
      targetStudent = await _hive.getStudentById(studentId);
    } catch (e) {
      if (kDebugMode) print('Could not load student before deletion: $e');
    }
    if (targetStudent == null) {
      for (final student in _students) {
        if (student.id == studentId) {
          targetStudent = student;
          break;
        }
      }
    }

    // 1. Delete from Backup Database (Hive)
    await _hive.deleteStudent(studentId, student: targetStudent);
    try {
      await _db.deleteStudent(studentId, student: targetStudent);
    } catch (e) {
      if (kDebugMode) print('Local SQLite deleteStudent notice: $e');
    }

    // 2. Delete from Primary Database (Supabase)
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        final deleted = await _supabase.deleteStudent(
          studentId,
          targetStudent?.universityId,
        );
        if (deleted) {
          _isPrimaryConnected = true;
        } else if (kDebugMode) {
          print('Remote student delete deferred to the sync queue');
        }
      } catch (e) {
        if (kDebugMode) print('Direct primary DB deleteStudent notice: $e');
      }
    }
    _students.removeWhere((student) => student.id == studentId);
    _todayAttendance.removeWhere(
      (record) =>
          record.studentId == studentId ||
          (targetStudent != null &&
              record.universityId == targetStudent.universityId),
    );
    _fingerprints.removeWhere((fingerprint) => fingerprint.studentId == studentId);
    _biometricLogs.removeWhere(
      (log) =>
          log.studentId == studentId ||
          (targetStudent != null &&
              log.universityId == targetStudent.universityId),
    );
    await refreshStudents();
    notifyListeners();
  }

  Future<void> deleteMultipleStudents(List<int> studentIds) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      throw Exception('ليس لديك صلاحية لحذف الطلاب');
    }

    final idsToDelete = studentIds.toSet().toList();
    final studentsById = <int, Student>{};
    for (final id in idsToDelete) {
      try {
        final student = await _hive.getStudentById(id);
        if (student != null) studentsById[id] = student;
      } catch (e) {
        if (kDebugMode) print('Could not load student $id before deletion: $e');
      }
      if (!studentsById.containsKey(id)) {
        for (final student in _students) {
          if (student.id == id) {
            studentsById[id] = student;
            break;
          }
        }
      }
    }

    // 1. Delete from Backup Database (Hive)
    await _hive.deleteMultipleStudents(
      idsToDelete,
      studentsById: studentsById,
    );
    for (final id in idsToDelete) {
      try {
        await _db.deleteStudent(id, student: studentsById[id]);
      } catch (e) {
        if (kDebugMode) print('Local SQLite deleteStudent notice for $id: $e');
      }
    }

    // 2. Delete from Primary Database (Supabase)
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        final deleted = await _supabase.deleteMultipleStudents(
          studentsById.values.map((student) => student.universityId).toList(),
        );
        if (deleted) {
          _isPrimaryConnected = true;
        } else if (kDebugMode) {
          print('Remote bulk student delete deferred to the sync queue');
        }
      } catch (e) {
        if (kDebugMode) print('Direct primary DB deleteMultipleStudents notice: $e');
      }
    }
    final deletedUniversityIds = studentsById.values
        .map((student) => student.universityId)
        .toSet();
    _students.removeWhere((student) => idsToDelete.contains(student.id));
    _todayAttendance.removeWhere(
      (record) =>
          idsToDelete.contains(record.studentId) ||
          deletedUniversityIds.contains(record.universityId),
    );
    _fingerprints.removeWhere(
      (fingerprint) => idsToDelete.contains(fingerprint.studentId),
    );
    _biometricLogs.removeWhere(
      (log) =>
          idsToDelete.contains(log.studentId) ||
          deletedUniversityIds.contains(log.universityId),
    );
    await refreshStudents();
    notifyListeners();
  }

  Future<void> deleteAttendanceRecord(String id) async {
    // 1. Delete from Backup Database (Hive)
    await _hive.deleteAttendanceRecord(id);
    try {
      await _db.deleteAttendanceRecord(id);
    } catch (_) {}

    // 2. Delete from Primary Database (Supabase)
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.deleteAttendanceRecord(id);
        _isPrimaryConnected = true;
      } catch (e) {
        if (kDebugMode) print('Direct primary DB deleteAttendanceRecord notice: $e');
      }
    }
    await refreshAttendance();
  }

  Future<void> deleteMultipleAttendanceRecords(List<String> ids) async {
    // 1. Delete from Backup Database (Hive)
    await _hive.deleteMultipleAttendanceRecords(ids);
    try {
      await _db.deleteMultipleAttendanceRecords(ids);
    } catch (_) {}

    // 2. Delete from Primary Database (Supabase)
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.deleteMultipleAttendanceRecords(ids);
        _isPrimaryConnected = true;
      } catch (e) {
        if (kDebugMode) print('Direct primary DB deleteMultipleAttendanceRecords notice: $e');
      }
    }
    await refreshAttendance();
  }

  /// Full two-way sync between Primary Database (Supabase) and Backup Database (Hive)
  Future<int> syncDatabases() async {
    final count = await _hive.syncWithSupabase();
    await checkPrimaryConnection();
    await refreshStudents();
    await refreshAttendance();
    notifyListeners();
    return count;
  }

  /// Check connectivity to Primary Database (Supabase)
  Future<bool> checkPrimaryConnection() async {
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        final res = await _supabase.testConnection();
        _isPrimaryConnected = res.isConnected;
      } catch (_) {
        _isPrimaryConnected = false;
      }
    } else {
      _isPrimaryConnected = false;
    }
    notifyListeners();
    return _isPrimaryConnected;
  }

  // --- Biometric / Fingerprint Operations ---

  /// تسجيل بصمة طالب جديدة وربطها بحسابه
  Future<void> enrollStudentFingerprint({
    required Student student,
    required String fingerprintId,
    required String templateHash,
    required int quality,
  }) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      throw Exception('ليس لديك صلاحية لتفعيل بصمة الطالب');
    }
    if (student.id == null ||
        student.universityId.trim().isEmpty ||
        fingerprintId.trim().isEmpty ||
        templateHash.trim().isEmpty ||
        quality < 75 ||
        quality > 100) {
      throw Exception('بيانات تسجيل البصمة غير مكتملة أو غير صالحة');
    }

    final storedStudent = await _hive.getStudentById(student.id!);
    if (storedStudent == null ||
        storedStudent.universityId != student.universityId) {
      throw Exception('يجب تسجيل الطالب أولاً وربط البصمة برقم جامعي صحيح');
    }

    // التحقق من عدم تكرار البصمة
    final isDuplicate = await isFingerprintDuplicate(
      fingerprintId,
      excludeStudentId: student.id,
    );
    if (isDuplicate) {
      throw Exception('هذه البصمة مسجلة بالفعل لطالب آخر. لا يمكن تكرار البصمة.');
    }

    final now = DateTime.now().toIso8601String();
    final fp = StudentFingerprint(
      id: student.id,
      studentId: student.id!,
      universityId: student.universityId,
      fingerprintId: fingerprintId,
      templateHash: templateHash,
      qualityScore: quality,
      enrolledAt: now,
      deviceModel: _deviceName,
      isActive: true,
    );

    // حفظ البصمة في Hive
    await _hive.saveStudentFingerprint(fp);
    // حفظ البصمة في SQLite
    try {
      await _db.saveStudentFingerprint(fp);
    } catch (_) {}

    // تحديث حالة البصمة في بيانات الطالب
    final updatedStudent = student.copyWith(
      fingerprintId: fingerprintId,
      fingerprintStatus: 'مسجلة',
      fingerprintQuality: quality,
      fingerprintEnrolledAt: now,
    );
    await updateStudent(updatedStudent);

    await refreshFingerprints();
    notifyListeners();
  }

  /// حذف بصمة طالب
  Future<void> deleteStudentFingerprint(int studentId) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      throw Exception('ليس لديك صلاحية لإلغاء تفعيل بصمة الطالب');
    }

    await _hive.deleteStudentFingerprint(studentId);
    try {
      await _db.deleteStudentFingerprint(studentId);
    } catch (_) {}

    // تحديث حالة الطالب
    final student = _students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => throw Exception('الطالب غير موجود'),
    );
    final updatedStudent = student.copyWith(clearFingerprint: true);
    await updateStudent(updatedStudent);

    await refreshFingerprints();
    notifyListeners();
  }

  /// التحقق من تكرار البصمة
  Future<bool> isFingerprintDuplicate(String fingerprintId, {int? excludeStudentId}) async {
    // التحقق في Hive أولاً
    final hiveDuplicate = await _hive.isFingerprintDuplicate(fingerprintId, excludeStudentId: excludeStudentId);
    if (hiveDuplicate) return true;
    // التحقق في SQLite
    try {
      return await _db.isFingerprintDuplicate(fingerprintId, excludeStudentId: excludeStudentId);
    } catch (_) {
      return false;
    }
  }

  /// تحميل البصمات المسجلة من قاعدة البيانات
  Future<void> refreshFingerprints() async {
    try {
      _fingerprints = await _hive.getStudentFingerprints();
      if (_fingerprints.isEmpty) {
        try {
          _fingerprints = await _db.getStudentFingerprints();
        } catch (_) {}
      }
    } catch (_) {
      try {
        _fingerprints = await _db.getStudentFingerprints();
      } catch (_) {}
    }
    notifyListeners();
  }

  /// تسجيل عملية تحقق بيومتري (ناجحة أو فاشلة) في السجل
  Future<void> logBiometricVerification(BiometricVerificationLog log) async {
    await _hive.logBiometricVerification(log);
    try {
      await _db.logBiometricVerification(log);
    } catch (_) {}
    _biometricLogs.add(log);
    notifyListeners();
  }

  /// جلب سجلات التحقق البيومتري
  Future<List<BiometricVerificationLog>> getBiometricVerificationLogs({bool onlyFailed = false}) async {
    try {
      final logs = await _hive.getBiometricVerificationLogs();
      if (onlyFailed) {
        return logs.where((l) => l.status != 'success').toList();
      }
      return logs;
    } catch (_) {
      try {
        return await _db.getBiometricVerificationLogs();
      } catch (_) {
        return [];
      }
    }
  }

  // --- Settings & Attendance Methods Control ---
  Future<void> toggleFingerprintMethod(bool enabled) async {
    if (!enabled && !_isBarcodeEnabled && !_isFaceEnabled) {
      throw Exception('لا يمكن تعطيل كافة وسائل الحضور. يجب الإبقاء على طريقة تسجيل واحدة على الأقل.');
    }
    _isFingerprintEnabled = enabled;
    await _hive.setSetting('enable_fingerprint', enabled ? 'true' : 'false');
    try {
      await _db.setSetting('enable_fingerprint', enabled ? 'true' : 'false');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleBarcodeMethod(bool enabled) async {
    if (!enabled && !_isFingerprintEnabled && !_isFaceEnabled) {
      throw Exception('لا يمكن تعطيل كافة وسائل الحضور. يجب الإبقاء على طريقة تسجيل واحدة على الأقل.');
    }
    _isBarcodeEnabled = enabled;
    await _hive.setSetting('enable_barcode', enabled ? 'true' : 'false');
    try {
      await _db.setSetting('enable_barcode', enabled ? 'true' : 'false');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleFaceMethod(bool enabled) async {
    if (!enabled && !_isFingerprintEnabled && !_isBarcodeEnabled) {
      throw Exception('لا يمكن تعطيل كافة وسائل الحضور. يجب الإبقاء على طريقة تسجيل واحدة على الأقل.');
    }
    _isFaceEnabled = enabled;
    await _hive.setSetting('enable_face', enabled ? 'true' : 'false');
    try {
      await _db.setSetting('enable_face', enabled ? 'true' : 'false');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateUniversityName(String name) async {
    _universityName = name;
    await _db.setSetting('university_name', name);
    notifyListeners();
  }

  /// تشغيل المزامنة التلقائية فوراً بالخلفية وبدون تدخل المستخدم
  void _triggerAutoSync() {
    Future.microtask(() async {
      try {
        if (_supabase.isConfigured) {
          await _hive.syncWithSupabase();
        }
      } catch (_) {}
    });
  }

  void toggleTheme(bool dark) {
    _isDarkMode = dark;
    notifyListeners();
  }
}

