import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';

void main() {
  test('Excel package create and save test', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([TextCellValue('الاسم'), TextCellValue('الرقم الجامعي')]);
    final bytes = excel.save();
    expect(bytes, isNotNull);
    expect(bytes!.isNotEmpty, isTrue);
  });
}
