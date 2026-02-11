import 'package:flutter/material.dart';

class AppColors {
  // Colores principales con mejor contraste
  static const Color primary = Color(0xFF0f172a); // slate-900 - más oscuro para mejor contraste
  static const Color secondary = Color(0xFF1e293b); // slate-800
  static const Color accent = Color(0xFF3b82f6); // blue-500
  
  // Colores de fondo mejorados
  static const Color background = Color(0xFF0f172a); // slate-900 - más oscuro
  static const Color backgroundLight = Color(0xFF1e293b); // slate-800
  static const Color backgroundCard = Color(0xFF334155); // slate-700 - más claro para tarjetas
  
  // Colores de texto con mejor contraste
  static const Color textPrimary = Color(0xFFf8fafc); // slate-50 - más claro
  static const Color textSecondary = Color(0xFFcbd5e1); // slate-300 - más claro que antes
  static const Color textMuted = Color(0xFF94a3b8); // slate-400 - más claro que antes
  static const Color textMutedLightMode = Color(0xFF64748B); // slate-500 - más oscuro para modo claro
  
  // Colores de acento y estado
  static const Color success = Color(0xFF10b981); // emerald-500
  static const Color warning = Color(0xFFf59e0b); // amber-500
  static const Color error = Color(0xFFef4444); // red-500
  static const Color info = Color(0xFF3b82f6); // blue-500
  
  // Colores glassmorphism mejorados para mejor visibilidad
  static const Color glassFill = Color.fromRGBO(30, 41, 59, 0.85); // slate-800 con más opacidad
  static const Color glassBorder = Color.fromRGBO(51, 65, 85, 0.95); // slate-600 con más opacidad
  static const Color glassFillStrong = Color.fromRGBO(51, 65, 85, 0.9); // slate-700 con más opacidad
  
  // Colores adicionales para mejorar legibilidad
  static const Color surface = Color(0xFF1e293b); // slate-800
  static const Color surfaceLight = Color(0xFF334155); // slate-700
  static const Color border = Color(0xFF475569); // slate-600
  static const Color backgroundDark = Color(0xFF0f172a); // slate-900
  
  // Colores pastel que faltaban (agregados para compatibilidad)
  static const Color pastelBlue = Color(0xFFdbeafe); // blue-100
  static const Color pastelMint = Color(0xFFdcfce7); // green-100
  static const Color pastelOrange = Color(0xFFfed7aa); // orange-100
  static const Color pastelYellow = Color(0xFFfef08a); // yellow-100
  static const Color pastelPink = Color(0xFFfbcfe8); // pink-100
  
  // Colores de acento mejorados
  static const Color accentBlue = Color(0xFF3b82f6); // blue-500
  static const Color accentPink = Color(0xFFec4899); // pink-500
  static const Color accentYellow = Color(0xFFf59e0b); // amber-500
  static const Color accentEmerald = Color(0xFF10b981); // emerald-500
  static const Color accentOrange = Color(0xFFf97316); // orange-500
  static const Color accentGreen = Color(0xFF22c55e); // green-500
  static const Color accentRed = Color(0xFFef4444); // red-500
  
  // Gradientes mejorados
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0f172a), // slate-900
      Color(0xFF1e293b), // slate-800
    ],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3b82f6), // blue-500
      Color(0xFF2563eb), // blue-600
    ],
  );

  // Paleta Modo Claro (Light Mode)
  static const Color backgroundLightMode = Color(0xFFF8FAFC); // slate-50
  static const Color backgroundCardLightMode = Color(0xFFFFFFFF); // white
  static const Color textPrimaryLightMode = Color(0xFF0F172A); // slate-900
  static const Color textSecondaryLightMode = Color(0xFF475569); // slate-600
  static const Color glassFillLightMode = Color.fromRGBO(255, 255, 255, 0.85);
  static const Color glassBorderLightMode = Color.fromRGBO(226, 232, 240, 0.95); // slate-200
  static const Color accentBlueLightMode = Color(0xFF2563EB); // blue-600 (más fuerte para contraste en blanco)
}