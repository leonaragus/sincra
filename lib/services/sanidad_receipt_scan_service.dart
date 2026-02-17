// ========================================================================
// SANIDAD RECEIPT SCAN SERVICE - OCR (on-device) + QR para recibos FATSA
// google_mlkit_text_recognition (local) + mobile_scanner. Regex para CUIL,
// Básico, Antigüedad %, Categoría, Horas Nocturnas, etc.
// Prioridad: QR JSON > QR URL > OCR.
// ========================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:elevar_liquidacion/services/claude_vision_service.dart';
import 'package:flutter/foundation.dart';
import 'subscription_service.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/sanidad_omni_engine.dart';

/// Origen de los datos extraídos
enum OcrExtractSourceSanidad { qrJson, qrUrl, ocr }

/// New data models for Claude Vision output
class Haber {
  final String? codigo;
  final String? descripcion;
  final String? cantidad;
  final double? monto;
  final bool? esRemunerativo;

  const Haber({
    this.codigo,
    this.descripcion,
    this.cantidad,
    this.monto,
    this.esRemunerativo,
  });

  factory Haber.fromJson(Map<String, dynamic> json) {
    return Haber(
      codigo: json['codigo'] as String?,
      descripcion: json['descripcion'] as String?,
      cantidad: json['cantidad'] as String?,
      monto: (json['monto'] as num?)?.toDouble(),
      esRemunerativo: json['es_remunerativo'] as bool?,
    );
  }
}

class Retencion {
  final String? codigo;
  final String? descripcion;
  final String? porcentaje;
  final double? monto;

  const Retencion({
    this.codigo,
    this.descripcion,
    this.porcentaje,
    this.monto,
  });

  factory Retencion.fromJson(Map<String, dynamic> json) {
    return Retencion(
      codigo: json['codigo'] as String?,
      descripcion: json['descripcion'] as String?,
      porcentaje: json['porcentaje'] as String?,
      monto: (json['monto'] as num?)?.toDouble(),
    );
  }
}

class OtroConcepto {
  final String? descripcion;
  final double? monto;

  const OtroConcepto({
    this.descripcion,
    this.monto,
  });

  factory OtroConcepto.fromJson(Map<String, dynamic> json) {
    return OtroConcepto(
      descripcion: json['descripcion'] as String?,
      monto: (json['monto'] as num?)?.toDouble(),
    );
  }
}

class LiquidacionDetallada {
  final List<Haber>? haberes;
  final List<Retencion>? retenciones;
  final List<OtroConcepto>? otrosConceptos;

  const LiquidacionDetallada({
    this.haberes,
    this.retenciones,
    this.otrosConceptos,
  });

