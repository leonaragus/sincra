// ========================================================================
// PlantillaCargoOmni - Plantillas Inteligentes de Cargo (liquidación 2026)
// Solo estructura numérica: puntos, índices, porcentajes. SIN nombre ni CUIL.
// Clave: perfilCargoId = [jurisdiccion]_[tipoGestion]_[tipoNomenclador]_[antigüedad]_[zona]_[nivelUbicacion]
// ========================================================================

import 'teacher_types.dart';
import 'ocr_confirm_result.dart';

/// Plantilla de perfil salarial por cargo. Identificación anónima vía perfilCargoId.
/// No se persisten nombres ni CUIL.
class PlantillaCargoOmni {
  final String perfilCargoId;
  final double? valorIndice;
  final double? sueldoBasico;
  final int? puntos;
  final double? antiguedadPct;

  const PlantillaCargoOmni({
    required this.perfilCargoId,
    this.valorIndice,
    this.sueldoBasico,
    this.puntos,
    this.antiguedadPct,
  });

  /// Genera el ID compuesto (ADN de cargo) para identificar perfiles idénticos de forma anónima.
  /// [antiguedadAnos] = años de antigüedad (p. ej. desde fechaIngreso).
  static String buildPerfilCargoId({
    required Jurisdiccion jurisdiccion,
    required TipoGestion tipoGestion,
    required TipoNomenclador tipoNomenclador,
    required int antiguedadAnos,
    required ZonaDesfavorable zona,
    required NivelUbicacion nivelUbicacion,
  }) {
    return '${jurisdiccion.name}_${tipoGestion.name}_${tipoNomenclador.name}_${antiguedadAnos}_${zona.name}_${nivelUbicacion.name}';
  }

  /// Genera perfilCargoId desde OcrConfirmResult. Usa [fallbackJurisdiccion] si viene null; nivelUbicacion=urbana.
  static String fromOcrConfirmResult(OcrConfirmResult r, {Jurisdiccion fallbackJurisdiccion = Jurisdiccion.buenosAires}) {
    final j = r.jurisdiccion ?? fallbackJurisdiccion;
    final tg = r.tipoGestion ?? TipoGestion.publica;
    final cargo = r.cargo ?? TipoNomenclador.maestroGrado;
    final zona = r.zona ?? ZonaDesfavorable.a;
    int anos = 0;
    if (r.fechaIngreso != null) {
      final ahora = DateTime.now();
      anos = ahora.year - r.fechaIngreso!.year;
      if (ahora.month < r.fechaIngreso!.month || (ahora.month == r.fechaIngreso!.month && ahora.day < r.fechaIngreso!.day)) anos--;
      if (anos < 0) anos = 0;
    }
    return buildPerfilCargoId(jurisdiccion: j, tipoGestion: tg, tipoNomenclador: cargo, antiguedadAnos: anos, zona: zona, nivelUbicacion: NivelUbicacion.urbana);
  }

  /// Etiqueta corta para UI: "Cargo, Zona X, N años".
  static String labelCorto(String perfilCargoId) {
    final p = perfilCargoId.split('_');
    if (p.length < 6) return perfilCargoId;
    final cargo = p[2].replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m.group(0)!.toUpperCase());
    return '$cargo, Zona ${p[4]}, ${p[3]} años';
  }

  Map<String, dynamic> toMap() {
    return {
      'perfilCargoId': perfilCargoId,
      if (valorIndice != null) 'valorIndice': valorIndice,
      if (sueldoBasico != null) 'sueldoBasico': sueldoBasico,
      if (puntos != null) 'puntos': puntos,
      if (antiguedadPct != null) 'antiguedadPct': antiguedadPct,
    };
  }

  static PlantillaCargoOmni fromMap(Map<String, dynamic> m) {
    return PlantillaCargoOmni(
      perfilCargoId: m['perfilCargoId']?.toString() ?? '',
      valorIndice: _toDouble(m['valorIndice']),
      sueldoBasico: _toDouble(m['sueldoBasico']),
      puntos: _toInt(m['puntos']),
      antiguedadPct: _toDouble(m['antiguedadPct']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.');
    return double.tryParse(s);
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}
