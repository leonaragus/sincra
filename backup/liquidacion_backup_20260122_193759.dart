/// Modelo para gestionar la liquidación de sueldos
class Liquidacion {
  // Constantes para Impuesto a las Ganancias 4ta Categoría (Enero 2026)
  // SMVM Enero 2026: $341.000
  // Mínimo no imponible: 15 SMVM
  static const double smvmEnero2026 = 341000.0;
  static const double minimoNoImponible = smvmEnero2026 * 15; // $5.115.000
  
  // Datos básicos
  final String empresaId;
  final String empleadoId;
  final String periodo;
  final String fechaPago;
  
  // Novedades
  double horasExtras50 = 0.0;
  double horasExtras100 = 0.0;
  double premios = 0.0;
  double conceptosNoRemunerativos = 0.0;
  
  // Conceptos adicionales
  final Map<String, double> conceptosRemunerativos = {};
  final Map<String, double> conceptosNoRemunerativosAdicionales = {};
  final Map<String, double> deduccionesAdicionales = {};
  
  // Impuesto a las Ganancias (calculado automáticamente o ingreso manual)
  double impuestoGanancias = 0.0;
  bool calcularGananciasAutomatico = true; // Si es true, calcula automáticamente
  
  // Afiliación sindical
  bool afiliadoSindical = false;
  
  // Días trabajados (para cálculo proporcional)
  int diasTrabajados = 30; // Por defecto 30 días (mes completo)
  
  Liquidacion({
    required this.empresaId,
    required this.empleadoId,
    required this.periodo,
    required this.fechaPago,
  });
  
  // Cálculo de Sueldo Bruto (suma de todos los conceptos remunerativos)
  // Si días trabajados < 30, calcula proporcional
  // NOTA: Horas extras y premios son NO REMUNERATIVOS, no se incluyen en el sueldo bruto
  double calcularSueldoBruto(double sueldoBasico) {
    // Calcular sueldo básico proporcional según días trabajados
    double sueldoBasicoProporcional = sueldoBasico;
    if (diasTrabajados < 30 && diasTrabajados > 0) {
      sueldoBasicoProporcional = (sueldoBasico * diasTrabajados) / 30;
    }
    
    double total = sueldoBasicoProporcional;
    
    // NO agregar horas extras ni premios (son no remunerativos)
    // total += horasExtras50;
    // total += horasExtras100;
    // total += premios;
    
    // Agregar conceptos remunerativos adicionales
    total += conceptosRemunerativos.values.fold(0.0, (sum, value) => sum + value);
    
    return total;
  }
  
  // Obtener sueldo básico proporcional (para mostrar en tabla)
  double obtenerSueldoBasicoProporcional(double sueldoBasico) {
    if (diasTrabajados < 30 && diasTrabajados > 0) {
      return (sueldoBasico * diasTrabajados) / 30;
    }
    return sueldoBasico;
  }
  
  // Cálculo de Aportes del Empleado (Deducciones Obligatorias 2026)
  Map<String, double> calcularAportes(double sueldoBruto) {
    return {
      'jubilacion': sueldoBruto * 0.11, // 11% SIPA
      'ley19032': sueldoBruto * 0.03,   // 3% PAMI
      'obraSocial': sueldoBruto * 0.03, // 3% Obra Social
      'cuotaSindical': afiliadoSindical ? sueldoBruto * 0.025 : 0.0, // 2.5% si está afiliado
    };
  }
  
  /// Calcula la Remuneración Neta Sujeta a Impuestos
  /// (Sueldo Bruto menos Jubilación y Obra Social)
  double calcularRemuneracionNetaSujetaAImpuestos(double sueldoBruto) {
    final aportes = calcularAportes(sueldoBruto);
    final jubilacion = aportes['jubilacion'] ?? 0.0;
    final obraSocial = aportes['obraSocial'] ?? 0.0;
    
    return sueldoBruto - jubilacion - obraSocial;
  }
  
