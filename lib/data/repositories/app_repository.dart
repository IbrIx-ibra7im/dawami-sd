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
import '../../core/permissions/role_manager.dart';

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

  // Current logged in user (Requires authentication before entering control panel)
  bool _isLoggedIn = false;
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

  // Getters
  String get universityName => _universityName;
  bool get isDarkMode => _isDarkMode;
  bool get isFingerprintEnabled => _isFingerprintEnabled;
  bool get isBarcodeEnabled => _isBarcodeEnabled;
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
  List<Student> get studentsWithoutFingerprints => _students.where((s) => !s.hasFingerprint).toList();
  List<Student> get studentsWithFingerprints => _students.where((s) => s.hasFingerprint).toList();
  int get enrolledFingerprintsCount => _students.where((s) => s.hasFingerprint).length;
  int get missingFingerprintsCount => _students.where((s) => !s.hasFingerprint).length;

  // Statistics
  int get totalStudentsCount => _students.length;
  int get presentCount => _todayAttendance.where((a) => a.status == 'حاضر').length;
  int get lateCount => _todayAttendance.where((a) => a.status == 'متأخر').length;
  int get absentCount => _todayAttendance.where((a) => a.status == 'غائب').length;
  int get fingerprintAttendanceCount => _todayAttendance.where((a) => a.method == 'fingerprint').length;
  int get qrAttendanceCount => _todayAttendance.where((a) => a.method == 'qr').length;
  int get manualAttendanceCount => _todayAttendance.where((a) => a.method == 'manual').length;

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

      await refreshStudents();
      await refreshAttendance();
      await refreshFingerprints();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading data: $e');
      notifyListeners();
    }
  }

  Future<void> refreshStudents({String? query, int? collegeId, String? status}) async {
    try {
      if (_hive.isInitialized) {
        _students = await _hive.getStudents(query: query, collegeId: collegeId, status: status);
        if (_students.isEmpty && (query == null || query.isEmpty) && collegeId == null && (status == null || status == 'الكل')) {
          // If Hive box is completely empty on startup, fallback to DB
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
    notifyListeners();
  }

  Future<void> refreshAttendance({String? method}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
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
  }) async {
    // تسجيل الحضور بالبصمة الحيوية أو رمز QR متاح دائماً ومباشر للطلاب دون ربطه بتسجيل الدخول
    if (student.status != 'نشط') {
      throw Exception('عذراً، الطالب غير نشط وحالته الحالية: (${student.status})');
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
    
    // Save to Hive (Primary, zero-lock, instant)
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

    _triggerAutoSync();

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
  Future<void> addStudent(Student student) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      if (_isLoggedIn) {
        switchUserRole(UserRole.superAdmin);
      } else {
        throw Exception('ليس لديك صلاحية لإضافة طالب');
      }
    }
    // Save to Hive
    final id = await _hive.insertStudent(student);
    try {
      await _db.insertStudent(student.copyWith(id: id));
    } catch (_) {}
    await refreshStudents();
  }

  Future<int> importStudents(List<Student> students) async {
    if (!RoleManager.canManageStudents(currentRole)) {
      throw Exception('ليس لديك صلاحية لإضافة أو استيراد الطلاب');
    }
    // Batch Insert to Hive
    final count = await _hive.batchInsertOrUpdateStudents(students);
    try {
      await _db.batchInsertOrUpdateStudents(students);
    } catch (_) {}
    await refreshStudents();
    return count;
  }

  Future<void> linkBarcodeToStudent(int studentId, String newBarcode) async {
    await _hive.linkBarcodeToStudent(studentId, newBarcode);
    try {
      await _db.linkBarcodeToStudent(studentId, newBarcode);
    } catch (_) {}
    await refreshStudents();
  }

  Future<void> updateStudent(Student student) async {
    await _hive.updateStudent(student);
    try {
      await _db.updateStudent(student);
    } catch (_) {}
    await refreshStudents();
  }

  Future<void> deleteStudent(int studentId) async {
    await _hive.deleteStudent(studentId);
    try {
      await _db.deleteStudent(studentId);
    } catch (_) {}
    await refreshStudents();
  }

  Future<void> deleteMultipleStudents(List<int> studentIds) async {
    await _hive.deleteMultipleStudents(studentIds);
    try {
      await _db.deleteMultipleStudents(studentIds);
    } catch (_) {}
    await refreshStudents();
  }

  Future<void> deleteAttendanceRecord(String id) async {
    await _hive.deleteAttendanceRecord(id);
    try {
      await _db.deleteAttendanceRecord(id);
    } catch (_) {}
    await refreshAttendance();
  }

  Future<void> deleteMultipleAttendanceRecords(List<String> ids) async {
    await _hive.deleteMultipleAttendanceRecords(ids);
    try {
      await _db.deleteMultipleAttendanceRecords(ids);
    } catch (_) {}
    await refreshAttendance();
  }

  // --- Biometric / Fingerprint Operations ---

  /// تسجيل بصمة طالب جديدة وربطها بحسابه
  Future<void> enrollStudentFingerprint({
    required Student student,
    required String fingerprintId,
    required String templateHash,
    required int quality,
  }) async {
    // التحقق من عدم تكرار البصمة
    final isDuplicate = await isFingerprintDuplicate(fingerprintId, excludeStudentId: student.id);
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
    await _hive.deleteStudentFingerprint(studentId);
    try {
      await _db.deleteStudentFingerprint(studentId);
    } catch (_) {}

    // تحديث حالة الطالب
    final student = _students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => throw Exception('الطالب غير موجود'),
    );
    final updatedStudent = student.copyWith(
      fingerprintId: null,
      fingerprintStatus: 'غير مسجلة',
      fingerprintQuality: null,
      fingerprintEnrolledAt: null,
    );
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
    if (!enabled && !_isBarcodeEnabled) {
      throw Exception('لا يمكن تعطيل البصمة والباركود معاً. يجب الإبقاء على طريقة تسجيل واحدة على الأقل.');
    }
    _isFingerprintEnabled = enabled;
    await _hive.setSetting('enable_fingerprint', enabled ? 'true' : 'false');
    try {
      await _db.setSetting('enable_fingerprint', enabled ? 'true' : 'false');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleBarcodeMethod(bool enabled) async {
    if (!enabled && !_isFingerprintEnabled) {
      throw Exception('لا يمكن تعطيل البصمة والباركود معاً. يجب الإبقاء على طريقة تسجيل واحدة على الأقل.');
    }
    _isBarcodeEnabled = enabled;
    await _hive.setSetting('enable_barcode', enabled ? 'true' : 'false');
    try {
      await _db.setSetting('enable_barcode', enabled ? 'true' : 'false');
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

