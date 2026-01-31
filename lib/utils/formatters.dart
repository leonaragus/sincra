// Formateo numérico unificado: formato argentino (coma decimal).
// Soporta punto (PC) o coma (celular) en entrada y normaliza automáticamente.
// - Valor Índice: hasta 6 decimales.
// - Montos/porcentajes: 2 decimales.

import 'package:flutter/services.dart';

/// Formateador numérico para la app. Formato argentino (coma decimal).
/// Detecta punto (teclado PC) o coma (celular) y normaliza a coma para visualización.
/// Para cálculos: usar `valor.replaceAll(',', '.')` antes de `double.tryParse`.
class AppNumberFormatter {
  static const int _decimalsValorIndice = 6;
  static const int _decimalsMonetario = 2;

  /// Formatea [value] para visualización o para asignar a controllers (carga desde DB/OCR).
  /// [valorIndice] true: hasta 6 decimales (valor índice); false: 2 decimales (montos, %).
  /// [value] puede ser num, String o null. Acepta "1.5" o "1,5" y normaliza a "1,5" / "1,50".
  static String format(dynamic value, {bool valorIndice = false}) {
    if (value == null) return '';
    if (value is num) {
      final d = value.toDouble();
      if (d.isNaN || d.isInfinite) return '';
      final dec = valorIndice ? _decimalsValorIndice : _decimalsMonetario;
      return d.toStringAsFixed(dec).replaceAll('.', ',');
    }
    if (value is String) {
      final d = _parseDouble(value);
      if (d != null) {
        final dec = valorIndice ? _decimalsValorIndice : _decimalsMonetario;
        return d.toStringAsFixed(dec).replaceAll('.', ',');
      }
      return _normalizeInput(value, valorIndice);
    }
    return '';
  }

  static double? _parseDouble(String s) {
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  /// Normaliza input: acepta punto o coma como decimal, convierte a coma (AR).
  /// Solo dígitos, una coma (o punto convertido a coma), opcional - al inicio.
  /// Limita decimales: [valorIndice] 6, si no 2.
  static String _normalizeInput(String text, bool valorIndice) {
    if (text.isEmpty) return '';
    final maxDec = valorIndice ? _decimalsValorIndice : _decimalsMonetario;
    // Unificar: both . and , → coma para trabajar en un solo separador
    String s = text.replaceAll('.', ',');
    final buf = StringBuffer();
    bool foundComma = false;
    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '-' && buf.isEmpty) {
        buf.write(c);
        continue;
      }
      if (c == ',' && !foundComma) {
        foundComma = true;
        buf.write(',');
        continue;
      }
      if (c == ',') continue; // descartar comas extra
      if (RegExp(r'[0-9]').hasMatch(c)) buf.write(c);
    }
    s = buf.toString();
    final idx = s.indexOf(',');
    if (idx >= 0 && idx < s.length - 1) {
      String dec = s.substring(idx + 1);
      if (dec.length > maxDec) dec = dec.substring(0, maxDec);
      s = s.substring(0, idx + 1) + dec;
    }
    return s;
  }

  /// TextInputFormatter para usar en [inputFormatters]. Normaliza punto/coma en tiempo real.
  /// [valorIndice] true: hasta 6 decimales; false: 2 (montos, %).
  static TextInputFormatter inputFormatter({bool valorIndice = false}) =>
      _AppNumberInputFormatter(valorIndice);

  /// Convierte un número a letras (estilo Argentina para recibos de sueldo)
  static String numeroALetras(double numero) {
    if (numero == 0) return 'CERO PESOS';
    
    final partes = numero.toStringAsFixed(2).split('.');
    final enteros = int.parse(partes[0]);
    final centavos = int.parse(partes[1]);
    
    String resultado = _convertirEnteros(enteros);
    
    if (enteros == 1) {
      resultado += ' PESO';
    } else {
      resultado += ' PESOS';
    }
    
    if (centavos > 0) {
      resultado += ' CON ${_convertirEnteros(centavos)} CENTAVOS';
    }
    
    return resultado.toUpperCase();
  }

  static String _convertirEnteros(int n) {
    if (n == 0) return 'CERO';
    if (n < 0) return 'ERROR';

    final unidades = ["", "UN", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE"];
    final especiales = ["DIEZ", "ONCE", "DOCE", "TRECE", "CATORCE", "QUINCE", "DIECISÉIS", "DIECISIETE", "DIECIOCHO", "DIECINUEVE"];
    final decenas = ["", "DIEZ", "VEINTE", "TREINTA", "CUARENTA", "CINCUENTA", "SESENTA", "SETENTA", "OCHENTA", "NOVENTA"];
    final centenas = ["", "CIENTO", "DOSCIENTOS", "TRESCIENTOS", "CUATROCIENTOS", "QUINIENTOS", "SEISCIENTOS", "SETECIENTOS", "OCHOCIENTOS", "NOVECIENTOS"];

    if (n < 10) return unidades[n];
    if (n < 20) return especiales[n - 10];
    if (n < 100) {
      final d = n ~/ 10;
      final u = n % 10;
      if (u == 0) return decenas[d];
      if (d == 2) return 'VEINTI${unidades[u]}';
      return '${decenas[d]} Y ${unidades[u]}';
    }
    if (n < 1000) {
      final c = n ~/ 100;
      final resto = n % 100;
      if (c == 1 && resto == 0) return "CIEN";
      if (resto == 0) return centenas[c];
      return "${centenas[c]} ${ _convertirEnteros(resto)}";
    }
    if (n < 1000000) {
      final m = n ~/ 1000;
      final resto = n % 1000;
      if (m == 1) return "MIL ${ _convertirEnteros(resto)}";
      return "${_convertirEnteros(m)} MIL ${ _convertirEnteros(resto)}";
    }
    if (n < 1000000000) {
      final mill = n ~/ 1000000;
      final resto = n % 1000000;
      if (mill == 1) return "UN MILLÓN ${ _convertirEnteros(resto)}";
      return "${_convertirEnteros(mill)} MILLONES ${ _convertirEnteros(resto)}";
    }

    return n.toString();
  }
}

class _AppNumberInputFormatter extends TextInputFormatter {
  final bool _valorIndice;

  _AppNumberInputFormatter(this._valorIndice);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized =
        AppNumberFormatter._normalizeInput(newValue.text, _valorIndice);
    if (normalized == newValue.text) return newValue;
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}
