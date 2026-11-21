import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<String?> saveFileImpl({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  Directory? targetDir;
  try {
    targetDir = await getDownloadsDirectory();
  } catch (_) {}
  try {
    targetDir ??= await getApplicationDocumentsDirectory();
  } catch (_) {}
  targetDir ??= Directory.current;

  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
  }

  final filePath = p.join(targetDir.path, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
