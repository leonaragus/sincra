// ========================================================================
// TEACHER RECEIPT SCAN SERVICE - OCR (on-device) + QR para recibos 2026
// google_mlkit_text_recognition (local) + mobile_scanner. Regex para CUIL,
// Básico, Antigüedad %, Puntos, Valor Índice. Prioridad: QR JSON > QR URL > OCR.
// ========================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'ocr_service.dart'; // Import OcrService
import '../models/recibo_model.dart'; // Import ReciboModel

/// Origen de los datos extraídos
enum OcrExtractSource { qrJson, qrUrl, ocr }

/// Resultado de la extracción (QR o OCR) para OcrReviewScreen
class OcrExtractResult {
  final String? cuil;
  final String? nombre;
  final String? razonSocial; // Institución
  final String? cuitEmpresa; // CUIT Institución
  final String? domicilioEmpresa; // Domicilio Institución
  final List<Map<String, dynamic>>? items; // Items del recibo (conceptos)
  final DateTime? fechaIngreso;
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
    this.razonSocial,
    this.cuitEmpresa,
    this.domicilioEmpresa,
    this.items,
    this.fechaIngreso,
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
      razonSocial: m['razonSocial']?.toString().trim(),
      cuitEmpresa: m['cuitEmpresa']?.toString().trim(),
      fechaIngreso: m['fechaIngreso'] != null ? DateTime.tryParse(m['fechaIngreso'].toString()) : null,
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

  // --- OCR (Cloud with Claude via OcrService) ---

  /// Ejecuta OCR sobre [imagePath] (ruta a archivo).
  Future<OcrExtractResult> runOcrFromPath(String imagePath) async {
    final xfile = XFile(imagePath);
    return runOcrFromXFile(xfile);
  }
  
  /// Ejecuta OCR sobre [XFile] (para compatibilidad Web).
  Future<OcrExtractResult> runOcrFromXFile(XFile file) async {
    try {
      // Usamos el OcrService estándar (el del verificador)
      final ocrService = OcrService();
      // Le pasamos contextoConvenio null por ahora, o podríamos pasar algo si fuera relevante
      final ocrResult = await ocrService.procesarImagen(file);

      if (!ocrResult.exito || ocrResult.reciboModel == null) {
        final errorMsg = ocrResult.texto.length > 200 
            ? '${ocrResult.texto.substring(0, 200)}...' 
            : ocrResult.texto;
        
        return OcrExtractResult(
          source: OcrExtractSource.ocr,
          error: 'No se pudieron extraer datos: $errorMsg', 
          rawTextOcr: ocrResult.textoCrudo,
        );
      }

      // MAPEO: Transformamos ReciboModel (complejo) a OcrExtractResult (plano para docentes)
      return _mapReciboModelToExtractResult(ocrResult.reciboModel!, ocrResult.textoCrudo);

    } catch (e, st) {
      debugPrint('TeacherReceiptScanService.runOcrFromXFile: $e\n$st');
      return const OcrExtractResult(
        source: OcrExtractSource.ocr,
        error: 'Error al procesar la imagen.',
      );
    }
  }

  /// Mapea la estructura compleja de ReciboModel a la estructura plana de OcrExtractResult
  OcrExtractResult _mapReciboModelToExtractResult(ReciboModel model, String rawText) {
    final cab = model.cabecera;
    final det = model.liquidacionDetallada;

    // 1. Mapeo de Items (todos)
    List<Map<String, dynamic>> allItems = [];

    // Haberes
    for (var h in det.haberes) {
      allItems.add({
        'codigo': h.codigo,
        'descripcion': h.descripcion,
        'cantidad': h.cantidad,
        'monto': h.monto,
        'tipo': 'haber',
        'es_remunerativo': h.esRemunerativo,
      });
    }

    // Retenciones
    for (var r in det.retenciones) {
      allItems.add({
        'codigo': r.codigo,
        'descripcion': r.descripcion,
        'cantidad': r.porcentaje, // Usamos porcentaje como cantidad/detalle
        'monto': r.monto,
        'tipo': 'retencion',
      });
    }

    // Otros
    for (var o in det.otrosConceptos) {
      allItems.add({
        'codigo': '',
        'descripcion': o.descripcion,
        'monto': o.monto,
        'tipo': 'otro',
      });
    }

    // 2. Extracción de valores clave para el docente (Básico, Antigüedad)
    double? basico;
    
    // Buscamos concepto Básico explícitamente
    for (var h in det.haberes) {
      final desc = h.descripcion.toLowerCase();
      // Ajustar heurística según nombres comunes en recibos docentes
      if (desc.contains('basico') || desc.contains('básico')) {
        basico = h.monto;
        break; 
      }
    }

    // Parseo de CUIL
    String? cuil = (cab.empleadoCuil?.isNotEmpty == true) ? cab.empleadoCuil : null;

    // Parseo de Jurisdicción (si viniera en cabecera o se deduce)
    String? jurisdiccion;
    final empresaLower = cab.empresaNombre?.toLowerCase() ?? '';
    if (empresaLower.contains('buenos aires') || empresaLower.contains('pba')) {
      jurisdiccion = 'PBA';
    } else if (empresaLower.contains('caba') || empresaLower.contains('ciudad')) {
      jurisdiccion = 'CABA';
    } else if (empresaLower.contains('mendoza')) {
      jurisdiccion = 'Mendoza';
    }

    // Parseo de Fecha Ingreso
    DateTime? fechaIngreso;
    if (cab.fechaIngreso?.isNotEmpty == true) {
      try {
        // Normalizamos separadores
        String f = cab.fechaIngreso!.replaceAll('-', '/');
        final parts = f.split('/');
        if (parts.length == 3) {
          // Formato yyyy/mm/dd
          if (parts[0].length == 4) {
            fechaIngreso = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } 
          // Formato dd/mm/yyyy
          else {
            fechaIngreso = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      } catch (_) {}
    }

    return OcrExtractResult(
      cuil: cuil,
      nombre: (cab.empleadoNombre?.isNotEmpty == true) ? cab.empleadoNombre : null,
      razonSocial: (cab.empresaNombre?.isNotEmpty == true) ? cab.empresaNombre : null,
      cuitEmpresa: (cab.empresaCuit?.isNotEmpty == true) ? cab.empresaCuit : null,
      domicilioEmpresa: (cab.empresaDomicilio?.isNotEmpty == true) ? cab.empresaDomicilio : null,
      items: allItems,
      fechaIngreso: fechaIngreso,
      sueldoBasico: basico,
      jurisdiccionRaw: jurisdiccion,
      source: OcrExtractSource.ocr,
      rawTextOcr: rawText,
    );
  }

  /// OCR desde bytes.
  Future<OcrExtractResult> runOcrFromBytes(Uint8List bytes, int width, int height) async {
    // Para usar OcrService necesitamos XFile.
    // XFile.fromData es compatible con bytes en memoria.
    final xfile = XFile.fromData(bytes);
    return runOcrFromXFile(xfile);
  }

  // _analyzeWithClaude REMOVED/DEPRECATED in favor of OcrService logic


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
