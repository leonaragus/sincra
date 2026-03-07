
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/recibo_model.dart';
import 'cct_database_service.dart';
import 'educational_concepts_service.dart';

// Importamos el servicio de suscripción
import '../subscription/subscription_service.dart';

class AuditResult {
  final bool isError;
  final String message;
  AuditResult({required this.isError, required this.message});
}

class ClaudeVisionService {
  static const String _minimalPrompt = '''
  Tu única tarea es analizar la imagen de un recibo de sueldo argentino y extraer el texto.
  Responde únicamente con un JSON con esta estructura compacta: {"empleado_cuil": "...", "conceptos": [["cod", "desc", "unid", 1.0, 0.0]], "neto": 1.0}
  ''';

  static Future<ReciboModel> analyzeAndAuditReceipt(Uint8List imageBytes) async {
    // --- CONTROL DE SUSCRIPCIÓN ---
    final bool canUse = await SubscriptionService.canUseClaude();
    if (!canUse) {
      final remainingDays = await SubscriptionService.getTrialDaysRemaining();
      if (remainingDays <= 0) {
        throw Exception('Tu período de prueba ha terminado. Suscríbete para seguir usando el análisis con IA.');
      } else {
        throw Exception('Alcanzaste el límite de 2 análisis con IA durante la prueba gratuita.');
      }
    }

    final base64Image = base64Encode(imageBytes);
    final rawJsonResponse = await _invokeClaudeHaiku(base64Image);

    // Si la llamada fue exitosa, registramos el uso.
    final reciboBase = _parseRawResponseToModel(rawJsonResponse, rawJsonResponse);
    return _auditarReciboCompleto(reciboBase, CctDatabaseService());
  }

  static ReciboModel _auditarReciboCompleto(ReciboModel recibo, CctDatabaseService cctService) {
    List<AlertaIa> alertas = [];
    List<ExplicacionIa> explicaciones = [];
    int healthScore = 100;

    final allConcepts = [...recibo.liquidacionDetallada.haberes, ...recibo.liquidacionDetallada.retenciones];
    final descripcionesFull = allConcepts.map((c) => c.descripcion.toLowerCase()).join(' ');

    final infoCCT = cctService.identificarCCT(descripcionesFull, recibo.cabecera.categoriaProfesional ?? '');
    final isLiquidacionFinal = descripcionesFull.contains('indemni');
    final topeVigente = cctService.obtenerTopePrevisional(recibo.cabecera.periodoAbonado ?? '');

    final conceptosAuditados = <String>['jubilaci', 'obra social', 'ley 19032'];
    final retencionesClave = recibo.liquidacionDetallada.retenciones.where((r) => conceptosAuditados.any((key) => r.descripcion.toLowerCase().contains(key))).toList();
    
    bool alcanzoTope = recibo.totales.totalBruto > topeVigente;
    bool topeValidado = true;

    for (var retencion in retencionesClave) {
        final auditResult = _auditarRetencion(retencion, recibo.totales.totalBruto, topeVigente, infoCCT, cctService);
        if (auditResult.isError) {
            alertas.add(AlertaIa(titulo: "🟡 Revisar ${retencion.descripcion}", descripcion: auditResult.message, severidad: 'media'));
            healthScore -= 25;
            topeValidado = false;
        }
    }

    if (alcanzoTope && topeValidado) {
      final totalAportes = retencionesClave.fold(0.0, (sum, item) => sum + item.monto.abs());
      final topeInfo = EducationalConceptsService.findExplanation("tope-aportes");
      if (topeInfo != null) {
          explicaciones.add(ExplicacionIa(
              concepto: topeInfo.title,
              detalle: "Tus aportes de ley sumaron \$${totalAportes.toStringAsFixed(2)}. ${topeInfo.explanation}",
              tipo: 'retencion_agrupada',
              monto: -totalAportes,
          ));
      }
    } 

    final conceptosRestantes = allConcepts.where((c) => !retencionesClave.contains(c) || !topeValidado || !alcanzoTope);
    for (var concepto in conceptosRestantes) {
         final conceptInfo = EducationalConceptsService.findExplanation(concepto.descripcion);
         String detalle = conceptInfo?.explanation ?? "Es un concepto específico de tu convenio por valor de \$${concepto.monto.toStringAsFixed(2)}.";
         String titulo = conceptInfo?.title ?? concepto.descripcion;

         explicaciones.add(ExplicacionIa(
          concepto: titulo,
          detalle: detalle,
          tipo: concepto.monto > 0 ? 'haber' : 'retencion',
          monto: concepto.monto,
         ));
    }

    String tituloScore;
    if (healthScore >= 95) tituloScore = "Salud de tu Recibo: ${healthScore}/100 (Excelente)";
    else if (healthScore >= 70) tituloScore = "Salud de tu Recibo: ${healthScore}/100 (Bueno)";
    else if (healthScore >= 50) tituloScore = "Salud de tu Recibo: ${healthScore}/100 (Requiere Atención)";
    else tituloScore = "Salud de tu Recibo: ${healthScore}/100 (Bajo)";

    String saludo = isLiquidacionFinal 
      ? "¡Hola! Analizamos tu liquidación final.": "¡Hola! Analizamos tu recibo mensual.";

    return recibo.copyWith(
      inferencias: InferenciasRecibo(convenioSugerido: infoCCT.nombre, confianza: infoCCT.confianza, healthScore: healthScore > 0 ? healthScore : 0),
      auditoriaIa: AuditoriaIa(analisisGeneral: "$tituloScore\n\n$saludo", alertas: alertas, explicacionesItems: explicaciones),
    );
  }

