// ========================================================================
// CONCEPTO RECURRENTE
// Representa conceptos que se aplican automáticamente cada mes
// (vales, descuentos fijos, embargos, etc.)
// ========================================================================

class ConceptoRecurrente {
  String id; // UUID
  String empleadoCuil;
  
  // Identificación del concepto
  String codigo; // "VALE_COMIDA", "EMBARGO_001", "SEGURO_VIDA"
  String nombre; // "Vale alimentario", "Embargo judicial", etc
  String descripcion;
  
  // Tipo de concepto
  String tipo; // "fijo", "porcentaje", "calculado"
  
  // Valor
  double valor; // Si es fijo: monto. Si es porcentaje: 0.05 para 5%
  String? formula; // Si es calculado: formula para calcular
  
  // Categorización
  String categoria; // "remunerativo", "no_remunerativo", "descuento"
  String? subcategoria; // "aporte", "contribucion", "embargo", "beneficio"
  
  // Vigencia
  DateTime activoDesde; // Mes/año desde cuándo
  DateTime? activoHasta; // NULL = indefinido
  
  // Estado
  bool activo;
  
  // Condiciones (opcional)
  String? condicion; // "solo_si_presentismo_100", "solo_zona_patagonica"
  
  // Para embargos: control de monto acumulado
  double? montoTotalEmbargo; // Si es embargo, monto total a descontar
  double montoAcumuladoDescontado; // Cuánto se descontó hasta ahora
  
  // Metadata
  DateTime? createdAt;
  DateTime? updatedAt;
  String? creadoPor;
  
  ConceptoRecurrente({
    required this.id,
    required this.empleadoCuil,
    required this.codigo,
    required this.nombre,
    this.descripcion = '',
    required this.tipo,
    required this.valor,
    this.formula,
    required this.categoria,
    this.subcategoria,
    required this.activoDesde,
    this.activoHasta,
    this.activo = true,
    this.condicion,
    this.montoTotalEmbargo,
    this.montoAcumuladoDescontado = 0.0,
    this.createdAt,
    this.updatedAt,
    this.creadoPor,
  });
  
