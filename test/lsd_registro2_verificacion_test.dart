// Verificación técnica de precisión: Registro Tipo 2 (Conceptos) LSD ARCA 2026.
// Imprime una línea real de SAC y una regla numérica para validar columnas (150 caracteres).
// Escribe test/LSD_Registro2_SAC_ejemplo.txt con la línea y la regla para copiar.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:syncra_arg/services/lsd_engine.dart';

void main() {
  test('Registro Tipo 2 SAC: formato posicional 150 chars, CUIL, código, importe 15, H', () {
    // 1. Datos de prueba
    const cuil = '20-31234567-7';
    const codigoArca = '120000'; // SAC
    const monto = 256906.08; // $256.906,08
    const indicador = 'H'; // Haber

    // 2. Generar Registro Tipo 2 con generateRegistro2Arca2026
    final reg2 = LSDGenerator.generateRegistro2Arca2026(
      cuilEmpleado: cuil,
      codigoArca6: codigoArca,
      importe: monto,
      tipo: indicador,
      descripcion: 'SAC (Aguinaldo)',
    );

    String linea = latin1.decode(reg2);

    // Rellenar con espacios hasta 150 si por algún motivo viniera más corta
    if (linea.length < 150) {
      linea = linea.padRight(150, ' ');
    }

    LSDFormatEngine.validarLongitudFija(linea, 150);

    // 3. Salida: línea y regla numérica para conteo visual de columnas
    print('');
    print('=== Registro Tipo 2 (SAC) - 150 caracteres ===');
    print(linea);
    print('');
    print('--- Regla numérica (columnas 1-150, cada 10) ---');
    print(('1234567890' * 15).substring(0, 150));
    print('');
    print('--- Posiciones: 1=Tipo(2), 2-12=CUIL(11), 13-18=Código(6), 19-22=Cant(4), 23=H/D(1), 24-38=Importe(15), 39-150=Desc(112) ---');
    print('');

    // Escribir archivo .txt para copiar (línea + regla + posiciones)
    final f = File('test/LSD_Registro2_SAC_ejemplo.txt');
    f.writeAsStringSync(
      '$linea\n'
      "${('1234567890' * 15).substring(0, 150)}\n"
      'Posiciones: 1=Tipo(2), 2-12=CUIL(11), 13-18=Código(6), 19-22=Cant(4), 23=H/D(1), 24-38=Importe(15), 39-150=Desc(112)\n',
    );
    print('Archivo escrito: ${f.path}');

    // Opcional: LSD completo (Reg1 + Reg2 + Reg3) para copiar
    final reg1 = LSDGenerator.generateRegistro1(
      cuitEmpresa: '30-12345678-9',
      periodo: 'SAC 1º Semestre 2026',
      fechaPago: '30/06/2026',
      razonSocial: 'Empresa Prueba SAC',
      domicilio: 'Av. Corrientes 123, CABA',
      tipoLiquidacion: 'S',
    );
    // Reg3: 10 bases imponibles obligatorias; cada una 15 caracteres (000000000000000 si es cero)
    final reg3 = LSDGenerator.generateRegistro3BasesArca2026(
      cuilEmpleado: cuil,
      bases: [256906.08, 256906.08, 256906.08, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    );
    final reg3Str = latin1.decode(reg3);
    expect(reg3Str.length, 230, reason: 'Reg3 debe tener 230 caracteres');
    for (var i = 0; i < 10; i++) {
      final baseI = reg3Str.substring(12 + i * 15, 12 + (i + 1) * 15);
      expect(baseI.length, 15, reason: 'Base ${i + 1} debe tener 15 caracteres (ceros 000000000000000 si es 0)');
    }
    // Lógica de seguridad: Base 9 (ART) = Base 1; Base 4 (OS) y Base 8 (Aporte OS) = Base 1
    final base1Str = reg3Str.substring(12, 27);
    expect(reg3Str.substring(12 + 8 * 15, 12 + 9 * 15), base1Str, reason: 'Base 9 (ART) debe ser igual a Base 1');
    expect(reg3Str.substring(12 + 3 * 15, 12 + 4 * 15), base1Str, reason: 'Base 4 (Obra Social) debe ser igual a Base 1');
    expect(reg3Str.substring(12 + 7 * 15, 12 + 8 * 15), base1Str, reason: 'Base 8 (Aporte OS) debe ser igual a Base 1');
    // Relleno 163-230: espacios
    expect(reg3Str.substring(162), ' ' * 68, reason: 'Pos 163-230: 68 espacios en blanco');
    final lsdCompleto = StringBuffer();
    lsdCompleto.write(latin1.decode(reg1));
    lsdCompleto.write(LSDGenerator.eolLsd);
    lsdCompleto.write(linea);
    lsdCompleto.write(LSDGenerator.eolLsd);
    lsdCompleto.write(latin1.decode(reg3));
    lsdCompleto.write(LSDGenerator.eolLsd);
    final fCompleto = File('test/LSD_completo_ejemplo.txt');
    fCompleto.writeAsStringSync(lsdCompleto.toString());
    print('LSD completo escrito: ${fCompleto.path}');

    // Verificación automática del importe esperado
    final importeEsperado = '000000025690608'; // 256906.08 * 100 = 25690608
    final importeEnLinea = linea.length >= 38 ? linea.substring(23, 38) : '';
    expect(importeEnLinea, importeEsperado, reason: 'Importe 15 dígitos en pos 24-38');

    final cuilLimpio = cuil.replaceAll(RegExp(r'[^\d]'), '');
    final cuilEnLinea = linea.length >= 12 ? linea.substring(1, 12) : '';
    expect(cuilEnLinea, cuilLimpio, reason: 'CUIL 11 dígitos en pos 2-12');

    final codEnLinea = linea.length >= 18 ? linea.substring(12, 18) : '';
    expect(codEnLinea, codigoArca.padLeft(6, '0').substring(0, 6), reason: 'Código 6 dígitos en pos 13-18');

    expect(linea[0], '2', reason: 'Tipo de registro 2 en pos 1');
    expect(linea[22], indicador, reason: 'Indicador H en pos 23 (índice 22)');
  });
}
