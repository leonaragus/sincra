// ========================================================================
// ESTRATEGIAS DE CAJA PREVISIONAL - Patrón Strategy para ARCA/AFIP
// RegimenNacional (ANSES): 11% Jub, 3% OS, 3% PAMI
// RegimenProvincialNeuquen (ISSN): 14.5% Jub, 5.5% Asistencial/OS
// ========================================================================

import 'package:decimal/decimal.dart';

/// Resultado de aportes (Jubilación, Obra Social, PAMI) en Decimal para precisión contable.
class AportesResult {
  final Decimal jubilacion;
  final Decimal obraSocial;
  final Decimal pami;

  AportesResult({required this.jubilacion, required this.obraSocial, required this.pami});

  double get jubilacionDouble => jubilacion.toDouble();
  double get obraSocialDouble => obraSocial.toDouble();
  double get pamiDouble => pami.toDouble();
}

/// Estrategia de cálculo de aportes previsionales. La base ya debe venir topeada (≤ tope 2026).
abstract class CajaPrevisionalStrategy {
  /// Calcula Jubilación, Obra Social y PAMI sobre [baseTopeada].
  /// Lanza [ArgumentError] si baseTopeada &lt; 0.
  AportesResult calcular(Decimal baseTopeada);
}

/// Régimen Nacional: ANSES 11% Jubilación, 3% Obra Social, 3% PAMI (Ley 19.032).
class RegimenNacionalStrategy implements CajaPrevisionalStrategy {
  static final Decimal _pctJub = Decimal.parse('0.11');
  static final Decimal _pctOS = Decimal.parse('0.03');
  static final Decimal _pctPami = Decimal.parse('0.03');

  static Decimal _redondear2(Decimal x) =>
      (x * Decimal.fromInt(100)).round() * Decimal.parse('0.01');

  @override
  AportesResult calcular(Decimal baseTopeada) {
    if (baseTopeada < Decimal.zero) {
      throw ArgumentError('PayrollCore: la base imponible no puede ser negativa. Recibido: $baseTopeada');
    }
    return AportesResult(
      jubilacion: _redondear2(baseTopeada * _pctJub),
      obraSocial: _redondear2(baseTopeada * _pctOS),
      pami: _redondear2(baseTopeada * _pctPami),
    );
  }
}

/// Régimen Provincial Neuquén (ISSN): 14.5% Jubilación, 5.5% Obra Social/Asistencial, 3% PAMI.
class RegimenProvincialNeuquenStrategy implements CajaPrevisionalStrategy {
  static final Decimal _pctJub = Decimal.parse('0.145');
  static final Decimal _pctOS = Decimal.parse('0.055');
  static final Decimal _pctPami = Decimal.parse('0.03');

  static Decimal _redondear2(Decimal x) =>
      (x * Decimal.fromInt(100)).round() * Decimal.parse('0.01');

  @override
  AportesResult calcular(Decimal baseTopeada) {
    if (baseTopeada < Decimal.zero) {
      throw ArgumentError('PayrollCore: la base imponible no puede ser negativa. Recibido: $baseTopeada');
    }
    return AportesResult(
      jubilacion: _redondear2(baseTopeada * _pctJub),
      obraSocial: _redondear2(baseTopeada * _pctOS),
      pami: _redondear2(baseTopeada * _pctPami),
    );
  }
}
