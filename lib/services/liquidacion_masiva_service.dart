// ========================================================================
// SERVICIO DE LIQUIDACIÓN MASIVA
// Procesa múltiples empleados en paralelo con progress tracking
// Integración con motores reales: TeacherOmniEngine y SanidadOmniEngine
// ========================================================================

import '../models/empleado_completo.dart';
import '../models/concepto_recurrente.dart';
import '../models/teacher_types.dart';
import '../models/historial_liquidacion.dart';
import 'empleados_service.dart';
import 'conceptos_recurrentes_service.dart';
import 'teacher_omni_engine.dart';
import 'sanidad_omni_engine.dart';
import 'validaciones_legales_service.dart';
import 'historial_liquidaciones_service.dart';
import 'auditoria_service.dart';

/// Resultado de una liquidación individual
class ResultadoLiquidacionIndividual {
  final String empleadoCuil;
  final String empleadoNombre;
  final bool exito;
  final String? error;
  final Map<String, dynamic>? resultado; // Resultado completo de la liquidación
  
  ResultadoLiquidacionIndividual({
    required this.empleadoCuil,
    required this.empleadoNombre,
    required this.exito,
    this.error,
    this.resultado,
  });
}

/// Resultado de liquidación masiva
class ResultadoLiquidacionMasiva {
  final int totalEmpleados;
  final int exitosos;
  final int fallidos;
  final List<ResultadoLiquidacionIndividual> resultados;
  final Duration duracion;
  final double masaSalarialTotal;
  final double aportesTotal;
  final double contribucionesTotal;
  
  ResultadoLiquidacionMasiva({
    required this.totalEmpleados,
    required this.exitosos,
    required this.fallidos,
    required this.resultados,
    required this.duracion,
    required this.masaSalarialTotal,
    required this.aportesTotal,
    required this.contribucionesTotal,
  });
  
  double get porcentajeExito => totalEmpleados > 0 
      ? (exitosos / totalEmpleados) * 100 
      : 0.0;
}

/// Configuración de liquidación masiva
class ConfiguracionLiquidacionMasiva {
  final int mes;
  final int anio;
  final String? empresaCuit;
  final List<String>? empleadosCuilsFiltro; // Si es null, liquida todos
  final String? provincia; // Filtro opcional
  final String? categoria; // Filtro opcional
  final String? sector; // Filtro opcional
  final bool aplicarConceptosRecurrentes;
  final bool generarRecibos;
  final bool generarF931AlFinal;
  
  ConfiguracionLiquidacionMasiva({
    required this.mes,
    required this.anio,
    this.empresaCuit,
    this.empleadosCuilsFiltro,
    this.provincia,
    this.categoria,
    this.sector,
    this.aplicarConceptosRecurrentes = true,
    this.generarRecibos = true,
    this.generarF931AlFinal = false,
  });
}

/// Callback de progreso
typedef ProgressCallback = void Function(int actual, int total, String mensaje);

