/// Modelo para gestionar la liquidación de sueldos
class Liquidacion {
  // ========== CONSTANTES LEGALES ENERO 2026 ==========
  // SMVM Enero 2026: $341.000
  static const double smvmEnero2026 = 341000.0;
  
  // Mínimo no imponible: 15 SMVM
  static const double minimoNoImponible = smvmEnero2026 * 15; // $5.115.000
  
  // TOPE PREVISIONAL BASE (Enero 2026)
  // Valor máximo sobre el cual se calculan los aportes
  // ignore: constant_identifier_names
  static const double TOPE_BASE = 2500000.00;
  
  // Datos básicos
  final String empresaId;
  final String empleadoId;
  final String periodo;
  final String fechaPago;
  
  // Novedades (genéricas)
  // Horas Extras: ahora se ingresan por cantidad y se calculan automáticamente como REMUNERATIVAS
  int cantidadHorasExtras50 = 0;  // Cantidad de horas extras al 50%
  int cantidadHorasExtras100 = 0; // Cantidad de horas extras al 100%
  double horasMensualesDivisor = 173.0; // Divisor para cálculo de horas extras (por defecto 173 para Petroleros Jerárquicos)
  
  // Getters para calcular montos de horas extras automáticamente
  double calcularMontoHorasExtras50(double sueldoBasico) {
    if (cantidadHorasExtras50 == 0) return 0.0;
    final valorHoraNormal = sueldoBasico / horasMensualesDivisor;
    return valorHoraNormal * 1.5 * cantidadHorasExtras50;
  }
  
  double calcularMontoHorasExtras100(double sueldoBasico) {
    if (cantidadHorasExtras100 == 0) return 0.0;
    final valorHoraNormal = sueldoBasico / horasMensualesDivisor;
    return valorHoraNormal * 2.0 * cantidadHorasExtras100;
  }
  
  // Mantener compatibilidad con código existente (deprecated)
  @Deprecated('Usar cantidadHorasExtras50 y calcularMontoHorasExtras50')
  double get horasExtras50 => 0.0;
  @Deprecated('Usar cantidadHorasExtras100 y calcularMontoHorasExtras100')
  double get horasExtras100 => 0.0;
  
  double premios = 0.0;
  double conceptosNoRemunerativos = 0.0;

  // Novedades específicas de CCT (ej. Camioneros)
  // Cantidades informadas por el usuario, los montos se calculan automáticamente
  int kilometrosRecorridos = 0;        // Remunerativo: AFIP 011000
  int diasViaticosComida = 0;         // No remunerativo: AFIP 112000
  int diasPernocte = 0;               // No remunerativo: AFIP 112000

  // Valores vigentes Enero 2026 para estos adicionales
  static const double valorKilometroEnero2026 = 150.0;
  static const double valorViaticoComidaEnero2026 = 2500.0;
  static const double valorPernocteEnero2026 = 3800.0;

  // Montos calculados automáticamente a partir de las cantidades
  double get montoKilometros =>
      kilometrosRecorridos > 0 ? kilometrosRecorridos * valorKilometroEnero2026 : 0.0;

  double get montoViaticosComida =>
      diasViaticosComida > 0 ? diasViaticosComida * valorViaticoComidaEnero2026 : 0.0;

  double get montoPernocte =>
      diasPernocte > 0 ? diasPernocte * valorPernocteEnero2026 : 0.0;
  
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
  
  // Presentismo
  bool presentismoActivo = true; // Por defecto activado
  int diasInasistencia = 0; // Días de inasistencia injustificada
  double porcentajePresentismo = 8.33; // Por defecto 8.33% (estándar en convenios)
  
