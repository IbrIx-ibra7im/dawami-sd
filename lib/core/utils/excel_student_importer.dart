import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import '../../data/models/student.dart';

class ExcelStudentImporter {
  /// Parse Excel (.xlsx / .xls) or CSV byte content into a list of Student models
  static Future<List<Student>> parseStudentsFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.csv')) {
      return _parseCsv(bytes);
    } else {
      return _parseExcel(bytes);
    }
  }

  static List<Student> _parseCsv(Uint8List bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) return [];

    final rows = <List<String>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      // Handle both comma and semicolon delimiters
      final sep = line.contains(';') ? ';' : ',';
      final cells = line.split(sep).map((c) => c.replaceAll('"', '').trim()).toList();
      rows.add(cells);
    }

    return _convertRowsToStudents(rows);
  }

  static List<Student> _parseExcel(Uint8List bytes) {
    final excel = xl.Excel.decodeBytes(bytes);
    final allRows = <List<String>>[];

    // Read the first non-empty sheet
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.rows.isEmpty) continue;

      for (final row in sheet.rows) {
        final rowValues = <String>[];
        bool hasContent = false;
        for (final cell in row) {
          final val = cell?.value?.toString().trim() ?? '';
          if (val.isNotEmpty) hasContent = true;
          rowValues.add(val);
        }
        if (hasContent) {
          allRows.add(rowValues);
        }
      }
      if (allRows.isNotEmpty) break;
    }

    return _convertRowsToStudents(allRows);
  }

  static List<Student> _convertRowsToStudents(List<List<String>> rows) {
    if (rows.length < 2) return [];

    // 1. Detect Header Indices
    final header = rows.first;
    int uniIdIdx = -1;
    int nameIdx = -1;
    int phoneIdx = -1;
    int emailIdx = -1;
    int collegeIdx = -1;
    int deptIdx = -1;
    int levelIdx = -1;
    int statusIdx = -1;
    int qrIdx = -1;

    for (int i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase().replaceAll('_', '').replaceAll(' ', '');
      if (uniIdIdx == -1 && (h.contains('جامعي') || h.contains('قيد') || h.contains('university') || h == 'id' || h.contains('رقم'))) {
        uniIdIdx = i;
      } else if (nameIdx == -1 && (h.contains('اسم') || h.contains('name') || h.contains('طالب'))) {
        nameIdx = i;
      } else if (phoneIdx == -1 && (h.contains('هاتف') || h.contains('جوال') || h.contains('phone') || h.contains('mobile'))) {
        phoneIdx = i;
      } else if (emailIdx == -1 && (h.contains('بريد') || h.contains('ايميل') || h.contains('email'))) {
        emailIdx = i;
      } else if (collegeIdx == -1 && (h.contains('كلية') || h.contains('college'))) {
        collegeIdx = i;
      } else if (deptIdx == -1 && (h.contains('قسم') || h.contains('department') || h.contains('dept'))) {
        deptIdx = i;
      } else if (levelIdx == -1 && (h.contains('مستوى') || h.contains('level') || h.contains('سنة'))) {
        levelIdx = i;
      } else if (statusIdx == -1 && (h.contains('حالة') || h.contains('status'))) {
        statusIdx = i;
      } else if (qrIdx == -1 && (h.contains('qr') || h.contains('باركود') || h.contains('barcode'))) {
        qrIdx = i;
      }
    }

    // Fallbacks if header wasn't matched explicitly
    if (uniIdIdx == -1) uniIdIdx = 0;
    if (nameIdx == -1 && header.length > 1) nameIdx = 1;
    if (phoneIdx == -1 && header.length > 2) phoneIdx = 2;
    if (emailIdx == -1 && header.length > 3) emailIdx = 3;

    final result = <Student>[];

    // 2. Parse data rows
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      String getCell(int idx) {
        if (idx >= 0 && idx < row.length) {
          return row[idx].trim();
        }
        return '';
      }

      final universityId = getCell(uniIdIdx);
      final fullName = getCell(nameIdx);

      // Skip row if essential fields missing
      if (universityId.isEmpty || fullName.isEmpty) continue;

      final phone = getCell(phoneIdx).isNotEmpty ? getCell(phoneIdx) : '0900000000';
      final email = getCell(emailIdx).isNotEmpty ? getCell(emailIdx) : '$universityId@dawami.edu';
      final status = getCell(statusIdx).isNotEmpty ? getCell(statusIdx) : 'نشط';
      final qr = getCell(qrIdx).isNotEmpty ? getCell(qrIdx) : 'DAWAMI:STUDENT:$universityId';

      final collegeName = getCell(collegeIdx).isNotEmpty ? getCell(collegeIdx) : 'كلية علوم الحاسوب والتنمية البشرية';
      final deptName = getCell(deptIdx).isNotEmpty ? getCell(deptIdx) : 'علوم الحاسوب';
      final levelName = getCell(levelIdx).isNotEmpty ? getCell(levelIdx) : 'المستوى الأول';

      result.add(
        Student(
          universityId: universityId,
          fullName: fullName,
          phone: phone,
          email: email,
          collegeId: 1,
          departmentId: 1,
          levelId: 1,
          semesterId: 1,
          status: status,
          qrCode: qr,
          // استيراد الملف لا يفعّل البصمة؛ يلزم التقاطها بقارئ معتمد.
          fingerprintStatus: 'غير مسجلة',
          collegeName: collegeName,
          departmentName: deptName,
          levelName: levelName,
        ),
      );
    }

    return result;
  }

  /// Generate a ready-to-use template Excel spreadsheet (.xlsx bytes)
  static Uint8List generateTemplateExcel() {
    final excel = xl.Excel.createExcel();
    final sheet = excel['قائمة_الطلاب'];
    excel.setDefaultSheet('قائمة_الطلاب');

    // Headers
    final headers = [
      'الرقم الجامعي',
      'اسم الطالب الرباعي',
      'رقم الهاتف',
      'البريد الإلكتروني',
      'الكلية',
      'القسم',
      'المستوى',
      'حالة الطالب',
      'رمز الباركود / QR',
      'معرف البصمة',
    ];

    sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());

    // Sample Rows
    final sampleRows = [
      [
        '2024-1001',
        'عمر عبدالكريم حسن أحمد',
        '0912345601',
        'omar.kareem@dawami.edu',
        'كلية علوم الحاسوب والتنمية البشرية',
        'علوم الحاسوب',
        'المستوى الأول',
        'نشط',
        'DAWAMI:STUDENT:2024-1001',
        'FP-20241001',
      ],
      [
        '2024-1002',
        'فاطمة الزهراء علي سالم',
        '0912345602',
        'fatima.ali@dawami.edu',
        'كلية علوم الحاسوب والتنمية البشرية',
        'تقنية المعلومات',
        'المستوى الثاني',
        'نشط',
        'DAWAMI:STUDENT:2024-1002',
        'FP-20241002',
      ],
      [
        '2024-1003',
        'إبراهيم مصطفى محمد يوسف',
        '0912345603',
        'ibrahim.mustafa@dawami.edu',
        'كلية علوم الحاسوب والتنمية البشرية',
        'نظم المعلومات',
        'المستوى الأول',
        'نشط',
        'DAWAMI:STUDENT:2024-1003',
        'FP-20241003',
      ],
    ];

    for (final row in sampleRows) {
      sheet.appendRow(row.map((c) => xl.TextCellValue(c)).toList());
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }
}