  /// Verifica si el concepto está activo para un mes/año dado
  bool estaActivoEn(int mes, int anio) {
    if (!activo) return false;
    
    final fecha = DateTime(anio, mes, 1);
    
    // Verificar desde
    if (fecha.isBefore(DateTime(activoDesde.year, activoDesde.month, 1))) {
      return false;
    }
    
    // Verificar hasta (si existe)
    if (activoHasta != null) {
      if (fecha.isAfter(DateTime(activoHasta!.year, activoHasta!.month, 1))) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Verifica si el embargo ya se completó
  bool embargoCompletado() {
    if (montoTotalEmbargo == null) return false;
    return montoAcumuladoDescontado >= montoTotalEmbargo!;
  }
  
  /// Registra un descuento de embargo
  void registrarDescuentoEmbargo(double monto) {
    montoAcumuladoDescontado += monto;
    if (embargoCompletado()) {
      activo = false;
    }
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'empleado_cuil': empleadoCuil,
      'codigo': codigo,
      'nombre': nombre,
      'descripcion': descripcion,
      'tipo': tipo,
      'valor': valor,
      'formula': formula,
      'categoria': categoria,
      'subcategoria': subcategoria,
      'activo_desde': activoDesde.toIso8601String(),
      'activo_hasta': activoHasta?.toIso8601String(),
      'activo': activo,
      'condicion': condicion,
      'monto_total_embargo': montoTotalEmbargo,
      'monto_acumulado_descontado': montoAcumuladoDescontado,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'creado_por': creadoPor,
    };
  }
  
  factory ConceptoRecurrente.fromMap(Map<String, dynamic> map) {
    return ConceptoRecurrente(
      id: map['id']?.toString() ?? '',
      empleadoCuil: map['empleado_cuil']?.toString() ?? '',
      codigo: map['codigo']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      descripcion: map['descripcion']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? 'fijo',
      valor: (map['valor'] as num?)?.toDouble() ?? 0.0,
      formula: map['formula']?.toString(),
      categoria: map['categoria']?.toString() ?? 'remunerativo',
      subcategoria: map['subcategoria']?.toString(),
      activoDesde: map['activo_desde'] != null
          ? DateTime.parse(map['activo_desde'].toString())
          : DateTime.now(),
      activoHasta: map['activo_hasta'] != null
          ? DateTime.tryParse(map['activo_hasta'].toString())
          : null,
      activo: map['activo'] == true || map['activo'] == 1,
      condicion: map['condicion']?.toString(),
      montoTotalEmbargo: (map['monto_total_embargo'] as num?)?.toDouble(),
      montoAcumuladoDescontado: (map['monto_acumulado_descontado'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      creadoPor: map['creado_por']?.toString(),
    );
  }
  
  ConceptoRecurrente copyWith({
    String? id,
    String? empleadoCuil,
    String? codigo,
    String? nombre,
    String? descripcion,
    String? tipo,
    double? valor,
    String? formula,
    String? categoria,
    String? subcategoria,
    DateTime? activoDesde,
    DateTime? activoHasta,
    bool? activo,
    String? condicion,
    double? montoTotalEmbargo,
    double? montoAcumuladoDescontado,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? creadoPor,
  }) {
    return ConceptoRecurrente(
      id: id ?? this.id,
      empleadoCuil: empleadoCuil ?? this.empleadoCuil,
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
      valor: valor ?? this.valor,
      formula: formula ?? this.formula,
      categoria: categoria ?? this.categoria,
      subcategoria: subcategoria ?? this.subcategoria,
      activoDesde: activoDesde ?? this.activoDesde,
      activoHasta: activoHasta ?? this.activoHasta,
      activo: activo ?? this.activo,
      condicion: condicion ?? this.condicion,
      montoTotalEmbargo: montoTotalEmbargo ?? this.montoTotalEmbargo,
      montoAcumuladoDescontado: montoAcumuladoDescontado ?? this.montoAcumuladoDescontado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creadoPor: creadoPor ?? this.creadoPor,
    );
  }
  
  @override
  String toString() {
    return 'ConceptoRecurrente(codigo: $codigo, nombre: $nombre, valor: $valor, categoria: $categoria, activo: $activo)';
  }
}

/// Plantillas de conceptos comunes
class PlantillasConceptos {
  static const List<Map<String, dynamic>> comunes = [
    {
      'codigo': 'VALE_COMIDA',
      'nombre': 'Vale alimentario',
      'descripcion': 'Vale de comida mensual',
      'tipo': 'fijo',
      'categoria': 'no_remunerativo',
      'subcategoria': 'beneficio',
      'valor_sugerido': 50000.0,
    },
    {
      'codigo': 'SEGURO_VIDA',
      'nombre': 'Seguro de vida',
      'descripcion': 'Descuento mensual seguro de vida',
      'tipo': 'fijo',
      'categoria': 'descuento',
      'subcategoria': 'aporte',
      'valor_sugerido': 5000.0,
    },
    {
      'codigo': 'CUOTA_SINDICAL',
      'nombre': 'Cuota sindical',
      'descripcion': 'Aporte sindical mensual',
      'tipo': 'porcentaje',
      'categoria': 'descuento',
      'subcategoria': 'aporte',
      'valor_sugerido': 0.025, // 2.5%
    },
    {
      'codigo': 'ANTICIPO',
      'nombre': 'Anticipo quincenal',
      'descripcion': 'Anticipo a cuenta de sueldo',
      'tipo': 'fijo',
      'categoria': 'descuento',
      'subcategoria': 'anticipo',
      'valor_sugerido': 100000.0,
    },
    {
      'codigo': 'EMBARGO',
      'nombre': 'Embargo judicial',
      'descripcion': 'Descuento por embargo',
      'tipo': 'fijo',
      'categoria': 'descuento',
      'subcategoria': 'embargo',
      'valor_sugerido': 15000.0,
    },
    {
      'codigo': 'PRESENTISMO',
      'nombre': 'Premio por presentismo',
      'descripcion': 'Adicional por asistencia perfecta',
      'tipo': 'porcentaje',
      'categoria': 'remunerativo',
      'subcategoria': 'beneficio',
      'valor_sugerido': 0.05, // 5%
      'condicion': 'solo_si_presentismo_100',
    },
    {
      'codigo': 'ZONA_DESFAVORABLE',
      'nombre': 'Zona desfavorable',
      'descripcion': 'Adicional por zona remota',
      'tipo': 'porcentaje',
      'categoria': 'remunerativo',
      'subcategoria': 'beneficio',
      'valor_sugerido': 0.20, // 20%
    },
  ];
}