  static AuditResult _auditarRetencion(ConceptoRecibo retencion, double bruto, double tope, InfoCCT infoCCT, CctDatabaseService cctService) {
    final key = retencion.descripcion.toLowerCase();
    String reglaKey = "";
    if (key.contains('jubilaci')) reglaKey = 'jubilaci';
    else if (key.contains('obra social')) reglaKey = 'obra social';
    else if (key.contains('ley 19032')) reglaKey = 'ley 19032';
    if (reglaKey.isEmpty) return AuditResult(isError: false, message: '');

    final regla = cctService.obtenerReglasRetencion(infoCCT.id, reglaKey);
    final monto = retencion.monto.abs();
    final baseDeCalculo = min(bruto, tope);

    if (baseDeCalculo <= 0) return AuditResult(isError: false, message: '');

    final pReal = (monto / baseDeCalculo) * 100;
    final pEsperadoMin = regla.min;
    final pEsperadoMax = regla.max;

    if (pReal >= pEsperadoMin - 0.2 && pReal <= pEsperadoMax + 0.2) {
      return AuditResult(isError: false, message: "OK");
    } else {
      if (infoCCT.id == "judicial" && pReal > pEsperadoMax) {
         return AuditResult(isError: true, message: "Tu descuento jubilatorio es del ${pReal.toStringAsFixed(1)}% sobre la base imponible (\$${baseDeCalculo.toStringAsFixed(2)}), superior a la ley general. Sabemos que el Poder Judicial tiene un régimen especial, por lo que este valor podría ser correcto, pero es nuestra obligación marcarlo.");
      }
      String mensaje = "El descuento es del ${pReal.toStringAsFixed(1)}% sobre la base de \$${baseDeCalculo.toStringAsFixed(2)}. Se esperaba entre ${pEsperadoMin}% y ${pEsperadoMax}%.";
      return AuditResult(isError: true, message: mensaje);
    }
  }
  
  static Future<String> _invokeClaudeHaiku(String base64Image) async {
    // Por ahora, devolvemos un JSON vacío para que _parseRawResponseToModel use el mock.
    return ""; 
  }

  static ReciboModel _parseRawResponseToModel(String rawJson, String rawText) { 
    return ReciboModel(
        textoCrudo: rawText,
        cabecera: const CabeceraRecibo(
            periodoAbonado: '2024-05',
            empleadoNombre: 'Perez, Juan',
            empleadoCuil: '20-30123456-7',
            categoriaProfesional: 'Administrativo A'
        ),
        liquidacionDetallada: const LiquidacionDetallada(
            haberes: [
                ConceptoRecibo(descripcion: 'BASICO', monto: 756000.00),
                ConceptoRecibo(descripcion: 'ASISTENCIA Y PUNTUALIDAD', monto: 63000.00),
                ConceptoRecibo(descripcion: 'ANTIGUEDAD 5 ANIOS', monto: 37800.00),
            ],
            retenciones: [
                ConceptoRecibo(descripcion: 'JUBILACION 11%', monto: -95013.60),
                ConceptoRecibo(descripcion: 'LEY 19032 3%', monto: -25912.80),
                ConceptoRecibo(descripcion: 'OBRA SOCIAL 3%', monto: -25912.80),
                ConceptoRecibo(descripcion: 'APORTE FAECYS', monto: -4095.00),
                ConceptoRecibo(descripcion: 'SINDICATO EMPLEADOS DE COMERCIO', monto: -17199.00),
            ]
        ),
        totales: const TotalesRecibo(
            totalBruto: 864000.00, 
            totalRetenciones: 168133.20,
            netoACobrar: 695866.80
        ),
        inferencias: const InferenciasRecibo(convenioSugerido: 'comercio', confianza: 'Baja', healthScore: 0),
        auditoriaIa: const AuditoriaIa(analisisGeneral: '', alertas: [], explicacionesItems: [])
    );
  }

  static Future<ReciboModel> extractRawModel(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    final raw = await _invokeClaudeHaiku(base64Image);
    return _parseRawResponseToModel(raw, raw);
  }
}
