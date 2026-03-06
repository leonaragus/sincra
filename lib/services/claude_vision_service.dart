import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recibo_model.dart';

// --- Interfaces de Contrato para el Servicio de CCT ---
// El motor de auditoría depende de estas abstracciones, no de una implementación concreta.

abstract class CctService {
  InfoCCT identificarCCT(String descripciones, String? categoria);
  ReglaRetencion obtenerReglasRetencion(String cctId, String retencionKey);
  double obtenerTopePrevisional(String? periodo);
  String? obtenerExplicacionAmigable(String descripcion, String cctId);
}

class ReglaRetencion {
  final double min; final double max;
  ReglaRetencion({required this.min, required this.max});
}

class InfoCCT {
  final String id; final String nombre; final String confianza;
  InfoCCT({required this.id, required this.nombre, required this.confianza});
}
// --- Fin de las Interfaces ---

class ClaudeVisionService {
  
  static const String _minimalPrompt = '''
  Tu única tarea es analizar la imagen de un recibo de sueldo argentino y extraer el texto.
  Responde únicamente con un JSON con esta estructura compacta: {"empleado_cuil": "...", "conceptos": [["cod", "desc", "unid", 1.0, 0.0]], "neto": 1.0}
  ''';

  // El método de análisis ahora requiere que se le pase un CctService real.
  static Future<ReciboModel> analyzeAndAuditReceipt(Uint8List imageBytes, CctService cctService) async {
    final base64Image = base64Encode(imageBytes);
    // En un caso real, la llamada a la IA y el parseo no se omitirían.
    final rawJsonResponse = await _invokeClaudeHaiku(base64Image);
    final reciboBase = _parseRawResponseToModel(rawJsonResponse, rawJsonResponse);
    
    // Inyectamos el servicio real al motor de auditoría.
    return _auditarReciboCompleto(reciboBase, cctService);
  }

  /// === MOTOR DE AUDITORÍA INTEGRAL v6.1 (ARQUITECTURA LIMPIA) ===
  static ReciboModel _auditarReciboCompleto(ReciboModel recibo, CctService cctService) {
    List<AlertaIa> alertas = [];
    List<ExplicacionIa> explicaciones = [];
    int healthScore = 100;

    final totalBruto = recibo.totales.totalBruto;
    final haberes = recibo.liquidacionDetallada.haberes;
    final retenciones = recibo.liquidacionDetallada.retenciones;
    final descripcionesFull = [...haberes, ...retenciones].map((c) => c.descripcion.toLowerCase()).join(' ');

    // 1. CONTEXTO (Delegado al CctService)
    final double topeVigente = cctService.obtenerTopePrevisional(recibo.cabecera.periodoAbonado);
    final infoCCT = cctService.identificarCCT(descripcionesFull, recibo.cabecera.categoriaProfesional);
    final isLiquidacionFinal = descripcionesFull.contains('indemni') || descripcionesFull.contains('egre') || descripcionesFull.contains('cese');

    // 2. PROCESAR HABERES
    for (var haber in haberes) {
      String desc = haber.descripcion.toLowerCase();
      String montoStr = "\$ ${haber.monto.toStringAsFixed(2)}";
      String detalle = cctService.obtenerExplicacionAmigable(haber.descripcion, infoCCT.id) ?? (isLiquidacionFinal && (desc.contains('egre') || desc.contains('indem'))) 
        ? "🌟 Este es el pago fuerte de tu salida ($montoStr). Entra 'limpia' a tu bolsillo, sin descuentos." 
        : (desc.contains('vac no goz') 
          ? "🏖️ Son $montoStr por las vacaciones que no te tomaste. ¡Te las pagan en efectivo por ley!" 
          : "Un concepto de tu convenio por valor de $montoStr.");
      explicaciones.add(ExplicacionIa(concepto: haber.descripcion, detalle: detalle, tipo: 'haber', monto: haber.monto));
    }

    // 3. AUDITORÍA DE RETENCIONES (Agnóstica al CCT)
    _auditarRetencionFlexible(alertas, explicaciones, retenciones, 'jubilaci', totalBruto, topeVigente, "Jubilación", infoCCT, cctService, healthScore);
    _auditarRetencionFlexible(alertas, explicaciones, retenciones, 'obra social', totalBruto, topeVigente, "Obra Social", infoCCT, cctService, healthScore);

    // 4. ALERTAS CRÍTICAS
    final cuotasAlimentarias = retenciones.where((r) => r.descripcion.toLowerCase().contains('cuota alim'));
    if (cuotasAlimentarias.isNotEmpty) {
      final montoCuota = cuotasAlimentarias.fold(0.0, (sum, item) => sum + item.monto);
      alertas.add(AlertaIa(titulo: "🔴 Ojo con la Cuota Alimentaria", descripcion: "Tenés una retención judicial de \$ ${montoCuota.toStringAsFixed(2)}. ¡Fijate si coincide con lo que firmó el juez!", severidad: 'alta'));
      healthScore -= 20;
    }

    // 5. GENERAR RESULTADO FINAL
    String saludo = isLiquidacionFinal 
      ? "¡Hola! Analizamos tu salida de la empresa. Revisamos cada peso de tu indemnización y vacaciones."
      : "¡Hola! Analizamos tu recibo mensual. Acá te explicamos qué es cada cosa para que no te queden dudas:";

    return recibo.copyWith(
      inferencias: InferenciasRecibo(convenioSugerido: infoCCT.nombre, confianza: infoCCT.confianza, healthScore: healthScore),
      auditoriaIa: AuditoriaIa(analisisGeneral: saludo, alertas: alertas, explicacionesItems: explicaciones),
    );
  }

