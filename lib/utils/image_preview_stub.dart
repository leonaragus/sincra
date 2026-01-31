// =============================================================================
// IMAGE PREVIEW - Versión Web (stub)
// =============================================================================
// En web no podemos acceder a archivos locales, mostramos placeholder.
// =============================================================================

import 'package:flutter/material.dart';

/// En web, mostramos un placeholder porque no podemos acceder a archivos locales.
Widget buildImagePreviewImpl({
  required String path,
  required double width,
  required double height,
  BoxFit fit = BoxFit.contain,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  // En web no podemos mostrar archivos locales
  // TODO: Implementar con base64 storage para web
  return placeholder ?? Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image, color: Colors.grey, size: 24),
        SizedBox(height: 4),
        Text('Vista previa', style: TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    ),
  );
}
