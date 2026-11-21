import 'dart:convert';
import '../../data/local/database_helper.dart';
import '../../data/local/hive_helper.dart';
import '../../data/models/student.dart';
import '../../data/models/attendance_record.dart';

class SyncBundleHelper {
  /// Generate a portable JSON synchronization bundle for local/offline backup & transfer
  static Future<Map<String, dynamic>> createSyncBundle() async {
    final hive = HiveHelper.instance;
    final students = await hive.getStudents();
    final attendance = await hive.getAttendanceRecords();
    final uniName = await hive.getSetting('university_name', defaultValue: 'جامعة دنقلا - كلية علوم الحاسوب والتنمية البشرية');

    return {
      'app': 'Dawami',
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'university_name': uniName,
      'students_count': students.length,
      'attendance_count': attendance.length,
      'students': students.map((s) => s.toMap()).toList(),
      'attendance': attendance.map((a) => a.toMap()).toList(),
    };
  }

  /// Exports bundle as UTF-8 bytes for file saving
  static Future<List<int>> exportSyncBundleBytes() async {
    final bundle = await createSyncBundle();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonStr = encoder.convert(bundle);
    return utf8.encode(jsonStr);
  }

  /// Restores/merges a synchronization bundle into local Hive and SQLite databases
  static Future<Map<String, int>> restoreSyncBundle(String jsonStr) async {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final hive = HiveHelper.instance;
    final db = DatabaseHelper.instance;

    int studentsRestored = 0;
    int attendanceRestored = 0;

    // 1. Restore Students
    if (data.containsKey('students') && data['students'] is List) {
      final List rawList = data['students'];
      final List<Student> students = [];
      for (final item in rawList) {
        if (item is Map) {
          final s = Student.fromMap(Map<String, dynamic>.from(item));
          students.add(s);
        }
      }
      if (students.isNotEmpty) {
        studentsRestored = await hive.batchInsertOrUpdateStudents(students);
        for (final s in students) {
          try {
            await db.insertStudent(s);
          } catch (_) {}
        }
      }
    }

    // 2. Restore Attendance Records
    if (data.containsKey('attendance') && data['attendance'] is List) {
      final List rawList = data['attendance'];
      for (final item in rawList) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final record = AttendanceRecord.fromMap(map);
          try {
            await hive.recordAttendance(
              studentId: record.studentId,
              sessionId: record.sessionId,
              method: record.method,
              status: record.status,
              deviceId: record.deviceId,
            );
            attendanceRestored++;
          } catch (_) {}
        }
      }
    }

    // Mark all queue items as synced locally
    await hive.markAllQueueItemsAsSynced();
    await db.markAllQueueItemsAsSynced();

    return {
      'students': studentsRestored,
      'attendance': attendanceRestored,
    };
  }
}
