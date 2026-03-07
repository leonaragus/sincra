
import 'package:supabase_flutter/supabase_flutter.dart';
import 'empleados_service.dart';
import '../models/empleado_completo.dart';

class ReportesService {

  /// **NUEVO MÉTODO UNIFICADO Y OPTIMIZADO**
  /// Obtiene todos los datos necesarios para el Dashboard Gerencial en una sola operación.
  static Future<Map<String, dynamic>> obtenerDatosDashboard({String? empresaCuit}) async {
    try {
      // 1. Obtener empleados activos (UNA SOLA VEZ)
      final empleados = await EmpleadosService.obtenerEmpleadosActivos(empresaCuit: empresaCuit);

      // 2. Calcular KPIs a partir de la lista de empleados
      final kpis = _calcularKPIsDesdeEmpleados(empleados);

      // 3. Calcular Top 5 empleados por antigüedad (reutilizando la lista)
      final topEmpleados = _calcularTopEmpleados(empleados, limit: 5);

      // 4. Obtener evolución de masa salarial desde la base de datos
      final evolucion = await obtenerEvolucionMasaSalarial(empresaCuit: empresaCuit);

      // 5. Devolver todo en un solo mapa
      return {
        'kpis': kpis,
        'evolucion': evolucion,
        'top_empleados': topEmpleados,
      };

    } catch (e) {
      print('Error unificado obteniendo datos del dashboard: $e');
      throw Exception('No se pudieron cargar los datos del dashboard.');
    }
  }

  /// Lógica de KPIs extraída para ser reutilizable.
  static Map<String, dynamic> _calcularKPIsDesdeEmpleados(List<EmpleadoCompleto> empleados) {
    final totalEmpleados = empleados.length;
    final porProvincia = <String, int>{};
    final porCategoria = <String, int>{};
    double costoEstimado = 0;

    for (final emp in empleados) {
      porProvincia[emp.provincia] = (porProvincia[emp.provincia] ?? 0) + 1;
      porCategoria[emp.categoria] = (porCategoria[emp.categoria] ?? 0) + 1;
      costoEstimado += 500000; // Placeholder para estimación de costo
    }

    return {
      'total_empleados': totalEmpleados,
      'costo_estimado_mes': costoEstimado,
      'por_provincia': porProvincia,
      'por_categoria': porCategoria,
    };
  }

  /// Lógica de Top Empleados extraída para ser reutilizable.
  static List<Map<String, dynamic>> _calcularTopEmpleados(List<EmpleadoCompleto> empleados, {int limit = 5}) {
    final List<Map<String, dynamic>> top = [];
    for (final e in empleados) {
      final item = {
        'nombre': e.nombreCompleto,
        'categoria': e.categoria,
        'antiguedad': e.antiguedadAnios,
        'provincia': e.provincia,
      };
      if (top.length < limit) {
        top.add(item);
      } else {
        int minIdx = 0;
        for (int i = 1; i < top.length; i++) {
          if ((top[i]['antiguedad'] as int) < (top[minIdx]['antiguedad'] as int)) {
            minIdx = i;
          }
        }
        if (e.antiguedadAnios > (top[minIdx]['antiguedad'] as int)) {
          top[minIdx] = item;
        }
      }
    }
    top.sort((a, b) => (b['antiguedad'] as int).compareTo(a['antiguedad'] as int));
    return top;
  }

  // --- Métodos antiguos (se mantienen por posible retrocompatibilidad) ---

  static Future<Map<String, dynamic>> obtenerKPIsMes({
    required int mes, required int anio, String? empresaCuit
  }) async {
    final empleados = await EmpleadosService.obtenerEmpleadosActivos(empresaCuit: empresaCuit);
    return _calcularKPIsDesdeEmpleados(empleados);
  }

  static Future<List<Map<String, dynamic>>> obtenerEvolucionMasaSalarial({String? empresaCuit}) async {
    try {
      final ahora = DateTime.now();
      final hace12Meses = DateTime(ahora.year - 1, ahora.month, 1);

      var query = Supabase.instance.client
          .from('f931_historial')
          .select('periodo_mes, periodo_anio, total_remuneraciones')
          .gte('periodo_anio', hace12Meses.year)
          .order('periodo_anio', ascending: false)
          .order('periodo_mes', ascending: false)
          .limit(12);
      
      if (empresaCuit != null) {
        query = query.eq('empresa_cuit', empresaCuit);
      }

      final res = await query;
      final list = (res as List).cast<Map<String, dynamic>>();
      return list.reversed.toList();
    } catch (e) {
      print('Error obteniendo evolución: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> obtenerTopEmpleados({String? empresaCuit, int limit = 10}) async {
    final empleados = await EmpleadosService.obtenerEmpleadosActivos(empresaCuit: empresaCuit);
    return _calcularTopEmpleados(empleados, limit: limit);
  }
  
  // ... (El resto de los métodos como `obtenerComparativaMesAnterior` se mantienen igual)
}
