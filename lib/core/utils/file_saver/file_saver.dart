import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

class FileSaver {
  /// Saves bytes to user's device (Downloads/Documents on Desktop/Mobile, browser download on Web)
  /// Returns the absolute path or human-readable destination.
  static Future<String?> saveFile({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    return saveFileImpl(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
  }
}
