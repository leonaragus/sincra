// ========================================================================
// MODELO DE AUSENCIA
// Licencias, ausencias, suspensiones con goce/sin goce
// ========================================================================

class Ausencia {
  final String id;
  final String empleadoCuil;
  final String empresaCuit;
  
  // Tipo
  final TipoAusencia tipo;
  final DateTime fechaDesde;
  final DateTime fechaHasta;
  
  // Remuneración
  final bool conGoce;
  final double porcentajeGoce; // 100%, 50%, etc
  
  // Documentación
  final String? motivo;
  final String? certificadoUrl;
  final String? numeroCertificado;
  
  // Estado
  final EstadoAusencia estado;
  final String? aprobadoPor;
  final DateTime? fechaAprobacion;
  
  // Auditoría
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creadoPor;
  
  Ausencia({
    required this.id,
    required this.empleadoCuil,
    required this.empresaCuit,
    required this.tipo,
    required this.fechaDesde,
    required this.fechaHasta,
    this.conGoce = true,
    this.porcentajeGoce = 100.0,
    this.motivo,
    this.certificadoUrl,
    this.numeroCertificado,
    this.estado = EstadoAusencia.pendiente,
    this.aprobadoPor,
    this.fechaAprobacion,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.creadoPor,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
  
  int get diasTotales {
    return fechaHasta.difference(fechaDesde).inDays + 1;
  }
  
  bool estaEnPeriodo(int mes, int anio) {
    final inicioPeriodo = DateTime(anio, mes, 1);
    final finPeriodo = DateTime(anio, mes + 1, 0); // Último día del mes
    
    // La ausencia está en el período si hay superposición
    return !(fechaHasta.isBefore(inicioPeriodo) || fechaDesde.isAfter(finPeriodo));
  }
  
  int diasEnPeriodo(int mes, int anio) {
    final inicioPeriodo = DateTime(anio, mes, 1);
    final finPeriodo = DateTime(anio, mes + 1, 0);
    
    final inicio = fechaDesde.isAfter(inicioPeriodo) ? fechaDesde : inicioPeriodo;
    final fin = fechaHasta.isBefore(finPeriodo) ? fechaHasta : finPeriodo;
    
    if (fin.isBefore(inicio)) return 0;
    
    return fin.difference(inicio).inDays + 1;
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'empleado_cuil': empleadoCuil,
      'empresa_cuit': empresaCuit,
      'tipo': tipo.name,
      'fecha_desde': fechaDesde.toIso8601String(),
      'fecha_hasta': fechaHasta.toIso8601String(),
      'con_goce': conGoce,
      'porcentaje_goce': porcentajeGoce,
      'motivo': motivo,
      'certificado_url': certificadoUrl,
      'numero_certificado': numeroCertificado,
      'estado': estado.name,
      'aprobado_por': aprobadoPor,
      'fecha_aprobacion': fechaAprobacion?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'creado_por': creadoPor,
    };
  }
  
  factory Ausencia.fromMap(Map<String, dynamic> map) {
    return Ausencia(
      id: map['id'] ?? '',
      empleadoCuil: map['empleado_cuil'] ?? '',
      empresaCuit: map['empresa_cuit'] ?? '',
      tipo: TipoAusencia.values.firstWhere(
        (t) => t.name == map['tipo'],
        orElse: () => TipoAusencia.enfermedad,
      ),
      fechaDesde: DateTime.parse(map['fecha_desde']),
      fechaHasta: DateTime.parse(map['fecha_hasta']),
      conGoce: map['con_goce'] ?? true,
      porcentajeGoce: (map['porcentaje_goce'] as num?)?.toDouble() ?? 100.0,
      motivo: map['motivo'],
      certificadoUrl: map['certificado_url'],
      numeroCertificado: map['numero_certificado'],
      estado: EstadoAusencia.values.firstWhere(
        (e) => e.name == map['estado'],
        orElse: () => EstadoAusencia.pendiente,
      ),
      aprobadoPor: map['aprobado_por'],
      fechaAprobacion: map['fecha_aprobacion'] != null 
          ? DateTime.parse(map['fecha_aprobacion']) 
          : null,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
      creadoPor: map['creado_por'],
    );
  }
  
  Ausencia copyWith({
    String? id,
    String? empleadoCuil,
    String? empresaCuit,
    TipoAusencia? tipo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool? conGoce,
    double? porcentajeGoce,
    String? motivo,
    String? certificadoUrl,
    String? numeroCertificado,
    EstadoAusencia? estado,
    String? aprobadoPor,
    DateTime? fechaAprobacion,
    String? creadoPor,
  }) {
    return Ausencia(
      id: id ?? this.id,
      empleadoCuil: empleadoCuil ?? this.empleadoCuil,
      empresaCuit: empresaCuit ?? this.empresaCuit,
      tipo: tipo ?? this.tipo,
      fechaDesde: fechaDesde ?? this.fechaDesde,
      fechaHasta: fechaHasta ?? this.fechaHasta,
      conGoce: conGoce ?? this.conGoce,
      porcentajeGoce: porcentajeGoce ?? this.porcentajeGoce,
      motivo: motivo ?? this.motivo,
      certificadoUrl: certificadoUrl ?? this.certificadoUrl,
      numeroCertificado: numeroCertificado ?? this.numeroCertificado,
      estado: estado ?? this.estado,
      aprobadoPor: aprobadoPor ?? this.aprobadoPor,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      creadoPor: creadoPor ?? this.creadoPor,
    );
  }
}

enum TipoAusencia {
  enfermedad,
  vacaciones,
  licenciaEspecial,
  suspension,
  maternidad,
  paternidad,
  casamiento,
  fallecimientoFamiliar,
  mudanza,
  donacionSangre,
  examen,
  otra,
}

enum EstadoAusencia {
  pendiente,
  aprobado,
  rechazado,
}

extension TipoAusenciaExtension on TipoAusencia {
  String get displayName {
    switch (this) {
      case TipoAusencia.enfermedad: return 'Enfermedad';
      case TipoAusencia.vacaciones: return 'Vacaciones';
      case TipoAusencia.licenciaEspecial: return 'Licencia Especial';
      case TipoAusencia.suspension: return 'Suspensión';
      case TipoAusencia.maternidad: return 'Maternidad';
      case TipoAusencia.paternidad: return 'Paternidad';
      case TipoAusencia.casamiento: return 'Casamiento';
      case TipoAusencia.fallecimientoFamiliar: return 'Fallecimiento Familiar';
      case TipoAusencia.mudanza: return 'Mudanza';
      case TipoAusencia.donacionSangre: return 'Donación de Sangre';
      case TipoAusencia.examen: return 'Examen';
      case TipoAusencia.otra: return 'Otra';
    }
  }
  
  bool get requiereCertificado {
    return this == TipoAusencia.enfermedad || 
           this == TipoAusencia.maternidad ||
           this == TipoAusencia.paternidad;
  }
}