  // Vacaciones (LCT 20.744)
  int diasVacaciones = 0; // Días de vacaciones a liquidar
  double montoVacaciones = 0.0; // Monto de vacaciones (divisor 25)
  double plusVacacional = 0.0; // Plus vacacional (diferencia entre divisor 25 y 30)
  bool vacacionesActivas = false; // Si las vacaciones están activas en esta liquidación
  bool vacacionesGozadas = true; // true = Gozadas, false = No Gozadas (para liquidaciones finales)
  String? fechaInicioVacaciones; // Fecha de inicio del período vacacional (DD/MM/YYYY)
  String? fechaFinVacaciones; // Fecha de fin del período vacacional (DD/MM/YYYY)
  bool ajusteManualVacaciones = false; // Si el usuario ajustó manualmente los días o monto
  
  Liquidacion({
    required this.empresaId,
    required this.empleadoId,
    required this.periodo,
    required this.fechaPago,
  });
  
  // Cálculo de Sueldo Bruto (suma de todos los conceptos remunerativos)
  // Si días trabajados < 30, calcula proporcional
  // NOTA: Horas extras y premios son NO REMUNERATIVOS, no se incluyen en el sueldo bruto
  // NOTA: Si hay vacaciones, se deduce del sueldo básico para evitar pagar los mismos días dos veces
  double calcularSueldoBruto(double sueldoBasico) {
    // Calcular sueldo básico proporcional según días trabajados
    double sueldoBasicoProporcional = sueldoBasico;
    if (diasTrabajados < 30 && diasTrabajados > 0) {
      sueldoBasicoProporcional = (sueldoBasico * diasTrabajados) / 30;
    }
    
    // Si hay vacaciones activas, deducir los días de vacaciones del sueldo básico
    // para evitar que se paguen los mismos días dos veces (Art. 155 LCT)
    if (vacacionesActivas && diasVacaciones > 0) {
      final deduccionVacaciones = (sueldoBasico / 30) * diasVacaciones;
      sueldoBasicoProporcional = (sueldoBasicoProporcional - deduccionVacaciones).clamp(0.0, double.infinity);
    }
    
    double total = sueldoBasicoProporcional;
    
    // Presentismo: solo se paga si está activo y no hay inasistencias injustificadas
    if (presentismoActivo && diasInasistencia == 0) {
      final presentismo = sueldoBasicoProporcional * (porcentajePresentismo / 100);
      total += presentismo;
    }
    
    // AGREGAR horas extras (ahora son REMUNERATIVAS)
    total += calcularMontoHorasExtras50(sueldoBasico);
    total += calcularMontoHorasExtras100(sueldoBasico);
    
    // NO agregar premios (son no remunerativos)
    // total += premios;

    // Agregar adicionales remunerativos específicos de convenio (ej. kilómetros recorridos)
    // IMPORTANTE: Estos sí integran la base imponible de seguridad social
    if (montoKilometros > 0) {
      total += montoKilometros;
    }
    
    // Agregar conceptos remunerativos adicionales
    total += conceptosRemunerativos.values.fold(0.0, (sum, value) => sum + value);
    
    // Agregar vacaciones (monto calculado con divisor 25) y plus vacacional
    if (vacacionesActivas && diasVacaciones > 0) {
      total += montoVacaciones;
      total += plusVacacional;
    }
    
    return total;
  }
  
  // Obtener sueldo básico proporcional (para mostrar en tabla)
  double obtenerSueldoBasicoProporcional(double sueldoBasico) {
    if (diasTrabajados < 30 && diasTrabajados > 0) {
      return (sueldoBasico * diasTrabajados) / 30;
    }
    return sueldoBasico;
  }
  
