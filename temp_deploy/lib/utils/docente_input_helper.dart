// Helper para construir DocenteOmniInput desde institución y legajo (pantallas SAC, Vacaciones, Final, Proporcional).

import '../models/teacher_types.dart';
import '../services/teacher_omni_engine.dart' show DocenteOmniInput, ConceptoPropioOmni;

/// Resultado: input para TeacherOmniEngine y conceptos propios del legajo.
({DocenteOmniInput input, List<ConceptoPropioOmni> conceptosPropios}) buildDocenteOmniInputFromMaps({
  required Map<String, dynamic> inst,
  required Map<String, dynamic> legajo,
}) {
  final j = inst['jurisdiccion']?.toString();
  final jurisdiccion = Jurisdiccion.values.cast<Jurisdiccion?>().firstWhere(
    (e) => e?.name == j,
    orElse: () => Jurisdiccion.buenosAires,
  ) ?? Jurisdiccion.buenosAires;

  final tg = inst['tipoGestion']?.toString();
  final tipoGestion = TipoGestion.values.cast<TipoGestion?>().firstWhere(
    (e) => e?.name == tg,
    orElse: () => TipoGestion.publica,
  ) ?? TipoGestion.publica;

  DateTime fechaIngreso = DateTime(2023, 1, 15);
  final fi = legajo['fechaIngreso']?.toString();
  if (fi != null && fi.isNotEmpty) {
    final d = DateTime.tryParse(fi);
    if (d != null) fechaIngreso = d;
  }

  final c = legajo['cargo']?.toString();
  final cargo = TipoNomenclador.values.cast<TipoNomenclador?>().firstWhere(
    (e) => e?.name == c,
    orElse: () => TipoNomenclador.maestroGrado,
  ) ?? TipoNomenclador.maestroGrado;

  final z = legajo['zona']?.toString();
  final zona = ZonaDesfavorable.values.cast<ZonaDesfavorable?>().firstWhere(
    (e) => e?.name == z,
    orElse: () => ZonaDesfavorable.a,
  ) ?? ZonaDesfavorable.a;

  final n = legajo['nivel']?.toString();
  final nivel = NivelEducativo.values.cast<NivelEducativo?>().firstWhere(
    (e) => e?.name == n,
    orElse: () => NivelEducativo.primario,
  ) ?? NivelEducativo.primario;

  final nu = legajo['nivelUbicacion']?.toString();
  final nivelUbicacion = NivelUbicacion.values.cast<NivelUbicacion?>().firstWhere(
    (e) => e?.name == nu,
    orElse: () => NivelUbicacion.urbana,
  ) ?? NivelUbicacion.urbana;

  final List<ConceptoPropioOmni> conceptosPropios = [];
  final L = legajo['conceptosPropiosActivos'];
  if (L is List) {
    for (final m in L) {
      if (m is! Map) continue;
      final mont = (m['monto'] is num)
          ? (m['monto'] as num).toDouble()
          : (double.tryParse(m['monto']?.toString() ?? '') ?? 0.0);
      conceptosPropios.add(ConceptoPropioOmni(
        codigo: (m['nombre'] ?? '').toString().replaceAll(RegExp(r'[^\w]'), '_'),
        descripcion: m['nombre']?.toString() ?? '',
        monto: mont,
        esRemunerativo: (m['naturaleza']?.toString() ?? 'remunerativo') == 'remunerativo',
        codigoAfip: m['codigoAfipArca']?.toString() ?? '011000',
      ));
    }
  }

  final pco = legajo['puntosCargoOverride'];
  final pho = legajo['puntosHoraCatedraOverride'];

  final valorIndiceRaw = legajo['valorIndice']?.toString().trim();
  final valorIndiceOverride = (valorIndiceRaw != null && valorIndiceRaw.isNotEmpty)
      ? double.tryParse(valorIndiceRaw.replaceAll(',', '.'))
      : null;

  final sbRaw = legajo['sueldoBasicoOverride']?.toString().trim();
  final sueldoBasicoOverride = (sbRaw != null && sbRaw.isNotEmpty)
      ? double.tryParse(sbRaw.replaceAll(',', '.'))
      : null;

  final input = DocenteOmniInput(
    nombre: legajo['nombre']?.toString() ?? '',
    cuil: legajo['cuil']?.toString() ?? '',
    jurisdiccion: jurisdiccion,
    tipoGestion: tipoGestion,
    cargoNomenclador: cargo,
    nivelEducativo: nivel,
    fechaIngreso: fechaIngreso,
    cargasFamiliares: (legajo['cargasFamiliares'] is int)
        ? legajo['cargasFamiliares'] as int
        : (int.tryParse(legajo['cargasFamiliares']?.toString() ?? '') ?? 0),
    codigoRnos: (legajo['codigoRnos']?.toString() ?? '').trim().isEmpty
        ? null
        : legajo['codigoRnos']?.toString().trim(),
    horasCatedra: (legajo['horasCatedra'] is int)
        ? legajo['horasCatedra'] as int
        : (int.tryParse(legajo['horasCatedra']?.toString() ?? '') ?? 0),
    zona: zona,
    nivelUbicacion: nivelUbicacion,
    valorIndiceOverride: valorIndiceOverride,
    sueldoBasicoOverride: sueldoBasicoOverride,
    puntosCargoOverride: pco is int ? pco : (pco != null ? int.tryParse(pco.toString()) : null),
    puntosHoraCatedraOverride: pho is int ? pho : (pho != null ? int.tryParse(pho.toString()) : null),
    esHoraCatedraSecundaria: cargo == TipoNomenclador.horaCatedraMedia,
  );
  return (input: input, conceptosPropios: conceptosPropios);
}
