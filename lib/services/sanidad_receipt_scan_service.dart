// ========================================================================
// SANIDAD RECEIPT SCAN SERVICE - OCR (on-device) + QR para recibos FATSA
// google_mlkit_text_recognition (local) + mobile_scanner. Regex para CUIL,
// Básico, Antigüedad %, Categoría, Horas Nocturnas, etc.
// Prioridad: QR JSON > QR URL > OCR.
// ========================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

  TextRecognizer? _textRecognizer;

  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  /// Liberar recurso (llamar al cerrar el flujo de escaneo)
  void close() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }

  // --- Regex 2026: precisos pero permisivos con fotos de baja calidad ---
  
  /// CUIL: \d{2}-\d{8}-\d{1} o con guión/espacio mal leído
  static final RegExp _reCuil = RegExp(r'\b\d{2}-\d{8}-\d{1}\b');
  static final RegExp _reCuilLax = RegExp(r'\b\d{2}[-\s]?\d{8}[-\s]?\d\b');

  /// Sueldo Básico: admite punto o coma como separador decimal
  static final RegExp _reBasico = RegExp(
    r'(?i)(?:Básico|Basico|Sueldo|001|S\.?Basico).*?(\d{1,3}(?:\.\d{3})*[.,]\d{1,2})',
  );
  static final RegExp _reBasicoLax = RegExp(
    r'(?i)(?:Básico|Basico|Sueldo|001|S\.?Basico).*?(\d{4,7})\b',
  );

  /// % Antigüedad
  static final RegExp _reAntig = RegExp(
    r'(?:Antig|Años|Aniversario).*?(\d{1,3})\s?%',
    caseSensitive: false,
  );

  /// Categoría: Profesional, Técnico, Servicios, Administrativo, Maestranza
  static final RegExp _reCategoria = RegExp(
    r'(?i)Categor[ií]a.*?(Profesional|T[ée]cnico|Servicios|Administrativ[oa]|Maestranza)',
  );
  
  /// Horas Nocturnas
  static final RegExp _reHorasNocturnas = RegExp(
    r'(?i)(?:Horas?\s+)?Nocturna?s?[:\s]*(\d{1,3})',
  );

  /// Adicional Título
  static final RegExp _reAdicionalTitulo = RegExp(
    r'(?i)(?:Adicional\s+)?T[ií]tulo.*?(\d{1,3}(?:\.\d{3})*[.,]\d{1,2})',
  );

  /// Tarea Crítica/Riesgo
  static final RegExp _reTareaCritica = RegExp(
    r'(?i)(?:Tarea\s+)?Cr[ií]tica.*?(\d{1,3}(?:\.\d{3})*[.,]\d{1,2})',
  );

  /// Plus Zona Patagónica
  static final RegExp _reZonaPatagonica = RegExp(
    r'(?i)(?:Plus\s+)?Zona\s+(?:Desfavorable|Patag[óo]nica?).*?(\d{1,3}(?:\.\d{3})*[.,]\d{1,2})',
  );

  /// Convierte formato argentino 1.234,56 a double
  static double? cleanAmount(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final t = s.trim();
    final sinMiles = t.replaceAll('.', '');
    final conDecimal = sinMiles.replaceAll(',', '.');
    return double.tryParse(conDecimal);
  }

  /// Normaliza CUIL laxo a formato "12-34567890-1"
  static String _normalizeCuil(String s) {
    final d = s.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length != 11) return s;
    return '${d.substring(0, 2)}-${d.substring(2, 10)}-${d.substring(10)}';
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
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognized = await _recognizer.processImage(inputImage);
      final String full = recognized.text;
      return _applyRegex(full);
    } catch (e, st) {
      debugPrint('SanidadReceiptScanService.runOcr: $e\n$st');
      return const SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'No se pudo leer la imagen. Complete los datos a mano o escanee una foto con mejor resolución.',
      );
    }
  }

  /// OCR desde bytes (formato NV21/YUV para cámara Android)
  Future<SanidadOcrExtractResult> runOcrFromBytes(Uint8List bytes, int width, int height) async {
    try {
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
    } catch (e, st) {
      debugPrint('SanidadReceiptScanService.runOcrFromBytes: $e\n$st');
      return const SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'No se pudo leer la imagen. Complete los datos a mano o escanee una foto con mejor resolución.',
      );
    }
  }

  /// Aplica regex al texto OCR para extraer datos de recibos FATSA
  SanidadOcrExtractResult _applyRegex(String full) {
    String? cuil;
    double? sueldoBasico;
    double? antiguedadPct;
    String? categoria;
    int? horasNocturnas;
    double? adicionalTitulo;
    double? tareaCritica;
    double? zonaPatagonica;

    // CUIL: estricto primero; fallback laxo
    var mCuil = _reCuil.firstMatch(full);
    if (mCuil != null) {
      cuil = mCuil.group(0);
    } else {
      mCuil = _reCuilLax.firstMatch(full);
      if (mCuil != null) cuil = _normalizeCuil(mCuil.group(0)!);
    }

    // Sueldo Básico
    final mBas = _reBasico.firstMatch(full);
    if (mBas != null) {
      sueldoBasico = cleanAmount(mBas.group(1));
    } else {
      final mLax = _reBasicoLax.firstMatch(full);
      if (mLax != null) sueldoBasico = cleanAmount(mLax.group(1));
    }

    // % Antigüedad
    final mAnt = _reAntig.firstMatch(full);
    if (mAnt != null) {
      final n = int.tryParse(mAnt.group(1) ?? '');
      if (n != null) antiguedadPct = n.toDouble();
    }

    // Categoría
    final mCat = _reCategoria.firstMatch(full);
    if (mCat != null) categoria = mCat.group(1);

    // Horas Nocturnas
    final mHN = _reHorasNocturnas.firstMatch(full);
    if (mHN != null) horasNocturnas = int.tryParse(mHN.group(1) ?? '');

    // Adicional Título
    final mTit = _reAdicionalTitulo.firstMatch(full);
    if (mTit != null) adicionalTitulo = cleanAmount(mTit.group(1));

    // Tarea Crítica/Riesgo
    final mCrit = _reTareaCritica.firstMatch(full);
    if (mCrit != null) tareaCritica = cleanAmount(mCrit.group(1));

    // Zona Patagónica
    final mZona = _reZonaPatagonica.firstMatch(full);
    if (mZona != null) zonaPatagonica = cleanAmount(mZona.group(1));

    return SanidadOcrExtractResult(
      cuil: cuil,
      nombre: null,
      sueldoBasico: sueldoBasico,
      antiguedadPct: antiguedadPct,
      categoriaRaw: categoria,
      horasNocturnas: horasNocturnas,
      source: OcrExtractSourceSanidad.ocr,
      rawTextOcr: full.length > 2000 ? '${full.substring(0, 2000)}...' : full,
      adicionalTitulo: adicionalTitulo,
      tareaCriticaRiesgo: tareaCritica,
      adicionalZonaPatagonica: zonaPatagonica,
    );
  }

  // --- Escaneo QR con MobileScanner ---

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
}
