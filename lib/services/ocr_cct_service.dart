// ========================================================================
// SERVICIO DE OCR PARA CCT
// Escanea PDFs de convenios y extrae escalas salariales automáticamente
// ========================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/image_bytes_reader.dart';
import 'claude_vision_service.dart';

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
      final bytes = await readImageBytes(imagePath);
      if (bytes == null || bytes.isEmpty) {
        throw Exception('No se pudieron leer los bytes de la imagen: $imagePath');
      }

      const prompt = '''Analiza este documento de Convenio Colectivo de Trabajo (CCT) o Escala Salarial.
Extrae la siguiente información en formato JSON estricto:
- "codigoCCT": El código del convenio (ej: 130/75). Si no está explícito, trata de inferirlo o usa null.
- "nombreCCT": El nombre del sindicato o convenio (ej: Empleados de Comercio).
- "escalas": Una lista de objetos con:
    - "categoria": Nombre de la categoría (ej: Maestranza A, Administrativo B).
    - "basico": El sueldo básico (numérico). Si hay "no remunerativo" inclúyelo sumado o aclaralo en observaciones.
    - "observaciones": Cualquier detalle relevante (ej: "A partir de Abril 2024").

Responde SOLO con el JSON.
Estructura:
{
  "codigoCCT": "...",
  "nombreCCT": "...",
  "escalas": [
    { "categoria": "...", "basico": 12345.67, "observaciones": "..." }
  ]
}
''';

      final jsonResponse = await ClaudeVisionService.analyzeReceipt(
        bytes, 
        customPrompt: prompt
      );

      // Parsear respuesta
      Map<String, dynamic> data;
      try {
        data = jsonDecode(jsonResponse);
      } catch (e) {
        // Intento de limpieza si viene con markdown
        final cleaned = jsonResponse.replaceAll(RegExp(r'```json|```'), '').trim();
        data = jsonDecode(cleaned);
      }

      final codigoCCT = data['codigoCCT']?.toString() ?? '';
      final nombreCCT = data['nombreCCT']?.toString() ?? '';
      final escalasData = (data['escalas'] as List?) ?? [];

      final escalas = escalasData.map((e) {
        return EscalaSalarialExtraida(
          categoria: e['categoria']?.toString() ?? 'Desconocida',
          basico: double.tryParse(e['basico']?.toString() ?? '0') ?? 0.0,
          observaciones: e['observaciones']?.toString(),
          confianza: 90, // Claude suele ser preciso
        );
      }).toList();

      return ResultadoOCRCCT(
        codigoCCT: codigoCCT,
        nombreCCT: nombreCCT,
        escalas: escalas,
        textoCompleto: jsonResponse, // Guardamos el JSON raw como "texto completo" para debug
        totalEscalasDetectadas: escalas.length,
        exito: true,
      );

    } catch (e) {
      debugPrint('Error procesando imagen CCT con Claude: $e');
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