  /// Cálculo de Aportes del Empleado (Deducciones Obligatorias 2026)
  /// 
  /// MOTOR DE CÁLCULO DINÁMICO 2026:
  /// - Las deducciones de Ley (Jubilación, PAMI, OS) DEBEN calcularse sobre el
  ///   valor MÍNIMO entre el Sueldo Bruto Remunerativo y el TOPE_BASE.
  /// - Cuota Sindical se calcula sobre la misma base topeada.
  /// 
  /// [sueldoBruto] - Sueldo bruto remunerativo total (puede exceder el tope)
  /// 
  /// Retorna un mapa con los aportes calculados sobre la base topeada
  Map<String, double> calcularAportes(double sueldoBruto) {
    // Aplicar tope previsional: mínimo entre sueldo bruto y TOPE_BASE
    // REGLA ESTRICTA: El sistema DEBE calcular sobre el mínimo
    final baseParaAportes = sueldoBruto < TOPE_BASE ? sueldoBruto : TOPE_BASE;
    
    return {
      'jubilacion': baseParaAportes * 0.11, // 11% SIPA sobre base topeada
      'ley19032': baseParaAportes * 0.03,   // 3% PAMI sobre base topeada
      'obraSocial': baseParaAportes * 0.03, // 3% Obra Social sobre base topeada
      'cuotaSindical': afiliadoSindical ? baseParaAportes * 0.025 : 0.0, // 2.5% sobre base topeada
    };
  }
  
  /// Obtiene la base imponible topeada para cálculos de aportes
  /// 
  /// [sueldoBruto] - Sueldo bruto remunerativo total
  /// 
  /// Retorna el mínimo entre sueldo bruto y TOPE_BASE
  double obtenerBaseImponibleTopeada(double sueldoBruto) {
    return sueldoBruto < TOPE_BASE ? sueldoBruto : TOPE_BASE;
  }
  
  /// Calcula la Remuneración Neta Sujeta a Impuestos
  /// (Base Topeada menos Jubilación y Obra Social)
  /// 
  /// IMPORTANTE: Se usa la base topeada, no el sueldo bruto total
  double calcularRemuneracionNetaSujetaAImpuestos(double sueldoBruto) {
    final baseTopeada = obtenerBaseImponibleTopeada(sueldoBruto);
    final aportes = calcularAportes(sueldoBruto);
    final jubilacion = aportes['jubilacion'] ?? 0.0;
    final obraSocial = aportes['obraSocial'] ?? 0.0;
    
    return baseTopeada - jubilacion - obraSocial;
  }
  
  /// Calcula el Impuesto a las Ganancias (4ta Categoría) según escala progresiva
  /// 
  /// MOTOR DE CÁLCULO DINÁMICO 2026:
  /// - VALIDACIÓN OBLIGATORIA: Si Remuneración Neta < (15 * SMVM), retorna 0
  /// - SMVM Enero 2026: $341.000
  /// - Mínimo No Imponible: 15 × $341.000 = $5.115.000
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
    // Calcular remuneración neta sujeta a impuestos (sobre base topeada)
    final remuneracionNeta = calcularRemuneracionNetaSujetaAImpuestos(sueldoBruto);
    
    // VALIDACIÓN OBLIGATORIA: Si Remuneración Neta < (15 * SMVM), retención DEBE ser 0
    if (remuneracionNeta < minimoNoImponible) {
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
  // Incluye: premios, conceptos no remunerativos y conceptos adicionales
  // NOTA: Las horas extras ahora son REMUNERATIVAS, no se incluyen aquí
  double calcularTotalNoRemunerativo() {
    double total = premios;
    total += conceptosNoRemunerativos;
    total += conceptosNoRemunerativosAdicionales.values.fold(0.0, (sum, value) => sum + value);

    // Agregar adicionales NO remunerativos específicos de convenio
    // Estos NO deben sumarse a la Base 1 (Jubilación) pero sí al total de la liquidación
    if (montoViaticosComida > 0) {
      total += montoViaticosComida;
    }
    if (montoPernocte > 0) {
      total += montoPernocte;
    }
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
    // Si hay vacaciones, mostrar la deducción explícitamente
    double sueldoBasicoProporcional = obtenerSueldoBasicoProporcional(sueldoBasico);
    double deduccionVacacionesSueldo = 0.0;
    
    if (vacacionesActivas && diasVacaciones > 0) {
      deduccionVacacionesSueldo = (sueldoBasico / 30) * diasVacaciones;
      sueldoBasicoProporcional = (sueldoBasicoProporcional - deduccionVacacionesSueldo).clamp(0.0, double.infinity);
    }
    
    final conceptoBasico = diasTrabajados < 30 && diasTrabajados > 0
        ? 'Sueldo Básico ($diasTrabajados días)'
        : 'Sueldo Básico';
    conceptos.add(ConceptoLiquidacion(
      concepto: conceptoBasico,
      remunerativo: sueldoBasicoProporcional,
      noRemunerativo: 0.0,
      deducciones: 0.0,
    ));
    
    // Si hay vacaciones, mostrar la deducción del sueldo básico
    if (vacacionesActivas && diasVacaciones > 0 && deduccionVacacionesSueldo > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Deducción Vacaciones ($diasVacaciones días)',
        remunerativo: 0.0,
        noRemunerativo: 0.0,
        deducciones: deduccionVacacionesSueldo,
      ));
    }
    
