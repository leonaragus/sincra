// ========================================================================
// SERVICIO DE VALIDACIONES LEGALES
// Validaciones críticas de compliance legal argentino
// ========================================================================

class ValidacionLegal {
  final bool esValido;
  final String? advertencia;
  final String? error;
  final double? valorSugerido;
  
  ValidacionLegal({
    required this.esValido,
    this.advertencia,
    this.error,
    this.valorSugerido,
  });
  
  factory ValidacionLegal.valido() {
    return ValidacionLegal(esValido: true);
  }
  
  factory ValidacionLegal.advertencia(String mensaje, {double? valorSugerido}) {
    return ValidacionLegal(
      esValido: true,
      advertencia: mensaje,
      valorSugerido: valorSugerido,
    );
  }
  
  factory ValidacionLegal.error(String mensaje, {double? valorSugerido}) {
    return ValidacionLegal(
      esValido: false,
      error: mensaje,
      valorSugerido: valorSugerido,
    );
  }
}

class ValidacionesLegalesService {
  /// Límite legal de embargos: 20% del neto (Ley de Contrato de Trabajo Art. 120)
  static const double LIMITE_EMBARGO_PCT = 20.0;
  
  /// Valida que los embargos no superen el 20% del neto
  /// 
  /// Base legal: Art. 120 LCT - Los embargos sobre sueldos no pueden exceder el 20%
  /// del sueldo neto, salvo por cuotas alimentarias (hasta 50%).
  static ValidacionLegal validarLimiteEmbargos({
    required double totalBruto,
    required double totalDescuentos,
    required double embargosJudiciales,
    required double cuotasAlimentarias,
    bool esEmpleadoDocente = false,
  }) {
    // Calcular neto antes de embargos
    final netoSinEmbargos = totalBruto - (totalDescuentos - embargosJudiciales - cuotasAlimentarias);
    
    if (netoSinEmbargos <= 0) {
      return ValidacionLegal.error(
        'El neto sin embargos es negativo o cero. No se pueden aplicar embargos.',
      );
    }
    
    // Calcular límites
    final limiteEmbargosComunes = netoSinEmbargos * (LIMITE_EMBARGO_PCT / 100);
    final limiteCuotasAlimentarias = netoSinEmbargos * 0.50; // Hasta 50%
    
    // Validar embargos comunes (excluye cuotas alimentarias)
    if (embargosJudiciales > limiteEmbargosComunes) {
      return ValidacionLegal.error(
        'ILEGAL: Los embargos judiciales (\$${embargosJudiciales.toStringAsFixed(2)}) '
        'superan el límite legal del 20% del neto (\$${limiteEmbargosComunes.toStringAsFixed(2)}). '
        'Art. 120 LCT.',
        valorSugerido: limiteEmbargosComunes,
      );
    }
    
    // Validar cuotas alimentarias (hasta 50%)
    if (cuotasAlimentarias > limiteCuotasAlimentarias) {
      return ValidacionLegal.advertencia(
        'ATENCIÓN: Las cuotas alimentarias (\$${cuotasAlimentarias.toStringAsFixed(2)}) '
        'superan el 50% del neto (\$${limiteCuotasAlimentarias.toStringAsFixed(2)}). '
        'Verificar orden judicial.',
        valorSugerido: limiteCuotasAlimentarias,
      );
    }
    
    // Si está cerca del límite (>15%), advertir
    final porcentajeActual = (embargosJudiciales / netoSinEmbargos) * 100;
    if (porcentajeActual > 15.0 && porcentajeActual <= LIMITE_EMBARGO_PCT) {
      return ValidacionLegal.advertencia(
        'Los embargos representan el ${porcentajeActual.toStringAsFixed(1)}% del neto. '
        'Está cerca del límite legal del 20%.',
      );
    }
    
    return ValidacionLegal.valido();
  }
  
  /// Valida que el neto a cobrar sea positivo
  /// 
  /// Si el neto es negativo o cero, indica un error en la configuración
  /// de conceptos o descuentos.
  static ValidacionLegal validarNetoPositivo({
    required double totalBruto,
    required double totalDescuentos,
    required String nombreEmpleado,
    required String cuil,
  }) {
    final neto = totalBruto - totalDescuentos;
    
    if (neto < 0) {
      return ValidacionLegal.error(
        'ERROR CRÍTICO: ${nombreEmpleado} (${cuil}) tiene neto NEGATIVO (\$${neto.toStringAsFixed(2)}). '
        'Los descuentos (\$${totalDescuentos.toStringAsFixed(2)}) superan los haberes (\$${totalBruto.toStringAsFixed(2)}). '
        'Revisar conceptos y descuentos.',
      );
    }
    
    if (neto == 0) {
      return ValidacionLegal.advertencia(
        'ATENCIÓN: ${nombreEmpleado} (${cuil}) tiene neto CERO. '
        'Los descuentos equivalen exactamente a los haberes. Verificar si es correcto.',
      );
    }
    
    // Si el neto es muy bajo (< 10% del bruto), advertir
    final porcentajeNeto = (neto / totalBruto) * 100;
    if (porcentajeNeto < 10.0) {
      return ValidacionLegal.advertencia(
        'ATENCIÓN: ${nombreEmpleado} (${cuil}) tiene un neto muy bajo (${porcentajeNeto.toStringAsFixed(1)}% del bruto). '
        'Neto: \$${neto.toStringAsFixed(2)}. Verificar descuentos.',
      );
    }
    
    return ValidacionLegal.valido();
  }
  
  /// Valida múltiples aspectos legales de una liquidación
  static List<ValidacionLegal> validarLiquidacionCompleta({
    required String nombreEmpleado,
    required String cuil,
    required double totalBruto,
    required double totalDescuentos,
    required double embargosJudiciales,
    required double cuotasAlimentarias,
    bool esEmpleadoDocente = false,
  }) {
    final validaciones = <ValidacionLegal>[];
    
    // 1. Validar neto positivo
    validaciones.add(validarNetoPositivo(
      totalBruto: totalBruto,
      totalDescuentos: totalDescuentos,
      nombreEmpleado: nombreEmpleado,
      cuil: cuil,
    ));
    
    // 2. Validar límite de embargos (solo si hay embargos)
    if (embargosJudiciales > 0 || cuotasAlimentarias > 0) {
      validaciones.add(validarLimiteEmbargos(
        totalBruto: totalBruto,
        totalDescuentos: totalDescuentos,
        embargosJudiciales: embargosJudiciales,
        cuotasAlimentarias: cuotasAlimentarias,
        esEmpleadoDocente: esEmpleadoDocente,
      ));
    }
    
    return validaciones;
  }
  
  /// Obtiene un resumen de todas las validaciones
  static Map<String, dynamic> obtenerResumenValidaciones(List<ValidacionLegal> validaciones) {
    final errores = validaciones.where((v) => !v.esValido).toList();
    final advertencias = validaciones.where((v) => v.esValido && v.advertencia != null).toList();
    
    return {
      'tiene_errores': errores.isNotEmpty,
      'tiene_advertencias': advertencias.isNotEmpty,
      'cantidad_errores': errores.length,
      'cantidad_advertencias': advertencias.length,
      'errores': errores.map((v) => v.error).toList(),
      'advertencias': advertencias.map((v) => v.advertencia).toList(),
      'todas_validas': errores.isEmpty,
    };
  }
}
