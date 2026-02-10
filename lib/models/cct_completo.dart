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
  });

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
    );
  }
}
