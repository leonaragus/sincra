// ========================================================================
// SERVICIO DE COMPARATIVAS MES A MES
// Compara liquidaciones entre períodos para análisis de evolución
// ========================================================================

import '../models/historial_liquidacion.dart';
import 'historial_liquidaciones_service.dart';

class ComparativaEmpleado {
  final String empleadoCuil;
  final String empleadoNombre;
  
  // Período actual
  final HistorialLiquidacion? liquidacionActual;
  
  // Período anterior
  final HistorialLiquidacion? liquidacionAnterior;
  
  // Diferencias absolutas
  final double diferenciaBasico;
  final double diferenciaAntiguedad;
  final double diferenciaBruto;
  final double diferenciaAportes;
  final double diferenciaNeto;
  
  // Diferencias porcentuales
  final double porcentajeBasico;
  final double porcentajeAntiguedad;
  final double porcentajeBruto;
  final double porcentajeAportes;
  final double porcentajeNeto;
  
  // Análisis
  final String tendencia; // 'aumento', 'disminucion', 'sin_cambio'
  final bool esCambioSignificativo; // >10%
  
  ComparativaEmpleado({
    required this.empleadoCuil,
    required this.empleadoNombre,
    this.liquidacionActual,
    this.liquidacionAnterior,
    required this.diferenciaBasico,
    required this.diferenciaAntiguedad,
    required this.diferenciaBruto,
    required this.diferenciaAportes,
    required this.diferenciaNeto,
    required this.porcentajeBasico,
    required this.porcentajeAntiguedad,
    required this.porcentajeBruto,
    required this.porcentajeAportes,
    required this.porcentajeNeto,
    required this.tendencia,
    required this.esCambioSignificativo,
  });
}

class ResumenComparativa {
  final int totalEmpleados;
  final int empleadosConAumento;
  final int empleadosConDisminucion;
  final int empleadosSinCambio;
  final double promedioVariacionPorcentual;
  final double masaSalarialActual;
  final double masaSalarialAnterior;
  final double variacionMasaSalarial;
  final List<ComparativaEmpleado> comparativas;
  
  ResumenComparativa({
    required this.totalEmpleados,
    required this.empleadosConAumento,
    required this.empleadosConDisminucion,
    required this.empleadosSinCambio,
    required this.promedioVariacionPorcentual,
    required this.masaSalarialActual,
    required this.masaSalarialAnterior,
    required this.variacionMasaSalarial,
    required this.comparativas,
  });
}

class ComparativasService {
  /// Compara liquidaciones entre dos períodos
  static Future<ResumenComparativa> compararPeriodos({
    required int mesActual,
    required int anioActual,
    int? mesAnterior,
    int? anioAnterior,
    List<String>? cuilsFiltro,
  }) async {
    // Si no se especifica período anterior, usar mes anterior
    if (mesAnterior == null || anioAnterior == null) {
      if (mesActual == 1) {
        mesAnterior = 12;
        anioAnterior = anioActual - 1;
      } else {
        mesAnterior = mesActual - 1;
        anioAnterior = anioActual;
      }
    }
    
    // Obtener liquidaciones de ambos períodos
    final liquidacionesActuales = await _obtenerLiquidacionesPeriodo(
      mesActual,
      anioActual,
      cuilsFiltro,
    );
    
    final liquidacionesAnteriores = await _obtenerLiquidacionesPeriodo(
      mesAnterior,
      anioAnterior,
      cuilsFiltro,
    );
    
    // Agrupar por CUIL
    final mapActuales = {for (var liq in liquidacionesActuales) liq.empleadoCuil: liq};
    final mapAnteriores = {for (var liq in liquidacionesAnteriores) liq.empleadoCuil: liq};
    
    // Obtener todos los CUILs únicos
    final cuils = {...mapActuales.keys, ...mapAnteriores.keys};
    
    // Generar comparativas
    final comparativas = <ComparativaEmpleado>[];
    int empleadosConAumento = 0;
    int empleadosConDisminucion = 0;
    int empleadosSinCambio = 0;
    double sumaVariaciones = 0;
    double masaSalarialActual = 0;
    double masaSalarialAnterior = 0;
    
    for (final cuil in cuils) {
      final liqActual = mapActuales[cuil];
      final liqAnterior = mapAnteriores[cuil];
      
      if (liqActual != null) {
        masaSalarialActual += liqActual.netoACobrar;
      }
      if (liqAnterior != null) {
        masaSalarialAnterior += liqAnterior.netoACobrar;
      }
      
      final comparativa = _compararLiquidaciones(liqActual, liqAnterior);
      comparativas.add(comparativa);
      
      // Contabilizar
      if (comparativa.tendencia == 'aumento') {
        empleadosConAumento++;
      } else if (comparativa.tendencia == 'disminucion') {
        empleadosConDisminucion++;
      } else {
        empleadosSinCambio++;
      }
      
      sumaVariaciones += comparativa.porcentajeNeto;
    }
    
    final promedioVariacion = cuils.isEmpty ? 0.0 : sumaVariaciones / cuils.length;
    final variacionMasa = masaSalarialAnterior == 0 
        ? 0.0 
        : ((masaSalarialActual - masaSalarialAnterior) / masaSalarialAnterior) * 100;
    
    return ResumenComparativa(
      totalEmpleados: cuils.length,
      empleadosConAumento: empleadosConAumento,
      empleadosConDisminucion: empleadosConDisminucion,
      empleadosSinCambio: empleadosSinCambio,
      promedioVariacionPorcentual: promedioVariacion,
      masaSalarialActual: masaSalarialActual,
      masaSalarialAnterior: masaSalarialAnterior,
      variacionMasaSalarial: variacionMasa,
      comparativas: comparativas,
    );
  }
  
