// Resultado de OcrReviewScreen al confirmar: datos docente, overrides y si se actualizó la jurisdicción.
// TeacherInterfaceScreen construye DatosDocenteLiquidacion desde estos campos.

import '../models/teacher_types.dart';
import '../services/teacher_receipt_scan_service.dart' show DocenteOmniOverrides;

class OcrConfirmResult {
  final String? nombre;
  final String? cuil;
  final Jurisdiccion? jurisdiccion;
  final TipoGestion? tipoGestion;
  final TipoNomenclador? cargo;
  final NivelEducativo? nivel;
  final ZonaDesfavorable? zona;
  final DateTime? fechaIngreso;
  final int? cargasFamiliares;
  final int? horasCatedra;
  final int? cantidadCargos;
  final String? codigoRnos;
  final double? aporteEstatal;

  final DocenteOmniOverrides overrides;
  final bool updateJurisdiccion;
  final Jurisdiccion jurisdiccionActualizada;

  const OcrConfirmResult({
    this.nombre,
    this.cuil,
    this.jurisdiccion,
    this.tipoGestion,
    this.cargo,
    this.nivel,
    this.zona,
    this.fechaIngreso,
    this.cargasFamiliares,
    this.horasCatedra,
    this.cantidadCargos,
    this.codigoRnos,
    this.aporteEstatal,
    required this.overrides,
    required this.updateJurisdiccion,
    required this.jurisdiccionActualizada,
  });
}
