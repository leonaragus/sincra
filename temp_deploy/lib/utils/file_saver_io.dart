// =============================================================================
// FILE SAVER - Versión Nativa (Windows, Android, iOS, macOS, Linux)
// =============================================================================
// Guarda archivos en el sistema de archivos local.
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// En nativo, guarda el archivo y retorna el path completo.
Future<String?> saveFileImpl({
  required String fileName,
  required Uint8List bytes,
  String? mimeType,
}) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e) {
    print('Error al guardar archivo: $e');
    return null;
  }
}

/// En nativo, guarda el archivo de texto y retorna el path completo.
Future<String?> saveTextFileImpl({
  required String fileName,
  required String content,
  String? mimeType,
}) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    // Usar latin1 para archivos LSD (compatibilidad ARCA)
    if (fileName.toLowerCase().contains('lsd') || fileName.toLowerCase().endsWith('.txt')) {
      await file.writeAsString(content, encoding: latin1);
    } else {
      await file.writeAsString(content);
    }
    return file.path;
  } catch (e) {
    print('Error al guardar archivo: $e');
    return null;
  }
}

/// En nativo, abre el archivo con la app por defecto.
Future<void> openFileImpl(String path) async {
  try {
    await OpenFile.open(path);
  } catch (e) {
    print('Error al abrir archivo: $e');
  }
}
