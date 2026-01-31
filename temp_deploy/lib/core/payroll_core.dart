// ========================================================================
// PAYROLL CORE - Núcleo contable con Decimal y validaciones ARCA/AFIP
// - Tipado estricto: Decimal para montos (evita redondeo)
// - Estrategia de Caja: RegimenNacional | RegimenProvincialNeuquen
// - Excepción si monto negativo o CUIL/CUIT inválido (Módulo 11)
// - Topes previsionales Enero 2026: ningún aporte sobre excedente de $2.500.000
// ========================================================================

import 'package:decimal/decimal.dart';

import '../utils/validadores.dart';
import 'caja_previsional_strategy.dart';

/// Tope previsional ARCA/AFIP Enero 2026 (aprox. $2.500.000). Ningún aporte se calcula sobre el excedente.
const double topePrevisional2026 = 2500000.0;

/// Excepción cuando un cálculo produce un valor negativo.
class PayrollValorNegativoException implements Exception {
  final String paso;
  final dynamic valor;

  PayrollValorNegativoException(this.paso, this.valor);

  @override
  String toString() => 'PayrollValorNegativo: en "$paso" se obtuvo un valor negativo o inválido: $valor';
}

/// Excepción cuando CUIL o CUIT no pasa el algoritmo Módulo 11.
class PayrollCUILCUITInvalidoException implements Exception {
  final String numero;
  final String contexto;

  PayrollCUILCUITInvalidoException(this.numero, [this.contexto = '']);

  @override
  String toString() => 'PayrollCUILCUITInvalido: $numero no cumple Módulo 11. $contexto';
}

/// Núcleo de cálculo con Decimal. Validaciones estrictas y estrategia de caja.
class PayrollCore {
  final CajaPrevisionalStrategy _strategy;
  final Decimal _topePrevisional;

  PayrollCore({
    required CajaPrevisionalStrategy strategy,
    double topePrevisional = topePrevisional2026,
  })  : _strategy = strategy,
        _topePrevisional = Decimal.parse(topePrevisional.toString());

  /// Valida CUIL o CUIT con Módulo 11. Lanza [PayrollCUILCUITInvalidoException] si falla.
  static void validarCUILCUIT(String numero, [String contexto = '']) {
    final limpio = numero.replaceAll(RegExp(r'[^\d]'), '');
    if (limpio.length != 11) {
      throw PayrollCUILCUITInvalidoException(numero, 'Debe tener 11 dígitos. $contexto');
    }
    if (!validarCUITCUIL(numero)) {
      throw PayrollCUILCUITInvalidoException(numero, 'No pasa validación Módulo 11. $contexto');
    }
  }

  /// Garantiza que un monto no sea negativo. Lanza [PayrollValorNegativoException] si lo es.
  static void requireNoNegativo(num valor, String paso) {
    if (valor < 0) throw PayrollValorNegativoException(paso, valor);
  }

  /// Aplica tope previsional: min(base, tope). El resultado es el máximo sobre el que se calculan aportes.
  Decimal aplicarTopePrevisional(Decimal base) {
    if (base < Decimal.zero) throw PayrollValorNegativoException('aplicarTopePrevisional', base);
    return base > _topePrevisional ? _topePrevisional : base;
  }

  /// Calcula aportes (Jub, OS, PAMI) sobre la base ya topeada. Nunca sobre el excedente del tope.
  /// [baseBruta] se topea internamente; los aportes se calculan solo sobre el tope.
  AportesResult aportes(Decimal baseBruta) {
    final base = aplicarTopePrevisional(baseBruta);
    return _strategy.calcular(base);
  }

  /// Versión que acepta [double] y devuelve (jub, os, pami) en double para compatibilidad.
  (double jub, double os, double pami) aportesFromDouble(double baseBruta) {
    final d = Decimal.parse(baseBruta.toString());
    final r = aportes(d);
    return (r.jubilacionDouble, r.obraSocialDouble, r.pamiDouble);
  }
}
