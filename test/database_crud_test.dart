import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_app/data/models/student.dart';
import 'package:my_app/data/local/hive_helper.dart';
import 'package:my_app/data/repositories/app_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_crud_test');
    await HiveHelper.instance.init(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Database Operations & Data Insertion Tests', () {
    late AppRepository repo;

    setUp(() async {
      repo = AppRepository();
      await repo.loadInitialData();
      await repo.login('admin@dawami.edu', '00000');
    });

    test('Add student persists to Hive and AppRepository list immediately', () async {
      final initialCount = repo.students.length;
      final uniqueUniId = 'TEST-${DateTime.now().millisecondsSinceEpoch}';

      final newStudent = Student(
        universityId: uniqueUniId,
        fullName: 'طالب اختبار إضافة البيانات',
        phone: '0912349999',
        email: 'test.student@dawami.edu',
        collegeId: 1,
        departmentId: 1,
        levelId: 1,
        semesterId: 1,
        status: 'نشط',
        qrCode: 'DAWAMI:STUDENT:$uniqueUniId',
        collegeName: 'كلية علوم الحاسوب والتنمية البشرية',
        departmentName: 'علوم الحاسوب',
        levelName: 'المستوى الأول',
      );

      await repo.addStudent(newStudent);

      expect(repo.students.length, equals(initialCount + 1));
      final added = repo.students.firstWhere((s) => s.universityId == uniqueUniId);
      expect(added.fullName, equals('طالب اختبار إضافة البيانات'));
      expect(added.collegeName, equals('كلية علوم الحاسوب والتنمية البشرية'));
      expect(added.departmentName, equals('علوم الحاسوب'));
      expect(added.id, isNotNull);

      // Verify direct retrieval from Hive
      final fromHive = await HiveHelper.instance.getStudentByUniversityId(uniqueUniId);
      expect(fromHive, isNotNull);
      expect(fromHive!.fullName, equals('طالب اختبار إضافة البيانات'));
      expect(fromHive.collegeName, equals('كلية علوم الحاسوب والتنمية البشرية'));
    });

    test('Batch import of students handles string/int keys without CastError', () async {
      final batchList = [
        Student(
          universityId: 'BATCH-001',
          fullName: 'طالب استيراد دفعات 1',
          phone: '0911111111',
          email: 'batch1@dawami.edu',
          collegeId: 1,
          departmentId: 2,
          levelId: 2,
          semesterId: 1,
          status: 'نشط',
          qrCode: 'DAWAMI:STUDENT:BATCH-001',
          collegeName: 'كلية علوم الحاسوب والتنمية البشرية',
          departmentName: 'تقنية المعلومات',
        ),
        Student(
          universityId: 'BATCH-002',
          fullName: 'طالب استيراد دفعات 2',
          phone: '0922222222',
          email: 'batch2@dawami.edu',
          collegeId: 1,
          departmentId: 3,
          levelId: 3,
          semesterId: 1,
          status: 'نشط',
          qrCode: 'DAWAMI:STUDENT:BATCH-002',
          collegeName: 'كلية علوم الحاسوب والتنمية البشرية',
          departmentName: 'نظم المعلومات',
        ),
      ];

      final count = await repo.importStudents(batchList);
      expect(count, equals(2));

      final student1 = repo.students.firstWhere((s) => s.universityId == 'BATCH-001');
      expect(student1.fullName, equals('طالب استيراد دفعات 1'));
      expect(student1.departmentName, equals('تقنية المعلومات'));

      final student2 = repo.students.firstWhere((s) => s.universityId == 'BATCH-002');
      expect(student2.fullName, equals('طالب استيراد دفعات 2'));
      expect(student2.departmentName, equals('نظم المعلومات'));
    });

    test('Register attendance records check-in and check-out successfully', () async {
      // Find an active student
      final activeStudent = repo.students.firstWhere((s) => s.status == 'نشط');

      // 1. Record Check-In
      final checkInRecord = await repo.registerAttendance(
        student: activeStudent,
        method: 'qr',
      );
      expect(checkInRecord.studentId, equals(activeStudent.id));
      expect(checkInRecord.checkIn, isNotEmpty);
      expect(checkInRecord.status, equals('حاضر'));

      // 2. Second scan records Check-Out
      final checkOutRecord = await repo.registerAttendance(
        student: activeStudent,
        method: 'qr',
      );
      expect(checkOutRecord.checkOut, isNotNull);
      expect(checkOutRecord.status, equals('تم الانصراف'));

      // 3. Third scan prevents duplicate and throws informative message
      expect(
        () async => await repo.registerAttendance(student: activeStudent, method: 'qr'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('تم تسجيل الحضور'))),
      );
    });

    test('Update and Delete student removes record from database correctly', () async {
      final uniqueUniId = 'DEL-${DateTime.now().millisecondsSinceEpoch}';
      final student = Student(
        universityId: uniqueUniId,
        fullName: 'طالب قابل للحذف',
        phone: '0900000000',
        email: 'del@dawami.edu',
        collegeId: 1,
        departmentId: 1,
        levelId: 1,
        semesterId: 1,
        status: 'نشط',
        qrCode: 'DAWAMI:STUDENT:$uniqueUniId',
      );

      await repo.addStudent(student);
      final added = repo.students.firstWhere((s) => s.universityId == uniqueUniId);
      final studentId = added.id!;

      // Update
      final updated = added.copyWith(fullName: 'طالب تم تحديث اسمه');
      await repo.updateStudent(updated);
      final foundUpdated = repo.students.firstWhere((s) => s.id == studentId);
      expect(foundUpdated.fullName, equals('طالب تم تحديث اسمه'));

      // Delete
      await repo.deleteStudent(studentId);
      final exists = repo.students.any((s) => s.id == studentId);
      expect(exists, isFalse);

      final fromHive = await HiveHelper.instance.getStudentById(studentId);
      expect(fromHive, isNull);
    });

    test('deleteMultipleStudents batch deletes selected students correctly', () async {
      final s1 = Student(
        universityId: 'MULTI-001',
        fullName: 'طالب متعدد 1',
        phone: '0911111111',
        email: 'm1@dawami.edu',
        collegeId: 1,
        departmentId: 1,
        levelId: 1,
        semesterId: 1,
        status: 'نشط',
        qrCode: 'MULTI-001',
      );
      final s2 = Student(
        universityId: 'MULTI-002',
        fullName: 'طالب متعدد 2',
        phone: '0922222222',
        email: 'm2@dawami.edu',
        collegeId: 1,
        departmentId: 1,
        levelId: 1,
        semesterId: 1,
        status: 'نشط',
        qrCode: 'MULTI-002',
      );

      await repo.addStudent(s1);
      await repo.addStudent(s2);

      final id1 = repo.students.firstWhere((s) => s.universityId == 'MULTI-001').id!;
      final id2 = repo.students.firstWhere((s) => s.universityId == 'MULTI-002').id!;

      await repo.deleteMultipleStudents([id1, id2]);

      expect(repo.students.any((s) => s.id == id1), isFalse);
      expect(repo.students.any((s) => s.id == id2), isFalse);
    });

    test('deleteAttendanceRecord and deleteMultipleAttendanceRecords remove records', () async {
      final s = Student(
        universityId: 'ATT-DEL-001',
        fullName: 'طالب فحص الحذف',
        phone: '0900000000',
        email: 'att@test.com',
        collegeId: 1,
        departmentId: 1,
        levelId: 1,
        semesterId: 1,
        status: 'نشط',
        qrCode: 'ATT-DEL-001',
      );
      await repo.addStudent(s);
      final addedStudent = repo.students.firstWhere((st) => st.universityId == 'ATT-DEL-001');

      final record = await repo.registerAttendance(student: addedStudent, method: 'manual');
      expect(repo.todayAttendance.any((r) => r.id == record.id), isTrue);

      // Single delete
      await repo.deleteAttendanceRecord(record.id);
      expect(repo.todayAttendance.any((r) => r.id == record.id), isFalse);

      // Register attendance again (since previous was deleted)
      final rec2 = await repo.registerAttendance(student: addedStudent, method: 'manual');
      expect(repo.todayAttendance.any((r) => r.id == rec2.id), isTrue);

      await repo.deleteMultipleAttendanceRecords([rec2.id]);
      expect(repo.todayAttendance.any((r) => r.id == rec2.id), isFalse);
    });
  });
}