    // Presentismo (REMUNERATIVO) - solo si está activo y no hay inasistencias
    if (presentismoActivo && diasInasistencia == 0) {
      final presentismo = sueldoBasicoProporcional * (porcentajePresentismo / 100);
      if (presentismo > 0) {
        conceptos.add(ConceptoLiquidacion(
          concepto: 'Presentismo (${porcentajePresentismo.toStringAsFixed(2)}%)',
          remunerativo: presentismo,
          noRemunerativo: 0.0,
          deducciones: 0.0,
        ));
      }
    }
    
    // Horas extras 50% (REMUNERATIVO)
    final montoHorasExtras50 = calcularMontoHorasExtras50(sueldoBasico);
    if (montoHorasExtras50 > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Horas Extras 50% ($cantidadHorasExtras50 horas)',
        remunerativo: montoHorasExtras50,
        noRemunerativo: 0.0,
        deducciones: 0.0,
      ));
    }
    
    // Horas extras 100% (REMUNERATIVO)
    final montoHorasExtras100 = calcularMontoHorasExtras100(sueldoBasico);
    if (montoHorasExtras100 > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Horas Extras 100% ($cantidadHorasExtras100 horas)',
        remunerativo: montoHorasExtras100,
        noRemunerativo: 0.0,
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

    // Kilómetros recorridos (REMUNERATIVO)
    if (kilometrosRecorridos > 0 && montoKilometros > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Kilometros Recorridos ($kilometrosRecorridos km)',
        remunerativo: montoKilometros,
        noRemunerativo: 0.0,
        deducciones: 0.0,
      ));
    }

    // Viáticos / Comida (NO REMUNERATIVO)
    if (diasViaticosComida > 0 && montoViaticosComida > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Viaticos / Comida ($diasViaticosComida dias)',
        remunerativo: 0.0,
        noRemunerativo: montoViaticosComida,
        deducciones: 0.0,
      ));
    }

    // Pernocte (NO REMUNERATIVO)
    if (diasPernocte > 0 && montoPernocte > 0) {
      conceptos.add(ConceptoLiquidacion(
        concepto: 'Pernocte ($diasPernocte dias)',
        remunerativo: 0.0,
        noRemunerativo: montoPernocte,
        deducciones: 0.0,
      ));
    }
    
    // Vacaciones (REMUNERATIVO) - Art. 155 LCT (divisor 25)
    if (vacacionesActivas && diasVacaciones > 0) {
      if (montoVacaciones > 0) {
        conceptos.add(ConceptoLiquidacion(
          concepto: 'Vacaciones ($diasVacaciones días)',
          remunerativo: montoVacaciones,
          noRemunerativo: 0.0,
          deducciones: 0.0,
        ));
      }
      
      // Plus Vacacional (REMUNERATIVO) - Diferencia entre divisor 25 y 30
      if (plusVacacional > 0) {
        conceptos.add(ConceptoLiquidacion(
          concepto: 'Plus Vacacional',
          remunerativo: plusVacacional,
          noRemunerativo: 0.0,
          deducciones: 0.0,
        ));
      }
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
