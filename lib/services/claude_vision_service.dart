
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recibo_model.dart';
import 'cct_database_service.dart';
import 'educational_concepts_service.dart';
import 'ai_engine_service.dart'; // <- AGREGAR AQUÍ

// Importamos el servicio de suscripción
import '../subscription/subscription_service.dart';

class AuditResult {
  final bool isError;
  final String message;
  AuditResult({required this.isError, required this.message});
}

class ClaudeVisionService {
  static const String _minimalPrompt = r'''
  Actúa como un analista experto en recibos de sueldo de Argentina.
  Tu tarea es extraer de forma precisa y estructurada toda la información de la imagen.
  
  Estructura JSON requerida:
  {
    "cabecera": {
      "empresa_nombre": "Nombre de la empresa/razón social",
      "empresa_cuit": "CUIT del empleador",
      "empresa_domicilio": "Dirección fiscal si figura",
      "empleado_nombre": "Apellido y Nombre del trabajador",
      "empleado_cuil": "CUIL del trabajador",
      "fecha_ingreso": "Fecha de ingreso (DD/MM/AAAA)",
      "categoria": "Categoría laboral (ej: Administrativo A, Operativo, Maestro de Grado)",
      "periodo": "Mes y año liquidado (ej: Mayo 2024)",
      "metadata_docente": {
        "puntos": 0,
        "valor_indice": 0.0,
        "jurisdiccion": "PBA, CABA, etc.",
        "antiguedad_anos": "Cantidad de años",
        "es_rural": false
      }
    },
    "liquidacion": {
      "haberes": [
        {"codigo": "...", "descripcion": "...", "cantidad": "...", "monto": 100.0, "es_remunerativo": true}
      ],
      "retenciones": [
        {"codigo": "...", "descripcion": "...", "cantidad": "...", "monto": 50.0}
      ]
    },
    "totales": {
      "bruto": 150.0,
      "retenciones": 50.0,
      "neto": 100.0
    },
    "inferencias": {
      "convenio": "Identifica el Convenio Colectivo",
      "confianza": "Alta/Media/Baja",
      "resumen_amigable": "Un resumen de 2-3 líneas para el trabajador. Usa tono humano, amigable y 'bien argentino' (ej: 'Che, fijate que...', 'Tranqui que está todo OK'). Explícale lo principal como a un amigo."
    }
  }

  REGLAS CRÍTICAS:
  1. No inventes datos. Si no figura, deja null.
  2. Los montos deben ser numéricos (sin el signo $).
  3. Identifica correctamente si un haber es 'remunerativo' (está en la columna de aportes) o 'no remunerativo'.
  4. Responde ÚNICAMENTE con el objeto JSON puro, sin texto adicional.
  ''';

  static Future<ReciboModel> analyzeAndAuditReceipt(Uint8List imageBytes, {String? contexto}) async {
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
    final promptFinal = (contexto != null && contexto.isNotEmpty) 
        ? "CONTEXTO DEL CONVENIO: $contexto\n\n$_minimalPrompt" 
        : _minimalPrompt;
    final rawJsonResponse = await _invokeClaudeHaiku(base64Image, prompt: promptFinal);

    // Si la llamada fue exitosa, registramos el uso.
    final reciboBase = _parseRawResponseToModel(rawJsonResponse, rawJsonResponse);
    return _auditarReciboCompleto(reciboBase, CctDatabaseService());
  }

