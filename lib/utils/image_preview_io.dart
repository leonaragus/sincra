// =============================================================================
// IMAGE PREVIEW - Versión Nativa (Windows, Android, iOS, macOS, Linux)
// =============================================================================
// Muestra imágenes desde el sistema de archivos local.
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';

/// En nativo, mostramos la imagen del archivo.
Widget buildImagePreviewImpl({
  required String path,
  required double width,
  required double height,
  BoxFit fit = BoxFit.contain,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  final file = File(path);
  
  return Image.file(
    file,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return errorWidget ?? Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    },
  );
}
