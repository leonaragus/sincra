import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincra/services/sanidad_omni_engine.dart';
import 'package:sincra/services/lsd/strategies/sanidad_lsd_strategy.dart';
import 'package:sincra/models/sanidad_empleado_model.dart';
import 'package:intl/intl.dart';

void main() {
  test('Validación de estructura y contenido LSD Sanidad para AFIP - Caso 2', () async {
    // 1. Crear un empleado de prueba con datos diferentes (Técnico en zona patagónica)
    final input = SanidadEmpleadoInput(
      nombre: "MARIA GONZALEZ",
      cuil: "27258889994",
      fechaIngreso: DateTime(2015, 2, 20),
      categoria: CategoriaSanidad.tecnico,
      nivelTitulo: NivelTituloSanidad.tecnico,
      tareaCriticaRiesgo: false,
      aplicarCuotaSindicalAtsa: true,
      manejoEfectivoCaja: false,
      horasNocturnas: 0,
      horasExtras50: 10.0,
      horasExtras100: 0.0,
      adelantos: 0.0,
      embargos: 12000.0,
      prestamos: 0.0,
      codigoRnos: "126205",
      cantidadFamiliares: 0,
      codigoModalidad: "008",
      codigoSituacion: "01",
    );

    // 2. Liquidar el sueldo (Marzo 2026) en Jurisdicción Patagónica (Río Negro)
    final liquidacion = SanidadOmniEngine.liquidar(
      input,
      periodo: "202603",
      fechaPago: "04/04/2026",
      jurisdiccion: "rioNegro", // Esto dispara el Plus Zona Patagónica
      modo: ModoLiquidacionSanidad.mensual,
    );

    // 3. Generar el archivo LSD TXT
    final strategy = SanidadLsdExportStrategy();
    final lsdTxt = await strategy.generarLsdTxt(
      liquidaciones: [liquidacion],
      empresaData: {
        'cuit': '33887766559',
        'razonSocial': 'SANATORIO PATAGONICO S.R.L.',
        'domicilio': 'CALLE 123, VIEDMA, RIO NEGRO',
      },
    );

    // 4. Auditoría de líneas
    final lineas = lsdTxt.split('\r\n').where((l) => l.trim().isNotEmpty).toList();
    
    print('--- INICIO DE AUDITORIA LSD SANIDAD (CASO 2) ---');
    print('Total de registros generados: ${lineas.length}');

    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      final nroRegistro = i + 1;
      
      expect(linea.length, 195, reason: 'Línea $nroRegistro: Longitud incorrecta');
      
      final tipoReg = linea.substring(0, 1);
      
      if (tipoReg == '1') {
        expect(linea.substring(12, 23), '33887766559', reason: 'CUIT de empresa incorrecto');
        expect(linea.substring(23, 29), '202603', reason: 'Periodo incorrecto');
      } else if (tipoReg == '2') {
        expect(linea.substring(1, 12), '27258889994', reason: 'CUIL de empleado incorrecto');
      } else if (tipoReg == '3') {
        final codigo = linea.substring(12, 22).trim();
        final importeStr = linea.substring(22, 37).trim();
        final importe = double.parse(importeStr) / 100;
        
        if (codigo == '0001') { // Básico (según mapeo SanidadLsdCodigos)
           print('  - Sueldo Básico: $importe');
           expect(importe, greaterThan(0));
        }
        if (codigo == '0005') { // Zona Patagónica
           print('  - Plus Zona Patagónica detectado: $importe');
           expect(importe, greaterThan(0));
        }
      } else if (tipoReg == '5') {
        final zona = linea.substring(194, 195);
        print('  - Código de Zona AFIP: $zona');
        expect(zona, '1', reason: 'Debe ser zona 1 por ser Río Negro');
      }
    }
    print('--- FIN DE AUDITORIA ---');
  });
}