  static ReciboModel _auditarReciboCompleto(ReciboModel recibo, CctDatabaseService cctService) {
    List<AlertaIa> alertas = [];
    List<ExplicacionIa> explicaciones = [];
    int healthScore = 100;

    // 1. Auditoría de Cabecera (NUEVO)
    if (recibo.cabecera.empresaCuit == null || recibo.cabecera.empresaCuit!.isEmpty) {
      alertas.add(const AlertaIa(titulo: "CUIT Faltante", descripcion: "No se detectó el CUIT del empleador. Esto es obligatorio en recibos legales.", severidad: 'baja'));
    }
    if (recibo.cabecera.empleadoCuil == null || recibo.cabecera.empleadoCuil!.isEmpty) {
      alertas.add(const AlertaIa(titulo: "CUIL Faltante", descripcion: "No se detectó el CUIL del empleado.", severidad: 'media'));
    }

    // 2. Identificación de CCT (Mejorado con Inferencia de IA)
    final allConcepts = [...recibo.liquidacionDetallada.haberes, ...recibo.liquidacionDetallada.retenciones];
    final descripcionesFull = allConcepts.map((c) => c.descripcion.toLowerCase()).join(' ');
    
    // Si la IA ya sugirió un convenio, lo usamos como pista principal
    final sugerenciaIA = recibo.inferencias.convenioSugerido.toLowerCase();
    final infoCCT = cctService.identificarCCT(
      "$descripcionesFull $sugerenciaIA", 
      recibo.cabecera.categoriaProfesional ?? ''
    );

    final isLiquidacionFinal = descripcionesFull.contains('indemni');
    final topeVigente = cctService.obtenerTopePrevisional(recibo.cabecera.periodoAbonado ?? '');

    // 3. Auditoría de Retenciones (Más precisa con montos numéricos)
    final conceptosAuditados = <String>['jubilaci', 'obra social', 'ley 19032'];
    final retencionesClave = recibo.liquidacionDetallada.retenciones.where((r) => 
      conceptosAuditados.any((key) => r.descripcion.toLowerCase().contains(key))
    ).toList();
    
    // Calculamos el Bruto Sujeto a Aportes (Remunerativo) de forma real si la IA lo detectó bien
    final brutoRemunerativo = recibo.liquidacionDetallada.haberes
        .where((h) => h.esRemunerativo)
        .fold(0.0, (sum, h) => sum + h.monto);
    
    // Si el bruto de la IA es consistente, lo usamos; si no, el calculado
    final baseCalculo = brutoRemunerativo > 0 ? brutoRemunerativo : recibo.totales.totalBruto;

    bool alcanzoTope = baseCalculo > topeVigente;
    bool topeValidado = true;

    for (var retencion in retencionesClave) {
        final auditResult = _auditarRetencion(retencion, baseCalculo, topeVigente, infoCCT, cctService);
        if (auditResult.isError) {
            alertas.add(AlertaIa(titulo: "🟡 Revisar ${retencion.descripcion}", descripcion: auditResult.message, severidad: 'media'));
            healthScore -= 15; // Reducimos penalidad por ser más precisos
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

  static Future<String> analyzeReceipt(Uint8List imageBytes, {String? customPrompt}) async {
    final base64Image = base64Encode(imageBytes);
    return await _invokeClaudeHaiku(base64Image, prompt: customPrompt);
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
  
  static Future<String> _invokeClaudeHaiku(String base64Image, {String? prompt}) async {
    // Redirigimos a AiEngineService (Gemini 2.5 como motor principal)
    final imageBytes = base64Decode(base64Image);
    return await AiEngineService.processImage(
      imageBytes: imageBytes, 
      prompt: prompt ?? _minimalPrompt,
      primaryProvider: AiProvider.gemini,
    );
  }

  static ReciboModel _parseRawResponseToModel(String rawJson, String rawText) {
    try {
      // 1. Limpieza de bloques de código Markdown si el modelo los incluyó
      String jsonStr = rawJson.trim();
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final cab = data['cabecera'] ?? {};
      final liq = data['liquidacion'] ?? {};
      final tot = data['totales'] ?? {};
      final inf = data['inferencias'] ?? {};

      return ReciboModel(
        textoCrudo: rawText,
        cabecera: CabeceraRecibo(
          empleadoCuil: cab['empleado_cuil']?.toString(),
          empleadoNombre: cab['empleado_nombre']?.toString(),
          empresaCuit: cab['empresa_cuit']?.toString(),
          empresaNombre: cab['empresa_nombre']?.toString(),
          empresaDomicilio: cab['empresa_domicilio']?.toString(),
          fechaIngreso: cab['fecha_ingreso']?.toString(),
          categoriaProfesional: cab['categoria']?.toString(),
          periodoAbonado: cab['periodo']?.toString(),
          docenteMetadata: _parseDocenteMetadata(cab['metadata_docente']), // <- NUEVO
        ),
        liquidacionDetallada: LiquidacionDetallada(
          haberes: (liq['haberes'] as List? ?? []).map((h) => ConceptoRecibo(
            codigo: h['codigo']?.toString(),
            descripcion: h['descripcion']?.toString() ?? 'Concepto',
            cantidad: h['cantidad']?.toString(),
            monto: (h['monto'] as num? ?? 0.0).toDouble(),
            esRemunerativo: h['es_remunerativo'] == true,
          )).toList(),
          retenciones: (liq['retenciones'] as List? ?? []).map((r) => ConceptoRecibo(
            codigo: r['codigo']?.toString(),
            descripcion: r['descripcion']?.toString() ?? 'Retención',
            cantidad: r['cantidad']?.toString(),
            monto: (r['monto'] as num? ?? 0.0).toDouble(),
            esRemunerativo: false,
          )).toList(),
        ),
        totales: TotalesRecibo(
          totalBruto: (tot['bruto'] as num? ?? 0.0).toDouble(),
          totalRetenciones: (tot['retenciones'] as num? ?? 0.0).toDouble(),
          netoACobrar: (tot['neto'] as num? ?? 0.0).toDouble(),
        ),
        inferencias: InferenciasRecibo(
          convenioSugerido: inf['convenio']?.toString() ?? 'Sin identificar',
          confianza: inf['confianza']?.toString() ?? 'Baja',
          healthScore: 0,
        ),
        auditoriaIa: AuditoriaIa(
          analisisGeneral: '',
          analisisHumano: inf['resumen_amigable']?.toString(), // <- NUEVO
          alertas: [],
          explicacionesItems: [],
        ),
      );
    } catch (e) {
      debugPrint('Error al parsear el JSON de la IA: $e');
      // Fallback a un modelo vacío si el parseo falla catastróficamente
      return _generateEmptyModel(rawText);
    }
  }

  static MetadataDocente? _parseDocenteMetadata(dynamic data) {
    if (data == null || data is! Map) return null;
    return MetadataDocente(
      puntos: (data['puntos'] as num?)?.toInt(),
      valorIndice: (data['valor_indice'] as num?)?.toDouble(),
      jurisdiccion: data['jurisdiccion']?.toString(),
      antiguedadAnos: data['antiguedad_anos']?.toString(),
      esRural: data['es_rural'] == true,
    );
  }

  static ReciboModel _generateEmptyModel(String rawText) {
    return const ReciboModel(
      textoCrudo: '',
      cabecera: CabeceraRecibo(),
      liquidacionDetallada: LiquidacionDetallada(haberes: [], retenciones: []),
      totales: TotalesRecibo(totalBruto: 0, totalRetenciones: 0, netoACobrar: 0),
      inferencias: InferenciasRecibo(convenioSugerido: 'Error de análisis', confianza: 'Baja', healthScore: 0),
      auditoriaIa: AuditoriaIa(analisisGeneral: 'No se pudo leer el recibo. Intenta con una imagen más nítida.', alertas: [], explicacionesItems: []),
    );
  }

  static Future<ReciboModel> extractRawModel(Uint8List imageBytes, {String? contexto}) async {
    final base64Image = base64Encode(imageBytes);
    final promptFinal = (contexto != null && contexto.isNotEmpty) 
        ? "CONTEXTO DEL CONVENIO: $contexto\n\n$_minimalPrompt" 
        : _minimalPrompt;
    final raw = await _invokeClaudeHaiku(base64Image, prompt: promptFinal);
    return _parseRawResponseToModel(raw, raw);
  }

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('claude_api_key');
  }

  static Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_api_key');
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('claude_api_key', key);
  }

  static Future<void> setGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
  }
}