  /// Obtiene liquidaciones de un período específico
  static Future<List<HistorialLiquidacion>> _obtenerLiquidacionesPeriodo(
    int mes,
    int anio,
    List<String>? cuilsFiltro,
  ) async {
    // Si hay filtro de CUILs, obtener uno por uno
    if (cuilsFiltro != null && cuilsFiltro.isNotEmpty) {
      final liquidaciones = <HistorialLiquidacion>[];
      for (final cuil in cuilsFiltro) {
        final historial = await HistorialLiquidacionesService.obtenerHistorialEmpleado(
          cuil,
          anio: anio,
          mes: mes,
          limit: 1,
        );
        if (historial.isNotEmpty) {
          liquidaciones.add(historial.first);
        }
      }
      return liquidaciones;
    }
    
    // Si no hay filtro, obtener todas (nota: necesitarías un método para obtener todas)
    // Por ahora, retornamos lista vacía
    return [];
  }
  
  /// Compara dos liquidaciones individuales
  static ComparativaEmpleado _compararLiquidaciones(
    HistorialLiquidacion? actual,
    HistorialLiquidacion? anterior,
  ) {
    final cuil = actual?.empleadoCuil ?? anterior?.empleadoCuil ?? '';
    final nombre = actual?.empleadoCuil ?? anterior?.empleadoCuil ?? '';
    
    // Si no hay liquidación anterior, todo es "nuevo"
    if (anterior == null && actual != null) {
      return ComparativaEmpleado(
        empleadoCuil: cuil,
        empleadoNombre: nombre,
        liquidacionActual: actual,
        liquidacionAnterior: null,
        diferenciaBasico: actual.sueldoBasico,
        diferenciaAntiguedad: actual.adicionalAntiguedad,
        diferenciaBruto: actual.totalBrutoRemunerativo,
        diferenciaAportes: actual.totalAportes,
        diferenciaNeto: actual.netoACobrar,
        porcentajeBasico: 100.0,
        porcentajeAntiguedad: 100.0,
        porcentajeBruto: 100.0,
        porcentajeAportes: 100.0,
        porcentajeNeto: 100.0,
        tendencia: 'aumento',
        esCambioSignificativo: true,
      );
    }
    
    // Si no hay liquidación actual, todo es "perdida"
    if (actual == null && anterior != null) {
      return ComparativaEmpleado(
        empleadoCuil: cuil,
        empleadoNombre: nombre,
        liquidacionActual: null,
        liquidacionAnterior: anterior,
        diferenciaBasico: -anterior.sueldoBasico,
        diferenciaAntiguedad: -anterior.adicionalAntiguedad,
        diferenciaBruto: -anterior.totalBrutoRemunerativo,
        diferenciaAportes: -anterior.totalAportes,
        diferenciaNeto: -anterior.netoACobrar,
        porcentajeBasico: -100.0,
        porcentajeAntiguedad: -100.0,
        porcentajeBruto: -100.0,
        porcentajeAportes: -100.0,
        porcentajeNeto: -100.0,
        tendencia: 'disminucion',
        esCambioSignificativo: true,
      );
    }
    
    // Calcular diferencias
    final difBasico = actual!.sueldoBasico - anterior!.sueldoBasico;
    final difAntiguedad = actual.adicionalAntiguedad - anterior.adicionalAntiguedad;
    final difBruto = actual.totalBrutoRemunerativo - anterior.totalBrutoRemunerativo;
    final difAportes = actual.totalAportes - anterior.totalAportes;
    final difNeto = actual.netoACobrar - anterior.netoACobrar;
    
    // Calcular porcentajes
    final pctBasico = anterior.sueldoBasico == 0 ? 0.0 : (difBasico / anterior.sueldoBasico) * 100;
    final pctAntiguedad = anterior.adicionalAntiguedad == 0 ? 0.0 : (difAntiguedad / anterior.adicionalAntiguedad) * 100;
    final pctBruto = anterior.totalBrutoRemunerativo == 0 ? 0.0 : (difBruto / anterior.totalBrutoRemunerativo) * 100;
    final pctAportes = anterior.totalAportes == 0 ? 0.0 : (difAportes / anterior.totalAportes) * 100;
    final pctNeto = anterior.netoACobrar == 0 ? 0.0 : (difNeto / anterior.netoACobrar) * 100;
    
    // Determinar tendencia
    String tendencia;
    if (difNeto > 0.01) {
      tendencia = 'aumento';
    } else if (difNeto < -0.01) {
      tendencia = 'disminucion';
    } else {
      tendencia = 'sin_cambio';
    }
    
    final esCambioSignificativo = pctNeto.abs() > 10.0;
    
    return ComparativaEmpleado(
      empleadoCuil: cuil,
      empleadoNombre: nombre,
      liquidacionActual: actual,
      liquidacionAnterior: anterior,
      diferenciaBasico: difBasico,
      diferenciaAntiguedad: difAntiguedad,
      diferenciaBruto: difBruto,
      diferenciaAportes: difAportes,
      diferenciaNeto: difNeto,
      porcentajeBasico: pctBasico,
      porcentajeAntiguedad: pctAntiguedad,
      porcentajeBruto: pctBruto,
      porcentajeAportes: pctAportes,
      porcentajeNeto: pctNeto,
      tendencia: tendencia,
      esCambioSignificativo: esCambioSignificativo,
    );
  }
  
