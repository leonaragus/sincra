// ========================================================================
// GENERADOR F931 (SICOSS)
// Genera el archivo de Declaración Jurada mensual para AFIP
// Formato posicional según especificaciones SICOSS
// ========================================================================

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/validaciones_arca.dart';
import 'hybrid_isar_stub.dart' as _local;

/// Registro de liquidación para F931 (simplificado)
class RegistroLiquidacionF931 {
  final String empleadoCuil;
  final String empleadoNombre;
  final String empleadoApellido;
  final double remuneracionBruta;
  final double aportesJubilacion;
  final double aportesObraSocial;
  final double aportesPami;
  final double aportesArt;
  final double contribucionesJubilacion;
  final double contribucionesObraSocial;
  final double contribucionesPami;
  final double contribucionesArt;
  final double contribucionesFNE; // Fondo Nacional de Empleo
  final String codigoRnos;
  final int modalidadContratacion; // 1=Permanente, 2=Temporario, etc
  
  RegistroLiquidacionF931({
    required this.empleadoCuil,
    required this.empleadoNombre,
    required this.empleadoApellido,
    required this.remuneracionBruta,
    required this.aportesJubilacion,
    required this.aportesObraSocial,
    required this.aportesPami,
    required this.aportesArt,
    required this.contribucionesJubilacion,
    required this.contribucionesObraSocial,
    required this.contribucionesPami,
    required this.contribucionesArt,
    required this.contribucionesFNE,
    required this.codigoRnos,
    this.modalidadContratacion = 1,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'empleado_cuil': empleadoCuil,
      'empleado_nombre': empleadoNombre,
      'empleado_apellido': empleadoApellido,
      'remuneracion_bruta': remuneracionBruta,
      'aportes_jubilacion': aportesJubilacion,
      'aportes_obra_social': aportesObraSocial,
      'aportes_pami': aportesPami,
      'aportes_art': aportesArt,
      'contribuciones_jubilacion': contribucionesJubilacion,
      'contribuciones_obra_social': contribucionesObraSocial,
      'contribuciones_pami': contribucionesPami,
      'contribuciones_art': contribucionesArt,
      'contribuciones_fne': contribucionesFNE,
      'codigo_rnos': codigoRnos,
      'modalidad_contratacion': modalidadContratacion,
    };
  }
  
