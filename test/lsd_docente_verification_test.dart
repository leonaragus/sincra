import 'package:syncra_arg/models/teacher_constants.dart';
import 'package:syncra_arg/models/teacher_types.dart';
import 'package:syncra_arg/services/lsd_engine.dart';
import 'package:syncra_arg/services/lsd_parser_service.dart';
import 'package:syncra_arg/services/lsd_validator_helper.dart';
import 'package:syncra_arg/services/teacher_lsd_export.dart';
import 'package:syncra_arg/services/teacher_omni_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LSD Docente Verification', () {
    test('Generate, Parse and Validate LSD for Docente Neuquén', () async {
      // 1. Setup Mock Data
      final validCuil = '20111111112'; // CUIL válido verificado
      
      final input = DocenteOmniInput(
        nombre: 'JUAN PEREZ',
        cuil: validCuil,
        jurisdiccion: Jurisdiccion.neuquen,
        tipoGestion: TipoGestion.privada,
        cargoNomenclador: TipoNomenclador.maestroGrado,
        nivelEducativo: NivelEducativo.primario,
        fechaIngreso: DateTime(2010, 3, 1),
        cargasFamiliares: 2,
        codigoRnos: '115404', // OSDOP - RNOS válido
        horasCatedra: 0,
        zona: ZonaDesfavorable.a,
        nivelUbicacion: NivelUbicacion.urbana,
        esHoraCatedraSecundaria: false,
        modoLiquidacion: 'mensual',
      );

      final config = JurisdiccionDBOmni.get(Jurisdiccion.neuquen)!;
      
      // Create a mock result
      // Sueldo (500k) + Antiguedad (100k) = 600k Total
      final liquidacion = LiquidacionOmniResult(
        input: input,
        config: config,
        periodo: '2024-05',
        fechaPago: '2024-06-05',
        sueldoBasico: 500000.0,
        adicionalAntiguedad: 100000.0,
        adicionalZona: 0.0,
        adicionalZonaPatagonica: 0.0,
        plusUbicacion: 0.0,
        adicionalSalarialCiudad: 0.0,
        itemAula: 0.0,
        estadoDocente: 0.0,
        presentismo: 0.0,
        materialDidactico: 0.0,
        fonid: 0.0,
        conectividad: 0.0,
        horasCatedra: 0.0,
        ajusteEquiparacionLey13047: 0.0,
        fondoCompensador: 0.0,
        adicionalGarantiaSalarial: 0.0,
        conceptosPropios: [], // Eliminamos concepto duplicado
        detallePuntosYValorIndice: '',
        desgloseBaseBonificable: '',
        totalBrutoRemunerativo: 600000.0,
        totalNoRemunerativo: 0.0,
        baseImponibleTopeada: 600000.0,
        aporteJubilacion: 66000.0, // 11%
        aporteObraSocial: 18000.0, // 3%
        porcentajeObraSocial: 3.0,
        aportePami: 18000.0, // 3%
        impuestoGanancias: 0.0,
        deduccionesAdicionales: {},
        dto23315: 0.0,
        ubicacionZona: 0.0,
        a5D33516: 0.0,
        incDocenteLey25053: 0.0,
        compFonid: 0.0,
        ipcFonid: 0.0,
        conectividadNacional: 0.0,
        conectividadProvincial: 0.0,
        redondeoMonto: 0.0,
        dec13705: 0.0,
        totalDescuentos: 102000.0,
        netoACobrar: 498000.0,
        bloqueArt12Ley17250: 'BLOQUE ART 12',
      );

      // 2. Generate LSD
      final lsdContent = await teacherOmniToLsdTxt(
        liquidacion: liquidacion,
        cuitEmpresa: '30112233445',
        razonSocial: 'COLEGIO TEST',
        domicilio: 'CALLE FALSA 123',
      );

      // 3. Verify Format
      print('Generated LSD Content:');
      print(lsdContent);
      
      expect(lsdContent, isNotEmpty);
      LSDGenerator.validarLongitud195(lsdContent);

      // 4. Parse and Validate
      final parsedFile = LSDParserService.parseFileContent(lsdContent);
      if (parsedFile.erroresParsing.isNotEmpty) {
        print('Parsing Errors:');
        for (var e in parsedFile.erroresParsing) {
          print(e);
        }
        fail('Parsing failed with ${parsedFile.erroresParsing.length} errors');
      }

      final validationResults = LSDValidatorHelper.validateParsedFile(parsedFile);
      bool hasErrors = false;
      for (var res in validationResults) {
        if (res.hasErrors) {
          hasErrors = true;
          print('Validation Errors for CUIL ${res.cuil}:');
          for (var err in res.errors) {
            print('- [${err.type}] ${err.message}');
          }
        }
      }
      expect(hasErrors, isFalse, reason: 'LSD Validation failed');

      // 5. Specific Checks
      
      // Verify Base Imponible 1 (Remuneración 1) matches Total Remunerativo (600,000)
      final basesReg = parsedFile.bases.firstWhere((b) => b.cuil == validCuil);
      final base1 = basesReg.getBaseAsDouble(0); // Base 1 is usually at index 0
      
      expect(base1, closeTo(600000.0, 0.01), reason: 'Base Imponible 1 should match Total Remunerativo');
      
      // Verify Complementarios exist
      final complReg = parsedFile.complementarios.firstWhere((c) => c.cuil == validCuil);
      expect(complReg, isNotNull);
    });

    test('LSD Docente with Zona Desfavorable', () async {
       // 1. Setup Mock Data
       final validCuil = '27987654320'; // CUIL válido verificado
       
       final input = DocenteOmniInput(
          nombre: 'MARIA GOMEZ',
          cuil: validCuil,
          jurisdiccion: Jurisdiccion.neuquen,
          tipoGestion: TipoGestion.privada,
          cargoNomenclador: TipoNomenclador.profesor,
          nivelEducativo: NivelEducativo.secundario,
          fechaIngreso: DateTime(2015, 3, 1),
          cargasFamiliares: 0,
          codigoRnos: '115404',
          horasCatedra: 20,
          zona: ZonaDesfavorable.b, // 20%
          nivelUbicacion: NivelUbicacion.alejada,
          esHoraCatedraSecundaria: true,
          modoLiquidacion: 'mensual',
       );

       final config = JurisdiccionDBOmni.get(Jurisdiccion.neuquen)!;

       final liquidacion = LiquidacionOmniResult(
        input: input,
        config: config,
        periodo: '2024-05',
        fechaPago: '2024-06-05',
        sueldoBasico: 400000.0,
        adicionalAntiguedad: 80000.0,
        adicionalZona: 0.0,
        adicionalZonaPatagonica: 96000.0, // 20% de (400k + 80k)
        plusUbicacion: 0.0,
        adicionalSalarialCiudad: 0.0,
        itemAula: 0.0,
        estadoDocente: 0.0,
        presentismo: 0.0,
        materialDidactico: 0.0,
        fonid: 0.0,
        conectividad: 0.0,
        horasCatedra: 20.0,
        ajusteEquiparacionLey13047: 0.0,
        fondoCompensador: 0.0,
        adicionalGarantiaSalarial: 0.0,
        conceptosPropios: [],
        detallePuntosYValorIndice: '',
        desgloseBaseBonificable: '',
        totalBrutoRemunerativo: 576000.0,
        totalNoRemunerativo: 0.0,
        baseImponibleTopeada: 576000.0,
        aporteJubilacion: 63360.0,
        aporteObraSocial: 17280.0,
        porcentajeObraSocial: 3.0,
        aportePami: 17280.0,
        impuestoGanancias: 0.0,
        deduccionesAdicionales: {},
        dto23315: 0.0,
        ubicacionZona: 0.0,
        a5D33516: 0.0,
        incDocenteLey25053: 0.0,
        compFonid: 0.0,
        ipcFonid: 0.0,
        conectividadNacional: 0.0,
        conectividadProvincial: 0.0,
        redondeoMonto: 0.0,
        dec13705: 0.0,
        totalDescuentos: 97920.0,
        netoACobrar: 478080.0,
        bloqueArt12Ley17250: '',
      );

       // 2. Generate LSD
       final lsdContent = await teacherOmniToLsdTxt(
          liquidacion: liquidacion,
          cuitEmpresa: '30112233445',
          razonSocial: 'INSTITUTO ZONA',
          domicilio: 'RUTA 40 KM 10',
       );

       // 3. Validate
       LSDGenerator.validarLongitud195(lsdContent);
       final parsedFile = LSDParserService.parseFileContent(lsdContent);
       expect(parsedFile.erroresParsing, isEmpty);
       
       final validationResults = LSDValidatorHelper.validateParsedFile(parsedFile);
       bool hasErrors = false;
       for (var res in validationResults) {
         if (res.hasErrors) {
           hasErrors = true;
           print('Validation Errors for CUIL ${res.cuil}:');
           for (var err in res.errors) {
             print('- [${err.type}] ${err.message}');
           }
         }
       }
       expect(hasErrors, isFalse);
    });
  });
}
