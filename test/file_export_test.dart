import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/utils/csv_report_helper.dart';
import 'package:my_app/core/utils/file_saver/file_saver.dart';
import 'package:my_app/data/models/student.dart';
import 'package:my_app/data/models/attendance_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('File Export & Device Saving Tests', () {
    test('Export students to native Excel (.xlsx) bytes', () {
      final students = [
        Student(
          id: 1,
          universityId: '2023-1001',
          fullName: 'أحمد علي حسن',
          phone: '0912345678',
          email: 'ahmed@dawami.edu',
          collegeId: 1,
          departmentId: 1,
          levelId: 1,
          semesterId: 1,
          status: 'نشط',
          qrCode: 'DAWAMI:STUDENT:2023-1001',
          collegeName: 'كلية علوم الحاسوب والتنمية البشرية',
          departmentName: 'علوم الحاسوب',
        ),
      ];

      final excelBytes = CsvReportHelper.exportStudentsToExcel(students);
      expect(excelBytes, isNotNull);
      expect(excelBytes.isNotEmpty, isTrue);

      final csvBytes = CsvReportHelper.exportStudentsToCsvBytes(students);
      expect(csvBytes, isNotNull);
      expect(csvBytes.length, greaterThan(3)); // BOM + content
      // Check for UTF-8 BOM: 0xEF, 0xBB, 0xBF
      expect(csvBytes[0], equals(0xEF));
      expect(csvBytes[1], equals(0xBB));
      expect(csvBytes[2], equals(0xBF));
    });

    test('Export attendance to native Excel (.xlsx) bytes', () {
      final records = [
        AttendanceRecord(
          id: 'REC-001',
          studentId: 1,
          sessionId: 1,
          checkIn: '2026-11-21T08:00:00',
          checkOut: '2026-11-21T10:00:00',
          method: 'qr',
          status: 'حاضر',
          deviceId: 'ZK-F18',
          createdAt: '2026-11-21T08:00:00',
          studentName: 'أحمد علي حسن',
          universityId: '2023-1001',
        ),
      ];

      final excelBytes = CsvReportHelper.exportAttendanceToExcel(records);
      expect(excelBytes.isNotEmpty, isTrue);

      final csvBytes = CsvReportHelper.exportAttendanceToCsvBytes(records);
      expect(csvBytes[0], equals(0xEF));
      expect(csvBytes[1], equals(0xBB));
      expect(csvBytes[2], equals(0xBF));
    });

    test('FileSaver saves file directly to device filesystem', () async {
      const fileName = 'test_export_device.csv';
      final testData = [0xEF, 0xBB, 0xBF, 65, 66, 67]; // BOM + ABC

      final savedPath = await FileSaver.saveFile(
        fileName: fileName,
        bytes: testData,
        mimeType: 'text/csv',
      );

      expect(savedPath, isNotNull);
      expect(savedPath, contains(fileName));

      final file = File(savedPath!);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), equals(testData.length));

      // Cleanup
      try {
        file.deleteSync();
      } catch (_) {}
    });
  });
}
