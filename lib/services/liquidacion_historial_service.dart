// ========================================================================
// SERVICIO DE HISTORIAL DE LIQUIDACIONES
// Almacena historial de liquidaciones por empleado para:
// - Cálculo automático de mejor remuneración (últimos 6 meses)
// - Comparativas mes a mes
// - Detección de saltos inusuales
// - Auditoría y trazabilidad
// ========================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Registro de liquidación para historial
class RegistroLiquidacion {
  final String empleadoCuil;
  final String empleadoNombre;
  final String modulo; // 'sanidad', 'docentes'
  final DateTime fecha;
  final String periodo; // 'Enero 2026'
  final double totalBrutoRemunerativo;
  final double totalNoRemunerativo;
  final double totalDescuentos;
  final double netoACobrar;
  final Map<String, double> detalleConceptos; // Para auditoría detallada
  final String tipoLiquidacion; // 'mensual', 'sac', 'vacaciones', 'liquidacion_final'
  final String? observaciones;
  
  RegistroLiquidacion({
    required this.empleadoCuil,
    required this.empleadoNombre,
    required this.modulo,
    required this.fecha,
    required this.periodo,
    required this.totalBrutoRemunerativo,
    required this.totalNoRemunerativo,
    required this.totalDescuentos,
    required this.netoACobrar,
    required this.detalleConceptos,
    required this.tipoLiquidacion,
    this.observaciones,
  });
  
  Map<String, dynamic> toJson() => {
    'empleadoCuil': empleadoCuil,
    'empleadoNombre': empleadoNombre,
    'modulo': modulo,
    'fecha': fecha.toIso8601String(),
    'periodo': periodo,
    'totalBrutoRemunerativo': totalBrutoRemunerativo,
    'totalNoRemunerativo': totalNoRemunerativo,
    'totalDescuentos': totalDescuentos,
    'netoACobrar': netoACobrar,
    'detalleConceptos': detalleConceptos,
    'tipoLiquidacion': tipoLiquidacion,
    'observaciones': observaciones,
  };
  
  factory RegistroLiquidacion.fromJson(Map<String, dynamic> json) => RegistroLiquidacion(
    empleadoCuil: json['empleadoCuil'] as String,
    empleadoNombre: json['empleadoNombre'] as String,
    modulo: json['modulo'] as String,
    fecha: DateTime.parse(json['fecha'] as String),
    periodo: json['periodo'] as String,
    totalBrutoRemunerativo: (json['totalBrutoRemunerativo'] as num).toDouble(),
    totalNoRemunerativo: (json['totalNoRemunerativo'] as num).toDouble(),
    totalDescuentos: (json['totalDescuentos'] as num).toDouble(),
    netoACobrar: (json['netoACobrar'] as num).toDouble(),
    detalleConceptos: Map<String, double>.from(
      (json['detalleConceptos'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
    ),
    tipoLiquidacion: json['tipoLiquidacion'] as String,
    observaciones: json['observaciones'] as String?,
  );
}

/// Servicio de historial de liquidaciones
class LiquidacionHistorialService {
  static const String _keyPrefix = 'historial_liquidaciones_';
  static const int _maxRegistrosPorEmpleado = 24; // 2 años de historia
  
  /// Guarda una liquidación en el historial
  static Future<void> guardarLiquidacion(RegistroLiquidacion registro) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${registro.empleadoCuil}';
    
    // Cargar historial existente
    final historialJson = prefs.getString(key);
    List<RegistroLiquidacion> historial = [];
    
    if (historialJson != null && historialJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(historialJson);
        historial = decoded.map((j) => RegistroLiquidacion.fromJson(j)).toList();
      } catch (e) {
        print('Error decodificando historial: $e');
      }
    }
    
    // Agregar nuevo registro
    historial.insert(0, registro);
    
    // Limitar a máximo de registros
    if (historial.length > _maxRegistrosPorEmpleado) {
      historial = historial.sublist(0, _maxRegistrosPorEmpleado);
    }
    
    // Guardar
    final encoded = jsonEncode(historial.map((r) => r.toJson()).toList());
    await prefs.setString(key, encoded);
  }
  
  /// Obtiene el historial de un empleado
  static Future<List<RegistroLiquidacion>> obtenerHistorial(String cuil) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$cuil';
    final historialJson = prefs.getString(key);
    
