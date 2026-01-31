import 'package:flutter/material.dart';

/// Paleta moderna estilo React - Sincronizado con web de pruebas.
abstract class AppColors {
  AppColors._();

  /// Fondo general de la app (slate-950).
  static const Color background = Color(0xFF0f172a);

  /// Variantes de fondo para tarjetas/overlays (slate-800/40, slate-900/40).
  static const Color backgroundLight = Color(0xFF1e293b);
  static const Color backgroundCard = Color(0xFF334155);
  static const Color backgroundDark = Color(0xFF020617); // slate-950 deep

  /// Primary color (primary-600).
  static const Color primary = Color(0xFF0284c7);
  static const Color primaryLight = Color(0xFF0ea5e9);
  static const Color primaryDark = Color(0xFF0369a1);

  /// Colores de acento modernos.
  static const Color accentBlue = Color(0xFF3b82f6);
  static const Color accentEmerald = Color(0xFF10b981);
  static const Color accentYellow = Color(0xFFeab308);
  static const Color accentPink = Color(0xFFec4899);
  static const Color accentPurple = Color(0xFFa855f7);
  static const Color accentOrange = Color(0xFFf97316);

  /// Colores pastel (mantenidos para compatibilidad).
  static const Color pastelYellow = Color(0xFFeab308);
  static const Color pastelBlue = Color(0xFF3b82f6);
  static const Color pastelOrange = Color(0xFFf97316);
  static const Color pastelMint = Color(0xFF10b981);
  static const Color pastelPink = Color(0xFFec4899);
  static const Color pastelLavender = Color(0xFFa855f7);

  /// Texto.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFcbd5e1); // slate-300
  static const Color textMuted = Color(0xFF94a3b8); // slate-400

  /// Bordes y glassmorphism (slate-700/60).
  static const Color glassFill = Color.fromRGBO(51, 65, 85, 0.4); // slate-800/40
  static const Color glassBorder = Color.fromRGBO(51, 65, 85, 0.6); // slate-700/60
  static const Color glassFillStrong = Color.fromRGBO(30, 41, 59, 0.4); // slate-900/40
}
