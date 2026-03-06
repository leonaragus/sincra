import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../config/arca_lsd_config.dart';
import '../core/validation_utils.dart'; // ACCIÓN CORRECTIVA 5: Importar el núcleo de validación
import '../models/liquidacion.dart';
import '../services/parametros_legales_service.dart';

class LSDFormatEngine {
  // ... (código sin cambios)
}

class LSDGenerator {
  static const String eolLsd = '\r\n';
  static String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^\d]'), '');
  static String _pad(String s, int len) {
    final t = s.length > len ? s.substring(0, len) : s;
    return t.padRight(len, ' ');
  }
  static String _padDigits(String s, int len) {
    final d = _digitsOnly(s);
    final t = d.length > len ? d.substring(d.length - len) : d;
    return t.padLeft(len, '0');
  }
  static String _importe15(double monto) {
    final v = (monto * 100).round();
    final s = v.toString();
    return s.length > 15 ? s.substring(s.length - 15) : s.padLeft(15, '0');
  }
  static Uint8List _encodeFixed(String s) {
    final line = s.length == 195 ? s : s.padRight(195, ' ');
    return latin1.encode(line);
  }
  static Uint8List generateRegistro1({
    required String cuitEmpresa,
    required String periodo,
    required String fechaPago,
    required String razonSocial,
    required String domicilio,
    String? tipoLiquidacion,
  }) {
    final cuilPlaceholder = _padDigits('', 11);
    final p = _pad(periodo, 10);
    final fp = _pad(fechaPago, 10);
    final rs = _pad(razonSocial, 50);
    final dom = _pad(domicilio, 50);
    final ce = _padDigits(cuitEmpresa, 11);
    final tl = _pad(tipoLiquidacion ?? '', 1);
    final s = '1' + cuilPlaceholder + ce + p + fp + rs + dom + tl;
    return _encodeFixed(s);
  }
  static Uint8List generateRegistro2DatosReferenciales({
    required String cuilEmpleado,
    required String legajo,
    required int diasBase,
  }) {
    final cuil = _padDigits(cuilEmpleado, 11);
    final lg = _pad(legajo, 10);
    final db = _padDigits(diasBase.toString(), 2);
    final s = '2' + cuil + lg + db;
    return _encodeFixed(s);
  }
  static Uint8List generateRegistro3Conceptos({
    required String cuilEmpleado,
    required String codigoConcepto,
    required double importe,
    required String descripcionConcepto,
    String? tipo,
    int? cantidad,
  }) {
    final cuil = _padDigits(cuilEmpleado, 11);
    final cod = _pad(codigoConcepto.toUpperCase(), 10);
    final imp = _importe15(importe);
    final desc = _pad(descripcionConcepto, 50);
    final tp = _pad((tipo ?? 'H').toUpperCase(), 1);
    final cant = _padDigits((cantidad ?? 0).toString(), 6);
    final s = '3' + cuil + cod + imp + desc + tp + cant;
    return _encodeFixed(s);
  }
  static Uint8List generateRegistro4Bases({
    required String cuilEmpleado,
    required List<double> bases,
  }) {
    final cuil = _padDigits(cuilEmpleado, 11);
    final b = List<double>.from(bases);
    while (b.length < 10) {
      b.add(0.0);
    }
    final parts = b.take(10).map(_importe15).join();
    final s = '4' + cuil + parts;
    return _encodeFixed(s);
  }
  static Uint8List generateRegistro5DatosComplementarios({
    required String cuilEmpleado,
    required String codigoRnos,
    required int cantidadFamiliares,
    String? codigoModalidad,
    String? codigoCondicion,
    String? codigoActividad,
    String? codigoPuesto,
    String? codigoZona,
  }) {
    final cuil = _padDigits(cuilEmpleado, 11);
    final rnos = _padDigits(codigoRnos, 6);
    final fam = _padDigits(cantidadFamiliares.toString(), 2);
    final mod = _padDigits((codigoModalidad ?? ''), 3);
    final cond = _padDigits((codigoCondicion ?? ''), 2);
    final act = _padDigits((codigoActividad ?? ''), 3);
    final puesto = _padDigits((codigoPuesto ?? ''), 4);
    final zona = _padDigits((codigoZona ?? ''), 1);
    final s = '5' + cuil + rnos + fam + mod + cond + act + puesto + zona;
    return _encodeFixed(s);
  }

  static Uint8List validarYObtenerBytesLSD({
    required String contenido,
    int longitudEsperada = 195,
  }) {
    final lineas = contenido.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final errores = <String>[];
    
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      final lineaLimpia = linea.replaceAll('\r', '');
      if (lineaLimpia.length != longitudEsperada) {
        errores.add('Línea ${i + 1}: Longitud incorrecta (${lineaLimpia.length} caracteres, debe ser $longitudEsperada)');
      }
    }
    
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i].replaceAll('\r', '');
      if (linea.isEmpty || linea.length < 12) continue;
      
      final tipoRegistro = linea[0];
      if (tipoRegistro == '1' || tipoRegistro == '2' || tipoRegistro == '3' || tipoRegistro == '4' || tipoRegistro == '5') {
        if (linea.length >= 12) {
          final cuil = linea.substring(1, 12);
          if (!RegExp(r'^\d{11}$').hasMatch(cuil)) {
            errores.add('Línea ${i + 1}: CUIL con formato inválido ($cuil)');
          // ACCIÓN CORRECTIVA 5: Reemplazar la función duplicada por la llamada al core.
          } else if (!validarCUITCUIL(cuil)) { 
            errores.add('Línea ${i + 1}: CUIL inválido (no pasa Módulo 11): $cuil');
          }
        }
      }
    }
    
    if (errores.isNotEmpty) {
      throw StateError(
        'ERROR CRÍTICO: El archivo no puede generarse debido a inconsistencias:\n'
        '${errores.join('\n')}\n\n'
        'Por favor, verifique los datos y vuelva a intentar.'
      );
    }
    
    return latin1.encode(contenido);
  }

  // ... (código sin cambios)

  static Map<String, dynamic> validarArchivoLSD(String contenido, {int longitudEsperada = 195}) {
    final errores = <String>[];
    final advertencias = <String>[];
    final lineas = contenido.split('\n').where((l) => l.trim().isNotEmpty).toList();
    
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      final lineaLimpia = linea.replaceAll('\r', '');
      if (lineaLimpia.length != longitudEsperada) {
        errores.add('Línea ${i + 1}: Longitud incorrecta (${lineaLimpia.length} caracteres, debe ser $longitudEsperada)');
      }
    }
    
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      if (linea.isEmpty || linea.length < 12) continue;
      
      final tipoRegistro = linea[0];
      
      if (tipoRegistro == '1' || tipoRegistro == '2' || tipoRegistro == '3' || tipoRegistro == '4' || tipoRegistro == '5') {
        if (linea.length >= 12) {
          final cuil = linea.substring(1, 12);
          
          if (!RegExp(r'^\d{11}$').hasMatch(cuil)) {
            errores.add('Línea ${i + 1}: CUIL con formato inválido ($cuil) - BLOQUEA DESCARGA');
          } else {
            // ACCIÓN CORRECTIVA 5: Reemplazar la función duplicada por la llamada al core.
            if (!validarCUITCUIL(cuil)) {
              errores.add('Línea ${i + 1}: CUIL inválido (no pasa Módulo 11): $cuil - BLOQUEA DESCARGA');
            }
          }
        }
      }
      
      if (tipoRegistro == '3') {
        if (linea.length >= 22) {
          final codigoInterno = linea.substring(12, 22).trim();
          if (codigoInterno.isEmpty) {
            errores.add('Línea ${i + 1}: Código interno del concepto vacío');
          }
        }
      }
    }
    
    return {
      'valido': errores.isEmpty,
      'errores': errores,
      'advertencias': advertencias,
    };
  }
  
  // ACCIÓN CORRECTIVA 5: Eliminar la función duplicada `_validarCUITCUILInterno`
  static void validarLongitud195(String contenido) {
    final r = validarArchivoLSD(contenido, longitudEsperada: 195);
    if (r['valido'] != true) {
      final errs = (r['errores'] as List).join('\n');
      throw StateError(errs);
    }
  }
}
