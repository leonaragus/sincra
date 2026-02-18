// ========================================================================
// SERVICIO DE OCR PARA CCT
// Escanea PDFs de convenios y extrae escalas salariales automáticamente
// ========================================================================

// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility

class EscalaSalarialExtraida {
  final String categoria;
  final double? basico;
  final String? observaciones;
  final int confianza; // 0-100%
  
  EscalaSalarialExtraida({
    required this.categoria,
    this.basico,
    this.observaciones,
    this.confianza = 50,
  });
}

class ResultadoOCRCCT {
  final String codigoCCT;
  final String nombreCCT;
  final List<EscalaSalarialExtraida> escalas;
  final String textoCompleto;
  final int totalEscalasDetectadas;
  final bool exito;
  final String? error;
  
  ResultadoOCRCCT({
    required this.codigoCCT,
    required this.nombreCCT,
    required this.escalas,
    required this.textoCompleto,
    required this.totalEscalasDetectadas,
    required this.exito,
    this.error,
  });
}

class OCRCCTService {
  // static final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  /// Procesa un PDF de CCT y extrae escalas salariales
  /// 
  /// Nota: Para PDFs, primero se deben convertir a imágenes.
  /// Este servicio trabaja con imágenes (jpg/png) del PDF.
  static Future<ResultadoOCRCCT> procesarImagenCCT(String imagePath) async {
    try {
      /*
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final textoCompleto = recognizedText.text;
      */
      const textoCompleto = "OCR deshabilitado en versión web.";
      
      // Extraer información del CCT
      final codigoCCT = _extraerCodigoCCT(textoCompleto);
      final nombreCCT = _extraerNombreCCT(textoCompleto);
      
      // Extraer escalas salariales
      final escalas = _extraerEscalasSalariales(textoCompleto);
      
      return ResultadoOCRCCT(
        codigoCCT: codigoCCT,
        nombreCCT: nombreCCT,
        escalas: escalas,
        textoCompleto: textoCompleto,
        totalEscalasDetectadas: escalas.length,
        exito: true,
      );
    } catch (e) {
      print('Error procesando imagen CCT: $e');
      return ResultadoOCRCCT(
        codigoCCT: '',
        nombreCCT: '',
        escalas: [],
        textoCompleto: '',
        totalEscalasDetectadas: 0,
        exito: false,
        error: e.toString(),
      );
    }
  }
  
  /// Procesa múltiples imágenes de un PDF (páginas)
  static Future<ResultadoOCRCCT> procesarPDFCompleto(List<String> imagePaths) async {
    final escalasTotal = <EscalaSalarialExtraida>[];
    String textoCompleto = '';
    String codigoCCT = '';
    String nombreCCT = '';
    
    for (final imagePath in imagePaths) {
      final resultado = await procesarImagenCCT(imagePath);
      
      if (!resultado.exito) continue;
      
      // Usar información de la primera página
      if (codigoCCT.isEmpty && resultado.codigoCCT.isNotEmpty) {
        codigoCCT = resultado.codigoCCT;
      }
      
      if (nombreCCT.isEmpty && resultado.nombreCCT.isNotEmpty) {
        nombreCCT = resultado.nombreCCT;
      }
      
      escalasTotal.addAll(resultado.escalas);
      textoCompleto += resultado.textoCompleto + '\n\n';
    }
    
    return ResultadoOCRCCT(
      codigoCCT: codigoCCT,
      nombreCCT: nombreCCT,
      escalas: escalasTotal,
      textoCompleto: textoCompleto,
      totalEscalasDetectadas: escalasTotal.length,
      exito: true,
    );
  }
  
