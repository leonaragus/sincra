// ========================================================================
// SIMULADOR DE IMPACTO DE PARITARIAS
// Calcula el impacto financiero de cambios en escalas salariales
// antes de aplicarlos
// ========================================================================

import 'liquidacion_historial_service.dart';

/// Resultado de simulación de impacto
class ImpactoSimulacion {
  final double masaSalarialActual;
  final double masaSalarialNueva;
  final double diferenciaAbsoluta;
  final double diferenciaPorcentual;
  final int cantidadEmpleados;
  final Map<String, double> impactoPorCategoria;
  final double costoEmpleadorActual;
  final double costoEmpleadorNuevo;
  final double diferenciaCostoEmpleador;
  
  ImpactoSimulacion({
    required this.masaSalarialActual,
    required this.masaSalarialNueva,
    required this.diferenciaAbsoluta,
    required this.diferenciaPorcentual,
    required this.cantidadEmpleados,
    required this.impactoPorCategoria,
    required this.costoEmpleadorActual,
    required this.costoEmpleadorNuevo,
    required this.diferenciaCostoEmpleador,
  });
}

/// Servicio simulador de impacto
class SimuladorImpactoService {
  /// Simula impacto de cambio porcentual en paritarias
  static Future<ImpactoSimulacion> simularImpactoPorcentual(
    List<String> empleadosCuils,
    double porcentajeAumento,
  ) async {
    double masaSalarialActual = 0;
    double masaSalarialNueva = 0;
    final impactoPorCategoria = <String, double>{};
    
    // Obtener liquidaciones más recientes de cada empleado
    for (final cuil in empleadosCuils) {
      final historial = await LiquidacionHistorialService.obtenerUltimosMesesMensuales(cuil, 1);
      
      if (historial.isNotEmpty) {
        final ultima = historial.first;
        final brutoActual = ultima.totalBrutoRemunerativo;
        final brutoNuevo = brutoActual * (1 + porcentajeAumento / 100);
        
        masaSalarialActual += brutoActual;
        masaSalarialNueva += brutoNuevo;
        
        // Por categoría (simplificado - usaríamos metadata real)
        final categoria = 'General';
        impactoPorCategoria[categoria] = (impactoPorCategoria[categoria] ?? 0) + (brutoNuevo - brutoActual);
      }
    }
    
    final diferenciaAbsoluta = masaSalarialNueva - masaSalarialActual;
    final diferenciaPorcentual = masaSalarialActual > 0 
        ? (diferenciaAbsoluta / masaSalarialActual) * 100 
        : 0.0;
    
    // Estimar costo empleador (aprox 33% de contribuciones patronales)
    final costoEmpleadorActual = masaSalarialActual * 1.33;
    final costoEmpleadorNuevo = masaSalarialNueva * 1.33;
    final diferenciaCostoEmpleador = costoEmpleadorNuevo - costoEmpleadorActual;
    
    return ImpactoSimulacion(
      masaSalarialActual: masaSalarialActual,
      masaSalarialNueva: masaSalarialNueva,
      diferenciaAbsoluta: diferenciaAbsoluta,
      diferenciaPorcentual: diferenciaPorcentual,
      cantidadEmpleados: empleadosCuils.length,
      impactoPorCategoria: impactoPorCategoria,
      costoEmpleadorActual: costoEmpleadorActual,
      costoEmpleadorNuevo: costoEmpleadorNuevo,
      diferenciaCostoEmpleador: diferenciaCostoEmpleador,
    );
  }
  
  /// Genera reporte de impacto
  static String generarReporteImpacto(ImpactoSimulacion impacto) {
    final sb = StringBuffer();
    
    sb.writeln('═══════════════════════════════════════════════');
    sb.writeln('SIMULACIÓN DE IMPACTO DE PARITARIAS');
    sb.writeln('═══════════════════════════════════════════════');
    sb.writeln();
    
    sb.writeln('📊 RESUMEN GENERAL');
    sb.writeln('   Cantidad de empleados: ${impacto.cantidadEmpleados}');
    sb.writeln();
    
    sb.writeln('💰 MASA SALARIAL');
    sb.writeln('   Actual:  \$${impacto.masaSalarialActual.toStringAsFixed(2)}');
    sb.writeln('   Nueva:   \$${impacto.masaSalarialNueva.toStringAsFixed(2)}');
    sb.writeln('   Diferencia: \$${impacto.diferenciaAbsoluta.toStringAsFixed(2)} '
                '(${impacto.diferenciaPorcentual > 0 ? '+' : ''}${impacto.diferenciaPorcentual.toStringAsFixed(2)}%)');
    sb.writeln();
    
    sb.writeln('🏢 COSTO EMPLEADOR (incluye contribuciones ~33%)');
    sb.writeln('   Actual:  \$${impacto.costoEmpleadorActual.toStringAsFixed(2)}');
    sb.writeln('   Nuevo:   \$${impacto.costoEmpleadorNuevo.toStringAsFixed(2)}');
    sb.writeln('   Diferencia: \$${impacto.diferenciaCostoEmpleador.toStringAsFixed(2)}');
    sb.writeln();
    
    if (impacto.impactoPorCategoria.isNotEmpty) {
      sb.writeln('📋 IMPACTO POR CATEGORÍA');
      impacto.impactoPorCategoria.forEach((cat, imp) {
        sb.writeln('   $cat: \$${imp.toStringAsFixed(2)}');
      });
      sb.writeln();
    }
    
    sb.writeln('📈 PROYECCIÓN ANUAL');
    final impactoMensual = impacto.diferenciaAbsoluta;
    final impactoAnual = impactoMensual * 12;
    final impactoConSAC = impactoAnual + (impactoMensual * 2); // Incluye SAC
    sb.writeln('   Impacto mensual: \$${impactoMensual.toStringAsFixed(2)}');
    sb.writeln('   Impacto anual (sin SAC): \$${impactoAnual.toStringAsFixed(2)}');
    sb.writeln('   Impacto anual (con SAC): \$${impactoConSAC.toStringAsFixed(2)}');
    
    return sb.toString();
  }
  
  /// Compara dos escenarios de paritarias
  static Map<String, dynamic> compararEscenarios({
    required double escenario1Pct,
    required double escenario2Pct,
    required double masaSalarialBase,
  }) {
    final masa1 = masaSalarialBase * (1 + escenario1Pct / 100);
    final masa2 = masaSalarialBase * (1 + escenario2Pct / 100);
    
    final diferencia = masa2 - masa1;
    final diferenciaPct = masa1 > 0 ? ((diferencia / masa1) * 100) : 0.0;
    
    return {
      'escenario1': {
        'porcentaje': escenario1Pct,
        'masaSalarial': masa1,
        'costoEmpleador': masa1 * 1.33,
      },
      'escenario2': {
        'porcentaje': escenario2Pct,
        'masaSalarial': masa2,
        'costoEmpleador': masa2 * 1.33,
      },
      'diferencia': {
        'absoluta': diferencia,
        'porcentual': diferenciaPct,
        'costoEmpleador': (masa2 - masa1) * 1.33,
      },
    };
  }
}
