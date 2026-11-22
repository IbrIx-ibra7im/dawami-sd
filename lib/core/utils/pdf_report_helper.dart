import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/student.dart';

class PdfReportHelper {
  static Future<Uint8List> generateAttendanceReport({
    required String universityName,
    required String reportTitle,
    required List<AttendanceRecord> records,
    String? subtitle,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 15),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(universityName, style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue900)),
                  pw.SizedBox(height: 4),
                  pw.Text('نظام دوامي لإدارة الحضور والغياب (DAWAMI)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text('تقرير رسمي', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue800)),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 15),
          pw.Center(
            child: pw.Text(reportTitle, style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900)),
          ),
          if (subtitle != null) ...[
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
          ],
          pw.SizedBox(height: 20),

          // Statistics summary bar
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text('إجمالي السجلات: ${records.length}', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                pw.Text('الحاضرون: ${records.where((r) => r.status == 'حاضر').length}', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.green800)),
                pw.Text('المتأخرون: ${records.where((r) => r.status == 'متأخر').length}', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.orange800)),
                pw.Text('الغائبون: ${records.where((r) => r.status == 'غائب').length}', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.red800)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Attendance Table
          pw.TableHelper.fromTextArray(
            headers: ['#', 'الرقم الجامعي', 'اسم الطالب', 'وقت الحضور', 'وقت الانصراف', 'طريقة الحضور', 'الحالة'],
            data: List.generate(records.length, (index) {
              final r = records[index];
              final methodText = r.method == 'qr'
                  ? 'QR كود'
                  : (r.method == 'fingerprint' ? 'بصمة' : 'يدوي');
              final inTime = r.checkIn.length >= 16 ? r.checkIn.substring(11, 16) : r.checkIn;
              final outTime = (r.checkOut != null && r.checkOut!.length >= 16)
                  ? r.checkOut!.substring(11, 16)
                  : (r.checkOut != null ? r.checkOut! : 'لم ينصرف');
              return [
                '${index + 1}',
                r.universityId ?? '-',
                r.studentName ?? 'طالب غير محدد',
                inTime,
                outTime,
                methodText,
                r.status,
              ];
            }),
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellAlignment: pw.Alignment.center,
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          ),
        ],
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('تاريخ الطباعة: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text('الصفحة ${context.pageNumber} من ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  /// توليد وطباعة بطاقة الطالب الرسمية بدقة عالية متضمنة الباركود ورمز QR
  static Future<Uint8List> generateStudentCardPdf({
    required Student student,
    String universityName = 'جامعة دنقلا - كلية علوم الحاسوب والتنمية البشرية',
  }) async {
    final pdf = pw.Document();

    pw.Font font;
    pw.Font fontBold;
    try {
      font = await PdfGoogleFonts.cairoRegular();
      fontBold = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final codeData = student.qrCode.isNotEmpty ? student.qrCode : 'DAWAMI:STUDENT:${student.universityId}';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(85.6 * PdfPageFormat.mm, 53.98 * PdfPageFormat.mm, marginAll: 3 * PdfPageFormat.mm),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blue900, width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
            color: PdfColors.white,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('بطاقة طالب جامعية', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 8)),
                    pw.Text(universityName, style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 7)),
                  ],
                ),
              ),
              pw.SizedBox(height: 3),

              // Student Body Info & QR Code
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // QR Code
                    pw.Container(
                      width: 50,
                      height: 50,
                      padding: const pw.EdgeInsets.all(2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: codeData,
                      ),
                    ),
                    pw.SizedBox(width: 8),

                    // Info Details
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(student.fullName, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blue900), maxLines: 1),
                          pw.SizedBox(height: 2),
                          pw.Text('الرقم الجامعي: ${student.universityId}', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.black)),
                          pw.Text('القسم: ${student.departmentName ?? student.department}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
                          pw.Text('المستوى: ${student.levelName ?? student.academicLevel}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
                          pw.Text('الحالة: ${student.status}', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.green800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Barcode 128
              pw.Container(
                height: 16,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: student.universityId,
                  drawText: true,
                  textStyle: const pw.TextStyle(fontSize: 6),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }
}

