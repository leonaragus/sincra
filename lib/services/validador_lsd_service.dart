// ========================================================================
// VALIDADOR PRE-EXPORTACIÓN LSD (ARCA 2026)
// Suite completa de validaciones antes de generar el archivo LSD
// Previene rechazos de ARCA/AFIP
// ========================================================================

import '../models/empleado_completo.dart';
import 'validaciones_arca_service.dart';

class ResultadoValidacion {
  final String empleadoCuil;
  final String empleadoNombre;
  final String campo;
  final String tipo; // 'error' o 'advertencia'
  final String mensaje;
  
  ResultadoValidacion({
    required this.empleadoCuil,
    required this.empleadoNombre,
    required this.campo,
    required this.tipo,
    required this.mensaje,
  });
  
  bool get esError => tipo == 'error';
  bool get esAdvertencia => tipo == 'advertencia';
}

class ReporteValidacionLSD {
  final int totalEmpleados;
  final int empleadosValidos;
  final int empleadosConErrores;
  final int empleadosConAdvertencias;
  final List<ResultadoValidacion> errores;
  final List<ResultadoValidacion> advertencias;
  final bool aptoParaExportar;
  final DateTime fechaValidacion;
  
  ReporteValidacionLSD({
    required this.totalEmpleados,
    required this.empleadosValidos,
    required this.empleadosConErrores,
    required this.empleadosConAdvertencias,
    required this.errores,
    required this.advertencias,
    required this.aptoParaExportar,
    required this.fechaValidacion,
  });
  
  double get porcentajeValidos => 
      totalEmpleados == 0 ? 0.0 : (empleadosValidos / totalEmpleados) * 100;
}

class ValidadorLSDService {
  /// Valida una lista de empleados antes de exportar a LSD
  static ReporteValidacionLSD validarParaExportacion(
    List<EmpleadoCompleto> empleados,
    {bool strictMode = true}
  ) {
    final errores = <ResultadoValidacion>[];
    final advertencias = <ResultadoValidacion>[];
    final empleadosConError = <String>{};
    final empleadosConAdvertencia = <String>{};
    
    for (final empleado in empleados) {
      final validaciones = _validarEmpleado(empleado, strictMode: strictMode);
      
      for (final validacion in validaciones) {
        if (validacion.esError) {
          errores.add(validacion);
          empleadosConError.add(empleado.cuil);
        } else {
          advertencias.add(validacion);
          empleadosConAdvertencia.add(empleado.cuil);
        }
      }
    }
    
    final empleadosValidos = empleados.length - empleadosConError.length;
    
    return ReporteValidacionLSD(
      totalEmpleados: empleados.length,
      empleadosValidos: empleadosValidos,
      empleadosConErrores: empleadosConError.length,
      empleadosConAdvertencias: empleadosConAdvertencia.length,
      errores: errores,
      advertencias: advertencias,
      aptoParaExportar: errores.isEmpty,
      fechaValidacion: DateTime.now(),
    );
  }
  
