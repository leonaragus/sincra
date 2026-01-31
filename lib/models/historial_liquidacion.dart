// ========================================================================
// MODELO DE HISTORIAL DE LIQUIDACIÓN
// Registro histórico de todas las liquidaciones por empleado
// ========================================================================

class HistorialLiquidacion {
  final String id;
  final String empleadoCuil;
  final String empresaCuit;
  
  // Período
  final int mes;
  final int anio;
  final String periodo; // "01/2026"
  
  // Tipo de liquidación
  final String tipo; // mensual, sac, vacaciones, final
  final String? sector; // sanidad, docente, otro
  
  // Montos principales
  final double sueldoBasico;
  final double adicionalAntiguedad;
  final double otrosHaberes;
  final double totalBrutoRemunerativo;
  final double totalNoRemunerativo;
  
  // Descuentos
  final double totalAportes;
  final double totalDescuentos;
  final double embargosJudiciales;
  final double cuotasAlimentarias;
  
  // Contribuciones empleador
  final double totalContribuciones;
  
  // Neto
  final double netoACobrar;
  
  // Datos del cálculo
  final int antiguedadAnios;
  final String? provincia;
  final String? categoria;
  
  // Validaciones
  final bool tieneErrores;
  final bool tieneAdvertencias;
  final List<String>? errores;
  final List<String>? advertencias;
  
  // Auditoría
  final DateTime fechaLiquidacion;
  final String? liquidadoPor;
  final DateTime createdAt;
  
  // Referencia
  final String? liquidacionId; // ID de la liquidación masiva
  final String? reciboUrl;
  
  HistorialLiquidacion({
    required this.id,
    required this.empleadoCuil,
    required this.empresaCuit,
    required this.mes,
    required this.anio,
    required this.periodo,
    this.tipo = 'mensual',
    this.sector,
    required this.sueldoBasico,
    required this.adicionalAntiguedad,
    this.otrosHaberes = 0.0,
    required this.totalBrutoRemunerativo,
    this.totalNoRemunerativo = 0.0,
    required this.totalAportes,
    required this.totalDescuentos,
    this.embargosJudiciales = 0.0,
    this.cuotasAlimentarias = 0.0,
    this.totalContribuciones = 0.0,
    required this.netoACobrar,
    this.antiguedadAnios = 0,
    this.provincia,
    this.categoria,
    this.tieneErrores = false,
    this.tieneAdvertencias = false,
    this.errores,
    this.advertencias,
    required this.fechaLiquidacion,
    this.liquidadoPor,
    DateTime? createdAt,
    this.liquidacionId,
    this.reciboUrl,
  }) : createdAt = createdAt ?? DateTime.now();
  
  /// Calcula el porcentaje del neto sobre el bruto
  double get porcentajeNeto {
    if (totalBrutoRemunerativo == 0) return 0.0;
    return (netoACobrar / totalBrutoRemunerativo) * 100;
  }
  
  /// Calcula el costo empleador total
  double get costoEmpleadorTotal {
    return totalBrutoRemunerativo + totalContribuciones;
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'empleado_cuil': empleadoCuil,
      'empresa_cuit': empresaCuit,
      'mes': mes,
      'anio': anio,
      'periodo': periodo,
      'tipo': tipo,
      'sector': sector,
      'sueldo_basico': sueldoBasico,
      'adicional_antiguedad': adicionalAntiguedad,
      'otros_haberes': otrosHaberes,
      'total_bruto_remunerativo': totalBrutoRemunerativo,
      'total_no_remunerativo': totalNoRemunerativo,
      'total_aportes': totalAportes,
      'total_descuentos': totalDescuentos,
      'embargos_judiciales': embargosJudiciales,
      'cuotas_alimentarias': cuotasAlimentarias,
      'total_contribuciones': totalContribuciones,
      'neto_a_cobrar': netoACobrar,
      'antiguedad_anios': antiguedadAnios,
      'provincia': provincia,
      'categoria': categoria,
      'tiene_errores': tieneErrores,
      'tiene_advertencias': tieneAdvertencias,
      'errores': errores,
      'advertencias': advertencias,
      'fecha_liquidacion': fechaLiquidacion.toIso8601String(),
      'liquidado_por': liquidadoPor,
      'created_at': createdAt.toIso8601String(),
      'liquidacion_id': liquidacionId,
      'recibo_url': reciboUrl,
    };
  }
  
  factory HistorialLiquidacion.fromMap(Map<String, dynamic> map) {
    return HistorialLiquidacion(
      id: map['id'] ?? '',
      empleadoCuil: map['empleado_cuil'] ?? '',
      empresaCuit: map['empresa_cuit'] ?? '',
      mes: map['mes'] ?? 0,
      anio: map['anio'] ?? 0,
      periodo: map['periodo'] ?? '',
      tipo: map['tipo'] ?? 'mensual',
      sector: map['sector'],
      sueldoBasico: (map['sueldo_basico'] as num?)?.toDouble() ?? 0.0,
      adicionalAntiguedad: (map['adicional_antiguedad'] as num?)?.toDouble() ?? 0.0,
      otrosHaberes: (map['otros_haberes'] as num?)?.toDouble() ?? 0.0,
      totalBrutoRemunerativo: (map['total_bruto_remunerativo'] as num?)?.toDouble() ?? 0.0,
      totalNoRemunerativo: (map['total_no_remunerativo'] as num?)?.toDouble() ?? 0.0,
      totalAportes: (map['total_aportes'] as num?)?.toDouble() ?? 0.0,
      totalDescuentos: (map['total_descuentos'] as num?)?.toDouble() ?? 0.0,
      embargosJudiciales: (map['embargos_judiciales'] as num?)?.toDouble() ?? 0.0,
      cuotasAlimentarias: (map['cuotas_alimentarias'] as num?)?.toDouble() ?? 0.0,
      totalContribuciones: (map['total_contribuciones'] as num?)?.toDouble() ?? 0.0,
      netoACobrar: (map['neto_a_cobrar'] as num?)?.toDouble() ?? 0.0,
      antiguedadAnios: map['antiguedad_anios'] ?? 0,
      provincia: map['provincia'],
      categoria: map['categoria'],
      tieneErrores: map['tiene_errores'] ?? false,
      tieneAdvertencias: map['tiene_advertencias'] ?? false,
      errores: map['errores'] != null ? List<String>.from(map['errores']) : null,
      advertencias: map['advertencias'] != null ? List<String>.from(map['advertencias']) : null,
      fechaLiquidacion: DateTime.parse(map['fecha_liquidacion']),
      liquidadoPor: map['liquidado_por'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      liquidacionId: map['liquidacion_id'],
      reciboUrl: map['recibo_url'],
    );
  }
}

/// Estadísticas del historial de un empleado
class EstadisticasHistorialEmpleado {
  final String empleadoCuil;
  final int cantidadLiquidaciones;
  final double promedioNeto;
  final double promedioAportes;
  final double maximoNeto;
  final double minimoNeto;
  final double? mejorRemuneracionUltimos6Meses;
  final List<HistorialLiquidacion> ultimas6Liquidaciones;
  
  EstadisticasHistorialEmpleado({
    required this.empleadoCuil,
    required this.cantidadLiquidaciones,
    required this.promedioNeto,
    required this.promedioAportes,
    required this.maximoNeto,
    required this.minimoNeto,
    this.mejorRemuneracionUltimos6Meses,
    required this.ultimas6Liquidaciones,
  });
}