/// Servicio de liquidación masiva
class LiquidacionMasivaService {
  /// Liquida múltiples empleados en paralelo
  static Future<ResultadoLiquidacionMasiva> liquidarMasivo({
    required ConfiguracionLiquidacionMasiva config,
    ProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();
    
    // 1. Obtener empleados a liquidar
    List<EmpleadoCompleto> empleados = await _obtenerEmpleados(config);
    
    if (empleados.isEmpty) {
      return ResultadoLiquidacionMasiva(
        totalEmpleados: 0,
        exitosos: 0,
        fallidos: 0,
        resultados: [],
        duracion: Duration.zero,
        masaSalarialTotal: 0,
        aportesTotal: 0,
        contribucionesTotal: 0,
      );
    }
    
    onProgress?.call(0, empleados.length, 'Iniciando liquidación masiva...');
    
    // 2. Procesar empleados
    final resultados = <ResultadoLiquidacionIndividual>[];
    int procesados = 0;
    
    // Procesar en chunks para no saturar
    const chunkSize = 10; // Procesar 10 a la vez
    
    for (int i = 0; i < empleados.length; i += chunkSize) {
      final chunk = empleados.skip(i).take(chunkSize).toList();
      
      // Procesar chunk en paralelo
      final futures = chunk.map((emp) async {
        return await _liquidarEmpleado(
          empleado: emp,
          config: config,
        );
      }).toList();
      
      final chunkResultados = await Future.wait(futures);
      resultados.addAll(chunkResultados);
      
      procesados += chunk.length;
      onProgress?.call(
        procesados,
        empleados.length,
        'Liquidando empleado $procesados/${empleados.length}...',
      );
      
      // Pequeña pausa para no saturar (opcional)
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // 3. Calcular totales
    final exitosos = resultados.where((r) => r.exito).length;
    final fallidos = resultados.where((r) => !r.exito).length;
    
    double masaSalarialTotal = 0;
    double aportesTotal = 0;
    double contribucionesTotal = 0;
    
    for (final res in resultados) {
      if (res.exito && res.resultado != null) {
        masaSalarialTotal += (res.resultado!['totalBruto'] as num?)?.toDouble() ?? 0.0;
        aportesTotal += (res.resultado!['totalAportes'] as num?)?.toDouble() ?? 0.0;
        contribucionesTotal += (res.resultado!['totalContribuciones'] as num?)?.toDouble() ?? 0.0;
      }
    }
    
    final duracion = DateTime.now().difference(startTime);
    
    onProgress?.call(
      empleados.length,
      empleados.length,
      'Liquidación masiva completada!',
    );
    
    // Registrar en auditoría
    await AuditoriaService.registrarLiquidacionMasiva(
      liquidacionId: 'liqmasiva_${config.mes}_${config.anio}_${DateTime.now().millisecondsSinceEpoch}',
      cantidadEmpleados: exitosos,
      masaSalarialTotal: masaSalarialTotal,
      usuario: 'Sistema',
      empresaCuit: config.empresaCuit,
    );
    
    return ResultadoLiquidacionMasiva(
      totalEmpleados: empleados.length,
      exitosos: exitosos,
      fallidos: fallidos,
      resultados: resultados,
      duracion: duracion,
      masaSalarialTotal: masaSalarialTotal,
      aportesTotal: aportesTotal,
      contribucionesTotal: contribucionesTotal,
    );
  }
  
  /// Obtiene empleados a liquidar según configuración
  static Future<List<EmpleadoCompleto>> _obtenerEmpleados(
    ConfiguracionLiquidacionMasiva config,
  ) async {
    List<EmpleadoCompleto> empleados;
    
    // Si hay filtro de CUILs específicos
    if (config.empleadosCuilsFiltro != null && config.empleadosCuilsFiltro!.isNotEmpty) {
      empleados = [];
      for (final cuil in config.empleadosCuilsFiltro!) {
        final emp = await EmpleadosService.obtenerEmpleadoPorCuil(
          cuil,
          empresaCuit: config.empresaCuit,
        );
        if (emp != null) empleados.add(emp);
      }
    } else {
      // Obtener todos los empleados activos
      empleados = await EmpleadosService.obtenerEmpleadosActivos(
        empresaCuit: config.empresaCuit,
      );
    }
    
    // Aplicar filtros adicionales
    if (config.provincia != null) {
      empleados = empleados.where((e) => e.provincia == config.provincia).toList();
    }
    
    if (config.categoria != null) {
      empleados = empleados.where((e) => e.categoria == config.categoria).toList();
    }
    
    if (config.sector != null) {
      empleados = empleados.where((e) => e.sector == config.sector).toList();
    }
    
    return empleados;
  }
  
  /// Liquida un empleado individual
  static Future<ResultadoLiquidacionIndividual> _liquidarEmpleado({
    required EmpleadoCompleto empleado,
    required ConfiguracionLiquidacionMasiva config,
  }) async {
    try {
      // 1. Obtener conceptos recurrentes si está habilitado
      List<ConceptoRecurrente> conceptos = [];
      if (config.aplicarConceptosRecurrentes) {
        conceptos = await ConceptosRecurrentesService.obtenerConceptosActivos(
          empleado.cuil,
          config.mes,
          config.anio,
        );
      }
      
      // 2. Calcular liquidación
      // NOTA: Aquí deberías llamar a tu motor de liquidación real
      // Por ahora, esto es un placeholder que deberás reemplazar con:
      // - SanidadOmniEngine si es sector sanidad
      // - TeacherOmniEngine si es sector docente
      // - Etc.
      
      final resultado = await _calcularLiquidacion(
        empleado: empleado,
        conceptos: conceptos,
        mes: config.mes,
        anio: config.anio,
      );
      
      // 3. VALIDACIONES LEGALES CRÍTICAS
      final embargos = conceptos
          .where((c) => c.tipo == 'embargo_judicial')
          .fold(0.0, (sum, c) => sum + c.valor);
      
      final cuotasAlimentarias = conceptos
          .where((c) => c.codigo.toLowerCase().contains('cuota_alimentaria'))
          .fold(0.0, (sum, c) => sum + c.valor);
      
      final validaciones = ValidacionesLegalesService.validarLiquidacionCompleta(
        nombreEmpleado: empleado.nombreCompleto,
        cuil: empleado.cuil,
        totalBruto: (resultado['totalBruto'] as num?)?.toDouble() ?? 0.0,
        totalDescuentos: (resultado['descuentos'] as num?)?.toDouble() ?? 0.0,
        embargosJudiciales: embargos,
        cuotasAlimentarias: cuotasAlimentarias,
        esEmpleadoDocente: empleado.sector?.toLowerCase() == 'docente',
      );
      
      final resumenValidaciones = ValidacionesLegalesService.obtenerResumenValidaciones(validaciones);
      
      // Si hay errores críticos, no procesar
      if (resumenValidaciones['tiene_errores'] == true) {
        return ResultadoLiquidacionIndividual(
          empleadoCuil: empleado.cuil,
          empleadoNombre: empleado.nombreCompleto,
          exito: false,
          error: (resumenValidaciones['errores'] as List).join(' | '),
        );
      }
      
      // 4. Guardar en historial
      final historial = HistorialLiquidacion(
        id: 'hist_${empleado.cuil}_${config.mes}_${config.anio}_${DateTime.now().millisecondsSinceEpoch}',
        empleadoCuil: empleado.cuil,
        empresaCuit: config.empresaCuit ?? '',
        mes: config.mes,
        anio: config.anio,
        periodo: '${config.mes.toString().padLeft(2, '0')}/${config.anio}',
        tipo: 'mensual',
        sector: empleado.sector,
        sueldoBasico: (resultado['basico'] as num?)?.toDouble() ?? 0.0,
        adicionalAntiguedad: (resultado['antiguedad'] as num?)?.toDouble() ?? 0.0,
        otrosHaberes: (resultado['conceptosRemunerativos'] as num?)?.toDouble() ?? 0.0,
        totalBrutoRemunerativo: (resultado['totalBruto'] as num?)?.toDouble() ?? 0.0,
        totalNoRemunerativo: (resultado['conceptosNoRemunerativos'] as num?)?.toDouble() ?? 0.0,
        totalAportes: (resultado['totalAportes'] as num?)?.toDouble() ?? 0.0,
        totalDescuentos: (resultado['descuentos'] as num?)?.toDouble() ?? 0.0,
        embargosJudiciales: embargos,
        cuotasAlimentarias: cuotasAlimentarias,
        totalContribuciones: (resultado['totalContribuciones'] as num?)?.toDouble() ?? 0.0,
        netoACobrar: (resultado['neto'] as num?)?.toDouble() ?? 0.0,
        antiguedadAnios: empleado.antiguedadAnios,
        provincia: empleado.provincia,
        categoria: empleado.categoria,
        tieneErrores: resumenValidaciones['tiene_errores'] ?? false,
        tieneAdvertencias: resumenValidaciones['tiene_advertencias'] ?? false,
        errores: (resumenValidaciones['errores'] as List?)?.cast<String>(),
        advertencias: (resumenValidaciones['advertencias'] as List?)?.cast<String>(),
        fechaLiquidacion: DateTime.now(),
        liquidadoPor: 'Sistema',
      );
      
      await HistorialLiquidacionesService.registrarLiquidacion(historial);
      
      // Agregar advertencias al resultado si las hay
      if (resumenValidaciones['tiene_advertencias'] == true) {
        resultado['advertencias'] = resumenValidaciones['advertencias'];
      }
      
      return ResultadoLiquidacionIndividual(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        exito: true,
        resultado: resultado,
      );
    } catch (e) {
      return ResultadoLiquidacionIndividual(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        exito: false,
        error: e.toString(),
      );
    }
  }
  
  /// Calcula la liquidación usando los motores reales (TeacherOmniEngine o SanidadOmniEngine)
  static Future<Map<String, dynamic>> _calcularLiquidacion({
    required EmpleadoCompleto empleado,
    required List<ConceptoRecurrente> conceptos,
    required int mes,
    required int anio,
  }) async {
    // Preparar conceptos propios desde conceptos recurrentes
    final conceptosPropios = conceptos.map((c) {
      return ConceptoPropioOmni(
        codigo: c.codigo,
        descripcion: c.nombre,
        monto: c.valor,
        esRemunerativo: c.categoria == 'remunerativo',
        esBonificable: true, // Asumimos que sí por defecto
        codigoAfip: '011000', // Código genérico
      );
    }).toList();
    
    // Deducciones adicionales (descuentos)
    final deduccionesAdicionales = <String, double>{};
    for (final concepto in conceptos) {
      if (concepto.categoria == 'descuento') {
        deduccionesAdicionales[concepto.codigo] = concepto.valor;
      }
    }
    
    final periodo = '$mes/$anio';
    final fechaPago = DateTime(anio, mes, 28).toIso8601String().split('T')[0];
    
    // MOTOR DOCENTE
    if (empleado.sector?.toLowerCase() == 'docente' || empleado.sector?.toLowerCase() == 'educacion') {
      try {
        // Parsear jurisdicción
        Jurisdiccion jurisdiccion = Jurisdiccion.neuquen; // Default
        try {
          jurisdiccion = Jurisdiccion.values.firstWhere(
            (j) => j.name.toLowerCase() == empleado.provincia.toLowerCase().replaceAll(' ', ''),
            orElse: () => Jurisdiccion.neuquen,
          );
        } catch (_) {}
        
        // Crear input para motor docente
        final inputDocente = DocenteOmniInput(
          nombre: empleado.nombreCompleto,
          cuil: empleado.cuil,
          jurisdiccion: jurisdiccion,
          tipoGestion: TipoGestion.privada, // Puedes leer de empleado.subsector si lo tienes
          cargoNomenclador: TipoNomenclador.maestroGrado, // Mapear desde empleado.categoria
          nivelEducativo: NivelEducativo.primario,
          fechaIngreso: empleado.fechaIngreso,
          cargasFamiliares: 0, // Puedes agregarlo a EmpleadoCompleto
          codigoRnos: empleado.codigoRnos,
          horasCatedra: 0, // Puedes agregarlo a EmpleadoCompleto si aplica
        );
        
        final resultado = TeacherOmniEngine.liquidar(
          inputDocente,
          periodo: periodo,
          fechaPago: fechaPago,
          cantidadCargos: 1,
          conceptosPropios: conceptosPropios,
          deduccionesAdicionales: deduccionesAdicionales,
        );
        
        // Calcular totales de aportes y contribuciones
        final totalAportes = resultado.aporteJubilacion + 
                            resultado.aporteObraSocial + 
                            resultado.aportePami;
        
        // Contribuciones (estimadas): ~23% del bruto
        final totalContribuciones = resultado.totalBrutoRemunerativo * 0.23;
        
        return {
          'basico': resultado.sueldoBasico,
          'antiguedad': resultado.adicionalAntiguedad,
          'conceptosRemunerativos': conceptosPropios.where((c) => c.esRemunerativo).fold(0.0, (sum, c) => sum + c.monto),
          'conceptosNoRemunerativos': resultado.totalNoRemunerativo,
          'totalBruto': resultado.totalBrutoRemunerativo,
          'totalAportes': totalAportes,
          'totalContribuciones': totalContribuciones,
          'descuentos': resultado.totalDescuentos,
          'neto': resultado.netoACobrar,
          'mes': mes,
          'anio': anio,
          'resultado_completo': resultado, // Para detalles
        };
      } catch (e) {
        throw Exception('Error en motor docente: $e');
      }
    }
    
    // MOTOR SANIDAD
    else if (empleado.sector?.toLowerCase() == 'sanidad' || empleado.sector?.toLowerCase() == 'salud') {
      try {
        // Mapear categoría de string a enum
        CategoriaSanidad categoriaSanidad = CategoriaSanidad.profesional;
        final catLower = empleado.categoria.toLowerCase();
        if (catLower.contains('enferm') || catLower.contains('medic') || catLower.contains('profesional')) {
          categoriaSanidad = CategoriaSanidad.profesional;
        } else if (catLower.contains('tecnic') || catLower.contains('auxil')) {
          categoriaSanidad = CategoriaSanidad.tecnico;
        } else if (catLower.contains('servicio') || catLower.contains('limpieza')) {
          categoriaSanidad = CategoriaSanidad.servicios;
        } else if (catLower.contains('admin')) {
          categoriaSanidad = CategoriaSanidad.administrativo;
        } else if (catLower.contains('maestranza')) {
          categoriaSanidad = CategoriaSanidad.maestranza;
        }
        
        // Convertir conceptos propios a formato de sanidad
        final conceptosPropiosSanidad = conceptosPropios.map((c) => {
          'codigo': c.codigo,
          'descripcion': c.descripcion,
          'monto': c.monto,
          'es_remunerativo': c.esRemunerativo,
          'codigo_afip': c.codigoAfip,
        }).toList();
        
        // Crear input para motor sanidad
        final inputSanidad = SanidadEmpleadoInput(
          nombre: empleado.nombreCompleto,
          cuil: empleado.cuil,
          fechaIngreso: empleado.fechaIngreso,
          categoria: categoriaSanidad,
          nivelTitulo: NivelTituloSanidad.tecnico,
          codigoRnos: empleado.codigoRnos,
          cantidadFamiliares: 0,
          conceptosPropios: conceptosPropiosSanidad,
          embargos: deduccionesAdicionales.values.fold(0.0, (sum, v) => sum + v),
        );
        
        final resultado = SanidadOmniEngine.liquidar(
          inputSanidad,
          periodo: periodo,
          fechaPago: fechaPago,
        );
        
        // Calcular totales de aportes y contribuciones
        final totalAportes = resultado.aporteJubilacion + 
                            resultado.aporteLey19032 + 
                            resultado.aporteObraSocial +
                            resultado.cuotaSindicalAtsa +
                            resultado.seguroSepelio +
                            resultado.aporteSolidarioFatsa;
        
        // Contribuciones (estimadas): ~23% del bruto
        final totalContribuciones = resultado.totalBrutoRemunerativo * 0.23;
        
        return {
          'basico': resultado.sueldoBasico,
          'antiguedad': resultado.adicionalAntiguedad,
          'conceptosRemunerativos': conceptosPropios.where((c) => c.esRemunerativo).fold(0.0, (sum, c) => sum + c.monto),
          'conceptosNoRemunerativos': resultado.totalNoRemunerativo,
          'totalBruto': resultado.totalBrutoRemunerativo,
          'totalAportes': totalAportes,
          'totalContribuciones': totalContribuciones,
          'descuentos': resultado.totalDescuentos,
          'neto': resultado.netoACobrar,
          'mes': mes,
          'anio': anio,
          'resultado_completo': resultado, // Para detalles
        };
      } catch (e) {
        throw Exception('Error en motor sanidad: $e');
      }
    }
    
    // FALLBACK: Motor genérico para otros sectores
    else {
      // Cálculo genérico básico
      double basico = 450000; // Básico genérico
      
      // Antigüedad
      final antiguedad = basico * 0.02 * empleado.antiguedadAnios; // 2% por año
      
      // Conceptos recurrentes
      double conceptosRemunerativos = 0;
      double conceptosNoRemunerativos = 0;
      double descuentos = 0;
      
      for (final concepto in conceptos) {
        if (concepto.categoria == 'remunerativo') {
          conceptosRemunerativos += concepto.valor;
        } else if (concepto.categoria == 'no_remunerativo') {
          conceptosNoRemunerativos += concepto.valor;
        } else if (concepto.categoria == 'descuento') {
          descuentos += concepto.valor;
        }
      }
      
      final totalBruto = basico + antiguedad + conceptosRemunerativos;
      final totalAportes = totalBruto * 0.17; // 17% aportes
      final totalContribuciones = totalBruto * 0.23; // 23% contribuciones
      final neto = totalBruto + conceptosNoRemunerativos - totalAportes - descuentos;
      
      return {
        'basico': basico,
        'antiguedad': antiguedad,
        'conceptosRemunerativos': conceptosRemunerativos,
        'conceptosNoRemunerativos': conceptosNoRemunerativos,
        'totalBruto': totalBruto,
        'totalAportes': totalAportes,
        'totalContribuciones': totalContribuciones,
        'descuentos': descuentos,
        'neto': neto,
        'mes': mes,
        'anio': anio,
      };
    }
  }
  
  /// Genera resumen en texto
  static String generarResumen(ResultadoLiquidacionMasiva resultado) {
    final sb = StringBuffer();
    
    sb.writeln('═══════════════════════════════════════════════════════════');
    sb.writeln('           LIQUIDACIÓN MASIVA - RESUMEN');
    sb.writeln('═══════════════════════════════════════════════════════════');
    sb.writeln();
    
    sb.writeln('📊 ESTADÍSTICAS:');
    sb.writeln('   Total empleados procesados: ${resultado.totalEmpleados}');
    sb.writeln('   ✅ Exitosos: ${resultado.exitosos} (${resultado.porcentajeExito.toStringAsFixed(1)}%)');
    sb.writeln('   ❌ Fallidos: ${resultado.fallidos}');
    sb.writeln('   ⏱️  Tiempo: ${resultado.duracion.inSeconds} segundos');
    sb.writeln();
    
    sb.writeln('💰 TOTALES:');
    sb.writeln('   Masa salarial: \$${resultado.masaSalarialTotal.toStringAsFixed(2)}');
    sb.writeln('   Aportes: \$${resultado.aportesTotal.toStringAsFixed(2)}');
    sb.writeln('   Contribuciones: \$${resultado.contribucionesTotal.toStringAsFixed(2)}');
    sb.writeln('   Costo empleador: \$${(resultado.masaSalarialTotal + resultado.contribucionesTotal).toStringAsFixed(2)}');
    sb.writeln();
    
    if (resultado.fallidos > 0) {
      sb.writeln('⚠️ EMPLEADOS CON ERRORES:');
      for (final res in resultado.resultados.where((r) => !r.exito)) {
        sb.writeln('   • ${res.empleadoNombre} (${res.empleadoCuil}): ${res.error}');
      }
      sb.writeln();
    }
    
    sb.writeln('═══════════════════════════════════════════════════════════');
    
    return sb.toString();
  }
}