  /// Calcula el Impuesto a las Ganancias (4ta Categoría) según escala progresiva
  /// 
  /// Reglas (Enero 2026):
  /// - Si la Remuneración Neta Sujeta a Impuestos es menor al Mínimo No Imponible, retorna 0
  /// - Si la supera, calcula el excedente y aplica escala progresiva (27% a 35%)
  /// 
  /// Escala simplificada basada en tramos:
  /// - Hasta $2.000.000 de excedente: 27%
  /// - Más de $2.000.000 a $5.000.000: 30%
  /// - Más de $5.000.000: 35%
  double calcularGanancias(double sueldoBruto) {
    // Calcular remuneración neta sujeta a impuestos
    final remuneracionNeta = calcularRemuneracionNetaSujetaAImpuestos(sueldoBruto);
    
    // Si es menor al mínimo no imponible, no hay retención
    if (remuneracionNeta <= Liquidacion.minimoNoImponible) {
      return 0.0;
    }
    
    // Calcular excedente sobre el mínimo no imponible
    final excedente = remuneracionNeta - Liquidacion.minimoNoImponible;
    
    // Aplicar escala progresiva
    double impuesto = 0.0;
    
    if (excedente <= 2000000.0) {
      // Primer tramo: 27% sobre el excedente hasta $2.000.000
      impuesto = excedente * 0.27;
    } else if (excedente <= 5000000.0) {
      // Segundo tramo: 27% sobre primeros $2.000.000 + 30% sobre el resto
      impuesto = (2000000.0 * 0.27) + ((excedente - 2000000.0) * 0.30);
    } else {
      // Tercer tramo: 27% sobre primeros $2.000.000 + 30% sobre siguientes $3.000.000 + 35% sobre el resto
      impuesto = (2000000.0 * 0.27) + (3000000.0 * 0.30) + ((excedente - 5000000.0) * 0.35);
    }
    
    return impuesto;
  }
  
  // Total de Deducciones
  double calcularTotalDeducciones(double sueldoBruto) {
    final aportes = calcularAportes(sueldoBruto);
    double total = aportes.values.fold(0.0, (sum, value) => sum + value);
    
    // Calcular ganancias automáticamente si está habilitado
    if (calcularGananciasAutomatico) {
      final gananciasCalculadas = calcularGanancias(sueldoBruto);
      total += gananciasCalculadas;
    } else {
      // Usar valor manual si está deshabilitado el cálculo automático
      total += impuestoGanancias;
    }
    
    total += deduccionesAdicionales.values.fold(0.0, (sum, value) => sum + value);
    return total;
  }
  
  /// Obtiene el monto de ganancias (calculado o manual)
  double obtenerGanancias(double sueldoBruto) {
    if (calcularGananciasAutomatico) {
      return calcularGanancias(sueldoBruto);
    }
    return impuestoGanancias;
  }
  
  // Total No Remunerativo
  // Incluye: horas extras, premios, conceptos no remunerativos y conceptos adicionales
  double calcularTotalNoRemunerativo() {
    double total = horasExtras50 + horasExtras100 + premios;
    total += conceptosNoRemunerativos;
    total += conceptosNoRemunerativosAdicionales.values.fold(0.0, (sum, value) => sum + value);
    return total;
  }
  
  // Sueldo Neto a Cobrar
  double calcularSueldoNeto(double sueldoBasico) {
    final sueldoBruto = calcularSueldoBruto(sueldoBasico);
    final totalDeducciones = calcularTotalDeducciones(sueldoBruto);
    final totalNoRemunerativo = calcularTotalNoRemunerativo();
    
    return sueldoBruto - totalDeducciones + totalNoRemunerativo;
  }
  
