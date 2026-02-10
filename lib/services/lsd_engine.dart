import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import '../config/arca_lsd_config.dart';
import '../core/codigos_afip_arca.dart';
import '../models/liquidacion.dart';
import '../services/parametros_legales_service.dart';

/// Motor de formateo para archivos LSD según especificaciones AFIP
class LSDFormatEngine {
  /// Limpia el texto eliminando acentos y caracteres especiales
  /// Convierte caracteres como 'ñ', 'á', 'é', 'í', 'ó', 'ú' a sus equivalentes sin acento
  /// 
  /// [text] - El texto a limpiar
  /// 
  /// Retorna el texto sin acentos ni caracteres especiales
  static String limpiarTexto(String text) {
    // Mapa de caracteres especiales a sus equivalentes
    final Map<String, String> caracteresEspeciales = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
      'ñ': 'n', 'Ñ': 'N',
      'ü': 'u', 'Ü': 'U',
      'ç': 'c', 'Ç': 'C',
    };
    
    String resultado = text;
    
    // Reemplazar caracteres especiales
    caracteresEspeciales.forEach((especial, normal) {
      resultado = resultado.replaceAll(especial, normal);
    });
    
    return resultado;
  }

  /// Formatea un campo LSD según su tipo para ARCA 2026
  /// 
  /// [value] - El valor a formatear (String o num)
  /// [length] - La longitud exacta que debe tener el campo
  /// [type] - El tipo de campo: 'string' o 'number'
  /// 
  /// Si es 'string': completa con espacios a la derecha hasta [length]
  /// Si es 'number': multiplica por 100 (elimina decimales), convierte a entero
  ///                 y rellena con ceros a la izquierda hasta [length]
  /// 
  /// Retorna un String de exactamente [length] caracteres
  /// 
  /// Ejemplo:
  /// ```dart
  /// formatLSDField('ABC', 10, 'string') // 'ABC       ' (10 caracteres)
  /// formatLSDField(1234.56, 8, 'number') // '00123456' (8 caracteres, 1234.56 * 100 = 123456)
  /// formatLSDField(1500.00, 15, 'number') // '0000000000150000' (15 caracteres)
  /// ```
  static String formatLSDField(dynamic value, int length, String type) {
    if (type == 'string') {
      // Convertir a String y limpiar caracteres de control
      String text = value.toString();
      
      // Eliminar caracteres de control (0x00-0x1F excepto tab, newline, carriage return)
      // y DEL (0x7F) que no son válidos en archivos de texto plano
      text = text.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');
      
      // Eliminar saltos de línea y tabs que podrían causar problemas en formato fijo
      text = text.replaceAll(RegExp(r'[\n\r\t]'), ' ');
      
      // Rellenar con espacios a la derecha
      String formatted = text.padRight(length, ' ');
      
      // Truncar si excede el ancho para asegurar exactamente [length] caracteres
      if (formatted.length > length) {
        formatted = formatted.substring(0, length);
      }
      
      return formatted;
    } else if (type == 'number') {
      // Convertir a número
      num numberValue;
      if (value is num) {
        numberValue = value;
      } else if (value is String) {
        numberValue = num.parse(value);
      } else {
        throw ArgumentError('El valor debe ser num o String para tipo number');
      }
      
      // Multiplicar por 100 para eliminar decimales
      int intValue = (numberValue * 100).round();
      
      // Convertir a String y rellenar con ceros a la izquierda
      String formatted = intValue.toString().padLeft(length, '0');
      
      // Truncar si excede el ancho para asegurar exactamente [length] caracteres
      if (formatted.length > length) {
        formatted = formatted.substring(formatted.length - length);
      }
      
      return formatted;
    } else {
      throw ArgumentError('El tipo debe ser "string" o "number", se recibió: $type');
    }
  }

  /// Formatea un monto numérico con ceros a la izquierda y sin comas
  /// 
  /// [amount] - El monto a formatear
  /// [width] - El ancho fijo deseado (incluye decimales)
  /// [decimals] - Número de decimales (por defecto 2)
  /// 
  /// Retorna los bytes codificados en latin1
  static Uint8List formatAmount(double amount, int width, {int decimals = 2}) {
    // Convertir a entero multiplicando por 10^decimals para evitar problemas de punto flotante
    final multiplier = pow(10, decimals).toInt();
    final amountInt = (amount * multiplier).round();
    
    // Formatear con ceros a la izquierda
    final formatted = amountInt.toString().padLeft(width, '0');
    
    // Asegurar que no exceda el ancho
    final result = formatted.length > width 
        ? formatted.substring(formatted.length - width)
        : formatted;
    
    return latin1.encode(result);
  }

  /// Formatea un importe para Registro 02 y 03 con exactamente 15 dígitos
  /// Sin decimales visibles (ej: $1.500.000,00 se formatea como 000000150000000)
  /// 
  /// [amount] - El monto a formatear
  /// 
  /// Retorna los bytes codificados en latin1 con 15 dígitos
  static Uint8List formatImporte15Digitos(double amount) {
    // Convertir a centavos (multiplicar por 100 para tener 2 decimales)
    final amountInt = (amount * 100).round();
    
    // Formatear con ceros a la izquierda hasta 15 dígitos
    final formatted = amountInt.toString().padLeft(15, '0');
    
    // Asegurar que no exceda 15 dígitos (truncar si es necesario)
    final result = formatted.length > 15 
        ? formatted.substring(formatted.length - 15)
        : formatted;
    
    return latin1.encode(result);
  }

  /// Valida que [linea] tenga exactamente [longitud] caracteres.
  /// Lanza [StateError] si tiene un carácter de más o de menos.
  /// Útil para asegurar cumplimiento estricto del formato posicional LSD ARCA 2026.
  static void validarLongitudFija(String linea, int longitud) {
    if (linea.length != longitud) {
      throw StateError(
        'LSD: la línea debe tener exactamente $longitud caracteres, tiene ${linea.length}. '
        'Inicio: ${linea.substring(0, linea.length > 80 ? 80 : linea.length)}',
      );
    }
  }

  /// Formatea un texto con espacios a la derecha hasta el ancho fijo
  /// 
  /// [text] - El texto a formatear
  /// [width] - El ancho fijo deseado
  /// 
  /// Retorna los bytes codificados en latin1
  /// 
  /// Nota: Elimina solo caracteres de control, mantiene acentos y caracteres latinos
  static Uint8List formatText(String text, int width) {
    // Limpiar el texto: eliminar solo caracteres de control (no imprimibles)
    String cleaned = text.trim();
    
    // Eliminar caracteres de control (0x00-0x1F excepto tab, newline, carriage return)
    // y DEL (0x7F) que no son válidos en archivos de texto plano
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');
    
    // Eliminar saltos de línea y tabs que podrían causar problemas en formato fijo
    cleaned = cleaned.replaceAll(RegExp(r'[\n\r\t]'), ' ');
    
    // Rellenar con espacios a la derecha
    final formatted = cleaned.padRight(width, ' ');
    
    // Truncar si excede el ancho
    final result = formatted.length > width 
        ? formatted.substring(0, width)
        : formatted;
    
    // Codificar en latin1 (soporta caracteres acentuados del español)
    return latin1.encode(result);
  }

  /// Formatea una fecha al formato AAAAMMDD
  /// 
  /// [date] - La fecha a formatear (puede ser DateTime o String)
  /// 
  /// Retorna los bytes codificados en latin1
  static Uint8List formatDate(dynamic date) {
    DateTime dateTime;
    
    if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      // Intentar parsear diferentes formatos de fecha
      try {
        // Formato DD/MM/YYYY o DD-MM-YYYY
        if (date.contains('/') || date.contains('-')) {
          final parts = date.replaceAll('/', '-').split('-');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            dateTime = DateTime(year, month, day);
          } else {
            throw FormatException('Formato de fecha inválido: $date');
          }
        } else if (date.length == 8) {
          // Formato YYYYMMDD
          final year = int.parse(date.substring(0, 4));
          final month = int.parse(date.substring(4, 6));
          final day = int.parse(date.substring(6, 8));
          dateTime = DateTime(year, month, day);
        } else {
          dateTime = DateTime.parse(date);
        }
      } catch (e) {
        throw FormatException('No se pudo parsear la fecha: $date', e);
      }
    } else {
      throw ArgumentError('La fecha debe ser DateTime o String');
    }
    
    // Formatear como AAAAMMDD
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    
    final formatted = '$year$month$day';
    
    return latin1.encode(formatted);
  }
}

/// Generador de registros para archivos LSD según especificaciones AFIP
class LSDGenerator {
  /// Fin de línea obligatorio LSD: \r\n. Codificación ISO-8859-1 (latin1).
  static const String eolLsd = '\r\n';

