// ========================================================================
// SERVICIO DE REPORTES GERENCIALES
// Cálculos y estadísticas para dashboard con datos de Supabase
// ========================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'empleados_service.dart';

class ReportesService {
  /// Obtiene KPIs principales del mes
  static Future<Map<String, dynamic>> obtenerKPIsMes({
    required int mes,
    required int anio,
    String? empresaCuit,
  }) async {
    try {
      final empleados = await EmpleadosService.obtenerEmpleadosActivos(
        empresaCuit: empresaCuit,
      );
      
      // Calcular estadísticas básicas
      final totalEmpleados = empleados.length;
      final porProvincia = <String, int>{};
      final porCategoria = <String, int>{};
      final porSector = <String, int>{};
      
      double costoEstimado = 0;
      
      for (final emp in empleados) {
        // Contar por provincia
        porProvincia[emp.provincia] = (porProvincia[emp.provincia] ?? 0) + 1;
        
        // Contar por categoría
        porCategoria[emp.categoria] = (porCategoria[emp.categoria] ?? 0) + 1;
        
        // Contar por sector
        if (emp.sector != null) {
          porSector[emp.sector!] = (porSector[emp.sector!] ?? 0) + 1;
        }
        
        // Estimar costo (placeholder - debería usar liquidaciones reales)
        costoEstimado += 500000; // Placeholder
      }
      
      return {
        'total_empleados': totalEmpleados,
        'costo_estimado_mes': costoEstimado,
        'por_provincia': porProvincia,
        'por_categoria': porCategoria,
        'por_sector': porSector,
      };
    } catch (e) {
      print('Error obteniendo KPIs: $e');
      return {
        'total_empleados': 0,
        'costo_estimado_mes': 0.0,
        'por_provincia': {},
        'por_categoria': {},
        'por_sector': {},
      };
    }
  }
  
  /// Obtiene evolución de masa salarial (últimos 12 meses)
  static Future<List<Map<String, dynamic>>> obtenerEvolucionMasaSalarial({
    String? empresaCuit,
  }) async {
    try {
      final ahora = DateTime.now();
      final hace12Meses = DateTime(ahora.year - 1, ahora.month, 1);
      
      final res = await Supabase.instance.client
          .from('f931_historial')
          .select('periodo_mes, periodo_anio, total_remuneraciones, total_aportes, total_contribuciones')
          .gte('periodo_anio', hace12Meses.year)
          .order('periodo_anio', ascending: true)
          .order('periodo_mes', ascending: true);
      
      if (empresaCuit != null) {
        return (res as List).cast<Map<String, dynamic>>();
      }
      
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error obteniendo evolución: $e');
      return [];
    }
  }
  
  /// Obtiene top empleados mejor remunerados
  static Future<List<Map<String, dynamic>>> obtenerTopEmpleados({
    String? empresaCuit,
    int limit = 10,
  }) async {
    // Placeholder: Debería obtener desde historial de liquidaciones
    // Por ahora devolvemos empleados ordenados por antigüedad como proxy
    
    final empleados = await EmpleadosService.obtenerEmpleadosActivos(
      empresaCuit: empresaCuit,
    );
    
    empleados.sort((a, b) => b.antiguedadAnios.compareTo(a.antiguedadAnios));
    
    return empleados.take(limit).map((e) => {
      'nombre': e.nombreCompleto,
      'categoria': e.categoria,
      'antiguedad': e.antiguedadAnios,
      'provincia': e.provincia,
      'remuneracion_estimada': 500000.0 + (e.antiguedadAnios * 10000), // Placeholder
    }).toList();
  }
  
  /// Obtiene comparativa mes actual vs anterior
  static Future<Map<String, dynamic>> obtenerComparativaMesAnterior({
    required int mes,
    required int anio,
    String? empresaCuit,
  }) async {
    try {
      // Mes actual
      final actualQuery = Supabase.instance.client
          .from('f931_historial')
          .select()
          .eq('periodo_mes', mes)
          .eq('periodo_anio', anio);
      
      if (empresaCuit != null) {
        actualQuery.eq('empresa_cuit', empresaCuit);
      }
      
      final actual = await actualQuery.maybeSingle();
      
      // Mes anterior
      int mesAnterior = mes - 1;
      int anioAnterior = anio;
      if (mesAnterior == 0) {
        mesAnterior = 12;
        anioAnterior--;
      }
      
      final anteriorQuery = Supabase.instance.client
          .from('f931_historial')
          .select()
          .eq('periodo_mes', mesAnterior)
          .eq('periodo_anio', anioAnterior);
      
      if (empresaCuit != null) {
        anteriorQuery.eq('empresa_cuit', empresaCuit);
      }
      
      final anterior = await anteriorQuery.maybeSingle();
      
      if (actual == null) {
        return {
          'tiene_actual': false,
          'tiene_anterior': anterior != null,
        };
      }
      
      final totalActual = (actual['total_remuneraciones'] as num?)?.toDouble() ?? 0.0;
      final totalAnterior = (anterior?['total_remuneraciones'] as num?)?.toDouble() ?? 0.0;
      
      final variacion = totalAnterior > 0 
          ? ((totalActual - totalAnterior) / totalAnterior) * 100 
          : 0.0;
      
      return {
        'tiene_actual': true,
        'tiene_anterior': anterior != null,
        'total_actual': totalActual,
        'total_anterior': totalAnterior,
        'variacion_pct': variacion,
        'variacion_absoluta': totalActual - totalAnterior,
        'alerta': variacion.abs() > 10.0, // Alerta si variación > 10%
      };
    } catch (e) {
      print('Error obteniendo comparativa: $e');
      return {
        'tiene_actual': false,
        'tiene_anterior': false,
      };
    }
  }
}