  /// Valida un empleado individual
  static List<ResultadoValidacion> _validarEmpleado(
    EmpleadoCompleto empleado,
    {bool strictMode = true}
  ) {
    final validaciones = <ResultadoValidacion>[];
    
    // 1. VALIDAR CUIL (CRÍTICO)
    final validCuil = ValidacionesARCAService.validarCUIL(empleado.cuil);
    if (!validCuil.esValido) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'CUIL',
        tipo: 'error',
        mensaje: 'CUIL inválido: ${validCuil.error}',
      ));
    }
    
    // 2. VALIDAR NOMBRE COMPLETO (CRÍTICO)
    if (empleado.nombreCompleto.isEmpty || empleado.nombreCompleto.length < 3) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'Nombre Completo',
        tipo: 'error',
        mensaje: 'Nombre completo vacío o muy corto',
      ));
    }
    
    // 3. VALIDAR FECHA DE INGRESO (CRÍTICO)
    if (empleado.fechaIngreso.isAfter(DateTime.now())) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'Fecha Ingreso',
        tipo: 'error',
        mensaje: 'Fecha de ingreso futura: ${empleado.fechaIngreso.toString().split(' ')[0]}',
      ));
    }
    
    final antiguedadDias = DateTime.now().difference(empleado.fechaIngreso).inDays;
    if (antiguedadDias < 0) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'Antigüedad',
        tipo: 'error',
        mensaje: 'Antigüedad negativa',
      ));
    }
    
    // 4. VALIDAR PROVINCIA (CRÍTICO)
    if (empleado.provincia == null || empleado.provincia!.isEmpty) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'Provincia',
        tipo: 'error',
        mensaje: 'Provincia no especificada',
      ));
    }
    
    // 5. VALIDAR CBU (CRÍTICO SI TIENE)
    if (empleado.cbu != null && empleado.cbu!.isNotEmpty) {
      final validCbu = ValidacionesARCAService.validarCBU(empleado.cbu);
      if (!validCbu.esValido) {
        validaciones.add(ResultadoValidacion(
          empleadoCuil: empleado.cuil,
          empleadoNombre: empleado.nombreCompleto,
          campo: 'CBU',
          tipo: 'error',
          mensaje: 'CBU inválido: ${validCbu.error}',
        ));
      }
    } else if (strictMode) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'CBU',
        tipo: 'advertencia',
        mensaje: 'CBU no especificado (obligatorio para pago electrónico)',
      ));
    }
    
    // 6. VALIDAR CÓDIGO RNOS (CRÍTICO)
    if (empleado.codigoRnos == null || empleado.codigoRnos!.isEmpty) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'RNOS',
        tipo: 'error',
        mensaje: 'Código RNOS no especificado (obligatorio para aportes)',
      ));
    } else {
      final validRnos = ValidacionesARCAService.validarRNOS(empleado.codigoRnos);
      if (!validRnos.esValido) {
        validaciones.add(ResultadoValidacion(
          empleadoCuil: empleado.cuil,
          empleadoNombre: empleado.nombreCompleto,
          campo: 'RNOS',
          tipo: 'error',
          mensaje: 'Código RNOS inválido: ${validRnos.error}',
        ));
      }
    }
    
    // 7. VALIDAR CATEGORÍA (CRÍTICO)
    if (empleado.categoria == null || empleado.categoria!.isEmpty) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'Categoría',
        tipo: 'error',
        mensaje: 'Categoría no especificada',
      ));
    }
    
    // 8. VALIDAR SECTOR (ADVERTENCIA)
    if (empleado.sector == null || empleado.sector!.isEmpty) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'Sector',
        tipo: 'advertencia',
        mensaje: 'Sector no especificado (recomendado para correcta liquidación)',
      ));
    }
    
    // 9. VALIDAR DOMICILIO (ADVERTENCIA EN STRICT MODE)
    final domicilio = empleado.domicilio ?? '';
    if (strictMode && domicilio.isEmpty) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'Domicilio',
        tipo: 'advertencia',
        mensaje: 'Domicilio no especificado',
      ));
    }
    
    // 10. VALIDAR CÓDIGO POSTAL (ADVERTENCIA SI TIENE DOMICILIO)
    if (domicilio.isNotEmpty) {
      final cp = empleado.codigoPostal ?? '';
      if (cp.isEmpty) {
        validaciones.add(ResultadoValidacion(
          empleadoCuil: empleado.cuil,
          empleadoNombre: empleado.nombreCompleto,
          campo: 'Código Postal',
          tipo: 'advertencia',
          mensaje: 'Código postal no especificado',
        ));
      } else {
        final validCP = ValidacionesARCAService.validarCodigoPostal(empleado.codigoPostal);
        if (!validCP.esValido) {
          validaciones.add(ResultadoValidacion(
            empleadoCuil: empleado.cuil,
            empleadoNombre: empleado.nombreCompleto,
            campo: 'Código Postal',
            tipo: 'advertencia',
            mensaje: 'Código postal inválido: ${validCP.error}',
          ));
        }
      }
    }
    
    // 11. VALIDAR EMAIL (ADVERTENCIA EN STRICT MODE)
    final email = empleado.email ?? '';
    if (strictMode && email.isNotEmpty) {
      final validEmail = ValidacionesARCAService.validarEmail(empleado.email);
      if (!validEmail.esValido) {
        validaciones.add(ResultadoValidacion(
          empleadoCuil: empleado.cuil,
          empleadoNombre: empleado.nombreCompleto,
          campo: 'Email',
          tipo: 'advertencia',
          mensaje: 'Email inválido: ${validEmail.error}',
        ));
      }
    }
    
    // 12. VALIDAR TELÉFONO (ADVERTENCIA EN STRICT MODE)
    final telefono = empleado.telefono ?? '';
    if (strictMode && telefono.isNotEmpty) {
      final validTel = ValidacionesARCAService.validarTelefono(empleado.telefono);
      if (!validTel.esValido) {
        validaciones.add(ResultadoValidacion(
          empleadoCuil: empleado.cuil,
          empleadoNombre: empleado.nombreCompleto,
          campo: 'Teléfono',
          tipo: 'advertencia',
          mensaje: 'Teléfono inválido: ${validTel.error}',
        ));
      }
    }
    
    // 13. VALIDAR FECHA DE NACIMIENTO (ADVERTENCIA)
    if (empleado.fechaNacimiento != null) {
      final edad = DateTime.now().difference(empleado.fechaNacimiento!).inDays ~/ 365;
      
      if (edad < 16) {
        validaciones.add(ResultadoValidacion(
          empleadoCuil: empleado.cuil,
          empleadoNombre: empleado.nombreCompleto,
          campo: 'Fecha Nacimiento',
          tipo: 'error',
          mensaje: 'Empleado menor de 16 años (edad: $edad)',
        ));
      } else if (edad > 80) {
        validaciones.add(ResultadoValidacion(
          empleadoCuil: empleado.cuil,
          empleadoNombre: empleado.nombreCompleto,
          campo: 'Fecha Nacimiento',
          tipo: 'advertencia',
          mensaje: 'Empleado mayor de 80 años (edad: $edad)',
        ));
      }
    }
    
    // 14. VALIDAR MODALIDAD CONTRATACIÓN (ADVERTENCIA)
    if (empleado.modalidadContratacion == null || empleado.modalidadContratacion! <= 0) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'Modalidad Contratación',
        tipo: 'advertencia',
        mensaje: 'Modalidad de contratación no especificada',
      ));
    }
    
    // 15. VALIDAR CCT (ADVERTENCIA)
    if (empleado.cctCodigo == null || empleado.cctCodigo!.isEmpty) {
      validaciones.add(ResultadoValidacion(
        empleadoCuil: empleado.cuil,
        empleadoNombre: empleado.nombreCompleto,
        campo: 'CCT',
        tipo: 'advertencia',
        mensaje: 'CCT no especificado',
      ));
    }
    
    return validaciones;
  }
  
  /// Genera reporte de validación en texto plano
  static String generarReporteTexto(ReporteValidacionLSD reporte) {
    final buffer = StringBuffer();
    
    buffer.writeln('╔════════════════════════════════════════════════════════════╗');
    buffer.writeln('║  REPORTE DE VALIDACIÓN PRE-EXPORTACIÓN LSD (ARCA 2026)  ║');
    buffer.writeln('╚════════════════════════════════════════════════════════════╝');
    buffer.writeln('');
    buffer.writeln('Fecha: ${reporte.fechaValidacion.toString().split('.')[0]}');
    buffer.writeln('');
    buffer.writeln('═══ RESUMEN ═══');
    buffer.writeln('Total empleados:          ${reporte.totalEmpleados}');
    buffer.writeln('Empleados válidos:        ${reporte.empleadosValidos} (${reporte.porcentajeValidos.toStringAsFixed(1)}%)');
    buffer.writeln('Con errores:              ${reporte.empleadosConErrores}');
    buffer.writeln('Con advertencias:         ${reporte.empleadosConAdvertencias}');
    buffer.writeln('');
    buffer.writeln('Estado: ${reporte.aptoParaExportar ? "✅ APTO PARA EXPORTAR" : "❌ NO APTO - CORREGIR ERRORES"}');
    buffer.writeln('');
    
    if (reporte.errores.isNotEmpty) {
      buffer.writeln('═══ ERRORES CRÍTICOS (${reporte.errores.length}) ═══');
      buffer.writeln('');
      
      for (final error in reporte.errores) {
        buffer.writeln('❌ ${error.empleadoNombre} (${error.empleadoCuil})');
        buffer.writeln('   Campo: ${error.campo}');
        buffer.writeln('   Error: ${error.mensaje}');
        buffer.writeln('');
      }
    }
    
    if (reporte.advertencias.isNotEmpty) {
      buffer.writeln('═══ ADVERTENCIAS (${reporte.advertencias.length}) ═══');
      buffer.writeln('');
      
      for (final adv in reporte.advertencias) {
        buffer.writeln('⚠️  ${adv.empleadoNombre} (${adv.empleadoCuil})');
        buffer.writeln('   Campo: ${adv.campo}');
        buffer.writeln('   Advertencia: ${adv.mensaje}');
        buffer.writeln('');
      }
    }
    
    if (reporte.aptoParaExportar) {
      buffer.writeln('═══════════════════════════════════════════════════════════');
      buffer.writeln('✅ TODOS LOS EMPLEADOS PASARON LA VALIDACIÓN');
      buffer.writeln('   Puede proceder con la exportación del archivo LSD');
      buffer.writeln('═══════════════════════════════════════════════════════════');
    } else {
      buffer.writeln('═══════════════════════════════════════════════════════════');
      buffer.writeln('❌ HAY ERRORES QUE DEBEN CORREGIRSE');
      buffer.writeln('   No puede exportar hasta corregir todos los errores');
      buffer.writeln('═══════════════════════════════════════════════════════════');
    }
    
    return buffer.toString();
  }
}
