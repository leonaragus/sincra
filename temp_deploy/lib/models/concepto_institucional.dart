// ========================================================================
// Concepto Institucional — Conceptos propios de la institución para LSD 2026
// Nombre, Tipo (Suma Fija / Porcentaje), Naturaleza (Rem/No Rem), Código AFIP/ARCA
// ========================================================================

/// Tipo de valor del concepto (Suma Fija o Porcentaje)
enum TipoConceptoInstitucional {
  sumaFija,
  porcentaje,
}

/// Naturaleza contable del concepto
enum NaturalezaConcepto {
  remunerativo,
  noRemunerativo,
}

/// Modelo de un concepto propio de la institución para Libro de Sueldos Digital.
class ConceptoInstitucional {
  final String nombre;
  final TipoConceptoInstitucional tipo;
  final NaturalezaConcepto naturaleza;
  final String codigoAfipArca;

  const ConceptoInstitucional({
    required this.nombre,
    required this.tipo,
    required this.naturaleza,
    required this.codigoAfipArca,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'tipo': tipo.name,
        'naturaleza': naturaleza.name,
        'codigoAfipArca': codigoAfipArca,
      };

  static ConceptoInstitucional fromMap(Map<String, dynamic> m) {
    final t = m['tipo']?.toString();
    final n = m['naturaleza']?.toString();
    return ConceptoInstitucional(
      nombre: m['nombre']?.toString() ?? '',
      tipo: TipoConceptoInstitucional.values.cast<TipoConceptoInstitucional?>().firstWhere(
            (e) => e?.name == t,
            orElse: () => TipoConceptoInstitucional.sumaFija,
          ) ?? TipoConceptoInstitucional.sumaFija,
      naturaleza: NaturalezaConcepto.values.cast<NaturalezaConcepto?>().firstWhere(
            (e) => e?.name == n,
            orElse: () => NaturalezaConcepto.remunerativo,
          ) ?? NaturalezaConcepto.remunerativo,
      codigoAfipArca: m['codigoAfipArca']?.toString() ?? '011000',
    );
  }
}
