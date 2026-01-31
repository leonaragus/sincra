// ========================================================================
// MODELO DE PRÉSTAMO A EMPLEADO
// Préstamos con cuotas automáticas descontables en liquidación
// ========================================================================

class Prestamo {
  final String id;
  final String empleadoCuil;
  final String empresaCuit;
  
  // Datos del préstamo
  final double montoTotal;
  final double tasaInteres; // % anual
  final int cantidadCuotas;
  final double valorCuota;
  
  // Progreso
  final int cuotasPagadas;
  final double montoPagado;
  
  // Fechas
  final DateTime fechaOtorgamiento;
  final DateTime fechaPrimeraCuota;
  final DateTime? fechaUltimaCuota;
  
  // Estado
  final EstadoPrestamo estado;
  final String? motivoPrestamo;
  
  // Auditoría
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creadoPor;
  
  Prestamo({
    required this.id,
    required this.empleadoCuil,
    required this.empresaCuit,
    required this.montoTotal,
    this.tasaInteres = 0.0,
    required this.cantidadCuotas,
    required this.valorCuota,
    this.cuotasPagadas = 0,
    this.montoPagado = 0.0,
    required this.fechaOtorgamiento,
    required this.fechaPrimeraCuota,
    this.fechaUltimaCuota,
    this.estado = EstadoPrestamo.activo,
    this.motivoPrestamo,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.creadoPor,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
  
  double get montoRestante => montoTotal - montoPagado;
  
  double get porcentajePagado => montoTotal > 0 
      ? (montoPagado / montoTotal) * 100 
      : 0.0;
  
  bool get completado => cuotasPagadas >= cantidadCuotas;
  
  /// Calcula el valor de la cuota con interés simple
  static double calcularCuota({
    required double montoTotal,
    required double tasaInteres,
    required int cantidadCuotas,
  }) {
    if (cantidadCuotas <= 0) return 0.0;
    
    // Si no hay interés, es simple
    if (tasaInteres == 0) {
      return montoTotal / cantidadCuotas;
    }
    
    // Interés simple: Total + (Total * tasa * cuotas/12)
    final interesTotal = montoTotal * (tasaInteres / 100) * (cantidadCuotas / 12);
    return (montoTotal + interesTotal) / cantidadCuotas;
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'empleado_cuil': empleadoCuil,
      'empresa_cuit': empresaCuit,
      'monto_total': montoTotal,
      'tasa_interes': tasaInteres,
      'cantidad_cuotas': cantidadCuotas,
      'valor_cuota': valorCuota,
      'cuotas_pagadas': cuotasPagadas,
      'monto_pagado': montoPagado,
      'fecha_otorgamiento': fechaOtorgamiento.toIso8601String().split('T')[0],
      'fecha_primera_cuota': fechaPrimeraCuota.toIso8601String().split('T')[0],
      'fecha_ultima_cuota': fechaUltimaCuota?.toIso8601String().split('T')[0],
      'estado': estado.name,
      'motivo_prestamo': motivoPrestamo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'creado_por': creadoPor,
    };
  }
  
  factory Prestamo.fromMap(Map<String, dynamic> map) {
    return Prestamo(
      id: map['id'] ?? '',
      empleadoCuil: map['empleado_cuil'] ?? '',
      empresaCuit: map['empresa_cuit'] ?? '',
      montoTotal: (map['monto_total'] as num?)?.toDouble() ?? 0.0,
      tasaInteres: (map['tasa_interes'] as num?)?.toDouble() ?? 0.0,
      cantidadCuotas: map['cantidad_cuotas'] ?? 0,
      valorCuota: (map['valor_cuota'] as num?)?.toDouble() ?? 0.0,
      cuotasPagadas: map['cuotas_pagadas'] ?? 0,
      montoPagado: (map['monto_pagado'] as num?)?.toDouble() ?? 0.0,
      fechaOtorgamiento: DateTime.parse(map['fecha_otorgamiento']),
      fechaPrimeraCuota: DateTime.parse(map['fecha_primera_cuota']),
      fechaUltimaCuota: map['fecha_ultima_cuota'] != null 
          ? DateTime.parse(map['fecha_ultima_cuota']) 
          : null,
      estado: EstadoPrestamo.values.firstWhere(
        (e) => e.name == map['estado'],
        orElse: () => EstadoPrestamo.activo,
      ),
      motivoPrestamo: map['motivo_prestamo'],
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
      creadoPor: map['creado_por'],
    );
  }
  
  Prestamo copyWith({
    String? id,
    String? empleadoCuil,
    String? empresaCuit,
    double? montoTotal,
    double? tasaInteres,
    int? cantidadCuotas,
    double? valorCuota,
    int? cuotasPagadas,
    double? montoPagado,
    DateTime? fechaOtorgamiento,
    DateTime? fechaPrimeraCuota,
    DateTime? fechaUltimaCuota,
    EstadoPrestamo? estado,
    String? motivoPrestamo,
    String? creadoPor,
  }) {
    return Prestamo(
      id: id ?? this.id,
      empleadoCuil: empleadoCuil ?? this.empleadoCuil,
      empresaCuit: empresaCuit ?? this.empresaCuit,
      montoTotal: montoTotal ?? this.montoTotal,
      tasaInteres: tasaInteres ?? this.tasaInteres,
      cantidadCuotas: cantidadCuotas ?? this.cantidadCuotas,
      valorCuota: valorCuota ?? this.valorCuota,
      cuotasPagadas: cuotasPagadas ?? this.cuotasPagadas,
      montoPagado: montoPagado ?? this.montoPagado,
      fechaOtorgamiento: fechaOtorgamiento ?? this.fechaOtorgamiento,
      fechaPrimeraCuota: fechaPrimeraCuota ?? this.fechaPrimeraCuota,
      fechaUltimaCuota: fechaUltimaCuota ?? this.fechaUltimaCuota,
      estado: estado ?? this.estado,
      motivoPrestamo: motivoPrestamo ?? this.motivoPrestamo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      creadoPor: creadoPor ?? this.creadoPor,
    );
  }
}

enum EstadoPrestamo {
  activo,
  pagado,
  cancelado,
}

class CuotaPrestamo {
  final String id;
  final String prestamoId;
  final int numeroCuota;
  final double monto;
  final int periodoMes;
  final int periodoAnio;
  final bool pagada;
  final DateTime? fechaPago;
  final String? liquidacionId;
  
  CuotaPrestamo({
    required this.id,
    required this.prestamoId,
    required this.numeroCuota,
    required this.monto,
    required this.periodoMes,
    required this.periodoAnio,
    this.pagada = false,
    this.fechaPago,
    this.liquidacionId,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prestamo_id': prestamoId,
      'numero_cuota': numeroCuota,
      'monto': monto,
      'periodo_mes': periodoMes,
      'periodo_anio': periodoAnio,
      'pagada': pagada,
      'fecha_pago': fechaPago?.toIso8601String(),
      'liquidacion_id': liquidacionId,
    };
  }
  
  factory CuotaPrestamo.fromMap(Map<String, dynamic> map) {
    return CuotaPrestamo(
      id: map['id'] ?? '',
      prestamoId: map['prestamo_id'] ?? '',
      numeroCuota: map['numero_cuota'] ?? 0,
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      periodoMes: map['periodo_mes'] ?? 0,
      periodoAnio: map['periodo_anio'] ?? 0,
      pagada: map['pagada'] ?? false,
      fechaPago: map['fecha_pago'] != null 
          ? DateTime.parse(map['fecha_pago']) 
          : null,
      liquidacionId: map['liquidacion_id'],
    );
  }
}
