// ========================================================================
// TEACHER RECEIPT SCAN SERVICE - OCR (on-device) + QR para recibos 2026
// google_mlkit_text_recognition (local) + mobile_scanner. Regex para CUIL,
// Básico, Antigüedad %, Puntos, Valor Índice. Prioridad: QR JSON > QR URL > OCR.
// ========================================================================

import 'dart:convert';
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  // Se prioriza detectar todo lo posible; lo faltante se completa a mano o con otra foto.

  /// CUIL: \d{2}-\d{8}-\d{1} o con guión/espacio mal leído: \d{2}[-\s]?\d{8}[-\s]?\d
  static final RegExp _reCuil = RegExp(r'\b\d{2}-\d{8}-\d{1}\b');
  static final RegExp _reCuilLax = RegExp(r'\b\d{2}[-\s]?\d{8}[-\s]?\d\b');

  /// Sueldo Básico: 1 o 2 decimales; admite punto o coma. Incluye "Sueldo" por variantes.
  static final RegExp _reBasico = RegExp(
    r'(?i)(?:Básico|Basico|Sueldo|001|S\.?Basico).*?(\d{1,3}(?:\.\d{3})*[.,]\d{1,2})',
  );
  /// Fallback: número de 4–7 dígitos tras Básico/Sueldo (por si se pierde la coma).
  static final RegExp _reBasicoLax = RegExp(
    r'(?i)(?:Básico|Basico|Sueldo|001|S\.?Basico).*?(\d{4,7})\b',
  );

  /// % Antigüedad: (\d{1,3})\s?%
  static final RegExp _reAntig = RegExp(
    r'(?:Antig|Años|Aniversario).*?(\d{1,3})\s?%',
    caseSensitive: false,
  );

  /// Valor Índice: entero 1–4 dígitos, 2–6 decimales (fotos borrosas pueden perder decimales).
  static final RegExp _reValorIndice = RegExp(r'\b\d{1,4}[.,]\d{2,6}\b');

  /// Puntos: 2–5 dígitos (Ptos|Pje|Puntos|Pts).
  static final RegExp _rePuntos = RegExp(
    r'(?:Ptos|Pje|Puntos|Pts)[:\s]*(\d{2,5})',
    caseSensitive: false,
  );

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
  /// [InputImage.fromFilePath] requiere path. Si se usa [InputImage.fromFile],
  /// hay que pasar File. Aquí asumimos path o se puede cambiar a XFile/File.
  Future<OcrExtractResult> runOcrFromPath(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognized = await _recognizer.processImage(inputImage);
      final String full = recognized.text;
      return _applyRegex(full);
    } catch (e, st) {
      debugPrint('TeacherReceiptScanService.runOcr: $e\n$st');
      return const OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'No se pudo leer la imagen. Complete los datos a mano o escanee una foto con mejor resolución.',
      );
    }
  }

  /// OCR desde bytes. [bytes] en formato NV21/YUV (p. ej. cámara Android). Para archivos use [runOcrFromPath].
  Future<OcrExtractResult> runOcrFromBytes(Uint8List bytes, int width, int height) async {
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
      debugPrint('TeacherReceiptScanService.runOcrFromBytes: $e\n$st');
      return const OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'No se pudo leer la imagen. Complete los datos a mano o escanee una foto con mejor resolución.',
      );
    }
  }

  /// Aplica regex al texto OCR. Preciso pero permisivo con baja calidad de imagen.
  /// Si algo no se detecta, el usuario lo completa a mano o escanea de nuevo. Usa cleanAmount para formato argentino.
  OcrExtractResult _applyRegex(String full) {
    String? cuil;
    double? sueldoBasico;
    double? antiguedadPct;
    int? puntos;
    double? valorIndice;

    // CUIL: estricto primero; fallback laxo (guiones/espacios) y normalizamos
    var mCuil = _reCuil.firstMatch(full);
    if (mCuil != null) {
      cuil = mCuil.group(0);
    } else {
      mCuil = _reCuilLax.firstMatch(full);
      if (mCuil != null) cuil = _normalizeCuil(mCuil.group(0)!);
    }

    // Sueldo Básico: estricto (decimales); fallback solo dígitos si se pierde la coma
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

    // Valor Índice: 2–6 decimales
    final mVi = _reValorIndice.firstMatch(full);
    if (mVi != null) valorIndice = cleanAmount(mVi.group(0));

    // Puntos: 2–5 dígitos
    final mPt = _rePuntos.firstMatch(full);
    if (mPt != null) puntos = int.tryParse(mPt.group(1) ?? '');

    return OcrExtractResult(
      cuil: cuil,
      nombre: null,
      sueldoBasico: sueldoBasico,
      antiguedadPct: antiguedadPct,
      puntos: puntos,
      valorIndice: valorIndice,
      source: OcrExtractSource.ocr,
      rawTextOcr: full.length > 2000 ? '${full.substring(0, 2000)}...' : full,
    );
  }

  // --- Escaneo QR con MobileScanner (decodificación; la cámara se maneja en UI) ---

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
}
