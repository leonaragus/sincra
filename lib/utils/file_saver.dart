import 'dart:typed_data';

// Selecciona el archivo según la plataforma
export 'file_saver_stub_other.dart' 
    if (dart.library.html) 'file_saver_web.dart';

// Importación necesaria para que las funciones de abajo reconozcan las versiones "Impl"
import 'file_saver_stub_other.dart' 
    if (dart.library.html) 'file_saver_web.dart';

Future<String?> saveFile({
  required String fileName,
  required List<int> bytes,
  String? mimeType,
}) {
  return saveFileImpl(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: mimeType,
  );
}

Future<String?> saveTextFile({
  required String fileName,
  required String content,
  String? mimeType,
}) {
  return saveTextFileImpl(
    fileName: fileName,
    content: content,
    mimeType: mimeType,
  );
}

Future<void> openFile(String path) => openFileImpl(path);
