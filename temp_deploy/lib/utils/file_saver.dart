// =============================================================================
// FILE SAVER - Multiplataforma (Web + Nativo)
// =============================================================================
// Usa conditional imports para manejar la descarga de archivos en web y nativo.
// En web: usa download del navegador
// En nativo: guarda en el sistema de archivos
// =============================================================================

import 'dart:typed_data';
import 'file_saver_stub.dart' if (dart.library.io) 'file_saver_io.dart' as _impl;

/// Guarda un archivo y retorna el path donde fue guardado (o null en web).
/// En web, dispara la descarga automática del navegador.
/// En nativo, guarda en la carpeta de documentos de la app.
Future<String?> saveFile({
  required String fileName,
  required Uint8List bytes,
  String? mimeType,
}) async {
  return _impl.saveFileImpl(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
}

/// Guarda un archivo de texto y retorna el path donde fue guardado (o null en web).
Future<String?> saveTextFile({
  required String fileName,
  required String content,
  String? mimeType,
}) async {
  return _impl.saveTextFileImpl(
    fileName: fileName,
    content: content,
    mimeType: mimeType,
  );
}

/// Abre un archivo (solo funciona en nativo).
Future<void> openFile(String path) async {
  return _impl.openFileImpl(path);
}
