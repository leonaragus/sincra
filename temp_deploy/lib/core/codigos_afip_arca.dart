// ========================================================================
// CÓDIGOS AFIP/ARCA VÁLIDOS - Guía 4 Docentes, LSD
// Todo concepto dinámico del usuario debe vincularse a un código de este set.
// ========================================================================

/// Códigos de concepto AFIP/ARCA válidos (6 dígitos) para mapeo obligatorio.
class CodigosAfipArca {
  static const String c011000 = '011000';
  static const String c012000 = '012000';
  static const String c051000 = '051000';
  static const String c015000 = '015000';
  static const String c031000 = '031000';
  static const String c041000 = '041000';
  static const String c110000 = '110000';
  static const String c111000 = '111000';
  static const String c112000 = '112000';
  static const String c131000 = '131000';
  static const String c810000 = '810000';
  static const String c820000 = '820000';
  static const String c990000 = '990000';

  static const Set<String> _codigosBase = {
    c011000, c012000, c051000, c015000, c031000, c041000,
    c110000, c111000, c112000, c131000, c810000, c820000, c990000,
  };

  /// Set de códigos válidos, extensible en tiempo de ejecución
  static Set<String> todos = Set.from(_codigosBase);

  /// Permite registrar nuevos códigos válidos dinámicamente (ej. nuevos conceptos ARCA)
  static void registrarNuevoCodigo(String codigo) {
    final c = codigo.replaceAll(RegExp(r'[^\d]'), '').padLeft(6, '0');
    if (c.length == 6) {
      todos.add(c);
    }
  }

  /// Indica si [codigo] es un código AFIP/ARCA válido (6 dígitos en el set).
  static bool esValido(String codigo) {
    final c = codigo.replaceAll(RegExp(r'[^\d]'), '').padLeft(6, '0');
    return c.length == 6 && todos.contains(c);
  }

  /// Valida [codigo]. Lanza [ArgumentError] si no es válido.
  static void validar(String codigo, [String nombreConcepto = '']) {
    if (!esValido(codigo)) {
      throw ArgumentError(
        'Código AFIP/ARCA inválido: "$codigo" (concepto: $nombreConcepto). '
        'Debe ser uno de: 011000, 012000, 110000, 112000, 810000, 820000, 990000.',
      );
    }
  }
}
