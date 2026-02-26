
import 'package:flutter_test/flutter_test.dart';
import 'package:syncra_arg/services/lsd_parser_service.dart';
import 'package:syncra_arg/services/lsd_validator_helper.dart';
import 'package:syncra_arg/services/sanidad_lsd_export.dart';
import 'package:syncra_arg/services/sanidad_omni_engine.dart';

void main() {
  test('Sanidad LSD Verification: Generate, Parse and Validate LSD for Sanidad', () async {
    // 1. Setup Data
    final input = SanidadEmpleadoInput(
      nombre: 'JUAN PEREZ',
      cuil: '20111111112', // Valid CUIL
      fechaIngreso: DateTime(2020, 1, 1),
      categoria: CategoriaSanidad.administrativo,
      nivelTitulo: NivelTituloSanidad.sinTitulo,
      tareaCriticaRiesgo: false,
      codigoRnos: '115404',
      codigoActividad: '049',
      codigoPuesto: '0000',
      codigoCondicion: '01',
      codigoModalidad: '008',
    );

    // Mock calculated values
    final double sueldoBasico = 520000.0;
    final double adicionalAntiguedad = 41600.0; // 4 years * 2% * 520k = 41.6k
    final double horasExtras50Monto = 10000.0;
    // ARCA Validator expects Zona to be calculated on Total Remunerativo (excluding Zona itself)
    // So Base for Zona = Sueldo + Antiguedad + Horas Extras
    final double adicionalZonaPatagonica = (sueldoBasico + adicionalAntiguedad + horasExtras50Monto) * 0.20; 
    
    final double totalBrutoRemunerativo = sueldoBasico + adicionalAntiguedad + adicionalZonaPatagonica + horasExtras50Monto; 
    final double baseImponibleTopeada = totalBrutoRemunerativo; // Assuming below cap

    final liquidacion = LiquidacionSanidadResult(
      input: input,
      periodo: '2024-05',
      fechaPago: '2024-06-05',
      sueldoBasico: sueldoBasico,
      adicionalAntiguedad: adicionalAntiguedad,
      adicionalTitulo: 0.0,
      adicionalTareaCriticaRiesgo: 0.0,
      adicionalZonaPatagonica: adicionalZonaPatagonica,
      nocturnidad: 0.0,
      falloCaja: 0.0,
      horasExtras50Monto: horasExtras50Monto,
      totalBrutoRemunerativo: totalBrutoRemunerativo,
      totalNoRemunerativo: 0.0,
      aporteJubilacion: totalBrutoRemunerativo * 0.11,
      aporteLey19032: totalBrutoRemunerativo * 0.03,
      aporteObraSocial: totalBrutoRemunerativo * 0.03,
      cuotaSindicalAtsa: totalBrutoRemunerativo * 0.02,
      seguroSepelio: totalBrutoRemunerativo * 0.01,
      aporteSolidarioFatsa: totalBrutoRemunerativo * 0.01,
      adelantos: 0.0,
      embargos: 0.0,
      prestamos: 0.0,
      otrosDescuentos: 0.0,
      totalDescuentos: totalBrutoRemunerativo * 0.21,
      netoACobrar: totalBrutoRemunerativo * 0.79,
      baseImponibleTopeada: baseImponibleTopeada,
      conceptosPropios: [],
    );

    // 2. Generate LSD Text
    final lsdContent = await sanidadOmniToLsdTxt(
      liquidacion: liquidacion,
      cuitEmpresa: '30112233445',
      razonSocial: 'CLINICA TEST',
      domicilio: 'CALLE FALSA 123',
    );

    print('Generated LSD Content:');
    print(lsdContent);

    // 3. Parse Generated LSD
    final parsedFile = LSDParserService.parseFileContent(lsdContent);

    // 4. Validate Parsing
    expect(parsedFile.isValid, isTrue, reason: 'LSD File should be valid');
    expect(parsedFile.erroresParsing, isEmpty, reason: 'Should have no parsing errors');
    expect(parsedFile.header, isNotNull);
    expect(parsedFile.bases, isNotEmpty);
    expect(parsedFile.complementarios, isNotEmpty);
    expect(parsedFile.conceptos, isNotEmpty);

    // 5. Validate Specific Values
    // Check Header
    expect(parsedFile.header?.cuitEmpresa, '30112233445');
    expect(parsedFile.header?.periodo, '202405');

    // Check Bases (Registro 4)
    final validCuil = '20111111112';
    final basesReg = parsedFile.bases.firstWhere((b) => b.cuil == validCuil);
    final base1 = basesReg.getBaseAsDouble(0); // Base Imponible 1
    
    // CRITICAL CHECK: Total Remunerativo must match Base Imponible 1
    expect(base1, closeTo(totalBrutoRemunerativo, 0.01), 
      reason: 'Base Imponible 1 ($base1) should match Total Remunerativo ($totalBrutoRemunerativo)');

    // Check Zona Patagonica Logic (if applicable)
    // In this mock, we added Zona Patagonica, so base should reflect that.
    
    // Check Conceptos (Registro 3)
    final conceptosReg = parsedFile.conceptos.where((c) => c.cuil == validCuil).toList();
    expect(conceptosReg.any((c) => c.codigo.trim() == 'SUELDO_BAS'), isTrue);
    expect(conceptosReg.any((c) => c.codigo.trim() == 'ANTIGUEDAD'), isTrue);
    expect(conceptosReg.any((c) => c.codigo.trim() == 'PLUS_ZONA'), isTrue);

    // 6. Run Official Validator Helper
    final validationResults = LSDValidatorHelper.validateParsedFile(parsedFile);
    final allErrors = validationResults.expand((r) => r.errors).toList();
    
    if (allErrors.isNotEmpty) {
      print('Validation Errors:');
      for (final e in allErrors) {
        print(e.message);
      }
    }
    expect(allErrors, isEmpty, reason: 'Should pass LSDValidatorHelper checks');
  });
}