  /// Validador de longitud: si alguna línea no vacía no tiene 150 caracteres, aborta con [StateError].
  static void validarLongitud150(String contenido) {
    final lineas = contenido.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lineas.length; i++) {
      final L = lineas[i].replaceAll('\r', '');
      if (L.isEmpty) continue;
      if (L.length != 150) {
        throw StateError(
          'LSD Guía 4: la línea ${i + 1} tiene ${L.length} caracteres (debe ser 150). '
          'El proceso aborta. Inicio: ${L.substring(0, L.length > 60 ? 60 : L.length)}',
        );
      }
    }
  }

  /// Mapeo ARCA 2026: códigos de 6 dígitos para el archivo LSD.
  /// Verifica contra el catálogo oficial de CodigosAfipArca.
  static String obtenerCodigoArca2026(String concepto) {
    String codigo = '120000'; // Default SAC
    final c = concepto.toLowerCase().trim();
    
    if (c.contains('sac') || c.contains('aguinaldo')) codigo = '120000';
    else if (c.contains('sueldo') && (c.contains('básico') || c.contains('basico'))) codigo = '110000';
    else if (c.contains('antigüedad') || c.contains('antiguedad')) codigo = '111000';
    else if (c.contains('jubilación') || c.contains('jubilacion') || c.contains('sipa')) codigo = '810001';
    else if (c.contains('ley 19') || c.contains('19032') || c.contains('pami')) codigo = '810002';
    else if (c.contains('obra social')) codigo = '810003';
    
    // Validar si el código existe en el catálogo dinámico
    if (!CodigosAfipArca.todos.contains(codigo)) {
      print('Advertencia: El código $codigo derivado de "$concepto" no está en el catálogo oficial activo.');
    }
    
    return codigo;
  }

  /// Genera el Registro 1 (Datos básicos) de 150 caracteres
  /// 
  /// Estructura según ARCA 2026:
  /// - Posición 1: Tipo de registro (1 carácter) = "1"
  /// - Posición 2-12: CUIT empresa sin guiones (11 caracteres)
  /// - Posición 13-18: Período en formato AAAAMM (6 caracteres)
  /// - Posición 19-26: Fecha de pago en formato AAAAMMDD (8 caracteres)
  /// - Posición 27-56: Razón social (30 caracteres, espacios a la derecha)
  /// - Posición 57-96: Domicilio (40 caracteres, espacios a la derecha)
  /// - Posición 97-150: Campos adicionales (54 caracteres). Si [tipoLiquidacion]=='S', pos 97='S' (SAC).
  /// 
  /// Retorna los bytes codificados en latin1
  static Uint8List generateRegistro1({
    required String cuitEmpresa,
    required String periodo,
    required dynamic fechaPago,
    String? razonSocial,
    String? domicilio,
    String? tipoLiquidacion, // 'S' = SAC (Aguinaldo) para ARCA 2026
  }) {
    final buffer = StringBuffer();
    
    // Tipo de registro: 1 (1 carácter)
    buffer.write('1');
    
    // CUIT empresa sin guiones (11 caracteres)
    final cuitLimpio = cuitEmpresa.replaceAll(RegExp(r'[^\d]'), '');
    if (cuitLimpio.length != 11) {
      throw ArgumentError('CUIT debe tener 11 dígitos');
    }
    buffer.write(LSDFormatEngine.formatLSDField(cuitLimpio, 11, 'string'));
    
    // Período (formato AAAAMM) - 6 caracteres
    final periodoFormateado = _formatearPeriodo(periodo);
    buffer.write(LSDFormatEngine.formatLSDField(periodoFormateado, 6, 'string'));
    
    // Fecha de pago (AAAAMMDD) - 8 caracteres
    DateTime dateTime;
    if (fechaPago is DateTime) {
      dateTime = fechaPago;
    } else if (fechaPago is String) {
      try {
        if (fechaPago.contains('/') || fechaPago.contains('-')) {
          final parts = fechaPago.replaceAll('/', '-').split('-');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            dateTime = DateTime(year, month, day);
          } else {
            dateTime = DateTime.parse(fechaPago);
          }
        } else {
          dateTime = DateTime.parse(fechaPago);
        }
      } catch (e) {
        throw FormatException('No se pudo parsear la fecha: $fechaPago', e);
      }
    } else {
      throw ArgumentError('La fecha debe ser DateTime o String');
    }
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final fechaFormateada = '$year$month$day';
    buffer.write(LSDFormatEngine.formatLSDField(fechaFormateada, 8, 'string'));
    
    // Razón social (30 caracteres, espacios a la derecha)
    // Limpiar acentos y caracteres especiales
    final razonSocialLimpia = LSDFormatEngine.limpiarTexto(razonSocial ?? '');
    buffer.write(LSDFormatEngine.formatLSDField(razonSocialLimpia, 30, 'string'));
    
    // Domicilio (40 caracteres, espacios a la derecha)
    // Limpiar acentos y caracteres especiales
    final domicilioLimpio = LSDFormatEngine.limpiarTexto(domicilio ?? '');
    buffer.write(LSDFormatEngine.formatLSDField(domicilioLimpio, 40, 'string'));
    
    // Campos adicionales (54 caracteres). Si tipoLiquidacion=='S', pos 97='S' (SAC) para ARCA 2026.
    final extra = (tipoLiquidacion == 'S' || tipoLiquidacion == 's')
        ? 'S${''.padRight(53, ' ')}'
        : ''.padRight(54, ' ');
    buffer.write(LSDFormatEngine.formatLSDField(extra, 54, 'string'));
    
    // Aplicar formato estricto: padRight(150, ' ').substring(0, 150)
    String linea = buffer.toString();
    linea = linea.padRight(150, ' ').substring(0, 150);
    LSDFormatEngine.validarLongitudFija(linea, 150);
    
    return latin1.encode(linea);
  }

  /// Genera Registro 2 para ARCA 2026 con código de 6 dígitos. 150 caracteres.
  /// Pos: 1 tipo, 2-12 CUIL, 13-18 código ARCA (6), 19-22 cantidad (4), 23 H/D, 24-38 importe (15), 39-150 descripción (112).
  static Uint8List generateRegistro2Arca2026({
    required String cuilEmpleado,
    required String codigoArca6, // 6 dígitos: 120000, 810001, 810002, 810003
    required double importe,
    String tipo = 'H', // 'H' Haber, 'D' Descuento
    String descripcion = '',
    int cantidad = 0,
  }) {
    final cuil = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    if (cuil.length != 11) throw ArgumentError('CUIL debe tener 11 dígitos');
    final cod = codigoArca6.replaceAll(RegExp(r'[^\d]'), '').padLeft(6, '0').substring(0, 6);
    final cant = cantidad.toString().padLeft(4, '0');
    if (cant.length > 4) throw StateError('Cantidad 4 dígitos');
    final ind = (tipo.toUpperCase() == 'D') ? 'D' : 'H';
    final imp = (importe * 100).round().toString().padLeft(15, '0');
    final imp15 = imp.length > 15 ? imp.substring(imp.length - 15) : imp;
    final desc = LSDFormatEngine.limpiarTexto(descripcion);
    final desc112 = LSDFormatEngine.formatLSDField(desc, 112, 'string');
    final linea = '2' + cuil + cod + cant + ind + imp15 + desc112;
    LSDFormatEngine.validarLongitudFija(linea, 150);
    return latin1.encode(linea);
  }

  /// Genera Registro 3 ARCA 2026: 10 bases imponibles obligatorias de 15 caracteres cada una. Total 230 caracteres.
  /// Manual ARCA/AFIP 2026: cada base son 15 dígitos, ceros a la izquierda; si es cero, se escribe 000000000000000.
  /// Pos: 1 tipo, 2-12 CUIL, 13-27 base1, 28-42 base2, ... 148-162 base10, 163-230 relleno (espacios).
  ///
  /// Lógica de seguridad (evitar rechazo ARCA por Base Inconsistente):
  /// - Base 9 (ART): SIEMPRE = Base 1. No puede ser cero (ART sobre total haberes remunerativos).
  /// - Base 4 (Obra Social): = Base 1. Con OS en legajo; si no se detecta, fallback a Base 1.
  /// - Base 8 (Aporte Obra Social): misma lógica que Base 4. Si hay imponible, base de aporte.
  static Uint8List generateRegistro3BasesArca2026({
    required String cuilEmpleado,
    required List<double> bases, // 10 bases (1 a 10). Si < 10, se completan con 0.0 → 000000000000000 c/u.
  }) {
    final cuil = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    if (cuil.length != 11) throw ArgumentError('CUIL debe tener 11 dígitos');
    final b = List<double>.from(bases);
    while (b.length < 10) b.add(0.0);
    
    // Validación de seguridad ARCA 2026: Verificar topes imponibles dinámicos
    for (var i = 0; i < b.length; i++) {
      if (b[i] > 0 && !ArcaLsdConfig.validarTopeBaseImponible(b[i])) {
        // No bloqueamos la generación, pero advertimos en consola para auditoría
        print('Advertencia LSD: La base imponible ${i+1} (${b[i]}) está fuera de los topes vigentes (Min: ${ArcaLsdConfig.configuracionEnero2026['tope_base_imponible_min']}, Max: ${ArcaLsdConfig.configuracionEnero2026['tope_base_imponible_max']}).');
      }
    }

    // Aplicar lógica de seguridad: Base 9 (ART), Base 4 (OS) y Base 8 (Aporte OS) = Base 1
    final base1 = b[0];
    b[8] = base1; // Base 9 ART: obligatoria, nunca cero cuando hay imponible
    b[3] = base1; // Base 4 Obra Social: dinámica con fallback a Base 1 si no se detecta OS
    b[7] = base1; // Base 8 Aporte Obra Social: misma lógica que Base 4
    final sb = StringBuffer();
    sb.write('3');
    sb.write(cuil);
    for (var i = 0; i < 10; i++) {
      // Cada base: exactamente 15 caracteres, ceros a la izquierda. Cero → 000000000000000.
      final valorCentavos = (b[i] * 100).round();
      final base15 = valorCentavos.toString().padLeft(15, '0');
      sb.write(base15.length > 15 ? base15.substring(base15.length - 15) : base15);
    }
    final rest = 230 - 1 - 11 - 150; // 68
    sb.write(LSDFormatEngine.formatLSDField('', rest, 'string'));
    final linea = sb.toString();
    LSDFormatEngine.validarLongitudFija(linea, 230);
    return latin1.encode(linea);
  }

  /// Obtiene el código interno del catálogo de conceptos basado en el nombre del concepto
  /// 
  /// [nombreConcepto] - Nombre del concepto (ej: 'Sueldo Básico', 'Jubilación', etc.)
  /// 
  /// Retorna el código interno de 10 caracteres máximo (ej: 'SUELDO_BAS', 'JUBILACION')
  static String obtenerCodigoInternoConcepto(String nombreConcepto) {
    final conceptoLower = nombreConcepto.toLowerCase().trim();
    
    // Mapeo de nombres de conceptos a códigos internos del catálogo
    if (conceptoLower.contains('sueldo basico') || conceptoLower.contains('sueldo básico')) {
      return 'SUELDO_BAS';
    }
    if (conceptoLower.contains('jornal')) {
      return 'JORNAL';
    }
    if (conceptoLower.contains('adicionales generales') || conceptoLower.contains('adicionales')) {
      return 'ADIC_GEN';
    }
    if (conceptoLower.contains('antiguedad') || conceptoLower.contains('antigüedad')) {
      return 'ANTIGUEDAD';
    }
    // Adicionales específicos de convenio (ej. Camioneros)
    if (conceptoLower.contains('kilometros recorridos') || conceptoLower.contains('kilómetros recorridos') ||
        (conceptoLower.contains('kilometros') && conceptoLower.contains('recorridos'))) {
      return 'KM_RECORR';
    }
    if (conceptoLower.contains('titulo') || conceptoLower.contains('profesionalismo')) {
      return 'TITULO';
    }
    if (conceptoLower.contains('presentismo') || conceptoLower.contains('asistencia')) {
      return 'PRESENTISM';
    }
    if (conceptoLower.contains('horas extras') || conceptoLower.contains('horas extra')) {
      return 'HORAS_EXTR';
    }
    if (conceptoLower.contains('vacaciones')) {
      return 'VACACIONES';
    }
    if (conceptoLower.contains('sac') || conceptoLower.contains('aguinaldo')) {
      return 'SAC';
    }
    if (conceptoLower.contains('gratificaciones') || conceptoLower.contains('bonos') || conceptoLower.contains('premios')) {
      return 'GRATIF';
    }
    if (conceptoLower.contains('fallas de caja') || conceptoLower.contains('fallas caja')) {
      return 'FALLAS_CAJ';
    }
    // Viáticos genéricos
    if (conceptoLower.contains('viaticos / comida') || conceptoLower.contains('viáticos / comida')) {
      return 'VIAT_COM';
    }
    if (conceptoLower.contains('pernocte')) {
      return 'PERNOCTE';
    }
    if (conceptoLower.contains('viaticos') || conceptoLower.contains('viáticos')) {
      return 'VIATICOS';
    }
    if (conceptoLower.contains('asignaciones familiares') || conceptoLower.contains('asig. familiares')) {
      return 'ASIG_FAM';
    }
    if (conceptoLower.contains('indemnizaciones')) {
      return 'INDEMNIZ';
    }
    if (conceptoLower.contains('conceptos no rem') || conceptoLower.contains('conceptos no remun')) {
      return 'CONC_NO_RE';
    }
    if (conceptoLower.contains('jubilacion') || conceptoLower.contains('jubilación') || conceptoLower.contains('sipa')) {
      return 'JUBILACION';
    }
    if (conceptoLower.contains('ley 19.032') || conceptoLower.contains('ley 19032') || conceptoLower.contains('pami')) {
      return 'LEY19032';
    }
    if (conceptoLower.contains('obra social')) {
      return 'OBRA_SOC';
    }
    if (conceptoLower.contains('cuota sindical')) {
      return 'CUOTA_SIND';
    }
    if (conceptoLower.contains('fondo de desempleo') || conceptoLower.contains('uocra')) {
      return 'FONDO_DESE';
    }
    if (conceptoLower.contains('retencion ganancias') || conceptoLower.contains('retención ganancias') || 
        conceptoLower.contains('impuesto ganancias') || conceptoLower.contains('ganancias')) {
      return 'RET_GANANC';
    }
    
    // Si no se encuentra, generar código genérico basado en el nombre (máximo 10 caracteres)
    final codigoGenerico = conceptoLower
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .toUpperCase()
        .substring(0, conceptoLower.length > 10 ? 10 : conceptoLower.length)
        .padRight(10, '_');
    
    return codigoGenerico.length > 10 ? codigoGenerico.substring(0, 10) : codigoGenerico;
  }

  /// Genera el Registro 2 (Conceptos individuales) de 150 caracteres
  /// 
  /// Estructura según ARCA 2026 (posiciones exactas):
  /// - Posición 1: Tipo de registro (1 carácter) = "2"
  /// - Posición 2-12: CUIL empleado sin guiones (11 caracteres)
  /// - Posición 13-22: Código interno del concepto del catálogo (10 caracteres, espacios a la derecha)
  ///                    Ej: 'SUELDO_BAS', 'PRESENTISM', 'JUBILACION'
  /// - Posición 23-26: Cantidad (4 caracteres, ceros a la izquierda, sin multiplicar)
  /// - Posición 27: Indicador 'H' (Haber/Remunerativo) o 'D' (Descuento/Aporte)
  /// - Posición 28-42: Importe (15 caracteres exactos, ceros a la izquierda, sin puntos ni comas, últimos 2 dígitos son decimales)
  /// - Posición 43-150: Descripción (108 caracteres, espacios a la derecha, sin acentos)
  /// 
  /// IMPORTANTE: El parámetro codigoConcepto debe ser el código interno del catálogo (ej: 'SUELDO_BAS'),
  ///             NO el código AFIP. Use obtenerCodigoInternoConcepto() para obtener el código correcto.
  /// 
  /// Retorna los bytes codificados en Windows-1252
  static Uint8List generateRegistro2Conceptos({
    required String cuilEmpleado,
    required String codigoConcepto, // Código interno del catálogo, NO código AFIP
    required double importe,
    String? descripcionConcepto,
    int? cantidad,
    String? tipo, // 'H' para Haber/Remunerativo, 'D' para Descuento/Aporte
  }) {
    final buffer = StringBuffer();
    
    // Pos 1: Tipo de registro: 2 (1 carácter)
    buffer.write('2');
    
    // Pos 2-12: CUIL empleado sin guiones (11 caracteres)
    final cuilLimpio = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    if (cuilLimpio.length != 11) {
      throw ArgumentError('CUIL debe tener 11 dígitos');
    }
    buffer.write(LSDFormatEngine.formatLSDField(cuilLimpio, 11, 'string'));
    
    // Pos 13-22: Código interno del concepto del catálogo (10 caracteres, relleno con espacios a la derecha)
    // Este debe ser el código interno (ej: 'SUELDO_BAS'), NO el código AFIP
    final codigoInternoFormateado = codigoConcepto.trim().toUpperCase();
    buffer.write(LSDFormatEngine.formatLSDField(codigoInternoFormateado, 10, 'string'));
    
    // Pos 23-26: Cantidad (4 caracteres, ceros a la izquierda, sin multiplicar por 100)
    // Si no hay cantidad, usar '0000'
    final cantidadValor = cantidad ?? 0;
    final cantidadFormateada = cantidadValor.toString().padLeft(4, '0');
    if (cantidadFormateada.length > 4) {
      buffer.write(cantidadFormateada.substring(cantidadFormateada.length - 4));
    } else {
      buffer.write(cantidadFormateada);
    }
    
    // Pos 27: Indicador 'H' (Haber/Remunerativo) o 'D' (Descuento/Aporte)
    // Si no se especifica, determinar automáticamente por código interno
    String indicadorTipo;
    if (tipo != null && (tipo.toUpperCase() == 'H' || tipo.toUpperCase() == 'D')) {
      indicadorTipo = tipo.toUpperCase();
    } else {
      // Determinar automáticamente basado en el código interno
      final codigoUpper = codigoInternoFormateado;
      if (codigoUpper.contains('JUBILACION') || 
          codigoUpper.contains('LEY19032') || 
          codigoUpper.contains('OBRA_SOC') ||
          codigoUpper.contains('CUOTA_SIND') ||
          codigoUpper.contains('FONDO_DESE') ||
          codigoUpper.contains('RET_GANANC')) {
        indicadorTipo = 'D'; // Descuento
      } else {
        indicadorTipo = 'H'; // Haber
      }
    }
    buffer.write(indicadorTipo);
    
    // Pos 28-42: Importe (15 caracteres exactos, relleno con ceros a la izquierda, sin puntos ni comas, últimos 2 dígitos son decimales)
    // Convertir a centavos (multiplicar por 100 para tener 2 decimales)
    final amountInt = (importe * 100).round();
    final importeFormateado = amountInt.toString().padLeft(15, '0');
    // Asegurar que no exceda 15 dígitos (truncar si es necesario)
    if (importeFormateado.length > 15) {
      buffer.write(importeFormateado.substring(importeFormateado.length - 15));
    } else {
      buffer.write(importeFormateado);
    }
    
    // Pos 43-150: Descripción del concepto (108 caracteres, completar con espacios al final)
    // Limpiar acentos y caracteres especiales antes de formatear
    final descripcion = descripcionConcepto ?? '';
    final descripcionLimpia = LSDFormatEngine.limpiarTexto(descripcion);
    buffer.write(LSDFormatEngine.formatLSDField(descripcionLimpia, 108, 'string'));
    
    // Aplicar formato estricto: padRight(150, ' ').substring(0, 150)
    String linea = buffer.toString();
    linea = linea.padRight(150, ' ').substring(0, 150);
    
    // Codificar en Windows-1252 (compatible with Latin-1)
    return latin1.encode(linea);
  }

  /// Calcula automáticamente el total de conceptos remunerativos
  /// Suma todos los conceptos marcados como 'H' (Haber/Remunerativo)
  /// 
  /// [conceptos] - Lista de conceptos con sus importes y tipos
  /// 
  /// Retorna el total de conceptos remunerativos
  static double calcularTotalRemunerativoAutomatico(List<Map<String, dynamic>> conceptos) {
    double total = 0.0;
    for (final concepto in conceptos) {
      final tipo = concepto['tipo']?.toString().toUpperCase() ?? 'H';
      if (tipo == 'H') {
        final importe = concepto['importe'] is double 
            ? concepto['importe'] as double
            : (concepto['importe'] is num 
                ? (concepto['importe'] as num).toDouble()
                : double.tryParse(concepto['importe']?.toString() ?? '0') ?? 0.0);
        total += importe;
      }
    }
    return total;
  }
  
  /// Aplica topes legales vigentes a una base imponible
  /// Usa los parámetros legales almacenados dinámicamente
  /// 
  /// [base] - Base imponible a validar
  /// 
  /// Retorna la base ajustada según los topes legales vigentes
  static Future<double> aplicarTopesLegales(double base) async {
    final parametros = await ParametrosLegalesService.cargarParametros();
    return parametros.calcularBaseCalculo(base);
  }

  /// Aplica topes legales 2026 a una base imponible (método sincrónico para compatibilidad)
  /// Máximo: $2.500.000,00
  /// Mínimo: $85.000,00
  /// 
  /// [base] - Base imponible a validar
  /// 
  /// Retorna la base ajustada según los topes
  /// 
  /// DEPRECATED: Usar aplicarTopesLegales() en su lugar
  @Deprecated('Usar aplicarTopesLegales() que carga parámetros dinámicamente')
  static double aplicarTopesLegales2026(double base) {
    const double topeMax = 2500000.00;
    const double topeMin = 85000.00;
    
    if (base > topeMax) {
      return topeMax;
    }
    if (base < topeMin) {
      return topeMin;
    }
    return base;
  }
  
  /// Valida y ajusta la base imponible según los topes legales vigentes
  /// Si el total de conceptos remunerativos supera el tope máximo, retorna el tope máximo
  /// Si es menor al tope mínimo, retorna el tope mínimo
  /// 
  /// [totalRemunerativo] - Total de conceptos remunerativos
  /// 
  /// Retorna el monto ajustado según topes legales vigentes
  static Future<double> validarYAjustarBaseImponible(double totalRemunerativo) async {
    final parametros = await ParametrosLegalesService.cargarParametros();
    return parametros.calcularBaseCalculo(totalRemunerativo);
  }

  /// Valida el total de conceptos remunerativos y retorna el valor ajustado
  /// según los topes legales vigentes. Esta función debe usarse antes de generar
  /// el Registro 02 (Bases Imponibles) para asegurar que se use el tope máximo
  /// cuando el total remunerativo lo supere.
  /// 
  /// [totalRemunerativo] - Total de todos los conceptos remunerativos
  /// 
  /// Retorna el monto ajustado según topes legales vigentes
  /// 
  /// Ejemplo: Si el total remunerativo es $3.000.000 y el tope es $2.500.000,
  /// retornará $2.500.000 para usar en el Registro 02
  static Future<double> validarTotalRemunerativoParaRegistro02(double totalRemunerativo) async {
    final parametros = await ParametrosLegalesService.cargarParametros();
    return parametros.calcularBaseCalculo(totalRemunerativo);
  }

  /// Genera el Registro 3 (Bases Imponibles F.931) de 150 caracteres
  /// 
  /// Estructura según ARCA 2026:
  /// - Posición 1: Tipo de registro (1 carácter) = "3"
  /// - Posición 2-12: CUIL empleado sin guiones (11 caracteres)
  /// - Posición 13-27: Base imponible para Jubilación (15 caracteres, ceros a la izquierda)
  /// - Posición 28-42: Base imponible para Obra Social (15 caracteres, ceros a la izquierda)
  /// - Posición 43-57: Base imponible para Ley 19.032 (15 caracteres, ceros a la izquierda)
  /// - Posición 58-150: Campos adicionales (93 caracteres, espacios a la derecha)
  /// 
  /// IMPORTANTE: Las bases imponibles se ajustan automáticamente según los topes legales vigentes
  /// que se cargan dinámicamente desde ParametrosLegales.
  /// 
  /// Retorna los bytes codificados en latin1
  static Future<Uint8List> generateRegistro3Bases({
    required String cuilEmpleado,
    required double baseImponibleJubilacion,
    required double baseImponibleObraSocial,
    required double baseImponibleLey19032,
    double? totalRemunerativo, // Total de conceptos remunerativos para validación
  }) async {
    final buffer = StringBuffer();
    
    // Tipo de registro: 3 (1 carácter) - Bases Imponibles
    buffer.write('3');
    
    // CUIL empleado sin guiones (11 caracteres)
    final cuilLimpio = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    if (cuilLimpio.length != 11) {
      throw ArgumentError('CUIL debe tener 11 dígitos');
    }
    buffer.write(LSDFormatEngine.formatLSDField(cuilLimpio, 11, 'string'));
    
    // MOTOR DE CÁLCULO DINÁMICO 2026: Aplicar TOPE_BASE directamente
    // TOPE_BASE = $2.500.000,00 (Enero 2026)
    // ignore: constant_identifier_names
    const double TOPE_BASE = 2500000.00;
    
    double baseJubAjustada;
    double baseOSAjustada;
    double baseLey19032Ajustada;
    
    // Si se proporciona el total remunerativo, usar ese valor como base
    // Si no, usar las bases individuales proporcionadas
    final baseCalculada = totalRemunerativo ?? baseImponibleJubilacion;
    
    // Aplicar TOPE_BASE: mínimo entre base calculada y TOPE_BASE
    final baseAjustada = baseCalculada < TOPE_BASE ? baseCalculada : TOPE_BASE;
    baseJubAjustada = baseAjustada;
    baseOSAjustada = baseAjustada;
    baseLey19032Ajustada = baseAjustada;
    
    // Base imponible para Jubilación (15 caracteres, sin decimales visibles)
    // Formato: 000000150000000 (15 dígitos con padding de ceros a la izquierda)
    buffer.write(LSDFormatEngine.formatLSDField(baseJubAjustada, 15, 'number'));
    
    // Base imponible para Obra Social (15 caracteres, sin decimales visibles)
    // Formato: 000000150000000 (15 dígitos con padding de ceros a la izquierda)
    buffer.write(LSDFormatEngine.formatLSDField(baseOSAjustada, 15, 'number'));
    
    // Base imponible para Ley 19.032 (15 caracteres, sin decimales visibles)
    // Formato: 000000150000000 (15 dígitos con padding de ceros a la izquierda)
    buffer.write(LSDFormatEngine.formatLSDField(baseLey19032Ajustada, 15, 'number'));
    
    // Campos adicionales para completar 150 caracteres (93 caracteres restantes)
    buffer.write(LSDFormatEngine.formatLSDField('', 93, 'string'));
    
    // Aplicar formato estricto: padRight(150, ' ').substring(0, 150)
    String linea = buffer.toString();
    linea = linea.padRight(150, ' ').substring(0, 150);
    
    // Codificar en Windows-1252 (compatible with Latin-1)
    return latin1.encode(linea);
  }

  /// Genera el Registro 4 (Datos complementarios de seguridad social) de 150 caracteres
  /// 
  /// Estructura según ARCA 2026:
  /// - Posición 1: Tipo de registro (1 carácter) = "4"
  /// - Posición 2-12: CUIL empleado sin guiones (11 caracteres)
  /// - Posición 13-18: Código RNOS (6 dígitos, espacios a la derecha si es necesario)
  /// - Posición 19-22: Cantidad de familiares a cargo (4 caracteres, ceros a la izquierda)
  /// - Posición 23-150: Campos adicionales de seguridad social (128 caracteres, espacios a la derecha)
  ///                    Incluye datos necesarios para el F.931 (Formulario de Seguridad Social)
  /// 
  /// IMPORTANTE: Este registro debe incluir todos los datos de seguridad social del empleado
  /// para que el F.931 se liquide correctamente.
  /// 
  /// Retorna los bytes codificados en latin1
  static Uint8List generateRegistro4({
    required String cuilEmpleado,
    required String codigoRnos, // Código RNOS de 6 dígitos
    int cantidadFamiliares = 0,
    String? codigoActividad, // 3 dígitos
    String? codigoPuesto,    // 4 dígitos
    String? codigoCondicion, // 2 dígitos
    String? codigoModalidad, // 3 dígitos
    String? numeroAfiliadoObraSocial,
    String? codigoSindicato,
    String? codigoZona,
  }) {
    final buffer = StringBuffer();
    
    // Tipo de registro: 4 (1 carácter) - Datos complementarios de seguridad social
    buffer.write('4');
    
    // CUIL empleado sin guiones (11 caracteres)
    final cuilLimpio = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    if (cuilLimpio.length != 11) {
      throw ArgumentError('CUIL debe tener 11 dígitos');
    }
    buffer.write(LSDFormatEngine.formatLSDField(cuilLimpio, 11, 'string'));
    
    // Código RNOS (6 dígitos, posiciones 13-18)
    final codigoRnosLimpio = codigoRnos.trim();
    final codigoRnosFinal = (codigoRnosLimpio.isNotEmpty && codigoRnosLimpio.length == 6)
        ? codigoRnosLimpio
        : '126205'; // OSECAC por defecto
    buffer.write(LSDFormatEngine.formatLSDField(codigoRnosFinal, 6, 'string'));
    
    // Cantidad de familiares a cargo (4 caracteres, posiciones 19-22, ceros a la izquierda)
    buffer.write(cantidadFamiliares.toString().padLeft(4, '0').substring(0, 4));
    
    // Pos 23: Adherentes (1 carácter) - '0' por defecto
    buffer.write('0');
    
    // Pos 24-26: Código Actividad (3 caracteres)
    final act = (codigoActividad?.trim() ?? '001').padLeft(3, '0').substring(0, 3);
    buffer.write(act);
    
    // Pos 27-30: Código Puesto (4 caracteres)
    final pst = (codigoPuesto?.trim() ?? '0000').padLeft(4, '0').substring(0, 4);
    buffer.write(pst);
    
    // Pos 31-32: Código Condición (2 caracteres)
    final con = (codigoCondicion?.trim() ?? '01').padLeft(2, '0').substring(0, 2);
    buffer.write(con);
    
    // Pos 33-35: Código Modalidad Contratación (3 caracteres)
    final mod = (codigoModalidad?.trim() ?? '008').padLeft(3, '0').substring(0, 3);
    buffer.write(mod);
    
    // Pos 36-37: Código Siniestrado (2 caracteres) - '00'
    buffer.write('00');
    
    // Pos 38: Código Zona (1 carácter)
    final zona = (codigoZona?.trim() ?? '0').padLeft(1, '0').substring(0, 1);
    buffer.write(zona);
    
    // Pos 39-150: Relleno (112 caracteres)
    buffer.write(''.padRight(112, ' '));
    
    // Aplicar formato estricto: padRight(150, ' ').substring(0, 150)
    String linea = buffer.toString();
    linea = linea.padRight(150, ' ').substring(0, 150);
    
    return latin1.encode(linea);
  }

  /// Formatea un período al formato AAAAMM
  /// Acepta formatos como "Enero 2026", "01/2026", "2026-01", etc.
  static String _formatearPeriodo(String periodo) {
    try {
      // Intentar parsear diferentes formatos
      final periodoLower = periodo.toLowerCase().trim();
      
      // Formato "Enero 2026", "Febrero 2026", etc.
      final meses = {
        'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
        'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
        'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12',
      };
      
      for (final entry in meses.entries) {
        if (periodoLower.contains(entry.key)) {
          final yearMatch = RegExp(r'\d{4}').firstMatch(periodo);
          if (yearMatch != null) {
            return '${yearMatch.group(0)}${entry.value}';
          }
        }
      }
      
      // Formato "MM/YYYY" o "MM-YYYY"
      final match1 = RegExp(r'(\d{1,2})[/-](\d{4})').firstMatch(periodo);
      if (match1 != null) {
        final mes = match1.group(1)!.padLeft(2, '0');
        final anio = match1.group(2)!;
        return '$anio$mes';
      }
      
      // Formato "YYYY-MM" o "YYYYMM"
      final match2 = RegExp(r'(\d{4})[/-]?(\d{1,2})').firstMatch(periodo);
      if (match2 != null) {
        final anio = match2.group(1)!;
        final mes = match2.group(2)!.padLeft(2, '0');
        return '$anio$mes';
      }
      
      // Si no se puede parsear, retornar el original truncado/pad
      final soloDigitos = periodo.replaceAll(RegExp(r'[^\d]'), '');
      if (soloDigitos.length >= 6) {
        return soloDigitos.substring(0, 6);
      }
      return soloDigitos.padLeft(6, '0');
    } catch (e) {
      // En caso de error, retornar un formato por defecto
      return '000000';
    }
  }

  /// Genera el archivo completo de liquidación en formato TXT para ARCA 2026
  /// 
  /// [empresa] - Datos de la empresa (razonSocial, cuit, domicilio)
  /// [empleadosConLiquidaciones] - Lista de mapas con:
  ///   - empleado: Map con datos del empleado (nombre, cuil, etc.)
  ///   - liquidacion: Objeto Liquidacion con todos los conceptos
  ///   - sueldoBasico: double con el sueldo básico del empleado
  ///   - codigoObraSocial: String con el código de obra social (opcional)
  /// 
  /// Estructura del archivo según ARCA 2026 (orden jerárquico estricto):
  /// Para cada empleado:
  ///   1. Registro 1: Datos básicos del empleado
  ///   2. Registros 2: Un registro por cada concepto (identificador "2")
  ///   3. Registro 3: Bases imponibles F.931 (identificador "3", una sola vez)
  ///   4. Registro 4: Datos complementarios (identificador "4", una sola vez)
  /// 
  /// Todas las líneas tienen exactamente 150 caracteres con padding de espacios.
  /// 
  /// Retorna un String con todos los registros concatenados (codificación ANSI/latin1)
  static Future<String> generarLiquidacionTXT({
    required Map<String, dynamic> empresa,
    required List<Map<String, dynamic>> empleadosConLiquidaciones,
  }) async {
    final buffer = StringBuffer();
    
    // Validar que haya al menos un empleado
    if (empleadosConLiquidaciones.isEmpty) {
      throw ArgumentError('Debe haber al menos un empleado con liquidación');
    }
    
    // ===== Para cada empleado, generar registros en orden jerárquico =====
    for (final item in empleadosConLiquidaciones) {
      final empleado = item['empleado'] as Map<String, dynamic>;
      final liquidacion = item['liquidacion'] as Liquidacion;
      final sueldoBasico = item['sueldoBasico'] as double;
      
      final cuilEmpleado = empleado['cuil']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '';
      if (cuilEmpleado.length != 11) {
        continue; // Saltar empleados sin CUIL válido
      }
      
      // ===== REGISTRO 1: Datos básicos del empleado =====
      final registro01 = generateRegistro1(
        cuitEmpresa: empresa['cuit']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '',
        periodo: liquidacion.periodo,
        fechaPago: liquidacion.fechaPago,
        razonSocial: empresa['razonSocial']?.toString() ?? '',
        domicilio: empresa['domicilio']?.toString() ?? '',
      );
      buffer.write(String.fromCharCodes(registro01));
      buffer.writeln(); // Nueva línea después de cada registro
      
      // ===== REGISTROS 2: Conceptos individuales (uno por cada concepto) =====
      final conceptos = liquidacion.obtenerConceptosParaTabla(sueldoBasico);
      final sueldoBruto = liquidacion.calcularSueldoBruto(sueldoBasico);
      
      for (final concepto in conceptos) {
        // Obtener código interno del concepto del catálogo (NO código AFIP)
        final codigoInterno = obtenerCodigoInternoConcepto(concepto.concepto);
        
        // Determinar el importe según el tipo de concepto
        double importe = 0.0;
        String tipo = 'H'; // Por defecto Haber
        if (concepto.remunerativo > 0) {
          importe = concepto.remunerativo;
          tipo = 'H';
        } else if (concepto.noRemunerativo > 0) {
          importe = concepto.noRemunerativo;
          tipo = 'H';
        } else if (concepto.deducciones > 0) {
          importe = concepto.deducciones;
          tipo = 'D';
        } else {
          continue; // Saltar conceptos sin monto
        }
        
        // Solo generar registro si hay importe
        if (importe > 0) {
          final registro02 = generateRegistro2Conceptos(
            cuilEmpleado: cuilEmpleado,
            codigoConcepto: codigoInterno, // Código interno del catálogo
            importe: importe,
            descripcionConcepto: concepto.concepto,
            tipo: tipo,
          );
          buffer.write(String.fromCharCodes(registro02));
          buffer.writeln(); // Nueva línea después de cada registro
        }
      }
      
      // ===== REGISTRO 3: Bases imponibles F.931 (una sola vez) =====
      // MOTOR DE CÁLCULO DINÁMICO: Aplicar tope previsional
      final baseImponibleTopeada = liquidacion.obtenerBaseImponibleTopeada(sueldoBruto);
      
      // Las bases imponibles se calculan sobre el valor mínimo entre sueldo bruto y TOPE_BASE
      final baseImponibleJubilacion = baseImponibleTopeada;
      final baseImponibleObraSocial = baseImponibleTopeada;
      final baseImponibleLey19032 = baseImponibleTopeada;
      
      // Calcular total remunerativo para validación de topes
      double totalRemunerativo = sueldoBruto;
      
      final registro03 = await generateRegistro3Bases(
        cuilEmpleado: cuilEmpleado,
        baseImponibleJubilacion: baseImponibleJubilacion,
        baseImponibleObraSocial: baseImponibleObraSocial,
        baseImponibleLey19032: baseImponibleLey19032,
        totalRemunerativo: totalRemunerativo,
      );
      buffer.write(String.fromCharCodes(registro03));
      buffer.writeln(); // Nueva línea después de cada registro
      
      // ===== REGISTRO 4: Datos complementarios de seguridad social (una sola vez) =====
      // Obtener código RNOS y cantidad de familiares del empleado
      final codigoRnos = empleado['codigoRnos']?.toString().trim() ?? '126205'; // OSECAC por defecto
      final cantidadFamiliares = empleado['cantidadFamiliares'] is int
          ? empleado['cantidadFamiliares'] as int
          : (int.tryParse(empleado['cantidadFamiliares']?.toString() ?? '0') ?? 0);
      
      final registro04 = generateRegistro4(
        cuilEmpleado: cuilEmpleado,
        codigoRnos: codigoRnos,
        cantidadFamiliares: cantidadFamiliares,
      );
      buffer.write(String.fromCharCodes(registro04));
      buffer.writeln(); // Nueva línea después de cada registro
    }
    
    return buffer.toString();
  }

  /// Alias para generarLiquidacionTXT (compatibilidad)
  /// 
  /// Genera el archivo completo de liquidación en formato TXT para ARCA 2026
  /// con las reglas estrictas de estructura y padding.
  static Future<String> generarLSDArchivo({
    required Map<String, dynamic> empresa,
    required List<Map<String, dynamic>> empleadosConLiquidaciones,
  }) async {
    return await generarLiquidacionTXT(
      empresa: empresa,
      empleadosConLiquidaciones: empleadosConLiquidaciones,
    );
  }

  /// Guarda el contenido de liquidación en un archivo .txt con codificación Windows-1252 (ANSI)
  /// 
  /// VALIDACIÓN FINAL: Bloquea la descarga si hay errores
  /// - Valida que todas las líneas tengan exactamente 150 caracteres
  /// - Valida que todos los CUILs pasen el Módulo 11
  /// 
  /// [contenido] - El contenido del archivo (string con registros)
  /// [nombreArchivo] - Nombre del archivo sin extensión (se agregará .txt)
  /// 
  /// Retorna la ruta completa del archivo guardado
  /// 
  /// Lanza una excepción si:
  /// - Alguna línea no tiene 150 caracteres
  /// - Algún CUIL no pasa la validación Módulo 11
  /// - No se puede guardar el archivo
  /// 
  /// Nota: Esta función requiere import 'dart:io'
  /// El archivo se codifica en Windows-1252 (ANSI) - OBLIGATORIO
  static Future<String> guardarArchivoTXT({
    required String contenido,
    required String nombreArchivo,
  }) async {
    // ========== VALIDACIÓN FINAL ANTES DE GUARDAR ==========
    final lineas = contenido.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final errores = <String>[];
    
    // Validar longitud de líneas
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      // Eliminar \r si existe
      final lineaLimpia = linea.replaceAll('\r', '');
      if (lineaLimpia.length != 150) {
        errores.add('Línea ${i + 1}: Longitud incorrecta (${lineaLimpia.length} caracteres, debe ser 150)');
      }
    }
    
    // Validar CUILs con Módulo 11
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i].replaceAll('\r', '');
      if (linea.isEmpty || linea.length < 12) continue;
      
      final tipoRegistro = linea[0];
      if (tipoRegistro == '1' || tipoRegistro == '2' || tipoRegistro == '3' || tipoRegistro == '4') {
        if (linea.length >= 12) {
          final cuil = linea.substring(1, 12);
          if (!RegExp(r'^\d{11}$').hasMatch(cuil)) {
            errores.add('Línea ${i + 1}: CUIL con formato inválido ($cuil)');
          } else if (!_validarCUITCUILInterno(cuil)) {
            errores.add('Línea ${i + 1}: CUIL inválido (no pasa Módulo 11): $cuil');
          }
        }
      }
    }
    
    // BLOQUEAR DESCARGA si hay errores
    if (errores.isNotEmpty) {
      throw StateError(
        'ERROR CRÍTICO: El archivo no puede generarse debido a inconsistencias:\n'
        '${errores.join('\n')}\n\n'
        'Por favor, verifique los datos y vuelva a intentar.'
      );
    }
    
    final file = File('$nombreArchivo.txt');
    
    // Codificar el contenido en Windows-1252 (ANSI) - OBLIGATORIO
    // Usar latin1 que es compatible con Windows-1252 para caracteres básicos
    final bytes = latin1.encode(contenido);
    await file.writeAsBytes(bytes);
    
    return file.path;
  }

  /// Asigna el código AFIP a un concepto según la lógica de mapeo de ARCA
  /// 
  /// [nombreConcepto] - Nombre del concepto interno
  /// 
  /// Retorna el código AFIP de 6 dígitos según la biblioteca de mapeo
  static String _asignarCodigoAfip(String nombreConcepto) {
    final conceptoLower = nombreConcepto.toLowerCase().trim();
    
    // HABERES REMUNERATIVOS
    if (conceptoLower.contains('sueldo basico') || 
        conceptoLower.contains('jornal') ||
        conceptoLower.contains('adicionales generales') ||
        conceptoLower.contains('fallas de caja')) {
      return '011000';
    }
    // Kilómetros recorridos (remunerativo) - CCT Camioneros
    if (conceptoLower.contains('kilometros recorridos') || conceptoLower.contains('kilómetros recorridos') ||
        (conceptoLower.contains('kilometros') && conceptoLower.contains('recorridos'))) {
      return '011000';
    }
    if (conceptoLower.contains('antiguedad') || 
        conceptoLower.contains('titulo') ||
        conceptoLower.contains('profesionalismo')) {
      return '012000';
    }
    if (conceptoLower.contains('presentismo') || 
        conceptoLower.contains('asistencia')) {
      return '011000';
    }
    if (conceptoLower.contains('horas extras') || 
        conceptoLower.contains('horas extras 50%') ||
        conceptoLower.contains('horas extras 100%')) {
      return '051000';
    }
    if (conceptoLower.contains('vacaciones')) {
      return '015000';
    }
    if (conceptoLower.contains('plus vacacional') || conceptoLower.contains('plus vac')) {
      return '015000'; // Plus vacacional también usa código AFIP 015000
    }
    if (conceptoLower.contains('sac') || 
        conceptoLower.contains('aguinaldo')) {
      return '031000';
    }
    if (conceptoLower.contains('gratificaciones') || 
        conceptoLower.contains('bonos') ||
        conceptoLower.contains('premios')) {
      return '041000';
    }
    
    // HABERES NO REMUNERATIVOS
    if (conceptoLower.contains('viaticos / comida') || 
        conceptoLower.contains('viáticos / comida') ||
        conceptoLower.contains('pernocte') ||
        conceptoLower.contains('viaticos') || 
        conceptoLower.contains('conceptos no rem') ||
        conceptoLower.contains('conceptos no remun')) {
      return '112000';
    }
    if (conceptoLower.contains('asignaciones familiares') || 
        conceptoLower.contains('asig. familiares')) {
      return '111000';
    }
    if (conceptoLower.contains('indemnizaciones')) {
      return '131000';
    }
    
    // DESCUENTOS / RETENCIONES
    if (conceptoLower.contains('jubilacion') || 
        conceptoLower.contains('sipa')) {
      return '810000';
    }
    if (conceptoLower.contains('ley 19.032') || 
        conceptoLower.contains('ley 19032') ||
        conceptoLower.contains('pami')) {
      return '810000';
    }
    if (conceptoLower.contains('obra social')) {
      return '810000';
    }
    if (conceptoLower.contains('cuota sindical')) {
      return '820000';
    }
    if (conceptoLower.contains('fondo de desempleo') || 
        conceptoLower.contains('uocra')) {
      return '820000';
    }
    if (conceptoLower.contains('retencion ganancias') || 
        conceptoLower.contains('impuesto ganancias') ||
        conceptoLower.contains('ganancias')) {
      return '990000';
    }
    
    // Si no coincide, intentar con el mapeo de ArcaLsdConfig
    final codigoAfip = ArcaLsdConfig.obtenerCodigoAfipPorCoincidencia(nombreConcepto);
    if (codigoAfip != null) {
      return codigoAfip;
    }
    
    // Código por defecto según el tipo (si se puede inferir)
    if (conceptoLower.contains('descuento') || 
        conceptoLower.contains('retencion') ||
        conceptoLower.contains('aporte')) {
      return '810000'; // Descuento genérico
    }
    
    // Si no se puede determinar, usar código genérico remunerativo
    return '011000';
  }

  /// Genera el archivo de Importación de Conceptos para ARCA
  /// 
  /// Este archivo es el diccionario que asocia códigos internos con códigos AFIP oficiales.
  /// 
  /// Estructura por línea (150 caracteres exactos):
  /// - Pos 1-10: Código interno de la app (rellenar con espacios a la derecha)
  /// - Pos 11-60: Descripción (rellenar con espacios a la derecha)
  /// - Pos 61-66: Código AFIP (6 dígitos exactos)
  /// - Pos 67-150: Espacios en blanco
  /// 
  /// [conceptosAdicionales] - Lista opcional de conceptos adicionales personalizados
  ///                         Cada elemento debe ser un Map con 'codigo' y 'descripcion'
  /// 
  /// Retorna el contenido del archivo como String (codificado en Latin-1/ANSI)
  static String generarArchivoConceptosTXT({
    List<Map<String, String>>? conceptosAdicionales,
  }) {
    final buffer = StringBuffer();
    
    // ========== LISTA DE CONCEPTOS CON CÓDIGOS AFIP EXACTOS ==========
    // ARQUITECTURA DE LONGITUD FIJA ABSOLUTA - CÓDIGOS ESPECÍFICOS
    // Los códigos AFIP están hardcodeados para evitar errores de asignación
    final conceptosEstandar = [
      {'codigo': 'SUELDO_BAS', 'descripcion': 'Sueldo Basico', 'codigoAfip': '011000'},
      {'codigo': 'PRESENTISM', 'descripcion': 'Presentismo / Asistencia', 'codigoAfip': '011000'},
      {'codigo': 'ADIC_GEN', 'descripcion': 'Adicionales Generales', 'codigoAfip': '011000'},
      {'codigo': 'ANTIGUEDAD', 'descripcion': 'Antiguedad', 'codigoAfip': '012000'},
      {'codigo': 'HORAS_EXTR', 'descripcion': 'Horas Extras', 'codigoAfip': '051000'},
      {'codigo': 'VIATICOS', 'descripcion': 'Viaticos (con/sin comprobante)', 'codigoAfip': '112000'},
      {'codigo': 'JUBILACION', 'descripcion': 'Jubilacion (SIPA)', 'codigoAfip': '810000'},
      {'codigo': 'LEY19032', 'descripcion': 'Ley 19.032 (PAMI)', 'codigoAfip': '810000'},
      {'codigo': 'OBRA_SOC', 'descripcion': 'Obra Social', 'codigoAfip': '810000'},
      {'codigo': 'CUOTA_SIND', 'descripcion': 'Cuota Sindical', 'codigoAfip': '820000'},
      {'codigo': 'RET_GANANC', 'descripcion': 'Retencion Impuesto a las Ganancias', 'codigoAfip': '990000'},
    ];
    
    // ========== PROCESAR CONCEPTOS ESTÁNDAR CON CÓDIGOS AFIP EXACTOS ==========
    for (final concepto in conceptosEstandar) {
      final codigoInterno = concepto['codigo']!;
      final descripcion = concepto['descripcion']!;
      final codigoAfip = concepto['codigoAfip']!; // Código AFIP hardcodeado
      
      // Generar línea con formato exacto usando arquitectura de longitud fija absoluta
      final linea = _generarLineaConcepto(
        codigoInterno: codigoInterno,
        descripcion: descripcion,
        codigoAfip: codigoAfip,
      );
      buffer.write(linea);
      buffer.writeln();
    }
    
    // Procesar conceptos adicionales personalizados si se proporcionan
    if (conceptosAdicionales != null) {
      for (final concepto in conceptosAdicionales) {
        final codigoInterno = concepto['codigo'] ?? 'CONC_GEN';
        final descripcion = concepto['descripcion'] ?? 'Concepto Generico';
        final codigoAfip = _asignarCodigoAfip(descripcion);
        
        final linea = _generarLineaConcepto(
          codigoInterno: codigoInterno,
          descripcion: descripcion,
          codigoAfip: codigoAfip,
        );
        buffer.write(linea);
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }

  /// Genera una línea individual del archivo de conceptos
  /// 
  /// ARQUITECTURA DE LONGITUD FIJA ABSOLUTA - SISTEMA DE MISIÓN CRÍTICA
  /// 
  /// Esta función implementa una lógica infalible que garantiza:
  /// - Columna 1-10: ID Interno (10 caracteres exactos)
  /// - Columna 11-60: Descripción (50 caracteres exactos)
  /// - Columna 61-66: Código AFIP (6 caracteres exactos) ← POSICIÓN CRÍTICA
  /// - Columna 67-150: Relleno (84 espacios)
  /// 
  /// Total: 150 caracteres exactos - NO PERMITE ERRORES DE DESPLAZAMIENTO
  /// 
  /// [codigoInterno] - Código interno (máximo 10 caracteres)
  /// [descripcion] - Descripción del concepto (máximo 50 caracteres)
  /// [codigoAfip] - Código AFIP de 6 dígitos
  /// 
  /// Retorna una línea de exactamente 150 caracteres
  /// GARANTIZA que el código AFIP empiece SIEMPRE en la posición 61
  static String _generarLineaConcepto({
    required String codigoInterno,
    required String descripcion,
    required String codigoAfip,
  }) {
    // ========== LIMPIEZA DE MEMORIA Y VARIABLES TEMPORALES ==========
    // Eliminar cualquier residuo de procesamiento anterior
    String idLimpio = codigoInterno.trim();
    String descLimpia = descripcion.trim();
    String codAfipLimpio = codigoAfip.trim();
    
    // ========== COLUMNA 1: ID INTERNO (10 caracteres exactos - Pos 1-10) ==========
    // Limpiar ID: eliminar caracteres especiales, mantener solo alfanuméricos y guiones bajos
    idLimpio = idLimpio.replaceAll(RegExp(r'[^\w]'), '').toUpperCase();
    // Forzar exactamente 10 caracteres: padRight + substring (Dart usa padRight, no padEnd)
    final col1 = idLimpio.padRight(10, ' ').substring(0, 10);
    
    // ========== COLUMNA 2: DESCRIPCIÓN (50 caracteres exactos - Pos 11-60) ==========
    // Limpiar descripción: eliminar acentos y caracteres especiales ANTES del padding
    // Usar normalización NFD (equivalente a JavaScript normalize('NFD'))
    descLimpia = descLimpia
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u')
        .replaceAll('Á', 'A').replaceAll('É', 'E').replaceAll('Í', 'I')
        .replaceAll('Ó', 'O').replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n').replaceAll('Ñ', 'N')
        .replaceAll('ü', 'u').replaceAll('Ü', 'U');
    
    // Eliminar cualquier otro carácter especial que pueda causar problemas
    descLimpia = descLimpia.replaceAll(RegExp(r'[^\w\s]'), ' ');
    
    // Forzar exactamente 50 caracteres: padRight + substring (Dart usa padRight)
    // Esto garantiza que la columna 3 (AFIP) SIEMPRE empiece en posición 61
    final col2 = descLimpia.padRight(50, ' ').substring(0, 50);
    
    // ========== COLUMNA 3: CÓDIGO AFIP (6 caracteres exactos - Pos 61-66) ==========
    // Validar y limpiar código AFIP: solo dígitos
    codAfipLimpio = codAfipLimpio.replaceAll(RegExp(r'[^\d]'), '');
    if (codAfipLimpio.length != 6) {
      throw ArgumentError(
        'CÓDIGO AFIP INVÁLIDO: Debe tener exactamente 6 dígitos. '
        'Recibido: "$codigoAfip" (${codAfipLimpio.length} dígitos después de limpiar)'
      );
    }
    
    // Forzar exactamente 6 caracteres con padding de ceros a la izquierda (Dart usa padLeft)
    final col3 = codAfipLimpio.padLeft(6, '0').substring(0, 6);
    
    // ========== COLUMNA 4: RELLENO FINAL (84 espacios - Pos 67-150) ==========
    // Generar exactamente 84 espacios en blanco (Dart usa padRight)
    final col4 = ''.padRight(84, ' ');
    
    // ========== CONSTRUCCIÓN DE LA LÍNEA FINAL ==========
    // Concatenar las 4 columnas en orden estricto
    final resultado = col1 + col2 + col3 + col4;
    
    // ========== VALIDACIÓN DE SEGURIDAD INTERNA (BLOQUEO ABSOLUTO) ==========
    if (resultado.length != 150) {
      throw StateError(
        'ERROR CRÍTICO DE LONGITUD: La línea generada tiene ${resultado.length} caracteres, '
        'debe tener exactamente 150.\n'
        'ID: "$codigoInterno"\n'
        'Descripción: "$descripcion"\n'
        'Código AFIP: "$codigoAfip"\n'
        'Col1 (ID): ${col1.length} chars\n'
        'Col2 (Desc): ${col2.length} chars\n'
        'Col3 (AFIP): ${col3.length} chars\n'
        'Col4 (Relleno): ${col4.length} chars'
      );
    }
    
    // ========== VALIDACIÓN ADICIONAL: Verificar posición del código AFIP ==========
    // El código AFIP debe estar en la posición 61 (índice 60 en base 0)
    final codigoAfipEnPosicion = resultado.substring(60, 66);
    if (codigoAfipEnPosicion != col3) {
      throw StateError(
        'ERROR CRÍTICO DE DESPLAZAMIENTO: El código AFIP no está en la posición 61.\n'
        'Esperado en posición 61-66: "$col3"\n'
        'Encontrado en posición 61-66: "$codigoAfipEnPosicion"'
      );
    }
    
    return resultado;
  }
  
  /// Valida un archivo LSD antes de la descarga
  /// 
  /// [contenido] - Contenido del archivo a validar
  /// 
  /// Retorna un mapa con:
  /// - 'valido': bool indicando si el archivo es válido
  /// - 'errores': Lista de mensajes de error
  /// - 'advertencias': Lista de advertencias
  static Map<String, dynamic> validarArchivoLSD(String contenido) {
    final errores = <String>[];
    final advertencias = <String>[];
    final lineas = contenido.split('\n').where((l) => l.trim().isNotEmpty).toList();
    
    // Importar función de validación (import dinámico no es posible en Dart,
    // así que usamos la función directamente)
    // Nota: Esta función debe estar disponible en el scope, se importará en el archivo que la use
    
    // Validar longitud de líneas
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      if (linea.length != 150) {
        errores.add('Línea ${i + 1}: Longitud incorrecta (${linea.length} caracteres, debe ser 150)');
      }
    }
    
    // Validar CUILs y códigos en registros
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      if (linea.isEmpty || linea.length < 12) continue;
      
      final tipoRegistro = linea[0];
      
      if (tipoRegistro == '1' || tipoRegistro == '2' || tipoRegistro == '3' || tipoRegistro == '4') {
        // Validar CUIL (posiciones 2-12) - Validación matemática con Módulo 11
        if (linea.length >= 12) {
          final cuil = linea.substring(1, 12);
          
          // Primero verificar formato básico
          if (!RegExp(r'^\d{11}$').hasMatch(cuil)) {
            errores.add('Línea ${i + 1}: CUIL con formato inválido ($cuil) - BLOQUEA DESCARGA');
          } else {
            // VALIDACIÓN MATEMÁTICA OBLIGATORIA: Algoritmo Módulo 11 (BLOQUEA descarga si falla)
            if (!_validarCUITCUILInterno(cuil)) {
              errores.add('Línea ${i + 1}: CUIL inválido (no pasa Módulo 11): $cuil - BLOQUEA DESCARGA');
            }
          }
        }
      }
      
      if (tipoRegistro == '2') {
        // Validar código interno del concepto (posiciones 13-22)
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
  
  /// Valida un CUIT o CUIL usando el algoritmo de Módulo 11 (función interna)
  /// Esta función replica la lógica de validadores.dart para evitar dependencias circulares
  /// ya que lsd_engine.dart no puede importar utils/validadores.dart directamente
  static bool _validarCUITCUILInterno(String numero) {
    // Limpiar el número (eliminar guiones y espacios)
    final digitsOnly = numero.replaceAll(RegExp(r'[^\d]'), '');
    
    // Verificar que tenga exactamente 11 dígitos
    if (digitsOnly.length != 11) {
      return false;
    }
    
    // Verificar que todos sean dígitos
    if (!RegExp(r'^\d{11}$').hasMatch(digitsOnly)) {
      return false;
    }
    
    // Obtener el dígito verificador (último dígito)
    final digitoVerificador = int.parse(digitsOnly[10]);
    
    // Coeficientes para el algoritmo de Módulo 11
    final coeficientes = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
    
    // Multiplicar los primeros 10 dígitos por los coeficientes y sumar
    int suma = 0;
    for (int i = 0; i < 10; i++) {
      final digito = int.parse(digitsOnly[i]);
      suma += digito * coeficientes[i];
    }
    
    // Calcular el resto de la división por 11
    final resto = suma % 11;
    
    // Calcular el dígito verificador esperado según el algoritmo oficial
    int digitoEsperado;
    if (resto == 0) {
      digitoEsperado = 0;
    } else if (resto == 1) {
      digitoEsperado = 9; // Caso especial: si resto es 1, dígito es 9
    } else {
      digitoEsperado = 11 - resto;
    }
    
    // Comparar el dígito verificador ingresado con el esperado
    return digitoVerificador == digitoEsperado;
  }
}
