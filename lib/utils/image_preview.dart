// =============================================================================
// IMAGE PREVIEW - Multiplataforma (Web + Nativo)
// =============================================================================
// Muestra preview de imágenes desde path local.
// En web: muestra placeholder (no podemos acceder a archivos locales)
// En nativo: muestra la imagen del sistema de archivos
// =============================================================================

import 'package:flutter/material.dart';
import 'image_preview_stub.dart' if (dart.library.io) 'image_preview_io.dart' as _impl;

/// Construye un widget para mostrar preview de una imagen desde un path.
/// En web retorna un placeholder.
/// En nativo muestra la imagen del archivo.
Widget buildImagePreview({
  required String? path,
  required double width,
  required double height,
  BoxFit fit = BoxFit.contain,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  if (path == null || path.isEmpty || path == 'No disponible') {
    return placeholder ?? Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
  return _impl.buildImagePreviewImpl(
    path: path,
    width: width,
    height: height,
    fit: fit,
    placeholder: placeholder,
    errorWidget: errorWidget,
  );
}
