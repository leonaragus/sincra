// ========================================================================
// SANIDAD RECEIPT SCAN SERVICE - OCR (on-device) + QR para recibos FATSA
// google_mlkit_text_recognition (local) + mobile_scanner. Regex para CUIL,
// Básico, Antigüedad %, Categoría, Horas Nocturnas, etc.
// Prioridad: QR JSON > QR URL > OCR.
// ========================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../services/sanidad_omni_engine.dart';
import '../utils/image_bytes_reader.dart';
import 'ocr_service.dart';
import '../models/recibo_model.dart';

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
  
  // Lista de items completa para referencia (como en Docentes)
  final List<Map<String, dynamic>>? items;

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
    this.items,
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

/// Servicio de escaneo: OCR (ML Kit/Claude) y parsing de QR (JSON / URL)
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

  // --- OCR (Cloud with Claude via OcrService) ---

  /// Ejecuta OCR sobre [imagePath] (ruta a archivo).
  Future<SanidadOcrExtractResult> runOcrFromPath(String imagePath) async {
    try {
      final xfile = XFile(imagePath);
      return runOcrFromXFile(xfile);
    } catch (e, st) {
      debugPrint('SanidadReceiptScanService.runOcr: $e\n$st');
      return const SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'Error al procesar la imagen.',
      );
    }
  }

  /// Ejecuta OCR sobre [XFile] (para compatibilidad Web).
  Future<SanidadOcrExtractResult> runOcrFromXFile(XFile file) async {
    try {
      // Usamos el OcrService estándar (el del verificador y docentes)
      // Pasamos 'Sanidad' como contexto para ayudar a la IA si fuera necesario
      final ocrService = OcrService();
      final ocrResult = await ocrService.procesarImagen(file, contextoConvenio: 'Sanidad FATSA');

      if (!ocrResult.exito || ocrResult.reciboModel == null) {
        final errorMsg = ocrResult.texto.length > 200 
            ? '${ocrResult.texto.substring(0, 200)}...' 
            : ocrResult.texto;
        
        return SanidadOcrExtractResult(
          source: OcrExtractSourceSanidad.ocr,
          error: 'No se pudieron extraer datos: $errorMsg', 
          rawTextOcr: ocrResult.textoCrudo,
        );
      }

      // MAPEO: Transformamos ReciboModel (complejo) a SanidadOcrExtractResult (plano)
      return _mapReciboModelToSanidadResult(ocrResult.reciboModel!, ocrResult.textoCrudo);

    } catch (e, st) {
      debugPrint('SanidadReceiptScanService.runOcrFromXFile: $e\n$st');
      return const SanidadOcrExtractResult(
        source: OcrExtractSourceSanidad.ocr,
        error: 'Error al procesar la imagen.',
      );
    }
  }

  /// Mapea la estructura compleja de ReciboModel a la estructura de Sanidad
  SanidadOcrExtractResult _mapReciboModelToSanidadResult(ReciboModel model, String rawText) {
    final cab = model.cabecera;
    final det = model.liquidacionDetallada;

    // 1. Mapeo de Items para referencia (opcional pero útil)
    List<Map<String, dynamic>> allItems = [];
    for (var h in det.haberes) {
      allItems.add({
        'descripcion': h.descripcion,
        'monto': h.monto,
        'tipo': 'haber',
      });
    }
    for (var r in det.retenciones) {
      allItems.add({
        'descripcion': r.descripcion,
        'monto': r.monto,
        'tipo': 'retencion',
      });
    }

    // 2. Extracción de valores clave para Sanidad usando lógica difusa sobre los items
    double? basico;
    double? antiguedad;
    int? horasNocturnas;
    double? zona;
    double? titulo;
    double? riesgo;
    
    // Buscamos conceptos específicos en los haberes
    for (var h in det.haberes) {
      final desc = h.descripcion.toLowerCase();
      
      // Básico
      if (basico == null && (desc.contains('basico') || desc.contains('básico') || desc.contains('sueldo'))) {
        basico = h.monto;
      }
      
      // Antigüedad
      if (antiguedad == null && (desc.contains('antiguedad') || desc.contains('antigüedad'))) {
        // Intentamos sacar el porcentaje de la cantidad o descripción si es posible
        final cant = cleanAmount(h.cantidad);
        if (cant != null && cant > 0 && cant < 100) {
           antiguedad = cant; // Asumimos años/porcentaje
        }
      }
      
      // Horas Nocturnas
      if (horasNocturnas == null && (desc.contains('nocturna') || desc.contains('noche'))) {
        final cant = cleanAmount(h.cantidad);
        if (cant != null) {
          horasNocturnas = cant.toInt();
        }
      }
      
      // Zona Patagónica
      if (zona == null && (desc.contains('zona') || desc.contains('patagonica') || desc.contains('patagónica'))) {
        zona = h.monto;
      }
      
      // Título
      if (titulo == null && (desc.contains('titulo') || desc.contains('título'))) {
        titulo = h.monto;
      }
      
      // Riesgo / Tarea Crítica
      if (riesgo == null && (desc.contains('riesgo') || desc.contains('critica') || desc.contains('crítica'))) {
        riesgo = h.monto;
      }
    }

    return SanidadOcrExtractResult(
      cuil: cab.empleadoCuil,
      nombre: cab.empleadoNombre,
      sueldoBasico: basico,
      antiguedadPct: antiguedad,
      categoriaRaw: cab.categoriaProfesional, // Usamos la categoría detectada en cabecera
      horasNocturnas: horasNocturnas,
      jurisdiccionRaw: cab.empresaDomicilio, // Aproximación
      source: OcrExtractSourceSanidad.ocr,
      rawTextOcr: rawText,
      adicionalTitulo: titulo,
      tareaCriticaRiesgo: riesgo,
      adicionalZonaPatagonica: zona,
      items: allItems,
    );
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
  }
}
