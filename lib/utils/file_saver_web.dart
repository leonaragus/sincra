// =============================================================================
// FILE SAVER - Versión Web (stub)
// =============================================================================
// Usa la API del navegador para descargar archivos.
// =============================================================================

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert'; // Agregado para latin1

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
    dynamic blobContent = content;
    String finalMimeType = mimeType ?? 'text/plain; charset=utf-8';

    // MEJORA CRÍTICA: Detectar archivos LSD o TXT que requieren Latin-1 (ISO-8859-1) para AFIP
    // Si no hacemos esto, el navegador guardará como UTF-8 y romperá la longitud fija de registros
    // si hay caracteres especiales (tildes, ñ).
    if (fileName.toLowerCase().contains('lsd') || fileName.toLowerCase().endsWith('.txt')) {
       try {
         // Intentar codificar a Latin-1 (bytes)
         blobContent = latin1.encode(content);
         finalMimeType = 'text/plain; charset=iso-8859-1';
       } catch (e) {
         print('Advertencia: Falló la codificación Latin-1 para $fileName, usando UTF-8. Error: $e');
         // Fallback a UTF-8 (default)
       }
    }

    final blob = html.Blob([blobContent], finalMimeType);
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
