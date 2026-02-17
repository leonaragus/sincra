import 'package:elevar_liquidacion/services/cct_cloud_service.dart';

class ReciboEscaneado {
  final List<ConceptoRecibo> conceptos;
  final double totalRemunerativo;
  final double totalNoRemunerativo;
  final double totalDeducciones;
  final double sueldoNeto;
  // Posibles metadatos extraídos
  final String? cuitEmpleador;
  final String? nombreEmpleado;
  final String? cuilEmpleado;
  final String? periodo;
  final String? cctAplicable;
  final String? cctCodigo;
  final String? cctNombre;
  final CCTMaster? cctMaster;

  ReciboEscaneado({
    this.conceptos = const [],
    this.totalRemunerativo = 0.0,
    this.totalNoRemunerativo = 0.0,
    this.totalDeducciones = 0.0,
    this.sueldoNeto = 0.0,
    this.cuitEmpleador,
    this.nombreEmpleado,
    this.cuilEmpleado,
    this.periodo,
    this.cctAplicable,
    this.cctCodigo,
    this.cctNombre,
    this.cctMaster,
  });
}

class ConceptoRecibo {
  final String descripcion;
  final double? remunerativo;
  final double? noRemunerativo;
  final double? deducciones;

  ConceptoRecibo({
    required this.descripcion,
    this.remunerativo,
    this.noRemunerativo,
    this.deducciones,
  });
}