
import '../models/lsd_parsed_data.dart';

// =======================================================================
// MEJORA 2: Expansión de Tipos de Issue para Auto-Corrección
// =======================================================================
enum ValidationIssueType {
  generic,
  base4Inconsistent,
  remunerativoInconsistente, // NUEVO
  aporteJubilacionDiff,
  aporteLeyDiff,
  aporteOSDiff,
}

class ValidationIssue {
  final String message;
  final ValidationIssueType type;
  final Map<String, dynamic> data; // Para pasar datos a la UI (ej. valor teórico)

  ValidationIssue(this.message, {this.type = ValidationIssueType.generic, this.data = const {}});
}

class ValidationResult {
  final String cuil;
  final String nombre;
  final List<ValidationIssue> errors;
  final List<ValidationIssue> warnings;

  ValidationResult({required this.cuil, required this.nombre, required this.errors, required this.warnings});

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

class LSDValidatorHelper {

  // =======================================================================
  // MEJORA 2.1: Etiqueta para Bases Imponibles
  // =======================================================================
  static String getBaseLabel(int baseNumber) {
      switch (baseNumber) {
        case 1: return 'Base 1 (Rem)';
        case 2: return 'Base 2 (Rem)';
        case 3: return 'Base 3 (Desc. Ley)';
        case 4: return 'Base 4 (O.S.)';
        case 5: return 'Base 5 (ART)';
        case 6: return 'Base 6 (Jub. Esp.)';
        case 7: return 'Base 7 (Jub. Esp.)';
        case 8: return 'Base 8 (Aporte OS)';
        case 9: return 'Base 9 (Capacitación)';
        case 10: return 'Base 10 (Adic.)';
        default: return 'Base $baseNumber';
      }
  }

  static List<ValidationResult> validateParsedFile(LSDParsedFile file, {double? topeMin, double? topeMax}) {
    final results = <ValidationResult>[];
    final conceptosPorCuil = <String, List<LSDConcepto>>{};

    // Agrupar conceptos
    for (var c in file.conceptos) {
      if (!conceptosPorCuil.containsKey(c.cuil)) conceptosPorCuil[c.cuil] = [];
      conceptosPorCuil[c.cuil]!.add(c);
    }

    for (var legajo in file.referencias) {
      final cuil = legajo.cuil;
      final nombre = 'Legajo ${legajo.legajo}'; // LSD Registro 2 no tiene nombre
      final errores = <ValidationIssue>[];
      final advertencias = <ValidationIssue>[];

      final conceptos = conceptosPorCuil[cuil] ?? [];
      LSDBases? bases;
      try {
        bases = file.bases.firstWhere((b) => b.cuil == cuil);
      } catch (_) {
        bases = null;
      }
      
      if (bases == null) {
          errores.add(ValidationIssue("No se encontró registro de Bases (04) para este CUIL."));
          results.add(ValidationResult(cuil: cuil, nombre: nombre, errors: errores, warnings: advertencias));
          continue; // No se puede validar más sin bases
      }

      // ---- INICIO DE VALIDACIONES POR EMPLEADO ----
      
      final base1 = bases.getBaseAsDouble(0);
      final base4 = bases.getBaseAsDouble(3);
      final base8 = bases.getBaseAsDouble(7);

      // =======================================================================
      // MEJORA 2.2: Lógica para validar suma de remunerativos vs Bases 1 y 2
      // =======================================================================
      double totalRemunerativo = 0;
      for (var c in conceptos) {
          if (c.tipo == 'H' && c.codigo.trim().startsWith('1')) { // Código AFIP remunerativo
              totalRemunerativo += c.importeAsDouble;
          }
      }

      if ((totalRemunerativo - base1).abs() > 0.05) { // Tolerancia de 5 centavos
          advertencias.add(ValidationIssue(
              'La suma de haberes remunerativos (\$${totalRemunerativo.toStringAsFixed(2)}) no coincide con la Base 1 (\$${base1.toStringAsFixed(2)}).',
              type: ValidationIssueType.remunerativoInconsistente,
              data: {'remunerativoCalculado': totalRemunerativo}
          ));
      }

      // Validación de consistencia Base 4 vs Base 8
      if (base4 > 0 && base8 > 0 && (base4 - base8).abs() > 0.05) {
        errores.add(ValidationIssue(
            'Inconsistencia de Bases de Obra Social: Base 4 (\$${base4.toStringAsFixed(2)}) es distinta a Base 8 (\$${base8.toStringAsFixed(2)}).',
            type: ValidationIssueType.base4Inconsistent,
            data: {'base8': base8} 
        ));
      }

      // Validación de aportes legales
      final aporteJubTeorico = (base1 * 0.11).toStringAsFixed(2);
      final aporteLeyTeorico = (base1 * 0.03).toStringAsFixed(2);
      final aporteOSTeorico = (base4 * 0.03).toStringAsFixed(2);

      // Usamos búsqueda segura para evitar RangeError si no se encuentra
      LSDConcepto? getConceptoByAfip(String afipCode) {
        try {
          return conceptos.firstWhere((c) => c.codigo.trim() == afipCode);
        } catch (_) {
          return null;
        }
      }

      final aporteJubReal = getConceptoByAfip('110001')?.importeAsDouble.toStringAsFixed(2);
      final aporteLeyReal = getConceptoByAfip('110002')?.importeAsDouble.toStringAsFixed(2);
      final aporteOSReal = getConceptoByAfip('110003')?.importeAsDouble.toStringAsFixed(2);

      if (aporteJubReal != null && aporteJubReal != aporteJubTeorico) {
        advertencias.add(ValidationIssue(
            'Aporte Jubilatorio (11%) inconsistente. Declarado: \$$aporteJubReal, Calculado: \$$aporteJubTeorico.',
            type: ValidationIssueType.aporteJubilacionDiff,
            data: {'teorico': double.parse(aporteJubTeorico)}
        ));
      }
      if (aporteLeyReal != null && aporteLeyReal != aporteLeyTeorico) {
        advertencias.add(ValidationIssue(
            'Aporte Ley 19.032 (3%) inconsistente. Declarado: \$$aporteLeyReal, Calculado: \$$aporteLeyTeorico.',
            type: ValidationIssueType.aporteLeyDiff,
            data: {'teorico': double.parse(aporteLeyTeorico)}
        ));
      }
      if (aporteOSReal != null && aporteOSReal != aporteOSTeorico) {
        advertencias.add(ValidationIssue(
            'Aporte Obra Social (3%) inconsistente. Declarado: \$$aporteOSReal, Calculado: \$$aporteOSTeorico.',
            type: ValidationIssueType.aporteOSDiff,
            data: {'teorico': double.parse(aporteOSTeorico)}
        ));
      }
      
      results.add(ValidationResult(cuil: cuil, nombre: nombre, errors: errores, warnings: advertencias));
    }
    
    return results;
  }
}
