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
  // ... (código sin cambios)

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
}