  factory LiquidacionDetallada.fromJson(Map<String, dynamic> json) {
    return LiquidacionDetallada(
      haberes: (json['haberes'] as List<dynamic>?)
          ?.map((e) => Haber.fromJson(e as Map<String, dynamic>))
          .toList(),
      retenciones: (json['retenciones'] as List<dynamic>?)
          ?.map((e) => Retencion.fromJson(e as Map<String, dynamic>))
          .toList(),
      otrosConceptos: (json['otros_conceptos'] as List<dynamic>?)
          ?.map((e) => OtroConcepto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Cabecera {
  final String? empresaNombre;
  final String? empresaCuit;
  final String? empleadoNombre;
  final String? empleadoCuil;
  final String? legajo;
  final String? fechaIngreso;
  final String? antiguedadReconocida;
  final String? categoriaProfesional;
  final String? cctAplicable;
  final String? periodoAbonado;
  final String? lugarPago;

  const Cabecera({
    this.empresaNombre,
    this.empresaCuit,
    this.empleadoNombre,
    this.empleadoCuil,
    this.legajo,
    this.fechaIngreso,
    this.antiguedadReconocida,
    this.categoriaProfesional,
    this.cctAplicable,
    this.periodoAbonado,
    this.lugarPago,
  });

  factory Cabecera.fromJson(Map<String, dynamic> json) {
    return Cabecera(
      empresaNombre: json['empresa_nombre'] as String?,
      empresaCuit: json['empresa_cuit'] as String?,
      empleadoNombre: json['empleado_nombre'] as String?,
      empleadoCuil: json['empleado_cuil'] as String?,
      legajo: json['legajo'] as String?,
      fechaIngreso: json['fecha_ingreso'] as String?,
      antiguedadReconocida: json['antiguedad_reconocida'] as String?,
      categoriaProfesional: json['categoria_profesional'] as String?,
      cctAplicable: json['cct_aplicable'] as String?,
      periodoAbonado: json['periodo_abonado'] as String?,
      lugarPago: json['lugar_pago'] as String?,
    );
  }
}

class Totales {
  final double? totalBruto;
  final double? totalRetenciones;
  final double? totalNoRemunerativo;
  final double? netoACobrar;
  final String? netoEnLetras;

  const Totales({
    this.totalBruto,
    this.totalRetenciones,
    this.totalNoRemunerativo,
    this.netoACobrar,
    this.netoEnLetras,
  });

  factory Totales.fromJson(Map<String, dynamic> json) {
    return Totales(
      totalBruto: (json['total_bruto'] as num?)?.toDouble(),
      totalRetenciones: (json['total_retenciones'] as num?)?.toDouble(),
      totalNoRemunerativo: (json['total_no_remunerativo'] as num?)?.toDouble(),
      netoACobrar: (json['neto_a_cobrar'] as num?)?.toDouble(),
      netoEnLetras: json['neto_en_letras'] as String?,
    );
  }
}

class AuditoriaIa {
  final String? analisisLegal;
  final List<String>? alertasCriticas;
  final String? explicacionConceptosComplejos;
  final double? puntuacionConfianzaOcr;

  const AuditoriaIa({
    this.analisisLegal,
    this.alertasCriticas,
    this.explicacionConceptosComplejos,
    this.puntuacionConfianzaOcr,
  });

  factory AuditoriaIa.fromJson(Map<String, dynamic> json) {
    return AuditoriaIa(
      analisisLegal: json['analisis_legal'] as String?,
      alertasCriticas: (json['alertas_criticas'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      explicacionConceptosComplejos: json['explicacion_conceptos_complejos'] as String?,
      puntuacionConfianzaOcr: (json['puntuacion_confianza_ocr'] as num?)?.toDouble(),
    );
  }
}

/// Resultado de la extracción (QR o OCR) para revisión en Sanidad
class SanidadOcrExtractResult {
  final Cabecera? cabecera;
  final LiquidacionDetallada? liquidacionDetallada;
  final Totales? totales;
  final AuditoriaIa? auditoriaIa;
  final String? urlDetectada;
  final OcrExtractSourceSanidad source;
  final String? rawTextOcr;
  final String? error;

  const SanidadOcrExtractResult({
    this.cabecera,
    this.liquidacionDetallada,
    this.totales,
    this.auditoriaIa,
    this.urlDetectada,
    required this.source,
    this.rawTextOcr,
    this.error,
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
    return SanidadOcrExtractResult(
      cabecera: m['cabecera'] != null ? Cabecera.fromJson(m['cabecera'] as Map<String, dynamic>) : null,
      liquidacionDetallada: m['liquidacion_detallada'] != null ? LiquidacionDetallada.fromJson(m['liquidacion_detallada'] as Map<String, dynamic>) : null,
      totales: m['totales'] != null ? Totales.fromJson(m['totales'] as Map<String, dynamic>) : null,
      auditoriaIa: m['auditoria_ia'] != null ? AuditoriaIa.fromJson(m['auditoria_ia'] as Map<String, dynamic>) : null,
      urlDetectada: m['url_detectada']?.toString().trim().isNotEmpty == true ? m['url_detectada'].toString().trim() : null,
      source: OcrExtractSourceSanidad.qrJson, // Assuming QR JSON also provides this structure
      rawTextOcr: m['raw_text_ocr']?.toString(),
      error: m['error']?.toString(),
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
      final bytes = await File(imagePath).readAsBytes();
      final Map<String, dynamic> jsonResponse = await ClaudeVisionService.analyzeReceipt(bytes);
      SubscriptionService.registerOcrScan();
      return _fromJson(jsonResponse);
    } catch (e, st) {
      debugPrint('SanidadReceiptScanService.runOcrFromPath: $e\n$st');
      return SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'Error al procesar la imagen con Claude Vision: $e',
      );
    }
  }

  /// OCR desde bytes (formato NV21/YUV para cámara Android)
  Future<SanidadOcrExtractResult> runOcrFromBytes(Uint8List bytes, int width, int height) async {
    try {
      final Map<String, dynamic> jsonResponse = await ClaudeVisionService.analyzeReceipt(bytes);
      SubscriptionService.registerOcrScan();
      return _fromJson(jsonResponse);
    } catch (e, st) {
      debugPrint('SanidadReceiptScanService.runOcrFromBytes: $e\n$st');
      return SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'Error al procesar la imagen con Claude Vision: $e',
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
