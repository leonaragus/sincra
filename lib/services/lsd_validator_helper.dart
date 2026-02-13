
import '../models/lsd_parsed_data.dart';
import 'validaciones_arca_service.dart';

enum ValidationIssueType {
  generic,
  base4Inconsistent, // Base 4 < Base 8
  aporteJubilacionDiff,
  aporteLeyDiff,
  aporteOSDiff,
  zonaPatagonicaInconsistent, // Nueva: Base de Zona no coincide con Remu
  basesInconsistent, // Nueva: Bases 1-9 no coinciden entre sí
}

class ValidationIssue {
  final String message;
  final ValidationIssueType type;
  final dynamic data;

  ValidationIssue(this.message, this.type, [this.data]);
}

class ValidationResult {
  final String cuil;
  final String nombre; // If available, otherwise CUIL
  final List<ValidationIssue> errors;
  final List<ValidationIssue> warnings;

  ValidationResult({
    required this.cuil,
    required this.nombre,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get isClean => !hasErrors && !hasWarnings;
}

class LSDValidatorHelper {
  static List<ValidationResult> validateParsedFile(LSDParsedFile file, {double? topeMin, double? topeMax}) {
    final results = <ValidationResult>[];

    // Group by CUIL
    final employees = <String, Map<String, dynamic>>{};

    for (var ref in file.referencias) {
      if (!employees.containsKey(ref.cuil)) {
        employees[ref.cuil] = {'ref': ref, 'conceptos': <LSDConcepto>[], 'bases': null, 'compl': null};
      }
    }

    for (var conc in file.conceptos) {
      if (!employees.containsKey(conc.cuil)) {
        employees[conc.cuil] = {'ref': null, 'conceptos': <LSDConcepto>[], 'bases': null, 'compl': null};
      }
      (employees[conc.cuil]!['conceptos'] as List<LSDConcepto>).add(conc);
    }

    for (var base in file.bases) {
      if (!employees.containsKey(base.cuil)) {
         employees[base.cuil] = {'ref': null, 'conceptos': <LSDConcepto>[], 'bases': null, 'compl': null};
      }
      employees[base.cuil]!['bases'] = base;
    }

    for (var compl in file.complementarios) {
      if (!employees.containsKey(compl.cuil)) {
         employees[compl.cuil] = {'ref': null, 'conceptos': <LSDConcepto>[], 'bases': null, 'compl': null};
      }
      employees[compl.cuil]!['compl'] = compl;
    }

    // Validate each employee
    employees.forEach((cuil, data) {
      final errors = <ValidationIssue>[];
      final warnings = <ValidationIssue>[];
      final ref = data['ref'] as LSDLegajoRef?;
      final conceptos = data['conceptos'] as List<LSDConcepto>;
      final bases = data['bases'] as LSDBases?;
      final compl = data['compl'] as LSDComplementarios?;

      // 1. Structure Check
      if (ref == null) errors.add(ValidationIssue('Falta Registro 02 (Datos Referenciales)', ValidationIssueType.generic));
      if (bases == null) errors.add(ValidationIssue('Falta Registro 04 (Bases Imponibles)', ValidationIssueType.generic));
      if (compl == null) errors.add(ValidationIssue('Falta Registro 05 (Datos Complementarios)', ValidationIssueType.generic));
      if (conceptos.isEmpty) warnings.add(ValidationIssue('No hay conceptos liquidados (Registro 03)', ValidationIssueType.generic));

      // 2. CUIL Validation
      if (!ValidacionesARCAService.validarCUIL(cuil).esValido) {
        errors.add(ValidationIssue('CUIL inválido: $cuil', ValidationIssueType.generic));
      }

      // 3. Bases Logic
      if (bases != null) {
        final base1 = bases.getBaseAsDouble(0); // Base 1: Jubilación
        final base4 = bases.getBaseAsDouble(3); // Base 4: Obra Social
        final base8 = bases.getBaseAsDouble(7); // Base 8: Aporte OS

        // Validar contra topes si están disponibles
        if (topeMin != null && base1 > 0 && base1 < topeMin) {
          warnings.add(ValidationIssue(
            'Base 1 ($base1) es menor al mínimo legal ($topeMin). ARCA podría rechazar si no hay justificación.',
            ValidationIssueType.generic
          ));
        }

        if (topeMax != null && base1 > topeMax) {
          errors.add(ValidationIssue(
            'Base 1 ($base1) supera el tope máximo legal ($topeMax). Debe toparse a $topeMax.',
            ValidationIssueType.generic
          ));
        }

        if (base4 < base8) {
          errors.add(ValidationIssue(
            'Inconsistencia Bases: Base 4 (OS) no puede ser menor que Base 8 (Aporte OS)',
            ValidationIssueType.base4Inconsistent
          ));
        }

        // 3.1 Consistencia Federal Bases 1 a 9 (ARCA 2026)
        for (int i = 1; i < 9; i++) {
          if ((bases.getBaseAsDouble(0) - bases.getBaseAsDouble(i)).abs() > 1.0) {
            errors.add(ValidationIssue(
              'Inconsistencia Federal: La Base ${i + 1} (${bases.getBaseAsDouble(i)}) difiere de la Base 1 (${bases.getBaseAsDouble(0)}). En liquidaciones federales deben coincidir.',
              ValidationIssueType.basesInconsistent
            ));
            break; 
          }
        }
      }

      // 3.2 Validación de Conceptos vs Bases y Zona Patagónica
      if (conceptos.isNotEmpty && bases != null) {
        double totalRemu = 0.0;
        double montoZona = 0.0;
        bool tieneZona = false;

        for (var c in conceptos) {
          final desc = c.descripcion.toUpperCase();
          final esZona = desc.contains('ZONA PATAGONICA') || desc.contains('ADICIONAL ZONA') || desc.contains('ZONA DESFAVORABLE');
          
          if (c.tipo == 'H' || c.tipo == 'R') { // Haberes / Remunerativos
            totalRemu += c.importeAsDouble;
            if (esZona) {
              montoZona = c.importeAsDouble;
              tieneZona = true;
            }
          }
        }

        // Verificar que el total remunerativo coincida con Base 1 (con margen de redondeo)
        final base1 = bases.getBaseAsDouble(0);
        
        // CORRECCIÓN: Considerar tope máximo en la comparación
        double totalEsperado = totalRemu;
        if (topeMax != null && totalRemu > topeMax) {
          totalEsperado = topeMax;
        }

        // CORRECCIÓN DOCENTES: En Guía 4, algunos conceptos como FONID/CONECTIVIDAD 
        // a veces se excluyen de la base 1 pero se informan como remunerativos (tipo H).
        // Si hay una diferencia significativa, intentamos ver si restando esos conceptos coincide.
        bool coincide = (totalEsperado - base1).abs() <= 2.0;
        
        if (!coincide) {
          double montoExcluidoDocente = 0.0;
          for (var c in conceptos) {
            final cod = c.codigo.toUpperCase();
            if (cod.contains('FONID') || cod.contains('CONECT') || cod.contains('CONEC') || cod.contains('IPC_FONID') || cod.contains('COMP_FONID')) {
              if (c.tipo == 'H' || c.tipo == 'R') {
                montoExcluidoDocente += c.importeAsDouble;
              }
            }
          }
          
          double totalEsperadoDocente = totalRemu - montoExcluidoDocente;
          if (topeMax != null && totalEsperadoDocente > topeMax) {
            totalEsperadoDocente = topeMax;
          }

          if ((totalEsperadoDocente - base1).abs() <= 2.0) {
            coincide = true;
          }
        }

        if (!coincide) {
          errors.add(ValidationIssue(
            'Total Remunerativo (\$${totalRemu.toStringAsFixed(2)}) no coincide con Base Imponible 1 (\$${base1.toStringAsFixed(2)}). ARCA rechazará la declaración.',
            ValidationIssueType.generic
          ));
        }

        // REGLA CRÍTICA: Base de Zona Patagónica (Federal Compliance)
        if (tieneZona) {
          // Intentamos validar con base completa (estándar)
          final double baseCalculadaZonaEstandar = totalRemu - montoZona;
          
          // Intentamos validar con base reducida (excluyendo conceptos nacionales docentes que a veces no son base de zona)
          double montoExcluidoDocente = 0.0;
          for (var c in conceptos) {
            final cod = c.codigo.toUpperCase();
            if (cod.contains('FONID') || cod.contains('CONECT') || cod.contains('CONEC')) {
              if (c.tipo == 'H' || c.tipo == 'R') {
                montoExcluidoDocente += c.importeAsDouble;
              }
            }
          }
          final double baseCalculadaZonaDocente = baseCalculadaZonaEstandar - montoExcluidoDocente;

          bool zonaValida = false;
          final pcts = [0.20, 0.30, 0.40, 0.50, 0.80, 1.00, 0.11, 0.12]; 
          
          for (var p in pcts) {
            // Probar base estándar
            if ((baseCalculadaZonaEstandar * p - montoZona).abs() < 5.0) {
              zonaValida = true;
              break;
            }
            // Probar base docente (Neuquén/Río Negro)
            if (baseCalculadaZonaDocente > 0 && (baseCalculadaZonaDocente * p - montoZona).abs() < 5.0) {
              zonaValida = true;
              break;
            }
          }

          if (!zonaValida) {
            errors.add(ValidationIssue(
              'Cálculo de Zona Patagónica incorrecto: El monto (\$${montoZona.toStringAsFixed(2)}) no parece estar calculado sobre el total de conceptos remunerativos (\$${baseCalculadaZonaEstandar.toStringAsFixed(2)}) ni sobre la base docente (\$${baseCalculadaZonaDocente.toStringAsFixed(2)}).',
              ValidationIssueType.zonaPatagonicaInconsistent
            ));
          }
        }
      }

      // 4. Aportes Logic
      if (bases != null && conceptos.isNotEmpty) {
         // Calculate theoretical contributions
         final base1 = bases.getBaseAsDouble(0);
         final base4 = bases.getBaseAsDouble(3);
         
         final teoricoJub = base1 * 0.11;
         final teoricoLey = base1 * 0.03;
         
         // Ajuste federal para Obra Social (Neuquén ISSN usa 5.5%)
         double pctOS = 0.03;
         if (compl?.rnos == '820000') {
           pctOS = 0.055;
         }
         final teoricoOS = base4 * pctOS;

         double realJub = 0.0;
         double realLey = 0.0;
         double realOS = 0.0;

         for (var c in conceptos) {
            if (c.tipo == 'D') {
              if (c.codigo.contains('JUB') || c.descripcion.toUpperCase().contains('JUB')) realJub += c.importeAsDouble;
              if (c.codigo.contains('19032') || c.codigo.contains('LEY') || c.descripcion.contains('19032')) realLey += c.importeAsDouble;
              if (c.codigo.contains('OBRA') || c.codigo.contains('OS') || c.descripcion.contains('OBRA SOC')) realOS += c.importeAsDouble;
            }
         }

         // Tolerance of 1 peso
         if ((teoricoJub - realJub).abs() > 5.0) {
            warnings.add(ValidationIssue(
              'Diferencia Aporte Jubilación: Calculado ARCA ~${teoricoJub.toStringAsFixed(2)} vs Recibo ${realJub.toStringAsFixed(2)}',
              ValidationIssueType.aporteJubilacionDiff,
              {'teorico': teoricoJub}
            ));
         }
         if ((teoricoLey - realLey).abs() > 5.0) {
             warnings.add(ValidationIssue(
               'Diferencia Aporte Ley 19032: Calculado ARCA ~${teoricoLey.toStringAsFixed(2)} vs Recibo ${realLey.toStringAsFixed(2)}',
               ValidationIssueType.aporteLeyDiff,
               {'teorico': teoricoLey}
             ));
         }
         if ((teoricoOS - realOS).abs() > 5.0) {
             warnings.add(ValidationIssue(
               'Diferencia Aporte Obra Social: Calculado ARCA ~${teoricoOS.toStringAsFixed(2)} vs Recibo ${realOS.toStringAsFixed(2)}',
               ValidationIssueType.aporteOSDiff,
               {'teorico': teoricoOS}
             ));
         }
      }

      results.add(ValidationResult(
        cuil: cuil,
        nombre: ref?.legajo ?? 'Legajo Desconocido',
        errors: errors,
        warnings: warnings,
      ));
    });

    return results;
  }
}
