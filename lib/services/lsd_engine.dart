import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import '../config/arca_lsd_config.dart';
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
      final String dateStr = date.trim();
      if (dateStr.isEmpty) {
        throw FormatException('La fecha no puede estar vacía');
      }

      // Intentar parsear diferentes formatos de fecha
      try {
        // Formato DD/MM/YYYY o DD-MM-YYYY
        if (dateStr.contains('/') || dateStr.contains('-')) {
          final parts = dateStr.replaceAll('/', '-').split('-');
          if (parts.length == 3) {
            // Intentar DD-MM-YYYY
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            
            // Validar que el año sea de 4 dígitos (común en Argentina)
            if (year < 100) {
              // Si es YY, asumir 20YY
              dateTime = DateTime(2000 + year, month, day);
            } else {
              dateTime = DateTime(year, month, day);
            }
          } else {
            throw FormatException('Formato de fecha inválido (esperado DD/MM/YYYY): $dateStr');
          }
        } else if (dateStr.length == 8) {
          // Formato YYYYMMDD
          final year = int.parse(dateStr.substring(0, 4));
          final month = int.parse(dateStr.substring(4, 6));
          final day = int.parse(dateStr.substring(6, 8));
          dateTime = DateTime(year, month, day);
        } else {
          // Intentar parseo ISO
          dateTime = DateTime.parse(dateStr);
        }
      } catch (e) {
        throw FormatException('No se pudo interpretar la fecha "$dateStr". Use formato DD/MM/AAAA.');
      }
    } else {
      throw ArgumentError('La fecha debe ser DateTime o String, se recibió: ${date.runtimeType}');
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

  /// Validador de longitud: si alguna línea no vacía no tiene 195 caracteres, aborta con [StateError].
  static void validarLongitud195(String contenido) {
    final lineas = contenido.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lineas.length; i++) {
      final L = lineas[i].replaceAll('\r', '');
      if (L.isEmpty) continue;
      
      const longitudEsperada = 195;
      
      if (L.length != longitudEsperada) {
        throw StateError(
          'LSD ARCA: la línea ${i + 1} tiene ${L.length} caracteres (debe ser $longitudEsperada). '
          'El proceso aborta. Inicio: ${L.substring(0, L.length > 60 ? 60 : L.length)}',
        );
      }
    }
  }

  /// Obtiene el código interno (10 chars) para un concepto dado su nombre
  static String obtenerCodigoInternoConcepto(String nombreConcepto) {
    final nombreLower = nombreConcepto.toLowerCase().trim();
    
    if (nombreLower.contains('sueldo basico') || nombreLower.contains('jornal')) return 'SUELDO_BAS';
    if (nombreLower.contains('antiguedad')) return 'ANTIGUEDAD';
    if (nombreLower.contains('presentismo')) return 'PRESENTISM';
    if (nombreLower.contains('horas extras')) return 'HORAS_EXTR';
    if (nombreLower.contains('vacaciones')) return 'VACACIONES';
    if (nombreLower.contains('sac') || nombreLower.contains('aguinaldo')) return 'SAC';
    if (nombreLower.contains('jubilacion')) return 'JUBILACION';
    if (nombreLower.contains('obra social')) return 'OBRA_SOC';
    if (nombreLower.contains('ley 19.032') || nombreLower.contains('pami')) return 'LEY19032';
    if (nombreLower.contains('sindicato') || nombreLower.contains('cuota')) return 'CUOTA_SIND';
    if (nombreLower.contains('ganancias')) return 'RET_GANANC';
    if (nombreLower.contains('viaticos')) return 'VIATICOS';
    if (nombreLower.contains('zona')) return 'ZONA_DESF';
    if (nombreLower.contains('titulo')) return 'TITULO';
    
    // Si no coincide, generar uno basado en el nombre
    String codigo = nombreConcepto.replaceAll(RegExp(r'[^\w]'), '').toUpperCase();
    if (codigo.length > 10) codigo = codigo.substring(0, 10);
    return codigo.padRight(10, ' ');
  }

  /// Calcula el total remunerativo sumando los conceptos de tipo 'H' (Haberes remunerativos)
  static double calcularTotalRemunerativoAutomatico(List<Map<String, dynamic>> conceptos) {
    double total = 0.0;
    for (final c in conceptos) {
      final tipo = c['tipo']?.toString().toUpperCase() ?? '';
      if (tipo == 'H' || tipo == 'REM') {
        total += (c['importe'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  /// Aplica los topes legales vigentes a la base imponible
  static Future<double> aplicarTopesLegales(double base) async {
    try {
      final params = await ParametrosLegalesService.cargarParametros();
      if (base < params.baseImponibleMinima) return params.baseImponibleMinima;
      if (base > params.baseImponibleMaxima) return params.baseImponibleMaxima;
    } catch (e) {
      print('Error aplicando topes legales: $e');
    }
    return base;
  }

  /// Genera el Registro 1 (Datos de la liquidación) de 195 caracteres
  /// 
  /// Estructura según ARCA:
  /// - Posición 1: Tipo de registro (1 carácter) = "1"
  /// - Posición 2-12: CUIT empresa sin guiones (11 caracteres)
  /// - Posición 13-18: Período en formato AAAAMM (6 caracteres)
  /// - Posición 19-26: Fecha de pago en formato AAAAMMDD (8 caracteres)
  /// - Posición 27-56: Razón social (30 caracteres, espacios a la derecha)
  /// - Posición 57-96: Domicilio (40 caracteres, espacios a la derecha)
  /// - Posición 97-195: Campos adicionales y relleno (99 caracteres).
  static Uint8List generateRegistro1({
    required String cuitEmpresa,
    required String periodo,
    required dynamic fechaPago,
    String? razonSocial,
    String? domicilio,
    String? tipoLiquidacion, // 'S' = SAC (Aguinaldo)
  }) {
    final buffer = StringBuffer();
    
    buffer.write('1');
    
    final cuitLimpio = cuitEmpresa.replaceAll(RegExp(r'[^\d]'), '');
    if (cuitLimpio.length != 11) throw ArgumentError('CUIT debe tener 11 dígitos');
    buffer.write(LSDFormatEngine.formatLSDField(cuitLimpio, 11, 'string'));
    
    final periodoFormateado = _formatearPeriodo(periodo);
    buffer.write(LSDFormatEngine.formatLSDField(periodoFormateado, 6, 'string'));
    
    // Usar el método robusto formatDate para la fecha de pago
    final fechaPagoBytes = LSDFormatEngine.formatDate(fechaPago);
    buffer.write(latin1.decode(fechaPagoBytes));
    
    final razonSocialLimpia = LSDFormatEngine.limpiarTexto(razonSocial ?? '');
    buffer.write(LSDFormatEngine.formatLSDField(razonSocialLimpia, 30, 'string'));
    
    final domicilioLimpio = LSDFormatEngine.limpiarTexto(domicilio ?? '');
    buffer.write(LSDFormatEngine.formatLSDField(domicilioLimpio, 40, 'string'));
    
    // Campos adicionales (99 caracteres para llegar a 195)
    // Si tipoLiquidacion=='S', pos 97='S'
    final extra = (tipoLiquidacion == 'S' || tipoLiquidacion == 's')
        ? 'S${''.padRight(98, ' ')}'
        : ''.padRight(99, ' ');
    buffer.write(LSDFormatEngine.formatLSDField(extra, 99, 'string'));
    
    String linea = buffer.toString();
    linea = linea.padRight(195, ' ').substring(0, 195);
    LSDFormatEngine.validarLongitudFija(linea, 195);
    
    return latin1.encode(linea);
  }

  /// Genera Registro 2 (Datos referenciales del trabajador) de 195 caracteres
  /// Estructura según ARCA:
  /// - Pos 1: '2'
  /// - Pos 2-12: CUIL (11)
  /// - Pos 13-22: Legajo (10) - Opcional
  /// - Pos 23-44: CBU (22) - Opcional
  /// - Pos 45-47: Días base (3) - Default '030'
  /// - Pos 48-195: Relleno
  static Uint8List generateRegistro2DatosReferenciales({
    required String cuilEmpleado,
    String? legajo,
    String? cbu,
    int diasBase = 30,
  }) {
    final buffer = StringBuffer();
    buffer.write('2');
    
    final cuilLimpio = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    buffer.write(LSDFormatEngine.formatLSDField(cuilLimpio, 11, 'string'));
    
    final legajoLimpio = LSDFormatEngine.limpiarTexto(legajo ?? '').trim();
    buffer.write(LSDFormatEngine.formatLSDField(legajoLimpio, 10, 'string'));
    
    final cbuLimpio = (cbu ?? '').replaceAll(RegExp(r'[^\d]'), '');
    buffer.write(LSDFormatEngine.formatLSDField(cbuLimpio, 22, 'string'));
    
    final dias = diasBase.toString().padLeft(3, '0');
    buffer.write(dias);
    
    // Relleno hasta 195 (195 - 1 - 11 - 10 - 22 - 3 = 148 restantes)
    buffer.write(''.padRight(148, ' '));
    
    String linea = buffer.toString();
    linea = linea.padRight(195, ' ').substring(0, 195);
    LSDFormatEngine.validarLongitudFija(linea, 195);
    
    return latin1.encode(linea);
  }

  /// Genera Registro 3 (Detalle de conceptos) - ANTES REGISTRO 2
  /// Estructura: '3' + CUIL + Codigo + Cant + Tipo + Importe + Descripcion + Relleno
  static Uint8List generateRegistro3Conceptos({
    required String cuilEmpleado,
    required String codigoConcepto,
    required double importe,
    String? descripcionConcepto,
    int? cantidad,
    String? tipo,
  }) {
    final buffer = StringBuffer();
    buffer.write('3'); // Cambiado de 2 a 3
    
    final cuilLimpio = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    buffer.write(LSDFormatEngine.formatLSDField(cuilLimpio, 11, 'string'));
    
    final codigoInternoFormateado = codigoConcepto.trim().toUpperCase();
    buffer.write(LSDFormatEngine.formatLSDField(codigoInternoFormateado, 10, 'string'));
    
    final cantidadValor = cantidad ?? 0;
    final cantidadFormateada = cantidadValor.toString().padLeft(4, '0');
    buffer.write(cantidadFormateada.substring(cantidadFormateada.length - 4));
    
    String indicadorTipo;
    final tipoUpper = tipo?.toUpperCase();
    if (tipoUpper == 'R' || tipoUpper == 'H') {
      indicadorTipo = 'H'; // Remunerativo (Haber)
    } else if (tipoUpper == 'N') {
      indicadorTipo = 'N'; // No Remunerativo
    } else if (tipoUpper == 'D') {
      indicadorTipo = 'D'; // Descuento
    } else {
      // Lógica de detección automática si no se provee tipo explícito
      final codigoUpper = codigoInternoFormateado;
      if (codigoUpper.contains('JUBILACION') || codigoUpper.contains('LEY19032') || codigoUpper.contains('OBRA_SOC') || codigoUpper.contains('RET_GANANC')) {
        indicadorTipo = 'D';
      } else {
        indicadorTipo = 'H';
      }
    }
    buffer.write(indicadorTipo);
    
    final amountInt = (importe * 100).round();
    final importeFormateado = amountInt.toString().padLeft(15, '0');
    buffer.write(importeFormateado.length > 15 ? importeFormateado.substring(importeFormateado.length - 15) : importeFormateado);
    
    final descripcion = descripcionConcepto ?? '';
    final descripcionLimpia = LSDFormatEngine.limpiarTexto(descripcion);
    // Ajustar longitud descripcion para llegar a 195
    // Usados: 1+11+10+4+1+15 = 42. Restan: 195-42 = 153.
    buffer.write(LSDFormatEngine.formatLSDField(descripcionLimpia, 153, 'string'));
    
    String linea = buffer.toString();
    linea = linea.padRight(195, ' ').substring(0, 195);
    LSDFormatEngine.validarLongitudFija(linea, 195);
    
    return latin1.encode(linea);
  }

  /// Genera Registro 4 (Bases Imponibles F.931) de 195 caracteres
  /// 
  /// Estructura según ARCA:
  /// - Posición 1: Tipo de registro (1 carácter) = "4"
  /// - Posición 2-12: CUIL empleado sin guiones (11 caracteres)
  /// - Posición 13-27: Base imponible para Jubilación (15 caracteres, ceros a la izquierda)
  /// - Posición 28-42: Base imponible para Obra Social (15 caracteres, ceros a la izquierda)
  /// - Posición 43-57: Base imponible para Ley 19.032 (15 caracteres, ceros a la izquierda)
  /// - ... hasta 10 bases
  /// - Posición 163-195: Relleno (33 caracteres, espacios a la derecha)
  static Uint8List generateRegistro4Bases({
    required String cuilEmpleado,
    required List<double> bases, // 10 bases (1 a 10). Si < 10, se completan con 0.0 → 000000000000000 c/u.
  }) {
    final cuil = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    if (cuil.length != 11) throw ArgumentError('CUIL debe tener 11 dígitos');
    final b = List<double>.from(bases);
    while (b.length < 10) b.add(0.0);
    
    // Validación de seguridad ARCA: Verificar topes imponibles dinámicos
    for (var i = 0; i < b.length; i++) {
      if (b[i] > 0 && !ArcaLsdConfig.validarTopeBaseImponible(b[i])) {
        print('Advertencia LSD: La base imponible ${i+1} (${b[i]}) está fuera de los topes vigentes.');
      }
    }

    // Aplicar lógica de seguridad: Base 9 (ART), Base 4 (OS) y Base 8 (Aporte OS) = Base 1
    final base1 = b[0];
    b[8] = base1; // Base 9 ART
    b[3] = base1; // Base 4 Obra Social
    b[7] = base1; // Base 8 Aporte Obra Social
    
    final sb = StringBuffer();
    sb.write('4'); // Cambiado de 3 a 4
    sb.write(cuil);
    for (var i = 0; i < 10; i++) {
      final valorCentavos = (b[i] * 100).round();
      final base15 = valorCentavos.toString().padLeft(15, '0');
      sb.write(base15.length > 15 ? base15.substring(base15.length - 15) : base15);
    }
    
    // Relleno hasta 195 (195 - 1 - 11 - 150 = 33)
    sb.write(''.padRight(33, ' '));
    
    final linea = sb.toString();
    LSDFormatEngine.validarLongitudFija(linea, 195);
    return latin1.encode(linea);
  }
  
  // Deprecated wrapper for compatibility
  static Future<Uint8List> generateRegistro3Bases({
      required String cuilEmpleado,
      required double baseImponibleJubilacion,
      required double baseImponibleObraSocial,
      required double baseImponibleLey19032,
      double? totalRemunerativo,
    }) async {
      // Create bases list
      final bases = List<double>.filled(10, 0.0);
      final baseCalculada = totalRemunerativo ?? baseImponibleJubilacion;
      // TOPE logic is handled inside generateRegistro4Bases if we pass raw values, 
      // BUT here we need to simulate the old behavior where we passed specific bases.
      // However, to avoid code duplication, we'll assume the caller wants standard bases.
      // Since this is deprecated, we map to the new function but with Identifier 4.
      // Wait, if I change the identifier here, old code calling this will now output 4.
      // This is INTENDED as per user request to fix the format.
      
      const double TOPE_BASE = 2500000.00;
      final baseAjustada = baseCalculada < TOPE_BASE ? baseCalculada : TOPE_BASE;
      
      bases[0] = baseAjustada;
      bases[1] = baseAjustada; // Usually Base 2 is same
      bases[2] = baseAjustada; // Usually Base 3 is same
      
      return generateRegistro4Bases(cuilEmpleado: cuilEmpleado, bases: bases);
  }

  /// Genera el Registro 5 (Datos complementarios de seguridad social) de 195 caracteres
  /// 
  /// Estructura según ARCA:
  /// - Posición 1: Tipo de registro (1 carácter) = "5" (antes 4)
  /// - ... Mismos campos ...
  /// - Relleno hasta 195.
  static Uint8List generateRegistro5DatosComplementarios({
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
    
    buffer.write('5'); // Cambiado de 4 a 5
    
    final cuilLimpio = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
    if (cuilLimpio.length != 11) throw ArgumentError('CUIL debe tener 11 dígitos');
    buffer.write(LSDFormatEngine.formatLSDField(cuilLimpio, 11, 'string'));
    
    final codigoRnosLimpio = codigoRnos.trim();
    final codigoRnosFinal = (codigoRnosLimpio.isNotEmpty && codigoRnosLimpio.length == 6)
        ? codigoRnosLimpio
        : '126205';
    buffer.write(LSDFormatEngine.formatLSDField(codigoRnosFinal, 6, 'string'));
    
    buffer.write(cantidadFamiliares.toString().padLeft(4, '0').substring(0, 4));
    buffer.write('0'); // Adherentes
    
    final act = (codigoActividad?.trim() ?? '001').padLeft(3, '0').substring(0, 3);
    buffer.write(act);
    
    final pst = (codigoPuesto?.trim() ?? '0000').padLeft(4, '0').substring(0, 4);
    buffer.write(pst);
    
    final con = (codigoCondicion?.trim() ?? '01').padLeft(2, '0').substring(0, 2);
    buffer.write(con);
    
    final mod = (codigoModalidad?.trim() ?? '008').padLeft(3, '0').substring(0, 3);
    buffer.write(mod);
    
    buffer.write('00'); // Siniestrado
    
    final zona = (codigoZona?.trim() ?? '0').padLeft(1, '0').substring(0, 1);
    buffer.write(zona);
    
    // Relleno hasta 195
    // Usados: 1+11+6+4+1+3+4+2+3+2+1 = 38
    // Restan: 195 - 38 = 157
    buffer.write(''.padRight(157, ' '));
    
    final linea = buffer.toString();
    final lineaPad = linea.padRight(195, ' ').substring(0, 195);
    
    return latin1.encode(lineaPad);
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
      
      // ===== REGISTRO 2: Datos referenciales del trabajador =====
      final registro02Ref = generateRegistro2DatosReferenciales(
        cuilEmpleado: cuilEmpleado,
        legajo: empleado['legajo']?.toString(),
        cbu: empleado['cbu']?.toString(),
        diasBase: 30, // Default 30 días
      );
      buffer.write(String.fromCharCodes(registro02Ref));
      buffer.writeln();

      // ===== REGISTRO 3: Conceptos individuales (uno por cada concepto) =====
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
          final registro03Conc = generateRegistro3Conceptos(
            cuilEmpleado: cuilEmpleado,
            codigoConcepto: codigoInterno, // Código interno del catálogo
            importe: importe,
            descripcionConcepto: concepto.concepto,
            tipo: tipo,
          );
          buffer.write(String.fromCharCodes(registro03Conc));
          buffer.writeln(); // Nueva línea después de cada registro
        }
      }
      
      // ===== REGISTRO 4: Bases imponibles F.931 (una sola vez) =====
      // MOTOR DE CÁLCULO DINÁMICO: Aplicar tope previsional
      final baseImponibleTopeada = liquidacion.obtenerBaseImponibleTopeada(sueldoBruto);
      
      // Bases imponibles (10 bases)
      final bases = List<double>.filled(10, 0.0);
      bases[0] = baseImponibleTopeada; // Base 1
      bases[1] = baseImponibleTopeada; // Base 2
      bases[2] = baseImponibleTopeada; // Base 3
      bases[8] = baseImponibleTopeada; // Base 9 (LRT)
      
      final registro04Bases = generateRegistro4Bases(
        cuilEmpleado: cuilEmpleado,
        bases: bases,
      );
      buffer.write(String.fromCharCodes(registro04Bases));
      buffer.writeln(); // Nueva línea después de cada registro
      
      // ===== REGISTRO 5: Datos complementarios de seguridad social (una sola vez) =====
      // Obtener código RNOS y cantidad de familiares del empleado
      final codigoRnos = empleado['codigoRnos']?.toString().trim() ?? '126205'; // OSECAC por defecto
      final cantidadFamiliares = empleado['cantidadFamiliares'] is int
          ? empleado['cantidadFamiliares'] as int
          : (int.tryParse(empleado['cantidadFamiliares']?.toString() ?? '0') ?? 0);
      
      final registro05Compl = generateRegistro5DatosComplementarios(
        cuilEmpleado: cuilEmpleado,
        codigoRnos: codigoRnos,
        cantidadFamiliares: cantidadFamiliares,
      );
      buffer.write(String.fromCharCodes(registro05Compl));
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
  /// - Valida que todas las líneas tengan la longitud esperada
  /// - Valida que todos los CUILs pasen el Módulo 11
  /// 
  /// [contenido] - El contenido del archivo (string con registros)
  /// [nombreArchivo] - Nombre del archivo sin extensión (se agregará .txt)
  /// [longitudEsperada] - Longitud esperada de las líneas (default 195 para ARCA LSD)
  /// 
  /// Retorna la ruta completa del archivo guardado
  /// Valida el contenido del archivo LSD y devuelve los bytes en formato Windows-1252 (ANSI)
  /// Lanza [StateError] si la validación falla.
  static Uint8List validarYObtenerBytesLSD({
    required String contenido,
    int longitudEsperada = 195,
  }) {
    // ========== VALIDACIÓN FINAL ==========
    final lineas = contenido.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final errores = <String>[];
    
    // Validar longitud de líneas
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      // Eliminar \r si existe
      final lineaLimpia = linea.replaceAll('\r', '');
      if (lineaLimpia.length != longitudEsperada) {
        errores.add('Línea ${i + 1}: Longitud incorrecta (${lineaLimpia.length} caracteres, debe ser $longitudEsperada)');
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
    
    // BLOQUEAR si hay errores
    if (errores.isNotEmpty) {
      throw StateError(
        'ERROR CRÍTICO: El archivo no puede generarse debido a inconsistencias:\n'
        '${errores.join('\n')}\n\n'
        'Por favor, verifique los datos y vuelva a intentar.'
      );
    }
    
    // Codificar el contenido en Windows-1252 (ANSI) - OBLIGATORIO
    // Usar latin1 que es compatible con Windows-1252 para caracteres básicos
    return latin1.encode(contenido);
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
  /// [longitudEsperada] - Longitud esperada de las líneas (default 195)
  /// 
  /// Retorna un mapa con:
  /// - 'valido': bool indicando si el archivo es válido
  /// - 'errores': Lista de mensajes de error
  /// - 'advertencias': Lista de advertencias
  static Map<String, dynamic> validarArchivoLSD(String contenido, {int longitudEsperada = 195}) {
    final errores = <String>[];
    final advertencias = <String>[];
    final lineas = contenido.split('\n').where((l) => l.trim().isNotEmpty).toList();
    
    // Importar función de validación (import dinámico no es posible en Dart,
    // así que usamos la función directamente)
    // Nota: Esta función debe estar disponible en el scope, se importará en el archivo que la use
    
    // Validar longitud de líneas
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      // Eliminar \r si existe
      final lineaLimpia = linea.replaceAll('\r', '');
      if (lineaLimpia.length != longitudEsperada) {
        errores.add('Línea ${i + 1}: Longitud incorrecta (${lineaLimpia.length} caracteres, debe ser $longitudEsperada)');
      }
    }
    
    // Validar CUILs y códigos en registros
    for (int i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      if (linea.isEmpty || linea.length < 12) continue;
      
      final tipoRegistro = linea[0];
      
      if (tipoRegistro == '1' || tipoRegistro == '2' || tipoRegistro == '3' || tipoRegistro == '4' || tipoRegistro == '5') {
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
      
      if (tipoRegistro == '3') { // Conceptos ahora es registro 3
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
