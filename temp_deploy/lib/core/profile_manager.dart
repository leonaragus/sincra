// ========================================================================
// PROFILE MANAGER - Receta de liquidación y log de auditoría
// Cada ítem: esBonificableAntiguedad, esBonificableZona (booleanos estrictos).
// Exportación TXT del paso a paso para revisión contable.
// ========================================================================

/// Ítem de la receta de liquidación con flags de bonificabilidad.
class RecetaItem {
  final String codigo;
  final String descripcion;
  final bool esBonificableAntiguedad;
  final bool esBonificableZona;

  RecetaItem({
    required this.codigo,
    required this.descripcion,
    required this.esBonificableAntiguedad,
    required this.esBonificableZona,
  });
}

/// Receta de liquidación: secuencia de ítems que definen el orden y la bonificabilidad.
class RecetaLiquidacion {
  final String nombre;
  final List<RecetaItem> items;

  RecetaLiquidacion({required this.nombre, required this.items});
}

/// Entrada del log de auditoría (paso a paso).
class AuditLogEntry {
  final String paso;
  final String descripcion;
  final String? entrada;
  final String? salida;

  AuditLogEntry({
    required this.paso,
    required this.descripcion,
    this.entrada,
    this.salida,
  });
}

/// Log de auditoría para exportar TXT y revisión contable.
class AuditLog {
  final List<AuditLogEntry> _entries = [];

  void agregar(String paso, String descripcion, {String? entrada, String? salida}) {
    _entries.add(AuditLogEntry(paso: paso, descripcion: descripcion, entrada: entrada, salida: salida));
  }

  /// Exporta el log a un texto paso a paso. Codificación ISO-8859-1, fin de línea \r\n.
  String exportarTxt({String eol = '\r\n'}) {
    final sb = StringBuffer();
    sb.write('=== LOG DE AUDITORÍA - LIQUIDACIÓN ===');
    sb.write(eol);
    sb.write('Generado: ${DateTime.now().toIso8601String()}');
    sb.write(eol);
    sb.write(eol);
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      sb.write('--- Paso ${i + 1}: ${e.paso} ---');
      sb.write(eol);
      sb.write('  ${e.descripcion}');
      sb.write(eol);
      if (e.entrada != null && e.entrada!.isNotEmpty) {
        sb.write('  Entrada: ${e.entrada}');
        sb.write(eol);
      }
      if (e.salida != null && e.salida!.isNotEmpty) {
        sb.write('  Salida:  ${e.salida}');
        sb.write(eol);
      }
      sb.write(eol);
    }
    sb.write('=== FIN LOG ===');
    sb.write(eol);
    return sb.toString();
  }

  List<AuditLogEntry> get entries => List.unmodifiable(_entries);
}

/// Gestor de perfiles/recetas y log de auditoría.
class ProfileManager {
  final Map<String, RecetaLiquidacion> _recetas = {};
  final AuditLog auditLog = AuditLog();

  void registrarReceta(RecetaLiquidacion r) {
    _recetas[r.nombre] = r;
  }

  RecetaLiquidacion? receta(String nombre) => _recetas[nombre];
}