  factory RegistroLiquidacionF931.fromMap(Map<String, dynamic> map) {
    return RegistroLiquidacionF931(
      empleadoCuil: map['empleado_cuil']?.toString() ?? '',
      empleadoNombre: map['empleado_nombre']?.toString() ?? '',
      empleadoApellido: map['empleado_apellido']?.toString() ?? '',
      remuneracionBruta: (map['remuneracion_bruta'] as num?)?.toDouble() ?? 0.0,
      aportesJubilacion: (map['aportes_jubilacion'] as num?)?.toDouble() ?? 0.0,
      aportesObraSocial: (map['aportes_obra_social'] as num?)?.toDouble() ?? 0.0,
      aportesPami: (map['aportes_pami'] as num?)?.toDouble() ?? 0.0,
      aportesArt: (map['aportes_art'] as num?)?.toDouble() ?? 0.0,
      contribucionesJubilacion: (map['contribuciones_jubilacion'] as num?)?.toDouble() ?? 0.0,
      contribucionesObraSocial: (map['contribuciones_obra_social'] as num?)?.toDouble() ?? 0.0,
      contribucionesPami: (map['contribuciones_pami'] as num?)?.toDouble() ?? 0.0,
      contribucionesArt: (map['contribuciones_art'] as num?)?.toDouble() ?? 0.0,
      contribucionesFNE: (map['contribuciones_fne'] as num?)?.toDouble() ?? 0.0,
      codigoRnos: map['codigo_rnos']?.toString() ?? '',
      modalidadContratacion: (map['modalidad_contratacion'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Resultado de generación F931
class ResultadoF931 {
  final bool exito;
  final String contenidoArchivo;
  final List<String> errores;
  final List<String> advertencias;
  final Map<String, dynamic> resumen;
  
  ResultadoF931({
    required this.exito,
    required this.contenidoArchivo,
    required this.errores,
    required this.advertencias,
    required this.resumen,
  });
}

/// Servicio generador F931
class F931GeneratorService {
  static const String _tF931Historial = 'f931_historial';
  
  /// Genera archivo F931 a partir de liquidaciones del mes
  static ResultadoF931 generarF931({
    required String cuitEmpleador,
    required String razonSocial,
    required int mes,
    required int anio,
    required List<RegistroLiquidacionF931> liquidaciones,
  }) {
    final errores = <String>[];
    final advertencias = <String>[];
    
    // Validaciones previas
    if (!ValidacionesARCA.validarCUIL(cuitEmpleador)) {
      errores.add('CUIT empleador inválido: $cuitEmpleador');
    }
    
    if (liquidaciones.isEmpty) {
      errores.add('No hay liquidaciones para el período $mes/$anio');
    }
    
    if (mes < 1 || mes > 12) {
      errores.add('Mes inválido: $mes');
    }
    
    if (anio < 2000 || anio > 2100) {
      errores.add('Año inválido: $anio');
    }
    
    // Si hay errores críticos, devolver resultado fallido
    if (errores.isNotEmpty) {
      return ResultadoF931(
        exito: false,
        contenidoArchivo: '',
        errores: errores,
        advertencias: advertencias,
        resumen: {},
      );
    }
    
    // Validar cada liquidación
    for (final liq in liquidaciones) {
      if (!ValidacionesARCA.validarCUIL(liq.empleadoCuil)) {
        errores.add('CUIL inválido: ${liq.empleadoCuil} (${liq.empleadoApellido})');
      }
      
      if (liq.remuneracionBruta < 0) {
        errores.add('Remuneración negativa: ${liq.empleadoApellido}');
      }
      
      if (liq.codigoRnos.length != 6) {
        advertencias.add('Código RNOS inválido (debe ser 6 dígitos): ${liq.empleadoApellido}');
      }
    }
    
    // Si hay errores después de validar liquidaciones, devolver resultado fallido
    if (errores.isNotEmpty) {
      return ResultadoF931(
        exito: false,
        contenidoArchivo: '',
        errores: errores,
        advertencias: advertencias,
        resumen: {},
      );
    }
    
    // Generar contenido del archivo
    final contenido = StringBuffer();
    
    // ===============================================
    // REGISTRO TIPO 1: HEADER (Cabecera)
    // ===============================================
    final cuitLimpio = cuitEmpleador.replaceAll(RegExp(r'[^\d]'), '');
    final periodo = '${anio.toString().padLeft(4, '0')}${mes.toString().padLeft(2, '0')}';
    
    contenido.writeln(_generarRegistroTipo1(
      cuitEmpleador: cuitLimpio,
      periodo: periodo,
      cantidadEmpleados: liquidaciones.length,
    ));
    
    // ===============================================
    // REGISTRO TIPO 2: EMPLEADOS (uno por empleado)
    // ===============================================
    for (final liq in liquidaciones) {
      contenido.writeln(_generarRegistroTipo2(liq));
    }
    
    // ===============================================
    // REGISTRO TIPO 3: TOTALES Y CONTROL
    // ===============================================
    final totales = _calcularTotales(liquidaciones);
    contenido.writeln(_generarRegistroTipo3(
      cuitEmpleador: cuitLimpio,
      periodo: periodo,
      totales: totales,
    ));
    
    // Calcular resumen
    final resumen = {
      'cuit_empleador': cuitEmpleador,
      'periodo': '$mes/$anio',
      'cantidad_empleados': liquidaciones.length,
      'total_remuneraciones': totales['totalRemuneraciones'],
      'total_aportes': totales['totalAportes'],
      'total_contribuciones': totales['totalContribuciones'],
      'errores': errores.length,
      'advertencias': advertencias.length,
    };
    
    return ResultadoF931(
      exito: true,
      contenidoArchivo: contenido.toString(),
      errores: errores,
      advertencias: advertencias,
      resumen: resumen,
    );
  }
  
  /// Genera registro tipo 1 (Header)
  static String _generarRegistroTipo1({
    required String cuitEmpleador,
    required String periodo,
    required int cantidadEmpleados,
  }) {
    // Formato posicional F931 - Registro Tipo 1
    // Posición 1-2: Tipo registro ("01")
    // Posición 3-13: CUIT empleador (11 dígitos)
    // Posición 14-19: Período AAAAMM (6 dígitos)
    // Posición 20-25: Cantidad empleados (6 dígitos, right-aligned)
    // Posición 26-100: Reservado (espacios)
    
    final sb = StringBuffer();
    sb.write('01'); // Tipo registro
    sb.write(cuitEmpleador.padLeft(11, '0')); // CUIT
    sb.write(periodo); // Período
    sb.write(cantidadEmpleados.toString().padLeft(6, '0')); // Cantidad
    sb.write(''.padRight(75, ' ')); // Reservado
    
    return sb.toString();
  }
  
  /// Genera registro tipo 2 (Empleado)
  static String _generarRegistroTipo2(RegistroLiquidacionF931 liq) {
    // Formato posicional F931 - Registro Tipo 2
    // Posición 1-2: Tipo registro ("02")
    // Posición 3-13: CUIL empleado (11 dígitos)
    // Posición 14-43: Apellido empleado (30 caracteres, left-aligned)
    // Posición 44-63: Nombre empleado (20 caracteres, left-aligned)
    // Posición 64-75: Remuneración bruta (12 dígitos, 2 decimales, sin punto/coma)
    // Posición 76-87: Aportes jubilación (12 dígitos, 2 decimales)
    // Posición 88-99: Aportes obra social (12 dígitos, 2 decimales)
    // Posición 100-111: Aportes PAMI (12 dígitos, 2 decimales)
    // Posición 112-123: Contribuciones jubilación (12 dígitos, 2 decimales)
    // Posición 124-135: Contribuciones obra social (12 dígitos, 2 decimales)
    // Posición 136-147: Contribuciones PAMI (12 dígitos, 2 decimales)
    // Posición 148-159: Contribuciones ART (12 dígitos, 2 decimales)
    // Posición 160-171: Contribuciones FNE (12 dígitos, 2 decimales)
    // Posición 172-177: Código obra social RNOS (6 dígitos)
    // Posición 178-178: Modalidad contratación (1 dígito)
    // Posición 179-250: Reservado
    
    final cuilLimpio = liq.empleadoCuil.replaceAll(RegExp(r'[^\d]'), '');
    
    final sb = StringBuffer();
    sb.write('02'); // Tipo registro
    sb.write(cuilLimpio.padLeft(11, '0')); // CUIL
    sb.write(_padLeft(liq.empleadoApellido, 30)); // Apellido
    sb.write(_padLeft(liq.empleadoNombre, 20)); // Nombre
    sb.write(_formatMonto(liq.remuneracionBruta)); // Remuneración
    sb.write(_formatMonto(liq.aportesJubilacion)); // Aportes jubilación
    sb.write(_formatMonto(liq.aportesObraSocial)); // Aportes OS
    sb.write(_formatMonto(liq.aportesPami)); // Aportes PAMI
    sb.write(_formatMonto(liq.contribucionesJubilacion)); // Contrib jubilación
    sb.write(_formatMonto(liq.contribucionesObraSocial)); // Contrib OS
    sb.write(_formatMonto(liq.contribucionesPami)); // Contrib PAMI
    sb.write(_formatMonto(liq.contribucionesArt)); // Contrib ART
    sb.write(_formatMonto(liq.contribucionesFNE)); // Contrib FNE
    sb.write(liq.codigoRnos.padLeft(6, '0')); // RNOS
    sb.write(liq.modalidadContratacion.toString()); // Modalidad
    sb.write(''.padRight(72, ' ')); // Reservado
    
    return sb.toString();
  }
  
  /// Genera registro tipo 3 (Totales y control)
  static String _generarRegistroTipo3({
    required String cuitEmpleador,
    required String periodo,
    required Map<String, double> totales,
  }) {
    // Formato posicional F931 - Registro Tipo 3
    // Similar al tipo 1 pero con totales de control
    
    final sb = StringBuffer();
    sb.write('03'); // Tipo registro
    sb.write(cuitEmpleador.padLeft(11, '0')); // CUIT
    sb.write(periodo); // Período
    sb.write(_formatMonto(totales['totalRemuneraciones']!)); // Total remuneraciones
    sb.write(_formatMonto(totales['totalAportes']!)); // Total aportes
    sb.write(_formatMonto(totales['totalContribuciones']!)); // Total contribuciones
    sb.write(''.padRight(50, ' ')); // Reservado
    
    return sb.toString();
  }
  
  /// Calcula totales para registro tipo 3
  static Map<String, double> _calcularTotales(List<RegistroLiquidacionF931> liquidaciones) {
    double totalRemuneraciones = 0;
    double totalAportes = 0;
    double totalContribuciones = 0;
    
    for (final liq in liquidaciones) {
      totalRemuneraciones += liq.remuneracionBruta;
      totalAportes += liq.aportesJubilacion + 
                      liq.aportesObraSocial + 
                      liq.aportesPami;
      totalContribuciones += liq.contribucionesJubilacion + 
                             liq.contribucionesObraSocial + 
                             liq.contribucionesPami + 
                             liq.contribucionesArt + 
                             liq.contribucionesFNE;
    }
    
    return {
      'totalRemuneraciones': totalRemuneraciones,
      'totalAportes': totalAportes,
      'totalContribuciones': totalContribuciones,
    };
  }
  
  /// Formatea monto a 12 dígitos con 2 decimales (sin punto/coma)
  static String _formatMonto(double monto) {
    final montoInt = (monto * 100).round(); // Convertir a centavos
    return montoInt.toString().padLeft(12, '0');
  }
  
  /// Pad left para strings (agrega espacios a la derecha)
  static String _padLeft(String texto, int longitud) {
    if (texto.length >= longitud) {
      return texto.substring(0, longitud);
    }
    return texto.padRight(longitud, ' ');
  }
  
  // ========================================================================
  // HISTORIAL DE F931 GENERADOS
  // ========================================================================
  
  /// Guarda un F931 generado en el historial
  static Future<void> guardarEnHistorial({
    required String empresaCuit,
    required int mes,
    required int anio,
    required ResultadoF931 resultado,
    String? generadoPor,
  }) async {
    final historial = await _obtenerHistorial(empresaCuit);
    
    final registro = {
      'id': '${empresaCuit}_${anio}_${mes}',
      'empresa_cuit': empresaCuit,
      'periodo_mes': mes,
      'periodo_anio': anio,
      'cantidad_empleados': resultado.resumen['cantidad_empleados'],
      'total_remuneraciones': resultado.resumen['total_remuneraciones'],
      'total_aportes': resultado.resumen['total_aportes'],
      'total_contribuciones': resultado.resumen['total_contribuciones'],
      'contenido_archivo': resultado.contenidoArchivo,
      'generado_por': generadoPor,
      'fecha_generacion': DateTime.now().toIso8601String(),
    };
    
    // Actualizar o agregar
    final index = historial.indexWhere((h) => h['id'] == registro['id']);
    if (index >= 0) {
      historial[index] = registro;
    } else {
      historial.add(registro);
    }
    
    // Guardar localmente
    await _local.localPut(_tF931Historial, empresaCuit, jsonEncode(historial));
    
    // Sincronizar con Supabase
    _pushHistorialToSupabase(registro);
  }
  
  /// Obtiene historial de F931 generados
  static Future<List<Map<String, dynamic>>> _obtenerHistorial(String empresaCuit) async {
    final s = await _local.localGet(_tF931Historial, empresaCuit);
    if (s == null || s.isEmpty) return [];
    
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }
  
  /// Obtiene un F931 del historial
  static Future<Map<String, dynamic>?> obtenerF931Historial(
    String empresaCuit,
    int mes,
    int anio,
  ) async {
    final historial = await _obtenerHistorial(empresaCuit);
    final id = '${empresaCuit}_${anio}_${mes}';
    
    try {
      return historial.firstWhere((h) => h['id'] == id);
    } catch (_) {
      return null;
    }
  }
  
  static void _pushHistorialToSupabase(Map<String, dynamic> registro) {
    _runAsync(() async {
      final connectivityList = await Connectivity().checkConnectivity();
      if (connectivityList.isEmpty || 
          connectivityList.every((c) => c == ConnectivityResult.none)) {
        return;
      }
      
      try {
        await Supabase.instance.client
            .from('f931_historial')
            .upsert(registro, onConflict: 'id');
      } catch (e) {
        print('Error sincronizando F931 a Supabase: $e');
      }
    });
  }
  
  static void _runAsync(Future<void> Function() fn) {
    fn().catchError((_) {});
  }
}