  static void _auditarRetencionFlexible(List<AlertaIa> alertas, List<ExplicacionIa> explicaciones, List<ConceptoRecibo> retenciones, String key, double bruto, double tope, String nombre, InfoCCT infoCCT, CctService cctService, int healthScore) {
    final regla = cctService.obtenerReglasRetencion(infoCCT.id, key);
    final matches = retenciones.where((r) => r.descripcion.toLowerCase().contains(key));
    if (matches.isEmpty) return;

    final montoTotal = matches.fold(0.0, (sum, item) => sum + item.monto);
    double base = (bruto > tope) ? tope : bruto;
    double pReal = (base > 0) ? (montoTotal / base) * 100 : 0;

    if (pReal >= regla.min && pReal <= regla.max) {
      explicaciones.add(ExplicacionIa(concepto: nombre, detalle: "✅ \$ ${montoTotal.toStringAsFixed(2)} ($nombre). Todo en orden. El ${pReal.toStringAsFixed(1)}% coincide con tu convenio ${infoCCT.nombre}.", tipo: 'ok', monto: montoTotal));
    } else {
      alertas.add(AlertaIa(titulo: "🟡 Revisar $nombre", descripcion: "El descuento (${pReal.toStringAsFixed(1)}%) se sale del rango de tu convenio (${regla.min}% a ${regla.max}%).", severidad: 'media'));
      healthScore -= 15;
    }
  }

  // Funciones _invokeClaudeHaiku y _parseRawResponseToModel omitidas por brevedad, no cambian.
  static Future<String> _invokeClaudeHaiku(String base64Image) async { return ""; }
  static ReciboModel _parseRawResponseToModel(String rawJson, String rawText) { return ReciboModel(textoCrudo: '', cabecera: CabeceraRecibo(), liquidacionDetallada: LiquidacionDetallada(haberes: [], retenciones: []), totales: TotalesRecibo(totalBruto: 0, totalRetenciones: 0, netoACobrar: 0), inferencias: InferenciasRecibo(convenioSugerido: '', confianza: ''), auditoriaIa: AuditoriaIa(analisisGeneral: '', alertas: [], explicacionesItems: [])); }
}