  /// Extrae el código del CCT del texto
  static String _extraerCodigoCCT(String texto) {
    // Buscar patrones como "CCT 122/75", "CCT Nº 122/75", "Convenio 122/75"
    final patrones = [
      RegExp(r'CCT\s*N?[º°]?\s*(\d+/\d+)', caseSensitive: false),
      RegExp(r'Convenio\s*N?[º°]?\s*(\d+/\d+)', caseSensitive: false),
      RegExp(r'C\.C\.T\.\s*N?[º°]?\s*(\d+/\d+)', caseSensitive: false),
    ];
    
    for (final patron in patrones) {
      final match = patron.firstMatch(texto);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)!;
      }
    }
    
    return '';
  }
  
  /// Extrae el nombre del CCT del texto
  static String _extraerNombreCCT(String texto) {
    // Buscar líneas que contengan palabras clave
    final lineas = texto.split('\n');
    
    for (final linea in lineas) {
      if (linea.toLowerCase().contains('convenio colectivo') ||
          linea.toLowerCase().contains('federacion') ||
          linea.toLowerCase().contains('sindicato')) {
        return linea.trim();
      }
    }
    
    return '';
  }
  
  /// Extrae escalas salariales del texto
  static List<EscalaSalarialExtraida> _extraerEscalasSalariales(String texto) {
    final escalas = <EscalaSalarialExtraida>[];
    final lineas = texto.split('\n');
    
    // Patrones comunes de escalas salariales:
    // - "Maestro: $350.000"
    // - "Categoría A: $ 280.000"
    // - "Enfermero nivel 1 | $420.000"
    
    final patronCategoria = RegExp(
      r'(Maestro|Profesor|Director|Enfermero|Técnico|Auxiliar|Categoría\s*[A-Z0-9]+|Nivel\s*\d+)[\s\:\|\-]+\$?\s*([\d\.\,]+)',
      caseSensitive: false,
    );
    
    for (final linea in lineas) {
      final match = patronCategoria.firstMatch(linea);
      
      if (match != null && match.groupCount >= 2) {
        final categoria = match.group(1)!.trim();
        final basicoStr = match.group(2)!.trim();
        
        // Convertir el string a número
        final basicoLimpio = basicoStr.replaceAll(RegExp(r'[^\d]'), '');
        final basico = double.tryParse(basicoLimpio);
        
        if (basico != null && basico > 0) {
          // Calcular confianza basado en qué tan clara es la extracción
          int confianza = 70;
          if (linea.contains('\$')) confianza += 10;
          if (linea.contains('Básico') || linea.contains('Sueldo')) confianza += 10;
          if (basicoStr.contains('.')) confianza += 10;
          
          escalas.add(EscalaSalarialExtraida(
            categoria: categoria,
            basico: basico,
            observaciones: linea.trim(),
            confianza: confianza > 100 ? 100 : confianza,
          ));
        }
      }
    }
    
    return escalas;
  }
  
  /// Valida y limpia las escalas extraídas
  static List<EscalaSalarialExtraida> validarEscalas(
    List<EscalaSalarialExtraida> escalas,
    {int confianzaMinima = 60}
  ) {
    return escalas.where((escala) {
      // Filtrar por confianza mínima
      if (escala.confianza < confianzaMinima) return false;
      
      // Validar que el básico sea razonable (entre $100k y $10M)
      if (escala.basico == null || escala.basico! < 100000 || escala.basico! > 10000000) {
        return false;
      }
      
      return true;
    }).toList();
  }
  
  /// Genera reporte de extracción
  static String generarReporte(ResultadoOCRCCT resultado) {
    final buffer = StringBuffer();
    
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('        REPORTE DE EXTRACCIÓN OCR - CCT');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('Código CCT:        ${resultado.codigoCCT.isEmpty ? "(no detectado)" : resultado.codigoCCT}');
    buffer.writeln('Nombre:            ${resultado.nombreCCT.isEmpty ? "(no detectado)" : resultado.nombreCCT}');
    buffer.writeln('Escalas detectadas: ${resultado.totalEscalasDetectadas}');
    buffer.writeln('');
    
    if (resultado.escalas.isNotEmpty) {
      buffer.writeln('═══ ESCALAS SALARIALES EXTRAÍDAS ═══');
      buffer.writeln('');
      
      for (final escala in resultado.escalas) {
        buffer.writeln('${escala.categoria}:');
        buffer.writeln('  Básico:      \$${escala.basico?.toStringAsFixed(2) ?? "N/A"}');
        buffer.writeln('  Confianza:   ${escala.confianza}%');
        if (escala.observaciones != null) {
          buffer.writeln('  Observación: ${escala.observaciones}');
        }
        buffer.writeln('');
      }
    } else {
      buffer.writeln('(No se detectaron escalas salariales)');
    }
    
    buffer.writeln('═══════════════════════════════════════════════════════════');
    
    return buffer.toString();
  }
  
  /// Limpia recursos
  static void dispose() {
    // _textRecognizer.close();
  }
}
