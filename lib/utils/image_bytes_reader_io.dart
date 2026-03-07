// Implementación nativa (Windows, Android, iOS, macOS, Linux)
import 'dart:io';
import 'dart:typed_data';

/// Lee los bytes de una imagen desde el sistema de archivos.
Future<Uint8List?> readImageBytesImpl(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {
    // Silenciar errores de lectura
  }
  return null;
}

/// Lee los bytes de un archivo desde el sistema de archivos (Nativo).
Future<Uint8List?> readBytesFromFileImpl(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {
    // Silenciar errores de lectura
  }
  return null;
}
