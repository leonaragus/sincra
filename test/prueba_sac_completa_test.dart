// Prueba completa SAC: institución privada, portero. Genera PDF y LSD,
// imprime rutas y resumen aquí (en la salida de flutter test) para revisar y subir a ARCA.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:syncra_arg/models/empresa.dart';
import 'package:syncra_arg/models/empleado.dart';
import 'package:syncra_arg/models/teacher_constants.dart';
import 'package:syncra_arg/services/lsd_engine.dart';
import 'package:syncra_arg/utils/pdf_recibo.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('Prueba SAC completa: portero en institución privada — PDF y LSD generados', () async {
    // --- Datos de prueba (mismos que la prueba completa) ---
    const cuit = '30712345671';
    const cuil = '20312345677';
    const mayorRem = 1850000.0;
    const semestre = 1;
    const anio = 2025;
    const fechaPago = '30/06/2025';
    const periodoTexto = 'SAC 1º Semestre 2025';

    final inst = {
      'cuit': '30-71234567-1',
      'razonSocial': 'Instituto Privado San Juan S.A. (Prueba)',
      'domicilio': 'Av. Corrientes 1234, CABA',
      'jurisdiccion': 'caba',
      'tipoGestion': 'privada',
    };
    final legajo = {
      'nombre': 'Juan Carlos Pérez',
      'cuil': '20-31234567-7',
      'fechaIngreso': '2020-03-15',
      'cargo': 'Portero',
    };

    // --- Cálculos: SAC y aportes (gestión privada: 11% Jub, 3% OS, 3% PAMI) ---
    final sac = mayorRem * 0.5; // 925000
    final jub = sac * 0.11;     // 101750
    final os = sac * 0.03;     // 27750
    final pami = sac * 0.03;    // 27750
    final totalDeducciones = jub + os + pami; // 157250
    final neto = sac - totalDeducciones;      // 767750

    final conceptosPdf = [
      ConceptoParaPDF(descripcion: 'SAC (50% mayor remuneración)', remunerativo: sac, noRemunerativo: 0, descuento: 0),
      ConceptoParaPDF(descripcion: 'Jubilación (11%)', remunerativo: 0, noRemunerativo: 0, descuento: jub),
      ConceptoParaPDF(descripcion: 'Obra Social (3%)', remunerativo: 0, noRemunerativo: 0, descuento: os),
      ConceptoParaPDF(descripcion: 'PAMI (3%)', remunerativo: 0, noRemunerativo: 0, descuento: pami),
    ];

    final emp = Empresa(
      razonSocial: inst['razonSocial']! as String,
      cuit: cuit,
      domicilio: inst['domicilio']! as String,
      convenioId: 'docente_sac',
      convenioNombre: 'SAC Docente',
      convenioPersonalizado: false,
      categorias: [],
      parametros: [],
    );

    final cargo = (legajo['cargo'] as String?)?.trim() ?? '';
    final empr = Empleado(
      nombre: legajo['nombre']! as String,
      categoria: cargo.isEmpty ? 'SAC - $periodoTexto' : '$cargo - SAC - $periodoTexto',
      sueldoBasico: sac,
      periodo: periodoTexto,
      fechaPago: fechaPago,
      lugarPago: inst['domicilio'] as String?,
      fechaIngreso: legajo['fechaIngreso'] as String?,
    );

    // --- PDF ---
    final pdfBytes = await PdfRecibo.generarCompleto(
      empresa: emp,
      empleado: empr,
      conceptos: conceptosPdf,
      sueldoBruto: sac,
      totalDeducciones: totalDeducciones,
      totalNoRemunerativo: 0,
      sueldoNeto: neto,
    );

    final dir = await getTemporaryDirectory();
    final nombreArch = (legajo['nombre'] as String).replaceAll(RegExp(r'[^\w]'), '_');
    final pdfPath = '${dir.path}${Platform.pathSeparator}recibo_sac_${nombreArch}_$cuil.pdf';
    await File(pdfPath).writeAsBytes(pdfBytes);

    // --- LSD ---
    final baseImponible = sac > ParametrosFederales2026Omni.topePrevisional
        ? ParametrosFederales2026Omni.topePrevisional
        : sac;
    final reg1 = LSDGenerator.generateRegistro1(
      cuitEmpresa: cuit,
      periodo: periodoTexto,
      fechaPago: fechaPago,
      razonSocial: inst['razonSocial']! as String,
      domicilio: inst['domicilio']! as String,
    );
    final codSAC = LSDGenerator.obtenerCodigoInternoConcepto('SAC');
    final reg2 = LSDGenerator.generateRegistro2Conceptos(
      cuilEmpleado: cuil,
      codigoConcepto: codSAC,
      importe: sac,
      descripcionConcepto: 'SAC (Aguinaldo)',
      tipo: 'H',
    );
    final reg3 = await LSDGenerator.generateRegistro3Bases(
      cuilEmpleado: cuil,
      baseImponibleJubilacion: baseImponible,
      baseImponibleObraSocial: baseImponible,
      baseImponibleLey19032: baseImponible,
    );
    final sb = StringBuffer();
    sb.write(latin1.decode(reg1));
    sb.write(LSDGenerator.eolLsd);
    sb.write(latin1.decode(reg2));
    sb.write(LSDGenerator.eolLsd);
    sb.write(latin1.decode(reg3));
    sb.write(LSDGenerator.eolLsd);

    final lsdName = 'LSD_SAC_${nombreArch}_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.txt';
    final lsdPath = '${dir.path}${Platform.pathSeparator}$lsdName';
    await File(lsdPath).writeAsString(sb.toString(), encoding: latin1);

    // --- Resultados en pantalla (salida de flutter test) ---
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('══════════════════════════════════════════════════════════════════');
    // ignore: avoid_print
    print('  RESULTADOS PRUEBA SAC COMPLETA — Portero en institución privada');
    // ignore: avoid_print
    print('══════════════════════════════════════════════════════════════════');
    // ignore: avoid_print
    print('  Institución: ${inst['razonSocial']}');
    // ignore: avoid_print
    print('  CUIT: ${inst['cuit']}  •  Gestión: privada  •  CABA');
    // ignore: avoid_print
    print('  Empleado: ${legajo['nombre']} (${legajo['cargo']})');
    // ignore: avoid_print
    print('  CUIL: ${legajo['cuil']}');
    // ignore: avoid_print
    print('  Mayor remuneración: \$${mayorRem.toStringAsFixed(0)}  →  SAC: \$${sac.toStringAsFixed(0)}');
    // ignore: avoid_print
    print('  Descuentos (Jub 11%, OS 3%, PAMI 3%): \$${totalDeducciones.toStringAsFixed(0)}');
    // ignore: avoid_print
    print('  NETO: \$${neto.toStringAsFixed(0)}');
    // ignore: avoid_print
    print('  ──────────────────────────────────────────────────────────────');
    // ignore: avoid_print
    print('  Carpeta: ${dir.path}');
    // ignore: avoid_print
    print('  PDF recibo: ${pdfPath.split(Platform.pathSeparator).last}');
    // ignore: avoid_print
    print('  LSD ARCA:   $lsdName');
    // ignore: avoid_print
    print('  --- Contenido LSD (copiar a .txt para subir a ARCA) ---');
    // ignore: avoid_print
    print(sb.toString());
    // ignore: avoid_print
    print('  --- Fin LSD ---');
    // ignore: avoid_print
    print('══════════════════════════════════════════════════════════════════');
    // ignore: avoid_print
    print('');

    expect(File(pdfPath).existsSync(), true, reason: 'Debe existir el PDF');
    expect(File(pdfPath).lengthSync() > 0, true, reason: 'PDF no vacío');
    expect(File(lsdPath).existsSync(), true, reason: 'Debe existir el LSD');
    expect(File(lsdPath).lengthSync() > 0, true, reason: 'LSD no vacío');
  });
}
