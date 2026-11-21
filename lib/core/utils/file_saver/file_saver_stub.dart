Future<String?> saveFileImpl({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  throw UnsupportedError('Saving files is not supported on this platform');
}
