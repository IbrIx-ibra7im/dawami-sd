import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_app/data/models/attendance_record.dart';
import 'package:my_app/data/models/student.dart';
import 'package:my_app/data/local/hive_helper.dart';
import 'package:my_app/core/services/local_storage_service.dart';
import 'package:my_app/core/services/student_service.dart';
import 'package:my_app/core/services/attendance_service.dart';
import 'package:my_app/core/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('dawami_hive_sync_test_');
    Hive.init(tempDir.path);
    await HiveHelper.instance.init(tempDir.path);
    await LocalStorageService.instance.init(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('1. تسجيل الطلاب محلياً في Hive وسحابياً', () {
    test('حفظ طالب بالاسم والرقم الجامعي فقط محلياً في Hive', () async {
      final student = await StudentService.instance.registerStudent(
        fullName: 'أحمد إبراهيم علي',
        universityId: '2024-TEST-001',
      );

      expect(student.fullName, 'أحمد إبراهيم علي');
      expect(student.studentNumber, '2024-TEST-001');
      expect(student.qrCode, 'DAWAMI:STUDENT:2024-TEST-001');

      // التحقق من الحفظ في Hive
      final localStudent = await LocalStorageService.instance.getStudentByUniversityId('2024-TEST-001');
      expect(localStudent, isNotNull);
      expect(localStudent!.fullName, 'أحمد إبراهيم علي');
    });

    test('منع تكرار الرقم الجامعي لطالبين مختلفين', () async {
      expect(
        () async => await StudentService.instance.registerStudent(
          fullName: 'طالب مكرر',
          universityId: '2024-TEST-001',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('ربط البصمة والباركود بالرقم الجامعي', () async {
      final student = await LocalStorageService.instance.getStudentByUniversityId('2024-TEST-001');
      expect(student, isNotNull);

      // ربط البصمة
      await StudentService.instance.linkFingerprint(
        student: student!,
        fingerprintId: 'FP-TEST-001',
      );

      final updated = await LocalStorageService.instance.getStudentByUniversityId('2024-TEST-001');
      expect(updated!.fingerprintId, 'FP-TEST-001');
      expect(updated.hasFingerprint, isTrue);
    });
  });

  group('2. تسجيل الحضور بالبصمة والباركود دون إنترنت (Offline-First)', () {
    test('تسجيل الحضور بالباركود واستخراج الاسم والرقم الجامعي والتاريخ والوقت', () async {
      final record = await AttendanceService.instance.recordAttendanceByBarcode(
        barcode: 'DAWAMI:STUDENT:2024-TEST-001',
        sessionId: 1,
        lectureName: 'هياكل البيانات',
        classroomName: 'قاعة 1',
      );

      expect(record.id, isNotEmpty);
      expect(record.studentNumber, '2024-TEST-001');
      expect(record.studentName, 'أحمد إبراهيم علي');
      expect(record.method, 'barcode');
      expect(record.status, 'حاضر');
      expect(record.attendanceDate, isNotEmpty);
      expect(record.attendanceTime, isNotEmpty);
      expect(record.isSynced, isFalse);
      expect(record.syncStatus, 'غير مزامنة');
    });

    test('تسجيل الانصراف لنفس الطالب عند المسح الثاني', () async {
      final student = await LocalStorageService.instance.getStudentByUniversityId('2024-TEST-001');
      expect(student, isNotNull);

      final outRecord = await AttendanceService.instance.recordAttendance(
        student: student!,
        method: 'barcode',
        sessionId: 1,
      );

      expect(outRecord.status, 'تم الانصراف');
      expect(outRecord.checkOut, isNotNull);
    });

    test('منع تكرار الحضور والانصراف لنفس الطالب في نفس المحاضرة واليوم', () async {
      final student = await LocalStorageService.instance.getStudentByUniversityId('2024-TEST-001');
      expect(student, isNotNull);

      expect(
        () async => await AttendanceService.instance.recordAttendance(
          student: student!,
          method: 'barcode',
          sessionId: 1,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('3. قائمة الانتظار والمزامنة مع Supabase وحالة الإنترنت', () {
    test('سجلات الحضور غير المزامنة محفوظة في Hive مع عداد الانتظار', () async {
      final pendingCount = await LocalStorageService.instance.getPendingAttendanceCount();
      expect(pendingCount, greaterThanOrEqualTo(1));

      final pendingRecords = await LocalStorageService.instance.getPendingAttendanceRecords();
      expect(pendingRecords.any((r) => r.studentNumber == '2024-TEST-001'), isTrue);
    });

    test('SyncService يعكس حالة الإنترنت والسجلات بالانتظار وتنسيق آخر وقت', () async {
      final syncService = SyncService.instance;
      await syncService.refreshPendingCount();

      expect(syncService.pendingRecordsCount, greaterThanOrEqualTo(1));
      expect(syncService.syncStatusText, contains('بانتظار المزامنة'));
    });

    test('تعليم السجل كـ مزامن بعد نجاح الرفع دون فقدانه من Hive', () async {
      final pendingRecords = await LocalStorageService.instance.getPendingAttendanceRecords();
      expect(pendingRecords.isNotEmpty, isTrue);

      final record = pendingRecords.first;
      await LocalStorageService.instance.markAttendanceSynced(record.id);

      final allRecords = await LocalStorageService.instance.getAttendanceRecords();
      final updated = allRecords.firstWhere((r) => r.id == record.id);
      expect(updated.isSynced, isTrue);
      expect(updated.syncStatus, 'مزامنة');
    });
  });

  group('4. نموذج AttendanceRecord وتوافقه مع Supabase', () {
    test('toMap يخرج الحقول المطلوبة student_number, student_name, attendance_date, attendance_time, method, sync_status', () {
      final record = AttendanceRecord(
        id: 'test-uuid-1234',
        studentId: 10,
        sessionId: 2,
        checkIn: '2026-11-22T14:30:00.000',
        method: 'fingerprint',
        status: 'حاضر',
        deviceId: 'ZK-F18',
        createdAt: '2026-11-22T14:30:00.000',
        studentName: 'محمد عثمان',
        universityId: '2023-5566',
        isSynced: true,
      );

      final map = record.toMap();
      expect(map['id'], 'test-uuid-1234');
      expect(map['student_number'], '2023-5566');
      expect(map['student_name'], 'محمد عثمان');
      expect(map['attendance_date'], '2026-11-22');
      expect(map['attendance_time'], '14:30');
      expect(map['method'], 'fingerprint');
      expect(map['sync_status'], 'مزامنة');
      expect(map['is_synced'], 1);
    });

    test('fromMap يقرأ كل من التنسيقين القديم والجديد', () {
      final fromNew = AttendanceRecord.fromMap({
        'id': 'uuid-999',
        'student_number': '2025-1111',
        'student_name': 'سارة خالد',
        'attendance_date': '2026-11-22',
        'attendance_time': '09:00',
        'method': 'barcode',
        'sync_status': 'مزامنة',
      });

      expect(fromNew.studentNumber, '2025-1111');
      expect(fromNew.studentName, 'سارة خالد');
      expect(fromNew.method, 'barcode');
      expect(fromNew.isSynced, isTrue);
    });
  });

  group('5. توافق نموذج Student بدقة مع جدول public.students في Supabase', () {
    test('toSupabaseMap يصدر حصرياً الأعمدة المعتمدة في جدول public.students', () {
      final student = Student(
        id: 10,
        uuid: '550e8400-e29b-41d4-a716-446655440000',
        universityId: '2026-SUPA-001',
        fullName: 'عمر مصطفى حسن',
        phone: '0912345678',
        email: 'omar@dongola.edu.sd',
        collegeId: 1,
        departmentId: 2,
        levelId: 1,
        semesterId: 1,
        collegeName: 'كلية علوم الحاسوب والتنمية البشرية',
        departmentName: 'تقنية المعلومات',
        levelName: 'المستوى الأول',
        qrCode: 'DAWAMI:STUDENT:2026-SUPA-001',
        fingerprintId: 'FP-9988',
      );

      final map = student.toSupabaseMap();

      // التحقق من الحقول المسموح بها في جدول public.students فقط
      final allowedKeys = {
        'student_number',
        'full_name',
        'college',
        'department',
        'academic_level',
        'phone',
        'status',
        'university_id',
        'barcode_id',
        'fingerprint_registered',
      };

      expect(map.keys.toSet().difference(allowedKeys), isEmpty,
          reason: 'يجب ألا يحتوي map على أي حقل غير موجود في جدول public.students');

      expect(map['student_number'], '2026-SUPA-001');
      expect(map['full_name'], 'عمر مصطفى حسن');
      expect(map['college'], 'كلية علوم الحاسوب والتنمية البشرية');
      expect(map['department'], 'تقنية المعلومات');
      expect(map['academic_level'], 'المستوى الأول');
      expect(map['phone'], '0912345678');
      expect(map['status'], 'نشط');
      expect(map['barcode_id'], 'DAWAMI:STUDENT:2026-SUPA-001');
      expect(map['fingerprint_registered'], isTrue);

      // التأكد الصارم من عدم وجود أعمدة تسبب أخطاء Postgres
      expect(map.containsKey('college_id'), isFalse);
      expect(map.containsKey('department_id'), isFalse);
      expect(map.containsKey('level_id'), isFalse);
      expect(map.containsKey('semester_id'), isFalse);
      expect(map.containsKey('email'), isFalse);
      expect(map.containsKey('qr_code'), isFalse);
      expect(map.containsKey('fingerprint_id'), isFalse);
      expect(map.containsKey('photo_url'), isFalse);
    });

    test('Student.fromMap يقرأ سجل Supabase مع UUID بمرونة', () {
      final remoteRow = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'student_number': '2026-9999',
        'full_name': 'فاطمة الزهراء',
        'college': 'كلية علوم الحاسوب والتنمية البشرية',
        'department': 'علوم الحاسوب',
        'academic_level': 'المستوى الأول',
        'phone': '0922334455',
        'status': 'نشط',
        'university_id': '2026-9999',
        'barcode_id': 'BARCODE-9999',
        'fingerprint_registered': false,
      };

      final student = Student.fromMap(remoteRow);
      expect(student.uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
      expect(student.studentNumber, '2026-9999');
      expect(student.universityId, '2026-9999');
      expect(student.fullName, 'فاطمة الزهراء');
      expect(student.phone, '0922334455');
      expect(student.barcodeId, 'BARCODE-9999');
      expect(student.fingerprintRegistered, isFalse);
    });
  });
}