    if (historialJson == null || historialJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(historialJson);
      return decoded.map((j) => RegistroLiquidacion.fromJson(j)).toList();
    } catch (e) {
      print('Error cargando historial: $e');
      return [];
    }
  }
  
  /// Obtiene liquidaciones mensuales de los últimos N meses
  static Future<List<RegistroLiquidacion>> obtenerUltimosMesesMensuales(
    String cuil, 
    int meses,
  ) async {
    final historial = await obtenerHistorial(cuil);
    
    // Filtrar solo liquidaciones mensuales
    final mensuales = historial.where((r) => r.tipoLiquidacion == 'mensual').toList();
    
    // Tomar solo los últimos N meses
    if (mensuales.length <= meses) {
      return mensuales;
    }
    
    return mensuales.sublist(0, meses);
  }
  
  /// Calcula la mejor remuneración de los últimos N meses (para Art. 245 LCT)
  static Future<double?> calcularMejorRemuneracion(String cuil, {int meses = 6}) async {
    final liquidaciones = await obtenerUltimosMesesMensuales(cuil, meses);
    
    if (liquidaciones.isEmpty) {
      return null;
    }
    
    // Buscar la mejor remuneración bruta
    double mejor = 0;
    for (final liq in liquidaciones) {
      if (liq.totalBrutoRemunerativo > mejor) {
        mejor = liq.totalBrutoRemunerativo;
      }
    }
    
    return mejor > 0 ? mejor : null;
  }
  
  /// Obtiene la liquidación anterior (mismo tipo) para comparación
  static Future<RegistroLiquidacion?> obtenerLiquidacionAnterior(
    String cuil, 
    String tipoLiquidacion,
  ) async {
    final historial = await obtenerHistorial(cuil);
    
    // Buscar la primera liquidación del mismo tipo
    for (final reg in historial) {
      if (reg.tipoLiquidacion == tipoLiquidacion) {
        return reg;
      }
    }
    
    return null;
  }
  
  /// Detecta si hay un salto inusual (variación > 30%) entre liquidaciones
  static Future<Map<String, dynamic>?> detectarSaltoInusual(
    String cuil,
    double netoActual,
    String tipoLiquidacion,
  ) async {
    final anterior = await obtenerLiquidacionAnterior(cuil, tipoLiquidacion);
    
    if (anterior == null) {
      return null; // No hay historial para comparar
    }
    
    final netoAnterior = anterior.netoACobrar;
    if (netoAnterior <= 0) {
      return null;
    }
    
    final variacionPct = ((netoActual - netoAnterior) / netoAnterior) * 100;
    
    // Detectar saltos > 30% (positivos o negativos)
    if (variacionPct.abs() > 30) {
      return {
        'anterior': anterior,
        'netoAnterior': netoAnterior,
        'netoActual': netoActual,
        'variacionPct': variacionPct,
        'esAumento': variacionPct > 0,
      };
    }
    
    return null;
  }
  
  /// Elimina todo el historial de un empleado
  static Future<void> eliminarHistorial(String cuil) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$cuil';
    await prefs.remove(key);
  }
  
  /// Obtiene estadísticas del empleado (promedio últimos 6 meses, tendencia, etc.)
  static Future<Map<String, dynamic>> obtenerEstadisticas(String cuil) async {
    final liquidaciones = await obtenerUltimosMesesMensuales(cuil, 12);
    
    if (liquidaciones.isEmpty) {
      return {
        'promedioUltimos6Meses': 0.0,
        'promedioUltimos12Meses': 0.0,
        'tendencia': 'sin_datos',
        'cantidadLiquidaciones': 0,
      };
    }
    
    // Promedio últimos 6 meses
    final ultimos6 = liquidaciones.length > 6 ? liquidaciones.sublist(0, 6) : liquidaciones;
    final promedio6 = ultimos6.fold<double>(0, (sum, l) => sum + l.netoACobrar) / ultimos6.length;
    
    // Promedio últimos 12 meses
    final promedio12 = liquidaciones.fold<double>(0, (sum, l) => sum + l.netoACobrar) / liquidaciones.length;
    
    // Tendencia (comparar primeros 3 vs últimos 3)
    String tendencia = 'estable';
    if (liquidaciones.length >= 6) {
      final primeros3 = liquidaciones.sublist(0, 3);
      final ultimos3 = liquidaciones.sublist(liquidaciones.length - 3, liquidaciones.length);
      final promPrimeros = primeros3.fold<double>(0, (sum, l) => sum + l.netoACobrar) / 3;
      final promUltimos = ultimos3.fold<double>(0, (sum, l) => sum + l.netoACobrar) / 3;
      
      final variacion = ((promPrimeros - promUltimos) / promUltimos) * 100;
      if (variacion > 10) {
        tendencia = 'creciente';
      } else if (variacion < -10) {
        tendencia = 'decreciente';
      }
    }
    
    return {
      'promedioUltimos6Meses': promedio6,
      'promedioUltimos12Meses': promedio12,
      'tendencia': tendencia,
      'cantidadLiquidaciones': liquidaciones.length,
    };
  }
}
