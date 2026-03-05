// Modelo completo para Convenios Colectivos de Trabajo (CCT) de Argentina

class CategoriaCCT {
  final String id;
  final String nombre;
  final double salarioBase;
  final String? descripcion;

  const CategoriaCCT({
    required this.id,
    required this.nombre,
    required this.salarioBase,
    this.descripcion,
  });

  factory CategoriaCCT.fromJson(Map<String, dynamic> json) {
    return CategoriaCCT(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      salarioBase: (json['salarioBase'] as num).toDouble(),
      descripcion: json['descripcion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'salarioBase': salarioBase,
      'descripcion': descripcion,
    };
  }

  CategoriaCCT copyWith({
    String? id,
    String? nombre,
    double? salarioBase,
    String? descripcion,
  }) {
    return CategoriaCCT(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      salarioBase: salarioBase ?? this.salarioBase,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}

class DescuentoCCT {
  final String id;
  final String nombre;
  final double porcentaje;
  final String? descripcion;

  const DescuentoCCT({
    required this.id,
    required this.nombre,
    required this.porcentaje,
    this.descripcion,
  });

  factory DescuentoCCT.fromJson(Map<String, dynamic> json) {
    return DescuentoCCT(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      porcentaje: (json['porcentaje'] as num).toDouble(),
      descripcion: json['descripcion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'porcentaje': porcentaje,
      'descripcion': descripcion,
    };
  }

  DescuentoCCT copyWith({
    String? id,
    String? nombre,
    double? porcentaje,
    String? descripcion,
  }) {
    return DescuentoCCT(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      porcentaje: porcentaje ?? this.porcentaje,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}

class ZonaCCT {
  final String id;
  final String nombre;
  final double adicionalPorcentaje;
  final String? descripcion;

  const ZonaCCT({
    required this.id,
    required this.nombre,
    required this.adicionalPorcentaje,
    this.descripcion,
  });

  factory ZonaCCT.fromJson(Map<String, dynamic> json) {
    return ZonaCCT(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      adicionalPorcentaje: (json['adicionalPorcentaje'] as num).toDouble(),
      descripcion: json['descripcion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'adicionalPorcentaje': adicionalPorcentaje,
      'descripcion': descripcion,
    };
  }

  ZonaCCT copyWith({
    String? id,
    String? nombre,
    double? adicionalPorcentaje,
    String? descripcion,
  }) {
    return ZonaCCT(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      adicionalPorcentaje: adicionalPorcentaje ?? this.adicionalPorcentaje,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}

class CCTCompleto {
  final String id;
  final String numeroCCT;
  final String nombre;
  final String descripcion;
  final String? actividad;
  final List<CategoriaCCT> categorias;
  final List<DescuentoCCT> descuentos;
  final List<ZonaCCT> zonas;
  final double adicionalPresentismo;
  final double adicionalAntiguedad; // Porcentaje fijo de antigüedad (legacy)
  final double porcentajeAntiguedadAnual; // Porcentaje anual de antigüedad (ej: 1% para Comercio, 1.5% para otros)
  final double? horasMensualesDivisor; // Divisor para cálculo de horas extras (192, 200, 173, etc.)
  final bool esDivisorDias; // Si es true, el divisor es en días (ej: camioneros usa 24 días)
  final DateTime fechaVigencia;
  final bool activo;
  final String? pdfUrl;
  final bool esPersonalizado; // Nuevo campo

  const CCTCompleto({
    required this.id,
    required this.numeroCCT,
    required this.nombre,
    required this.descripcion,
    this.actividad,
    required this.categorias,
    required this.descuentos,
    required this.zonas,
    this.adicionalPresentismo = 0.0,
    this.adicionalAntiguedad = 0.0,
    this.porcentajeAntiguedadAnual = 1.0,
    this.horasMensualesDivisor = 192.0,
    this.esDivisorDias = false,
    required this.fechaVigencia,
    this.activo = true,
    this.pdfUrl,
    this.esPersonalizado = false, // Valor por defecto
  });

  factory CCTCompleto.fromJson(Map<String, dynamic> json) {
    return CCTCompleto(
      id: json['id'] as String,
      numeroCCT: json['numeroCCT'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String,
      actividad: json['actividad'] as String?,
      categorias: (json['categorias'] as List<dynamic>)
          .map((e) => CategoriaCCT.fromJson(e as Map<String, dynamic>))
          .toList(),
      descuentos: (json['descuentos'] as List<dynamic>)
          .map((e) => DescuentoCCT.fromJson(e as Map<String, dynamic>))
          .toList(),
      zonas: (json['zonas'] as List<dynamic>)
          .map((e) => ZonaCCT.fromJson(e as Map<String, dynamic>))
          .toList(),
      adicionalPresentismo: (json['adicionalPresentismo'] as num?)?.toDouble() ?? 0.0,
      adicionalAntiguedad: (json['adicionalAntiguedad'] as num?)?.toDouble() ?? 0.0,
      porcentajeAntiguedadAnual: (json['porcentajeAntiguedadAnual'] as num?)?.toDouble() ?? 1.0,
      horasMensualesDivisor: (json['horasMensualesDivisor'] as num?)?.toDouble() ?? 192.0,
      esDivisorDias: json['esDivisorDias'] as bool? ?? false,
      fechaVigencia: DateTime.parse(json['fechaVigencia'] as String),
      activo: json['activo'] as bool? ?? true,
      pdfUrl: json['pdfUrl'] as String?,
      esPersonalizado: json['esPersonalizado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numeroCCT': numeroCCT,
      'nombre': nombre,
      'descripcion': descripcion,
      'actividad': actividad,
      'categorias': categorias.map((e) => e.toJson()).toList(),
      'descuentos': descuentos.map((e) => e.toJson()).toList(),
      'zonas': zonas.map((e) => e.toJson()).toList(),
      'adicionalPresentismo': adicionalPresentismo,
      'adicionalAntiguedad': adicionalAntiguedad,
      'porcentajeAntiguedadAnual': porcentajeAntiguedadAnual,
      'horasMensualesDivisor': horasMensualesDivisor,
      'esDivisorDias': esDivisorDias,
      'fechaVigencia': fechaVigencia.toIso8601String(),
      'activo': activo,
      'pdfUrl': pdfUrl,
      'esPersonalizado': esPersonalizado,
    };
  }

  CCTCompleto copyWith({
    String? id,
    String? numeroCCT,
    String? nombre,
    String? descripcion,
    String? actividad,
    List<CategoriaCCT>? categorias,
    List<DescuentoCCT>? descuentos,
    List<ZonaCCT>? zonas,
    double? adicionalPresentismo,
    double? adicionalAntiguedad,
    double? porcentajeAntiguedadAnual,
    double? horasMensualesDivisor,
    bool? esDivisorDias,
    DateTime? fechaVigencia,
    bool? activo,
    String? pdfUrl,
    bool? esPersonalizado,
  }) {
    return CCTCompleto(
      id: id ?? this.id,
      numeroCCT: numeroCCT ?? this.numeroCCT,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      actividad: actividad ?? this.actividad,
      categorias: categorias ?? this.categorias,
      descuentos: descuentos ?? this.descuentos,
      zonas: zonas ?? this.zonas,
      adicionalPresentismo: adicionalPresentismo ?? this.adicionalPresentismo,
      adicionalAntiguedad: adicionalAntiguedad ?? this.adicionalAntiguedad,
      porcentajeAntiguedadAnual: porcentajeAntiguedadAnual ?? this.porcentajeAntiguedadAnual,
      horasMensualesDivisor: horasMensualesDivisor ?? this.horasMensualesDivisor,
      esDivisorDias: esDivisorDias ?? this.esDivisorDias,
      fechaVigencia: fechaVigencia ?? this.fechaVigencia,
      activo: activo ?? this.activo,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      esPersonalizado: esPersonalizado ?? this.esPersonalizado,
    );
  }
}
