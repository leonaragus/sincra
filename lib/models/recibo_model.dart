// import 'dart:convert';

class ReciboModel {
  final Cabecera cabecera;
  final LiquidacionDetallada liquidacionDetallada;
  final Totales totales;
  final AuditoriaIA auditoriaIA;

  ReciboModel({
    required this.cabecera,
    required this.liquidacionDetallada,
    required this.totales,
    required this.auditoriaIA,
  });

  factory ReciboModel.fromJson(Map<String, dynamic> json) {
    return ReciboModel(
      cabecera: Cabecera.fromJson(json['cabecera'] ?? {}),
      liquidacionDetallada: LiquidacionDetallada.fromJson(json['liquidacion_detallada'] ?? {}),
      totales: Totales.fromJson(json['totales'] ?? {}),
      auditoriaIA: AuditoriaIA.fromJson(json['auditoria_ia'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cabecera': cabecera.toJson(),
      'liquidacion_detallada': liquidacionDetallada.toJson(),
      'totales': totales.toJson(),
      'auditoria_ia': auditoriaIA.toJson(),
    };
  }
}

class Cabecera {
  final String empresaNombre;
  final String empresaCuit;
  final String empresaDomicilio;
  final String empleadoNombre;
  final String empleadoCuil;
  final String legajo;
  final String fechaIngreso;
  final String antiguedadReconocida;
  final String categoriaProfesional;
  final String cctAplicable;
  final String periodoAbonado;
  final String lugarPago;

  Cabecera({
    this.empresaNombre = '',
    this.empresaCuit = '',
    this.empresaDomicilio = '',
    this.empleadoNombre = '',
    this.empleadoCuil = '',
    this.legajo = '',
    this.fechaIngreso = '',
    this.antiguedadReconocida = '',
    this.categoriaProfesional = '',
    this.cctAplicable = '',
    this.periodoAbonado = '',
    this.lugarPago = '',
  });

  factory Cabecera.fromJson(Map<String, dynamic> json) {
    return Cabecera(
      empresaNombre: json['empresa_nombre'] ?? '',
      empresaCuit: json['empresa_cuit'] ?? '',
      empresaDomicilio: json['empresa_domicilio'] ?? '',
      empleadoNombre: json['empleado_nombre'] ?? '',
      empleadoCuil: json['empleado_cuil'] ?? '',
      legajo: json['legajo'] ?? '',
      fechaIngreso: json['fecha_ingreso'] ?? '',
      antiguedadReconocida: json['antiguedad_reconocida'] ?? '',
      categoriaProfesional: json['categoria_profesional'] ?? '',
      cctAplicable: json['cct_aplicable'] ?? '',
      periodoAbonado: json['periodo_abonado'] ?? '',
      lugarPago: json['lugar_pago'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'empresa_nombre': empresaNombre,
      'empresa_cuit': empresaCuit,
      'empresa_domicilio': empresaDomicilio,
      'empleado_nombre': empleadoNombre,
      'empleado_cuil': empleadoCuil,
      'legajo': legajo,
      'fecha_ingreso': fechaIngreso,
      'antiguedad_reconocida': antiguedadReconocida,
      'categoria_profesional': categoriaProfesional,
      'cct_aplicable': cctAplicable,
      'periodo_abonado': periodoAbonado,
      'lugar_pago': lugarPago,
    };
  }
}

class LiquidacionDetallada {
  final List<ItemHaber> haberes;
  final List<ItemRetencion> retenciones;
  final List<ItemOtro> otrosConceptos;

  LiquidacionDetallada({
    this.haberes = const [],
    this.retenciones = const [],
    this.otrosConceptos = const [],
  });

  factory LiquidacionDetallada.fromJson(Map<String, dynamic> json) {
    return LiquidacionDetallada(
      haberes: (json['haberes'] as List?)
              ?.map((e) => ItemHaber.fromJson(e))
              .toList() ??
          [],
      retenciones: (json['retenciones'] as List?)
              ?.map((e) => ItemRetencion.fromJson(e))
              .toList() ??
          [],
      otrosConceptos: (json['otros_conceptos'] as List?)
              ?.map((e) => ItemOtro.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'haberes': haberes.map((e) => e.toJson()).toList(),
      'retenciones': retenciones.map((e) => e.toJson()).toList(),
      'otros_conceptos': otrosConceptos.map((e) => e.toJson()).toList(),
    };
  }
}

class ItemHaber {
  final String codigo;
  final String descripcion;
  final String cantidad;
  final double monto;
  final bool esRemunerativo;

  ItemHaber({
    this.codigo = '',
    required this.descripcion,
    this.cantidad = '',
    this.monto = 0.0,
    this.esRemunerativo = true,
  });

  factory ItemHaber.fromJson(Map<String, dynamic> json) {
    return ItemHaber(
      codigo: json['codigo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      cantidad: json['cantidad']?.toString() ?? '',
      monto: _parseMonto(json['monto']),
      esRemunerativo: json['es_remunerativo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'cantidad': cantidad,
      'monto': monto,
      'es_remunerativo': esRemunerativo,
    };
  }
}

class ItemRetencion {
  final String codigo;
  final String descripcion;
  final String porcentaje;
  final double monto;

  ItemRetencion({
    this.codigo = '',
    required this.descripcion,
    this.porcentaje = '',
    this.monto = 0.0,
  });

  factory ItemRetencion.fromJson(Map<String, dynamic> json) {
    return ItemRetencion(
      codigo: json['codigo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      porcentaje: json['porcentaje']?.toString() ?? '',
      monto: _parseMonto(json['monto']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'porcentaje': porcentaje,
      'monto': monto,
    };
  }
}

class ItemOtro {
  final String descripcion;
  final double monto;

  ItemOtro({
    required this.descripcion,
    this.monto = 0.0,
  });

  factory ItemOtro.fromJson(Map<String, dynamic> json) {
    return ItemOtro(
      descripcion: json['descripcion']?.toString() ?? '',
      monto: _parseMonto(json['monto']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'descripcion': descripcion,
      'monto': monto,
    };
  }
}

class Totales {
  final double totalBruto;
  final double totalRetenciones;
  final double totalNoRemunerativo;
  final double netoACobrar;
  final String netoEnLetras;

  Totales({
    this.totalBruto = 0.0,
    this.totalRetenciones = 0.0,
    this.totalNoRemunerativo = 0.0,
    this.netoACobrar = 0.0,
    this.netoEnLetras = '',
  });

  factory Totales.fromJson(Map<String, dynamic> json) {
    return Totales(
      totalBruto: _parseMonto(json['total_bruto']),
      totalRetenciones: _parseMonto(json['total_retenciones']),
      totalNoRemunerativo: _parseMonto(json['total_no_remunerativo']),
      netoACobrar: _parseMonto(json['neto_a_cobrar']),
      netoEnLetras: json['neto_en_letras']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_bruto': totalBruto,
      'total_retenciones': totalRetenciones,
      'total_no_remunerativo': totalNoRemunerativo,
      'neto_a_cobrar': netoACobrar,
      'neto_en_letras': netoEnLetras,
    };
  }
}

class AuditoriaIA {
  final String analisisLegal;
  final List<String> alertasCriticas;
  final String explicacionConceptosComplejos;
  final double puntuacionConfianzaOcr;

  AuditoriaIA({
    this.analisisLegal = '',
    this.alertasCriticas = const [],
    this.explicacionConceptosComplejos = '',
    this.puntuacionConfianzaOcr = 0.0,
  });

  factory AuditoriaIA.fromJson(Map<String, dynamic> json) {
    return AuditoriaIA(
      analisisLegal: json['analisis_legal']?.toString() ?? '',
      alertasCriticas: (json['alertas_criticas'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      explicacionConceptosComplejos:
          json['explicacion_conceptos_complejos']?.toString() ?? '',
      puntuacionConfianzaOcr: _parseMonto(json['puntuacion_confianza_ocr']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analisis_legal': analisisLegal,
      'alertas_criticas': alertasCriticas,
      'explicacion_conceptos_complejos': explicacionConceptosComplejos,
      'puntuacion_confianza_ocr': puntuacionConfianzaOcr,
    };
  }
}

/// Helper para parsear montos robustamente (acepta num, String, formato AR, formato US)
double _parseMonto(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  String s = v.toString().trim();
  if (s.isEmpty) return 0.0;

  // 1. Intento parseo directo (formato estándar 1234.56)
  final d = double.tryParse(s);
  if (d != null) return d;

  // 2. Limpieza de símbolos ($ y espacios)
  s = s.replaceAll(RegExp(r'[^\d.,-]'), '');

  // 3. Heurística para separadores
  if (s.contains(',') && s.contains('.')) {
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      // Formato AR/EU: 1.234,56 -> Quitar puntos, cambiar coma por punto
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Formato US: 1,234.56 -> Quitar comas
      s = s.replaceAll(',', '');
    }
  } else if (s.contains(',')) {
    // Asumimos coma como decimal (estándar local más probable si viene como texto)
    s = s.replaceAll(',', '.');
  }
  // Si solo tiene puntos (1.234), double.tryParse arriba ya lo manejó como 1.234.
  // Si era 1.234 (mil), mala suerte, pero en JSON numérico el punto es decimal.

  return double.tryParse(s) ?? 0.0;
}
