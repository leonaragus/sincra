import 'dart:convert';

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
      codigo: json['codigo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      cantidad: json['cantidad']?.toString() ?? '',
      monto: (json['monto'] is int)
          ? (json['monto'] as int).toDouble()
          : (json['monto'] as double? ?? 0.0),
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
      codigo: json['codigo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      porcentaje: json['porcentaje']?.toString() ?? '',
      monto: (json['monto'] is int)
          ? (json['monto'] as int).toDouble()
          : (json['monto'] as double? ?? 0.0),
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
      descripcion: json['descripcion'] ?? '',
      monto: (json['monto'] is int)
          ? (json['monto'] as int).toDouble()
          : (json['monto'] as double? ?? 0.0),
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
      totalBruto: (json['total_bruto'] is int)
          ? (json['total_bruto'] as int).toDouble()
          : (json['total_bruto'] as double? ?? 0.0),
      totalRetenciones: (json['total_retenciones'] is int)
          ? (json['total_retenciones'] as int).toDouble()
          : (json['total_retenciones'] as double? ?? 0.0),
      totalNoRemunerativo: (json['total_no_remunerativo'] is int)
          ? (json['total_no_remunerativo'] as int).toDouble()
          : (json['total_no_remunerativo'] as double? ?? 0.0),
      netoACobrar: (json['neto_a_cobrar'] is int)
          ? (json['neto_a_cobrar'] as int).toDouble()
          : (json['neto_a_cobrar'] as double? ?? 0.0),
      netoEnLetras: json['neto_en_letras'] ?? '',
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
      analisisLegal: json['analisis_legal'] ?? '',
      alertasCriticas: (json['alertas_criticas'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      explicacionConceptosComplejos:
          json['explicacion_conceptos_complejos'] ?? '',
      puntuacionConfianzaOcr: (json['puntuacion_confianza_ocr'] is int)
          ? (json['puntuacion_confianza_ocr'] as int).toDouble()
          : (json['puntuacion_confianza_ocr'] as double? ?? 0.0),
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
