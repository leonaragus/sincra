
import 'package:flutter/material.dart';

/// Un modelo de datos para representar una tarjeta de módulo en la HomeScreen.
///
/// Esto permite definir la lista de módulos como datos, separando la configuración
/// de la lógica de la UI y haciendo que el mantenimiento sea mucho más sencillo.
class ModuleInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isPremium;
  final bool isHighlighted;
  final Widget Function(BuildContext) buildRoute;

  const ModuleInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.buildRoute,
    this.isPremium = false,
    this.isHighlighted = false,
  });
}
