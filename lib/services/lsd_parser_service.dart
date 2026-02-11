
import '../models/lsd_parsed_data.dart';

class LSDParserService {
  /// Parsea el contenido de un archivo LSD TXT
  static LSDParsedFile parseFileContent(String content) {
    final result = LSDParsedFile();
    final lines = content.split(RegExp(r'\r?\n'));

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].replaceAll('\r', '');
      if (line.isEmpty) continue;

      if (line.length != 195) {
        result.erroresParsing.add('Línea ${i + 1}: Longitud incorrecta (${line.length} chars). Se esperaban 195.');
        continue;
      }

      final tipo = line.substring(0, 1);

      try {
        switch (tipo) {
          case '1':
            result.header = _parseHeader(line);
            break;
          case '2':
            result.referencias.add(_parseReferencia(line));
            break;
          case '3':
            result.conceptos.add(_parseConcepto(line));
            break;
          case '4':
            result.bases.add(_parseBases(line));
            break;
          case '5':
            result.complementarios.add(_parseComplementarios(line));
            break;
          default:
            result.erroresParsing.add('Línea ${i + 1}: Tipo de registro desconocido "$tipo".');
        }
      } catch (e) {
        result.erroresParsing.add('Línea ${i + 1}: Error procesando registro tipo $tipo. $e');
      }
    }

    return result;
  }

  static LSDHeader _parseHeader(String line) {
    return LSDHeader(
      tipoRegistro: line.substring(0, 1),
      cuitEmpresa: line.substring(1, 12),
      periodo: line.substring(12, 18),
      fechaPago: line.substring(18, 26),
      razonSocial: line.substring(26, 56),
      domicilio: line.substring(56, 96),
      extra: line.substring(96, 195),
    );
  }

  static LSDLegajoRef _parseReferencia(String line) {
    return LSDLegajoRef(
      tipoRegistro: line.substring(0, 1),
      cuil: line.substring(1, 12),
      legajo: line.substring(12, 22),
      cbu: line.substring(22, 44),
      diasBase: line.substring(44, 47),
      extra: line.substring(47, 195),
    );
  }

  static LSDConcepto _parseConcepto(String line) {
    return LSDConcepto(
      tipoRegistro: line.substring(0, 1),
      cuil: line.substring(1, 12),
      codigo: line.substring(12, 22),
      cantidad: line.substring(22, 26),
      tipo: line.substring(26, 27),
      importe: line.substring(27, 42),
      descripcion: line.substring(42, 195),
    );
  }

  static LSDBases _parseBases(String line) {
    final basesList = <String>[];
    for (var i = 0; i < 10; i++) {
      final start = 12 + (i * 15);
      basesList.add(line.substring(start, start + 15));
    }
    
    return LSDBases(
      tipoRegistro: line.substring(0, 1),
      cuil: line.substring(1, 12),
      bases: basesList,
      extra: line.substring(162, 195),
    );
  }

  static LSDComplementarios _parseComplementarios(String line) {
    return LSDComplementarios(
      tipoRegistro: line.substring(0, 1),
      cuil: line.substring(1, 12),
      rnos: line.substring(12, 18),
      cantFamiliares: line.substring(18, 22),
      adherentes: line.substring(22, 23),
      actividad: line.substring(23, 26),
      puesto: line.substring(26, 30),
      condicion: line.substring(30, 32),
      modalidad: line.substring(32, 35),
      siniestrado: line.substring(35, 37),
      zona: line.substring(37, 38),
      extra: line.substring(38, 195),
    );
  }
}