  /// Genera reporte de texto de la comparativa
  static String generarReporteTexto(ResumenComparativa resumen, int mes, int anio) {
    final buffer = StringBuffer();
    
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('        COMPARATIVA MES A MES - $mes/$anio');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('RESUMEN GENERAL:');
    buffer.writeln('Total empleados:           ${resumen.totalEmpleados}');
    buffer.writeln('Con aumento:               ${resumen.empleadosConAumento} (${(resumen.empleadosConAumento / resumen.totalEmpleados * 100).toStringAsFixed(1)}%)');
    buffer.writeln('Con disminución:           ${resumen.empleadosConDisminucion} (${(resumen.empleadosConDisminucion / resumen.totalEmpleados * 100).toStringAsFixed(1)}%)');
    buffer.writeln('Sin cambio:                ${resumen.empleadosSinCambio}');
    buffer.writeln('');
    buffer.writeln('MASA SALARIAL:');
    buffer.writeln('Actual:                    \$${resumen.masaSalarialActual.toStringAsFixed(2)}');
    buffer.writeln('Anterior:                  \$${resumen.masaSalarialAnterior.toStringAsFixed(2)}');
    buffer.writeln('Variación:                 ${resumen.variacionMasaSalarial >= 0 ? "+" : ""}${resumen.variacionMasaSalarial.toStringAsFixed(2)}%');
    buffer.writeln('');
    buffer.writeln('VARIACIÓN PROMEDIO NETO:   ${resumen.promedioVariacionPorcentual >= 0 ? "+" : ""}${resumen.promedioVariacionPorcentual.toStringAsFixed(2)}%');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    
    return buffer.toString();
  }
}
