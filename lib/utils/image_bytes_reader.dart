// Helper para leer bytes de imagen - Multiplataforma (Web + Nativo)
// Usa conditional imports para manejar dart:io en nativo y alternativas en web

import 'dart:typed_data';
import 'image_bytes_reader_stub.dart' if (dart.library.io) 'image_bytes_reader_io.dart' as _impl;

/// Lee los bytes de una imagen desde un path.
/// En web retorna null (las imágenes se manejan diferente).
/// En nativo lee el archivo si existe.
Future<Uint8List?> readImageBytes(String? path) async {
  if (path == null || path.isEmpty || path == 'No disponible') {
    return null;
  }
  return _impl.readImageBytesImpl(path);
}
