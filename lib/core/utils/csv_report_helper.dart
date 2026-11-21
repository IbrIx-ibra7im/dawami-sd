import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import '../../data/models/attendance_record.dart';
import '../../data/models/student.dart';
import 'date_helper.dart';

class CsvReportHelper {
  static String exportAttendanceToCsv(List<AttendanceRecord> records) {
    List<List<dynamic>> rows = [
      ['المعرف', 'الرقم الجامعي', 'اسم الطالب', 'المحاضرة', 'القاعة', 'طريقة الحضور', 'الحالة', 'وقت الحضور', 'وقت الانصراف', 'حالة المزامنة']
    ];

    for (var r in records) {
      final method = r.method == 'qr'
          ? 'QR Code'
          : (r.method == 'fingerprint' ? 'بصمة' : 'يدوي');
      rows.add([
        r.id,
        r.universityId ?? '',
        r.studentName ?? '',
        r.lectureName ?? '',
        r.classroomName ?? '',
        method,
        r.status,
        DateHelper.formatTimeString(r.checkIn),
        r.checkOut != null ? DateHelper.formatTimeString(r.checkOut) : 'لم ينصرف بعد',
        r.isSynced ? 'متزامن' : 'محلي (معلق)',
      ]);
    }

    return csv.encode(rows);
  }

  /// Exports attendance to CSV with UTF-8 BOM so Microsoft Excel renders Arabic correctly
  static Uint8List exportAttendanceToCsvBytes(List<AttendanceRecord> records) {
    final csvStr = exportAttendanceToCsv(records);
    // UTF-8 BOM bytes [0xEF, 0xBB, 0xBF]
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvStr)];
    return Uint8List.fromList(bytes);
  }

  /// Exports attendance as a genuine native Microsoft Excel (.xlsx) file
  static Uint8List exportAttendanceToExcel(List<AttendanceRecord> records) {
    final excel = xl.Excel.createExcel();
    const sheetName = 'سجل الحضور اليومي';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow([
      xl.TextCellValue('المعرف'),
      xl.TextCellValue('الرقم الجامعي'),
      xl.TextCellValue('اسم الطالب'),
      xl.TextCellValue('المحاضرة'),
      xl.TextCellValue('القاعة'),
      xl.TextCellValue('طريقة الحضور'),
      xl.TextCellValue('الحالة'),
      xl.TextCellValue('وقت الحضور'),
      xl.TextCellValue('وقت الانصراف'),
      xl.TextCellValue('حالة المزامنة'),
    ]);

    for (var r in records) {
      final method = r.method == 'qr'
          ? 'QR Code'
          : (r.method == 'fingerprint' ? 'بصمة' : 'يدوي');
      sheet.appendRow([
        xl.TextCellValue(r.id),
        xl.TextCellValue(r.universityId ?? ''),
        xl.TextCellValue(r.studentName ?? ''),
        xl.TextCellValue(r.lectureName ?? ''),
        xl.TextCellValue(r.classroomName ?? ''),
        xl.TextCellValue(method),
        xl.TextCellValue(r.status),
        xl.TextCellValue(DateHelper.formatTimeString(r.checkIn)),
        xl.TextCellValue(r.checkOut != null ? DateHelper.formatTimeString(r.checkOut) : 'لم ينصرف بعد'),
        xl.TextCellValue(r.isSynced ? 'متزامن' : 'محلي (معلق)'),
      ]);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }

  static String exportStudentsToCsv(List<Student> students) {
    List<List<dynamic>> rows = [
      ['الرقم الجامعي', 'الاسم الرباعي', 'الكلية', 'القسم', 'المستوى', 'الهاتف', 'البريد الإلكتروني', 'الحالة', 'رمز QR', 'معرف البصمة']
    ];

    for (var s in students) {
      rows.add([
        s.universityId,
        s.fullName,
        s.collegeName ?? 'كلية علوم الحاسوب والتنمية البشرية',
        s.departmentName ?? 'علوم الحاسوب',
        s.levelName ?? 'المستوى الأول',
        s.phone,
        s.email,
        s.status,
        s.qrCode,
        s.fingerprintId ?? '',
      ]);
    }

    return csv.encode(rows);
  }

  /// Exports students to CSV with UTF-8 BOM so Microsoft Excel renders Arabic correctly
  static Uint8List exportStudentsToCsvBytes(List<Student> students) {
    final csvStr = exportStudentsToCsv(students);
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvStr)];
    return Uint8List.fromList(bytes);
  }

  /// Exports students as a genuine native Microsoft Excel (.xlsx) file
  static Uint8List exportStudentsToExcel(List<Student> students) {
    final excel = xl.Excel.createExcel();
    const sheetName = 'بيانات الطلاب';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow([
      xl.TextCellValue('الرقم الجامعي'),
      xl.TextCellValue('الاسم الرباعي'),
      xl.TextCellValue('الكلية'),
      xl.TextCellValue('القسم'),
      xl.TextCellValue('المستوى'),
      xl.TextCellValue('الهاتف'),
      xl.TextCellValue('البريد الإلكتروني'),
      xl.TextCellValue('الحالة'),
      xl.TextCellValue('رمز QR'),
      xl.TextCellValue('معرف البصمة'),
    ]);

    for (var s in students) {
      sheet.appendRow([
        xl.TextCellValue(s.universityId),
        xl.TextCellValue(s.fullName),
        xl.TextCellValue(s.collegeName ?? 'كلية علوم الحاسوب والتنمية البشرية'),
        xl.TextCellValue(s.departmentName ?? 'علوم الحاسوب'),
        xl.TextCellValue(s.levelName ?? 'المستوى الأول'),
        xl.TextCellValue(s.phone),
        xl.TextCellValue(s.email),
        xl.TextCellValue(s.status),
        xl.TextCellValue(s.qrCode),
        xl.TextCellValue(s.fingerprintId ?? ''),
      ]);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }
}
