import 'dart:typed_data';

Future<String?> saveFileImpl({
  required String fileName,
  required Uint8List bytes,
  String? mimeType,
}) async {
  return null;
}

Future<String?> saveTextFileImpl({
  required String fileName,
  required String content,
  String? mimeType,
}) async {
  return null;
}

Future<void> openFileImpl(String path) async {
  // No-op en otras plataformas
}
