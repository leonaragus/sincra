// ========================================================================
// TEACHER RECEIPT SCAN SERVICE - OCR (on-device) + QR para recibos 2026
// google_mlkit_text_recognition (local) + mobile_scanner. Regex para CUIL,
// Básico, Antigüedad %, Puntos, Valor Índice. Prioridad: QR JSON > QR URL > OCR.
// ========================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:mobile_scanner/mobile_scanner.dart';

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

  /// Normaliza CUIL laxo (ej. "12 34567890 1") a "12-34567890-1".
  static String _normalizeCuil(String s) {
    final d = s.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length != 11) return s;
    return '${d.substring(0, 2)}-${d.substring(2, 10)}-${d.substring(10)}';
  }

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

  // --- OCR (on-device) ---

  /// Ejecuta OCR sobre [imagePath] (ruta a archivo). Procesamiento 100% local.
  Future<OcrExtractResult> runOcrFromPath(String imagePath) async {
    try {
      /*
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognized = await _recognizer.processImage(inputImage);
      final String full = recognized.text;
      return _applyRegex(full);
      */
      return const OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'OCR local deshabilitado para compatibilidad web. Use la versión móvil.',
      );
    } catch (e, st) {
      debugPrint('TeacherReceiptScanService.runOcr: $e\n$st');
      return const OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'No se pudo leer la imagen.',
      );
    }
  }

  /// OCR desde bytes. [bytes] en formato NV21/YUV (p. ej. cámara Android). Para archivos use [runOcrFromPath].
  Future<OcrExtractResult> runOcrFromBytes(Uint8List bytes, int width, int height) async {
    try {
      /*
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );
      final RecognizedText recognized = await _recognizer.processImage(inputImage);
      return _applyRegex(recognized.text);
      */
      return const OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'OCR local deshabilitado para compatibilidad web. Use la versión móvil.',
      );
    } catch (e, st) {
      debugPrint('TeacherReceiptScanService.runOcrFromBytes: $e\n$st');
      return const OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'No se pudo leer la imagen.',
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
