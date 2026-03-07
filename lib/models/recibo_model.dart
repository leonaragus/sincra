import 'package:flutter/foundation.dart';

@immutable
class ReciboModel {
  final String textoCrudo; // JSON original de la IA
  final CabeceraRecibo cabecera;
  final LiquidacionDetallada liquidacionDetallada;
  final TotalesRecibo totales;
  final InferenciasRecibo inferencias;
  final AuditoriaIa auditoriaIa;

  const ReciboModel({
    required this.textoCrudo,
    required this.cabecera,
    required this.liquidacionDetallada,
    required this.totales,
    required this.inferencias,
    required this.auditoriaIa,
  });

  ReciboModel copyWith({
    String? textoCrudo,
    CabeceraRecibo? cabecera,
    LiquidacionDetallada? liquidacionDetallada,
    TotalesRecibo? totales,
    InferenciasRecibo? inferencias,
    AuditoriaIa? auditoriaIa,
  }) {
    return ReciboModel(
      textoCrudo: textoCrudo ?? this.textoCrudo,
      cabecera: cabecera ?? this.cabecera,
      liquidacionDetallada: liquidacionDetallada ?? this.liquidacionDetallada,
      totales: totales ?? this.totales,
      inferencias: inferencias ?? this.inferencias,
      auditoriaIa: auditoriaIa ?? this.auditoriaIa,
    );
  }
}

@immutable
class CabeceraRecibo {
  final String? empleadoCuil;
  final String? empleadoNombre;
  final String? empresaCuit;
  final String? empresaNombre;
  final String? empresaDomicilio;
  final String? fechaIngreso;
  final String? categoriaProfesional;
  final String? periodoAbonado;

  const CabeceraRecibo({
    this.empleadoCuil,
    this.empleadoNombre,
    this.empresaCuit,
    this.empresaNombre,
    this.empresaDomicilio,
    this.fechaIngreso,
    this.categoriaProfesional,
    this.periodoAbonado,
  });
}

@immutable
class LiquidacionDetallada {
  final List<ConceptoRecibo> haberes;
  final List<ConceptoRecibo> retenciones;
  final List<ConceptoRecibo> otrosConceptos;

  const LiquidacionDetallada({
    required this.haberes, 
    required this.retenciones,
    this.otrosConceptos = const [],
  });
}

@immutable
class ConceptoRecibo {
  final String? codigo;
  final String descripcion;
  final String? cantidad;
  final double monto;
  final bool esRemunerativo;
  final String? porcentaje;

  const ConceptoRecibo({
    this.codigo,
    required this.descripcion,
    this.cantidad,
    required this.monto,
    this.esRemunerativo = true,
    this.porcentaje,
  });
}

@immutable
class TotalesRecibo {
  final double totalBruto;
  final double totalRetenciones;
  final double netoACobrar;

  const TotalesRecibo({
    required this.totalBruto,
    required this.totalRetenciones,
    required this.netoACobrar,
  });
}

@immutable
class InferenciasRecibo {
  final String convenioSugerido;
  final String confianza;
  final int? healthScore;

  const InferenciasRecibo({required this.convenioSugerido, required this.confianza, this.healthScore});
}

@immutable
class AuditoriaIa {
  final String analisisGeneral;
  final List<AlertaIa> alertas;
  final List<ExplicacionIa> explicacionesItems;

  const AuditoriaIa({
    required this.analisisGeneral,
    required this.alertas,
    required this.explicacionesItems,
  });
}

@immutable
class AlertaIa {
  final String titulo;
  final String descripcion;
  final String severidad; // 'baja', 'media', 'alta', 'informativa'

  const AlertaIa({required this.titulo, required this.descripcion, required this.severidad});
}

@immutable
class ExplicacionIa {
  final String concepto;
  final String detalle;
  final String tipo; // 'ok', 'info', 'mejora', 'destacado', 'haber'
  final double? monto; // <-- CAMBIO: Añadido para mostrar montos en la UI

  const ExplicacionIa({required this.concepto, required this.detalle, required this.tipo, this.monto});
}
