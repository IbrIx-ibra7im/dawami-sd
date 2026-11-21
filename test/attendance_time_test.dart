import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/utils/date_helper.dart';
import 'package:my_app/core/utils/csv_report_helper.dart';
import 'package:my_app/data/models/attendance_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Attendance Check-In & Check-Out Time Tests', () {
    test('DateHelper formats checkIn and checkOut correctly', () {
      const checkInIso = '2026-11-21T08:15:30.000Z';
      const checkOutIso = '2026-11-21T14:45:00.000Z';

      final inFormatted = DateHelper.formatTimeString(checkInIso);
      final outFormatted = DateHelper.formatTimeString(checkOutIso);

      expect(inFormatted, isNotEmpty);
      expect(outFormatted, isNotEmpty);
      expect(DateHelper.formatTimeString(null, placeholder: 'لم ينصرف بعد'), equals('لم ينصرف بعد'));
    });

    test('AttendanceRecord models both checkIn and checkOut timestamps', () {
      final record = AttendanceRecord(
        id: 'rec-001',
        studentId: 1,
        sessionId: 10,
        checkIn: '2026-11-21T08:00:00.000Z',
        checkOut: '2026-11-21T14:00:00.000Z',
        method: 'qr',
        status: 'تم الانصراف',
        deviceId: 'SCANNER-01',
        createdAt: '2026-11-21T08:00:00.000Z',
        studentName: 'أحمد محمد',
        universityId: 'U202601',
      );

      expect(record.checkIn, isNotEmpty);
      expect(record.checkOut, isNotNull);
      expect(record.status, equals('تم الانصراف'));

      final map = record.toMap();
      expect(map['check_in'], equals('2026-11-21T08:00:00.000Z'));
      expect(map['check_out'], equals('2026-11-21T14:00:00.000Z'));

      final restored = AttendanceRecord.fromMap(map);
      expect(restored.checkIn, equals(record.checkIn));
      expect(restored.checkOut, equals(record.checkOut));
    });

    test('CsvReportHelper includes both checkIn and checkOut in CSV export', () {
      final records = [
        AttendanceRecord(
          id: 'test-1',
          studentId: 101,
          sessionId: 1,
          checkIn: '2026-11-21T08:05:00.000Z',
          checkOut: '2026-11-21T14:10:00.000Z',
          method: 'fingerprint',
          status: 'تم الانصراف',
          deviceId: 'ZK-F18',
          createdAt: '2026-11-21T08:05:00.000Z',
          studentName: 'سارة خالد',
          universityId: 'U202699',
        ),
      ];

      final csvContent = CsvReportHelper.exportAttendanceToCsv(records);
      expect(csvContent, contains('وقت الحضور'));
      expect(csvContent, contains('وقت الانصراف'));
      expect(csvContent, contains('سارة خالد'));
      expect(csvContent, contains('تم الانصراف'));
    });
  });
}
