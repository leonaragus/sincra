
import '../models/lsd_parsed_data.dart';

class LSDParserService {
  /// Parsea el contenido de un archivo LSD TXT
  static LSDParsedFile parseFileContent(String content) {
    final result = LSDParsedFile();
    final lines = content.split(RegExp(r'\r?\n'));

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].replaceAll('\r', '');
      if (line.isEmpty) continue;

      // ARCA 2026: La validación de 195 caracteres debe ser estricta pero flexible ante EOF
      if (line.length != 195) {
        // Ignorar líneas vacías al final que puedan tener basura
        if (line.trim().isEmpty) continue;
        
        // Intentar recuperar líneas cortas si es posible (padding con espacios)
        if (line.length < 195) {
          result.erroresParsing.add('Advertencia Línea ${i + 1}: Longitud corta (${line.length} chars). Se rellenó con espacios.');
          // Pad right with spaces
          // line = line.padRight(195, ' '); // No podemos modificar 'line' porque es final en este scope si no reasignamos
          // En vez de reasignar, usamos lógica de substring segura
        } else {
          result.erroresParsing.add('Error Línea ${i + 1}: Longitud incorrecta (${line.length} chars). Se esperaban 195.');
          continue;
        }
      }
      
      // Pad line if short (to avoid RangeError)
      final safeLine = line.length < 195 ? line.padRight(195, ' ') : line;

      // ARCA 2026 usa 2 dígitos para tipo de registro: '01', '02', '03', '04', '05'
      // Legacy usa 1 dígito: '1', '2', '3', '4', '5'
      String tipo = safeLine.substring(0, 2);
      bool isNewFormat = ['01', '02', '03', '04', '05'].contains(tipo);
      
      if (!isNewFormat) {
        // Intentar detectar si es formato legacy (1 dígito)
        final primerChar = safeLine.substring(0, 1);
        if (['1', '2', '3', '4', '5'].contains(primerChar)) {
          tipo = primerChar;
        } else {
          result.erroresParsing.add('Error Línea ${i + 1}: El inicio de la línea "$primerChar" no corresponde a ningún tipo de registro válido (01-05 o 1-5).');
          continue;
        }
      }

      try {
        switch (tipo) {
          case '01':
          case '1':
            result.header = _parseHeader(safeLine);
            break;
          case '02':
          case '2':
            result.referencias.add(_parseReferencia(safeLine));
            break;
          case '03':
          case '3':
            result.conceptos.add(_parseConcepto(safeLine));
            break;
          case '04':
          case '4':
            result.bases.add(_parseBases(safeLine));
            break;
          case '05':
          case '5':
            result.complementarios.add(_parseComplementarios(safeLine));
            break;
          default:
            result.erroresParsing.add('Línea ${i + 1}: Tipo de registro desconocido "$tipo".');
        }
      } catch (e) {
        result.erroresParsing.add('Línea ${i + 1}: Error procesando registro tipo $tipo. Verifique que la línea tenga el formato correcto.');
      }
    }

    return result;
  }

  static LSDHeader _parseHeader(String line) {
    final isNew = line.startsWith('01');
    final offset = isNew ? 1 : 0;
    
    return LSDHeader(
      tipoRegistro: isNew ? '01' : '1',
      cuitEmpresa: _safeSubstring(line, 1 + offset, 12 + offset),
      periodo: _safeSubstring(line, 12 + offset, 18 + offset),
      fechaPago: _safeSubstring(line, 18 + offset, 26 + offset),
      razonSocial: _safeSubstring(line, 26 + offset, 56 + offset),
      domicilio: _safeSubstring(line, 56 + offset, 96 + offset),
      extra: _safeSubstring(line, 96 + offset, 195),
    );
  }

  static LSDLegajoRef _parseReferencia(String line) {
    final isNew = line.startsWith('02');
    final offset = isNew ? 1 : 0;

    return LSDLegajoRef(
      tipoRegistro: isNew ? '02' : '2',
      cuil: _safeSubstring(line, 1 + offset, 12 + offset),
      legajo: _safeSubstring(line, 12 + offset, 22 + offset),
      cbu: _safeSubstring(line, 22 + offset, 44 + offset),
      diasBase: _safeSubstring(line, 44 + offset, 47 + offset),
      extra: _safeSubstring(line, 47 + offset, 195),
    );
  }

  static LSDConcepto _parseConcepto(String line) {
    final isNew = line.startsWith('03');
    final offset = isNew ? 1 : 0;

    return LSDConcepto(
      tipoRegistro: isNew ? '03' : '3',
      cuil: _safeSubstring(line, 1 + offset, 12 + offset),
      codigo: _safeSubstring(line, 12 + offset, 22 + offset),
      cantidad: _safeSubstring(line, 22 + offset, 26 + offset),
      tipo: _safeSubstring(line, 26 + offset, 27 + offset),
      importe: _safeSubstring(line, 27 + offset, 42 + offset),
      descripcion: _safeSubstring(line, 42 + offset, 195),
    );
  }

  static LSDBases _parseBases(String line) {
    final isNew = line.startsWith('04');
    final offset = isNew ? 1 : 0;
    
    final basesList = <String>[];
    for (var i = 0; i < 10; i++) {
      final start = 12 + offset + (i * 15);
      basesList.add(_safeSubstring(line, start, start + 15).padLeft(15, '0'));
    }
    
    return LSDBases(
      tipoRegistro: isNew ? '04' : '4',
      cuil: _safeSubstring(line, 1 + offset, 12 + offset),
      bases: basesList,
      extra: _safeSubstring(line, 162 + offset, 195),
    );
  }

  static LSDComplementarios _parseComplementarios(String line) {
    final isNew = line.startsWith('05');
    final offset = isNew ? 1 : 0;

    return LSDComplementarios(
      tipoRegistro: isNew ? '05' : '5',
      cuil: _safeSubstring(line, 1 + offset, 12 + offset),
      rnos: _safeSubstring(line, 12 + offset, 18 + offset),
      cantFamiliares: _safeSubstring(line, 18 + offset, 22 + offset),
      adherentes: _safeSubstring(line, 22 + offset, 23 + offset),
      actividad: _safeSubstring(line, 23 + offset, 26 + offset),
      puesto: _safeSubstring(line, 26 + offset, 30 + offset),
      condicion: _safeSubstring(line, 30 + offset, 32 + offset),
      modalidad: _safeSubstring(line, 32 + offset, 35 + offset),
      siniestrado: _safeSubstring(line, 35 + offset, 37 + offset),
      zona: _safeSubstring(line, 37 + offset, 38 + offset),
      extra: _safeSubstring(line, 38 + offset, 195),
    );
  }

  /// Método de ayuda para obtener un substring de forma segura sin lanzar RangeError
  static String _safeSubstring(String str, int start, int end) {
    if (start >= str.length) return ''.padRight(end - start, ' ');
    if (end > str.length) return str.substring(start).padRight(end - start, ' ');
    return str.substring(start, end);
  }
}
