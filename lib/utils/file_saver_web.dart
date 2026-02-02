// =============================================================================
// FILE SAVER - Versión Web (stub)
// =============================================================================
// Usa la API del navegador para descargar archivos.
// =============================================================================

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// En web, dispara la descarga del navegador y retorna null (no hay path).
Future<String?> saveFileImpl({
  required String fileName,
  required Uint8List bytes,
  String? mimeType,
}) async {
  try {
    final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // Crear anchor y añadirlo al DOM para mejor compatibilidad
    final anchor = html.AnchorElement()
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    
    html.document.body?.children.add(anchor);
    anchor.click();
    
    // Limpiar después de un pequeño delay
    Future.delayed(const Duration(milliseconds: 100), () {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    });
    
    return 'descargado'; // Indicar que se descargó (no hay path real en web)
  } catch (e) {
    print('Error al descargar archivo en web: $e');
    return null;
  }
}

/// En web, dispara la descarga del navegador y retorna null.
Future<String?> saveTextFileImpl({
  required String fileName,
  required String content,
  String? mimeType,
}) async {
  try {
    final blob = html.Blob([content], mimeType ?? 'text/plain; charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // Crear anchor y añadirlo al DOM para mejor compatibilidad
    final anchor = html.AnchorElement()
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    
    html.document.body?.children.add(anchor);
    anchor.click();
    
    // Limpiar después de un pequeño delay
    Future.delayed(const Duration(milliseconds: 100), () {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    });
    
    return 'descargado'; // Indicar que se descargó
  } catch (e) {
    print('Error al descargar archivo en web: $e');
    return null;
  }
}

/// En web no podemos abrir archivos locales.
Future<void> openFileImpl(String path) async {
  // No-op en web - el archivo ya fue descargado
}
