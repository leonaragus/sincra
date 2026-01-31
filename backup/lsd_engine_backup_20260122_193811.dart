import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Motor de formateo para archivos LSD según especificaciones AFIP
class LSDFormatEngine {
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
  /// Genera el Registro 1 (Cabecera) de 150 caracteres
  /// 
  /// Estructura según AFIP:
  /// - Posición 1: Tipo de registro (1 carácter) = "1"
  /// - Posición 2-12: CUIT empresa sin guiones (11 caracteres)
  /// - Posición 13-18: Período en formato AAAAMM (6 caracteres)
  /// - Posición 19-26: Fecha de pago en formato AAAAMMDD (8 caracteres)
  /// - Posición 27-56: Razón social (30 caracteres, espacios a la derecha)
  /// - Posición 57-96: Domicilio (40 caracteres, espacios a la derecha)
  /// - Posición 97-150: Campos adicionales (54 caracteres, espacios a la derecha)
  /// 
  /// Retorna los bytes codificados en latin1
  static Uint8List generateRegistro1({
    required String cuitEmpresa,
    required String periodo,
    required dynamic fechaPago,
    String? razonSocial,
    String? domicilio,
  }) {
    final buffer = StringBuffer();
    
    // Tipo de registro: 1 (1 carácter)
    buffer.write('1');
    
    // CUIT empresa sin guiones (11 caracteres, ceros a la izquierda)
    final cuitLimpio = cuitEmpresa.replaceAll(RegExp(r'[^\d]'), '');
    if (cuitLimpio.length != 11) {
      throw ArgumentError('CUIT debe tener 11 dígitos');
    }
    buffer.write(latin1.decode(LSDFormatEngine.formatText(cuitLimpio, 11)));
    
    // Período (formato AAAAMM) - 6 caracteres
    final periodoFormateado = _formatearPeriodo(periodo);
    buffer.write(latin1.decode(LSDFormatEngine.formatText(periodoFormateado, 6)));
    
    // Fecha de pago (AAAAMMDD) - 8 caracteres
    buffer.write(latin1.decode(LSDFormatEngine.formatDate(fechaPago)));
    
    // Razón social (30 caracteres, espacios a la derecha)
    buffer.write(latin1.decode(LSDFormatEngine.formatText(razonSocial ?? '', 30)));
    
    // Domicilio (40 caracteres, espacios a la derecha)
    buffer.write(latin1.decode(LSDFormatEngine.formatText(domicilio ?? '', 40)));
    
    // Campos adicionales para completar 150 caracteres (54 caracteres restantes)
    // Estos campos pueden incluir otros datos según especificaciones AFIP
    buffer.write(latin1.decode(LSDFormatEngine.formatText('', 54)));
    
    // Asegurar que el registro tenga exactamente 150 caracteres
    final result = buffer.toString();
    if (result.length != 150) {
      throw StateError('El registro 1 debe tener exactamente 150 caracteres, tiene ${result.length}');
    }
    
    return latin1.encode(result);
  }

  /// Genera el Registro 3 (Conceptos) de 110 caracteres
  /// 
  /// Estructura según AFIP:
  /// - Posición 1: Tipo de registro (1 carácter) = "3"
  /// - Posición 2-12: CUIL empleado sin guiones (11 caracteres)
  /// - Posición 13-18: Código de concepto (6 caracteres, espacios a la derecha)
  /// - Posición 19-33: Importe (15 caracteres, ceros a la izquierda, sin decimales visibles)
  /// - Posición 34-83: Descripción del concepto (50 caracteres, espacios a la derecha)
  /// - Posición 84-110: Campos adicionales (27 caracteres, espacios a la derecha)
  /// 
  /// Retorna los bytes codificados en latin1
  static Uint8List generateRegistro3({
    required String cuilEmpleado,
    required String codigoConcepto,
    required double importe,
    String? descripcionConcepto,
    int? cantidadDecimales,
  }) {
    final buffer = StringBuffer();
    
    // Tipo de registro: 3 (1 carácter)
    buffer.write('3');
    
    // CUIL empleado sin guiones (11 caracteres)
    final cuilLimpio = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    if (cuilLimpio.length != 11) {
      throw ArgumentError('CUIL debe tener 11 dígitos');
    }
    buffer.write(latin1.decode(LSDFormatEngine.formatText(cuilLimpio, 11)));
    
    // Código de concepto (6 caracteres, espacios a la derecha)
    buffer.write(latin1.decode(LSDFormatEngine.formatText(codigoConcepto, 6)));
    
    // Importe (15 caracteres, 2 decimales por defecto, ceros a la izquierda)
    final decimales = cantidadDecimales ?? 2;
    buffer.write(latin1.decode(LSDFormatEngine.formatAmount(importe, 15, decimals: decimales)));
    
    // Descripción del concepto (50 caracteres, espacios a la derecha)
    buffer.write(latin1.decode(LSDFormatEngine.formatText(descripcionConcepto ?? '', 50)));
    
    // Campos adicionales para completar 110 caracteres (27 caracteres restantes)
    buffer.write(latin1.decode(LSDFormatEngine.formatText('', 27)));
    
    // Asegurar que el registro tenga exactamente 110 caracteres
    final result = buffer.toString();
    if (result.length != 110) {
      throw StateError('El registro 3 debe tener exactamente 110 caracteres, tiene ${result.length}');
    }
    
    return latin1.encode(result);
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
}
