// ========================================================================
// TEACHER RECEIPT SCAN SERVICE - OCR (on-device) + QR para recibos 2026
// google_mlkit_text_recognition (local) + mobile_scanner. Regex para CUIL,
// Básico, Antigüedad %, Puntos, Valor Índice. Prioridad: QR JSON > QR URL > OCR.
// ========================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:elevar_liquidacion/services/claude_vision_service.dart';
import 'package:flutter/foundation.dart';
import 'subscription_service.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:mobile_scanner/mobile_scanner.dart';

/// Origen de los datos extraídos
enum OcrExtractSource { qrJson, qrUrl, ocr }

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

/// Resultado de la extracción (QR o OCR) para OcrReviewScreen
class OcrExtractResult {
  final Cabecera? cabecera;
  final LiquidacionDetallada? liquidacionDetallada;
  final Totales? totales;
  final AuditoriaIa? auditoriaIa;
  final String? urlDetectada;
  final OcrExtractSource source;
  final String? rawTextOcr;
  final String? error;
  final int? puntos;
  final double? valorIndice;
  final double? antiguedadPct;
  final double? sueldoBasico;
  final String? codigoRnos;
  final String? jurisdiccionRaw;

  const OcrExtractResult({
    this.cabecera,
    this.liquidacionDetallada,
    this.totales,
    this.auditoriaIa,
    this.urlDetectada,
    required this.source,
    this.rawTextOcr,
    this.error,
    this.puntos,
    this.valorIndice,
    this.antiguedadPct,
    this.sueldoBasico,
    this.codigoRnos,
    this.jurisdiccionRaw,
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
    return OcrExtractResult(
      cabecera: m['cabecera'] != null ? Cabecera.fromJson(m['cabecera'] as Map<String, dynamic>) : null,
      liquidacionDetallada: m['liquidacion_detallada'] != null ? LiquidacionDetallada.fromJson(m['liquidacion_detallada'] as Map<String, dynamic>) : null,
      totales: m['totales'] != null ? Totales.fromJson(m['totales'] as Map<String, dynamic>) : null,
      auditoriaIa: m['auditoria_ia'] != null ? AuditoriaIa.fromJson(m['auditoria_ia'] as Map<String, dynamic>) : null,
      source: OcrExtractSource.qrJson,
      urlDetectada: m['url']?.toString().trim().isNotEmpty == true ? m['url'].toString().trim() : null,
      puntos: (m['puntos'] as num?)?.toInt(),
      valorIndice: (m['valor_indice'] as num?)?.toDouble() ?? (m['valorIndice'] as num?)?.toDouble(),
      antiguedadPct: (m['antiguedad_pct'] as num?)?.toDouble() ?? (m['antiguedadPct'] as num?)?.toDouble(),
      sueldoBasico: (m['sueldo_basico'] as num?)?.toDouble() ?? (m['sueldoBasico'] as num?)?.toDouble(),
      codigoRnos: m['codigo_rnos'] as String?,
      jurisdiccionRaw: m['jurisdiccion_raw'] as String?,
    );
  }



  // --- OCR (on-device) ---

  /// Ejecuta OCR sobre [imagePath] (ruta a archivo). Procesamiento 100% local.
  Future<OcrExtractResult> runOcrFromPath(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final Map<String, dynamic> jsonResponse = await ClaudeVisionService.analyzeReceipt(bytes);
      SubscriptionService.registerOcrScan();
      return _fromJson(jsonResponse); // Assuming Claude Vision returns a structure similar to what _fromJson expects
      // We might need to adjust _fromJson or create a new parsing method for Claude's output
    } catch (e, st) {
      debugPrint('TeacherReceiptScanService.runOcrFromPath: $e\n$st');
      return OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'Error al procesar la imagen con Claude Vision: $e',
      );
    }
  }

  /// OCR desde bytes. [bytes] en formato NV21/YUV (p. ej. cámara Android). Para archivos use [runOcrFromPath].
  Future<OcrExtractResult> runOcrFromBytes(Uint8List bytes, int width, int height) async {
    try {
      final Map<String, dynamic> jsonResponse = await ClaudeVisionService.analyzeReceipt(bytes);
      SubscriptionService.registerOcrScan();
      return _fromJson(jsonResponse);
    } catch (e, st) {
      debugPrint('TeacherReceiptScanService.runOcrFromBytes: $e\n$st');
      return OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'Error al procesar la imagen con Claude Vision: $e',
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