  // Obtener todos los conceptos para la tabla
  List<ConceptoLiquidacion> obtenerConceptosParaTabla(double sueldoBasico) {
    final conceptos = <ConceptoLiquidacion>[];
    final sueldoBruto = calcularSueldoBruto(sueldoBasico);
    final aportes = calcularAportes(sueldoBruto);
    
    // Sueldo básico (proporcional si aplica)
    final sueldoBasicoProporcional = obtenerSueldoBasicoProporcional(sueldoBasico);
    final conceptoBasico = diasTrabajados < 30 && diasTrabajados > 0
        ? 'Sueldo Básico ($diasTrabajados días)'
        : 'Sueldo Básico';
    conceptos.add(ConceptoLiquidacion(
      concepto: conceptoBasico,
      remunerativo: sueldoBasicoProporcional,
      noRemunerativo: 0.0,
      deducciones: 0.0,
    ));
    
    // Horas extras 50% (NO REMUNERATIVO)
    if (horasExtras50 > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Horas Extras 50%',
        remunerativo: 0.0,
        noRemunerativo: horasExtras50,
        deducciones: 0.0,
      ));
    }
    
    // Horas extras 100% (NO REMUNERATIVO)
    if (horasExtras100 > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Horas Extras 100%',
        remunerativo: 0.0,
        noRemunerativo: horasExtras100,
        deducciones: 0.0,
      ));
    }
    
    // Premios (NO REMUNERATIVO)
    if (premios > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Premios',
        remunerativo: 0.0,
        noRemunerativo: premios,
        deducciones: 0.0,
      ));
    }
    
    // Conceptos remunerativos adicionales
    conceptosRemunerativos.forEach((nombre, valor) {
      if (valor > 0) {
        conceptos.add(ConceptoLiquidacion(
          concepto: nombre,
          remunerativo: valor,
          noRemunerativo: 0.0,
          deducciones: 0.0,
        ));
      }
    });
    
    // Conceptos no remunerativos
    if (conceptosNoRemunerativos > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Conceptos No Remunerativos',
        remunerativo: 0.0,
        noRemunerativo: conceptosNoRemunerativos,
        deducciones: 0.0,
      ));
    }
    
    conceptosNoRemunerativosAdicionales.forEach((nombre, valor) {
      if (valor > 0) {
        conceptos.add(ConceptoLiquidacion(
          concepto: nombre,
          remunerativo: 0.0,
          noRemunerativo: valor,
          deducciones: 0.0,
        ));
      }
    });
    
    // Deducciones - Siempre mostrar todas las deducciones por ley (aunque sean 0)
    // Esto asegura que aparezcan detalladas en el recibo
    conceptos.add(ConceptoLiquidacion(
      concepto: 'Jubilación (SIPA)',
      remunerativo: 0.0,
      noRemunerativo: 0.0,
      deducciones: aportes['jubilacion'] ?? 0.0,
    ));
    
    conceptos.add(ConceptoLiquidacion(
      concepto: 'Ley 19.032 (PAMI)',
      remunerativo: 0.0,
      noRemunerativo: 0.0,
      deducciones: aportes['ley19032'] ?? 0.0,
    ));
    
    conceptos.add(ConceptoLiquidacion(
      concepto: 'Obra Social',
      remunerativo: 0.0,
      noRemunerativo: 0.0,
      deducciones: aportes['obraSocial'] ?? 0.0,
    ));
    
    // Cuota Sindical (solo si está afiliado y hay monto)
    if (afiliadoSindical && (aportes['cuotaSindical'] ?? 0.0) > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Cuota Sindical',
        remunerativo: 0.0,
        noRemunerativo: 0.0,
        deducciones: aportes['cuotaSindical'] ?? 0.0,
      ));
    }
    
    // Impuesto a las Ganancias (4ta Categoría) - Solo mostrar si es mayor a 0
    final ganancias = obtenerGanancias(sueldoBruto);
    if (ganancias > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Retención Ganancias 4ta Cat.',
        remunerativo: 0.0,
        noRemunerativo: 0.0,
        deducciones: ganancias,
      ));
    }
    
    // Impuesto a las Ganancias manual (si está deshabilitado el cálculo automático y hay valor manual)
    if (!calcularGananciasAutomatico && impuestoGanancias > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Impuesto a las Ganancias (Manual)',
        remunerativo: 0.0,
        noRemunerativo: 0.0,
        deducciones: impuestoGanancias,
      ));
    }
    
    deduccionesAdicionales.forEach((nombre, valor) {
      if (valor > 0) {
        conceptos.add(ConceptoLiquidacion(
          concepto: nombre,
          remunerativo: 0.0,
          noRemunerativo: 0.0,
          deducciones: valor,
        ));
      }
    });
    
    return conceptos;
  }
}

class ConceptoLiquidacion {
  final String concepto;
  final double remunerativo;
  final double noRemunerativo;
  final double deducciones;
  
  ConceptoLiquidacion({
    required this.concepto,
    required this.remunerativo,
    required this.noRemunerativo,
    required this.deducciones,
  });
}
