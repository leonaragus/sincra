// Stub para Web - No puede leer archivos locales
import 'dart:typed_data';

/// En web, retorna null porque no podemos leer archivos locales.
/// Las imágenes en web se manejan de forma diferente (base64, URLs, etc.)
Future<Uint8List?> readImageBytesImpl(String path) async {
  // En web no podemos leer archivos del sistema de archivos local
  // TODO: Implementar alternativa para web (base64 storage, etc.)
  return null;
}
