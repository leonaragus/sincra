// ========================================================================
// TEACHER RECEIPT SCAN SERVICE - OCR (on-device) + QR para recibos 2026
// google_mlkit_text_recognition (local) + mobile_scanner. Regex para CUIL,
// Básico, Antigüedad %, Puntos, Valor Índice. Prioridad: QR JSON > QR URL > OCR.
// ========================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/image_bytes_reader.dart';
import 'claude_vision_service.dart';

/// Origen de los datos extraídos
enum OcrExtractSource { qrJson, qrUrl, ocr }

/// Resultado de la extracción (QR o OCR) para OcrReviewScreen
class OcrExtractResult {
  final String? cuil;
  final String? nombre;
  final double? sueldoBasico;
  final double? antiguedadPct;
  final int? puntos;
  final double? valorIndice;
  final String? jurisdiccionRaw;
  final String? urlDetectada;
  final OcrExtractSource source;
  final String? rawTextOcr;
  final String? error;

  const OcrExtractResult({
    this.cuil,
    this.nombre,
    this.sueldoBasico,
    this.antiguedadPct,
    this.puntos,
    this.valorIndice,
    this.jurisdiccionRaw,
    this.urlDetectada,
    required this.source,
    this.rawTextOcr,
    this.error,
  });

  bool get hasError => error != null && error!.isNotEmpty;
}

/// Overrides para DocenteOmniInput (mapeo desde OcrReviewScreen)
class DocenteOmniOverrides {
  final double? valorIndiceOverride;
  final double? sueldoBasicoOverride;
  final int? puntosCargoOverride;
  final int? puntosHoraCatedraOverride;

  const DocenteOmniOverrides({
    this.valorIndiceOverride,
    this.sueldoBasicoOverride,
    this.puntosCargoOverride,
    this.puntosHoraCatedraOverride,
  });
}

/// Servicio de escaneo: OCR (ML Kit) y parsing de QR (JSON / URL)
class TeacherReceiptScanService {
  static final TeacherReceiptScanService _instance = TeacherReceiptScanService._();
  factory TeacherReceiptScanService() => _instance;
  TeacherReceiptScanService._();

  /// Convierte formato argentino 1.234,56 a double. On-Device.
  static double? cleanAmount(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final t = s.trim();
    final sinMiles = t.replaceAll('.', '');
    final conDecimal = sinMiles.replaceAll(',', '.');
    return double.tryParse(conDecimal);
  }

  // /// Normaliza CUIL laxo (ej. "12 34567890 1") a "12-34567890-1".
  // static String _normalizeCuil(String s) {
  //   final d = s.replaceAll(RegExp(r'[^\d]'), '');
  //   if (d.length != 11) return s;
  //   return '${d.substring(0, 2)}-${d.substring(2, 10)}-${d.substring(10)}';
  // }

  // --- Parsing de QR ---

  /// Si [raw] es JSON de liquidación (ARCA/AFIP o estándar 2026), prioriza extracción desde ahí.
  /// Si es URL, devuelve resultado con urlDetectada. Si no, null → usar OCR.
  OcrExtractResult? tryParseQr(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // 1) JSON: prioridad ARCA/AFIP/liquidación 2026
    if ((s.startsWith('{') && s.contains('}')) || (s.startsWith('[') && s.contains(']'))) {
      try {
        final decoded = jsonDecode(s);
        final map = decoded is Map ? decoded as Map<String, dynamic> : null;
        if (map != null) return _fromJson(map);
      } catch (_) { /* no es JSON válido */ }
    }

    // 2) URL de liquidación
    if (RegExp(r'^https?://').hasMatch(s)) {
      return OcrExtractResult(
        source: OcrExtractSource.qrUrl,
        urlDetectada: s,
      );
    }

    return null;
  }

  OcrExtractResult _fromJson(Map<String, dynamic> m) {
    String? j;
    double? vb, va, vi;
    int? p;

    if (m['cuil'] != null) j = m['cuil'].toString().trim();
    vb = _toNumAmount(m['sueldoBasico']);
    vi = _toNumAmount(m['valorIndice']);
    if (m['puntos'] != null) p = _toInt(m['puntos']);
    va = _toNumAmount(m['antiguedadPct']) ?? _toNumAmount(m['antiguedad']);

    return OcrExtractResult(
      cuil: j,
      nombre: m['nombre']?.toString().trim(),
      sueldoBasico: vb,
      antiguedadPct: va,
      puntos: p,
      valorIndice: vi,
      jurisdiccionRaw: m['jurisdiccion']?.toString().trim(),
      source: OcrExtractSource.qrJson,
      urlDetectada: m['url']?.toString().trim().isNotEmpty == true ? m['url'].toString().trim() : null,
    );
  }

