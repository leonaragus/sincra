// ========================================================================
// SANIDAD RECEIPT SCAN SERVICE - OCR (on-device) + QR para recibos FATSA
// google_mlkit_text_recognition (local) + mobile_scanner. Regex para CUIL,
// Básico, Antigüedad %, Categoría, Horas Nocturnas, etc.
// Prioridad: QR JSON > QR URL > OCR.
// ========================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/sanidad_omni_engine.dart';

/// Origen de los datos extraídos
enum OcrExtractSourceSanidad { qrJson, qrUrl, ocr }

/// Resultado de la extracción (QR o OCR) para revisión en Sanidad
class SanidadOcrExtractResult {
  final String? cuil;
  final String? nombre;
  final double? sueldoBasico;
  final double? antiguedadPct;
  final String? categoriaRaw; // "Profesional", "Técnico", etc.
  final int? horasNocturnas;
  final String? jurisdiccionRaw;
  final String? urlDetectada;
  final OcrExtractSourceSanidad source;
  final String? rawTextOcr;
  final String? error;
  
  // Adicionales detectados
  final double? adicionalTitulo;
  final double? tareaCriticaRiesgo;
  final double? adicionalZonaPatagonica;

  const SanidadOcrExtractResult({
    this.cuil,
    this.nombre,
    this.sueldoBasico,
    this.antiguedadPct,
    this.categoriaRaw,
    this.horasNocturnas,
    this.jurisdiccionRaw,
    this.urlDetectada,
    required this.source,
    this.rawTextOcr,
    this.error,
    this.adicionalTitulo,
    this.tareaCriticaRiesgo,
    this.adicionalZonaPatagonica,
  });

  bool get hasError => error != null && error!.isNotEmpty;
}

/// Overrides para SanidadEmpleadoInput (mapeo desde pantalla de revisión OCR)
class SanidadOmniOverrides {
  final double? sueldoBasicoOverride;
  final CategoriaSanidad? categoriaOverride;
  final int? horasNocturnasOverride;

  const SanidadOmniOverrides({
    this.sueldoBasicoOverride,
    this.categoriaOverride,
    this.horasNocturnasOverride,
  });
}

/// Servicio de escaneo: OCR (ML Kit) y parsing de QR (JSON / URL)
class SanidadReceiptScanService {
  static final SanidadReceiptScanService _instance = SanidadReceiptScanService._();
  factory SanidadReceiptScanService() => _instance;
  SanidadReceiptScanService._();

  /// Convierte formato argentino 1.234,56 a double
  static double? cleanAmount(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final t = s.trim();
    final sinMiles = t.replaceAll('.', '');
    final conDecimal = sinMiles.replaceAll(',', '.');
    return double.tryParse(conDecimal);
  }

  // --- Parsing de QR ---

  /// Si [raw] es JSON de liquidación FATSA, prioriza extracción desde ahí
  /// Si es URL, devuelve resultado con urlDetectada. Si no, null → usar OCR.
  SanidadOcrExtractResult? tryParseQr(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // 1) JSON: prioridad datos FATSA/liquidación
    if ((s.startsWith('{') && s.contains('}')) || (s.startsWith('[') && s.contains(']'))) {
      try {
        final decoded = jsonDecode(s);
        final map = decoded is Map ? decoded as Map<String, dynamic> : null;
        if (map != null) return _fromJson(map);
      } catch (_) { /* no es JSON válido */ }
    }

    // 2) URL de liquidación
    if (RegExp(r'^https?://').hasMatch(s)) {
      return SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.qrUrl,
        urlDetectada: s,
      );
    }

    return null;
  }

  SanidadOcrExtractResult _fromJson(Map<String, dynamic> m) {
    String? c;
    double? vb, va, titulo, critica, zona;
    int? hn;
    
    if (m['cuil'] != null) c = m['cuil'].toString().trim();
    vb = _toNumAmount(m['sueldoBasico']);
    va = _toNumAmount(m['antiguedadPct']) ?? _toNumAmount(m['antiguedad']);
    if (m['horasNocturnas'] != null) hn = _toInt(m['horasNocturnas']);
    titulo = _toNumAmount(m['adicionalTitulo']);
    critica = _toNumAmount(m['tareaCriticaRiesgo']);
    zona = _toNumAmount(m['adicionalZonaPatagonica']);

    return SanidadOcrExtractResult(
      cuil: c,
      nombre: m['nombre']?.toString().trim(),
      sueldoBasico: vb,
      antiguedadPct: va,
      categoriaRaw: m['categoria']?.toString().trim(),
      horasNocturnas: hn,
      jurisdiccionRaw: m['jurisdiccion']?.toString().trim(),
      source: OcrExtractSourceSanidad.qrJson,
      urlDetectada: m['url']?.toString().trim().isNotEmpty == true ? m['url'].toString().trim() : null,
      adicionalTitulo: titulo,
      tareaCriticaRiesgo: critica,
      adicionalZonaPatagonica: zona,
    );
  }

  /// Convierte valor de JSON a double
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

  /// Ejecuta OCR sobre [imagePath]. Procesamiento 100% local.
  Future<SanidadOcrExtractResult> runOcrFromPath(String imagePath) async {
    try {
      /*
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognized = await _recognizer.processImage(inputImage);
      final String full = recognized.text;
      return _applyRegex(full);
      */
      return const SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'OCR local deshabilitado para compatibilidad web. Use la versión móvil.',
      );
    } catch (e, st) {
      debugPrint('SanidadReceiptScanService.runOcr: $e\n$st');
      return const SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'No se pudo leer la imagen.',
      );
    }
  }

  /// OCR desde bytes (formato NV21/YUV para cámara Android)
  Future<SanidadOcrExtractResult> runOcrFromBytes(Uint8List bytes, int width, int height) async {
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
      return const SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'OCR local deshabilitado para compatibilidad web. Use la versión móvil.',
      );
    } catch (e, st) {
      debugPrint('SanidadReceiptScanService.runOcrFromBytes: $e\n$st');
      return const SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'No se pudo leer la imagen.',
      );
    }
  }

  /// Parsea el contenido de [BarcodeCapture] si es código QR
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
