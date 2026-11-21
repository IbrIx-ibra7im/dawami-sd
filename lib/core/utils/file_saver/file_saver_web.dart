// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> saveFileImpl({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..target = 'blank'
    ..download = fileName;
  anchor.click();
  html.Url.revokeObjectUrl(url);
  return 'مجلد التنزيلات (Downloads): $fileName';
}