  /// Convierte valor de JSON a double: num directo, o cleanAmount si es String (argentino 1.234,56).
  double? _toNumAmount(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return cleanAmount(s) ?? _toDouble(v);
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.');
    return double.tryParse(s);
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  // --- OCR (Cloud with Claude) ---

  /// Ejecuta OCR sobre [imagePath] (ruta a archivo).
  Future<OcrExtractResult> runOcrFromPath(String imagePath) async {
    try {
      final bytes = await readImageBytes(imagePath);
      if (bytes == null || bytes.isEmpty) {
        return const OcrExtractResult(
          source: OcrExtractSource.ocr,
          error: 'No se pudo leer el archivo de imagen.',
        );
      }
      return _analyzeWithClaude(bytes);
    } catch (e, st) {
      debugPrint('TeacherReceiptScanService.runOcr: $e\n$st');
      return const OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'Error al procesar la imagen.',
      );
    }
  }

  /// OCR desde bytes.
  Future<OcrExtractResult> runOcrFromBytes(Uint8List bytes, int width, int height) async {
    // width y height se ignoran
    return _analyzeWithClaude(bytes);
  }

  Future<OcrExtractResult> _analyzeWithClaude(Uint8List bytes) async {
    try {
      const prompt = '''Analiza este recibo de sueldo Docente.
Extrae los siguientes datos en formato JSON estricto:
- "cuil": CUIL del docente.
- "nombre": Nombre del docente.
- "sueldoBasico": El sueldo básico (numérico).
- "antiguedadPct": Porcentaje de antigüedad (ej: 50.0). Si está en años, usa "antiguedad" (años).
- "puntos": Cantidad de puntos (si figura).
- "valorIndice": Valor del índice (si figura).
- "jurisdiccion": Jurisdicción (ej: PBA, CABA).
- "url": Si hay una URL o código QR con link, extraelo.

Responde SOLO con el JSON.
Estructura:
{
  "cuil": "...",
  "nombre": "...",
  "sueldoBasico": 123.45,
  "antiguedadPct": 50.0,
  "antiguedad": 10,
  "puntos": 0,
  "valorIndice": 0.0,
  "jurisdiccion": "PBA",
  "url": "..."
}
''';

      final jsonResponse = await ClaudeVisionService.analyzeReceipt(bytes, customPrompt: prompt);
      
      Map<String, dynamic> data;
      try {
        data = jsonDecode(jsonResponse);
      } catch (e) {
        final cleaned = jsonResponse.replaceAll(RegExp(r'```json|```'), '').trim();
        data = jsonDecode(cleaned);
      }
      
      final baseResult = _fromJson(data);
      
      return OcrExtractResult(
        cuil: baseResult.cuil,
        nombre: baseResult.nombre,
        sueldoBasico: baseResult.sueldoBasico,
        antiguedadPct: baseResult.antiguedadPct,
        puntos: baseResult.puntos,
        valorIndice: baseResult.valorIndice,
        jurisdiccionRaw: baseResult.jurisdiccionRaw,
        urlDetectada: baseResult.urlDetectada,
        source: OcrExtractSource.ocr, // Force OCR source
        rawTextOcr: jsonResponse,
      );

    } catch (e) {
      debugPrint('Error en Claude Vision (Teacher): $e');
      return OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'No se pudo interpretar el recibo: $e',
      );
    }
  }

  /// Parsea el contenido de [BarcodeCapture] si es código QR. Devuelve el string raw.
  String? getQrRawFromBarcode(BarcodeCapture capture) {
    final list = capture.barcodes;
    if (list.isEmpty) return null;
    for (final b in list) {
      final v = b.rawValue;
      if ((v ?? '').isNotEmpty) return v;
    }
    return null;
  }

  void close() {
    // _textRecognizer?.close();
    // _textRecognizer = null;
  }
}
