import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';

class ClaudeVisionService {
  static const String _kApiKeyPref = 'claude_api_key';

  /// Guarda la API Key de Claude
  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKeyPref, key);
  }

  /// Obtiene la API Key guardada, del archivo .env o hardcodeada
  static Future<String?> getApiKey() async {
    // 1. Prioridad: Key guardada manualmente por el usuario
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_kApiKeyPref);
    if (savedKey != null && savedKey.isNotEmpty) {
      return savedKey;
    }
    
    // 2. Fallback: Key del archivo .env o configuración interna
    return dotenv.env['ANTHROPIC_API_KEY'] ?? ApiKeys.anthropicApiKey;
  }

  static Future<String> analyzeReceipt(Uint8List imageBytes, {String? contextoConvenio, String? customPrompt}) async {
    final apiKey = await getApiKey();
    final base64Image = base64Encode(imageBytes);

    // 1. Prompt Construction
    String promptText;
    
    if (customPrompt != null && customPrompt.isNotEmpty) {
      promptText = customPrompt;
    } else {
      // Default Receipt Prompt
      promptText = '''Eres un asesor laboral empático y experto en liquidación de sueldos en Argentina, con la misión de ayudar a trabajadores a entender sus recibos. Tu tarea es analizar la imagen del recibo y convertirla en un JSON claro y completo.

IMPORTANTE: El lenguaje que uses en los campos de análisis debe ser cálido, cercano y fácil de entender para alguien sin conocimientos técnicos. Imagina que le estás explicando a un amigo.

Cuando expliques un porcentaje (ej: un descuento del 11%), siempre añade un ejemplo práctico entre paréntesis. Por ejemplo: "Este es el aporte para tu futura jubilación (es decir, por cada $100.000 de sueldo bruto, se te descuentan $11.000 para este fin)".

Debes responder ÚNICAMENTE con el JSON válido, sin texto adicional antes ni después.

NUEVA TAREA - INFERENCIA DE CONVENIO:
1.  **Analiza pistas:** Busca en el texto de la empresa (Razón Social), en los conceptos de aportes (Ej: "OSECAC", "SEC", "UOCRA", "FATSA") o en los conceptos de pago (Ej: "Adicional Art. 40 CCT 130/75") para adivinar el Convenio Colectivo de Trabajo (CCT).
2.  **Informa tu hallazgo:** En el nuevo campo "inferencias" del JSON, indica el convenio que crees que es y tu nivel de confianza.

Usa EXACTAMENTE esta estructura JSON:
{
   "cabecera": {
     "empresa_nombre": "Nombre o Razón Social",
     "empresa_cuit": "00-00000000-0",
     "empresa_domicilio": "Calle 123, Ciudad, Provincia",
     "empleado_nombre": "Nombre Completo",
     "empleado_cuil": "00-00000000-0",
     "legajo": "12345",
     "fecha_ingreso": "DD/MM/AAAA",
     "antiguedad_reconocida": "Años/Meses",
     "categoria_profesional": "Ej: Docente, Administrativo A, etc.",
     "cct_aplicable": "Ej: CCT 130/75",
     "periodo_abonado": "MM/AAAA",
     "lugar_pago": "Ciudad/Provincia"
   },
   "liquidacion_detallada": {
     "haberes": [
       {
         "codigo": "001",
         "descripcion": "Sueldo Básico",
         "cantidad": "1.0",
         "monto": 559704.10,
         "es_remunerativo": true
       }
     ],
     "retenciones": [
       {
         "codigo": "200",
         "descripcion": "Jubilación",
         "porcentaje": "11%",
         "monto": 193936.19
       }
     ],
     "otros_conceptos": [
       {
         "descripcion": "Asignaciones Familiares / No Remunerativos",
         "monto": 0.0
       }
     ]
   },
   "totales": {
     "total_bruto": 0.0,
     "total_retenciones": 0.0,
     "total_no_remunerativo": 0.0,
     "neto_a_cobrar": 1542946.00,
     "neto_en_letras": "Un millón quinientos..."
   },
   "inferencias": {
      "convenio_sugerido": "Ej: Empleados de Comercio",
      "confianza": "alta | media | baja"
   },
   "auditoria_ia": {
     "analisis_legal": "Un resumen amigable sobre si el recibo parece correcto y qué significa.",
     "alertas_criticas": [
       "Lista de posibles problemas, explicados de forma sencilla."
     ],
     "explicacion_conceptos_complejos": "Explicación de los conceptos más raros que encontraste, como si se lo contaras a alguien que no sabe nada del tema.",
     "puntuacion_confianza_ocr": 0.98
   }
}

Si algún campo no está presente o no es legible, usa null o una cadena vacía, pero mantén la estructura. Para los montos numéricos usa 0.0 si no se encuentra.
El campo 'auditoria_ia' es CRÍTICO: usa tu conocimiento para detectar inconsistencias y explícalas de forma cálida (Ej: 'Veo que tu descuento de Obra Social es del 3% (o sea, $3.000 por cada $100.000 de bruto). ¡Eso es correcto!').''';
    }

    // Lista de candidatos con estrategia (Simple vs Full Proxy)
    final candidates = [
      {'name': 'ocr-claude', 'type': 'simple'},
      {'name': 'claude-proxy', 'type': 'full'},
      {'name': 'claude-vision-ocr', 'type': 'simple'},
      {'name': 'analyze-receipt', 'type': 'simple'},
    ];

    for (final candidate in candidates) {
      final functionName = candidate['name'] as String;
      final type = candidate['type'] as String;
      
      try {
        debugPrint('Invocando Supabase Edge Function: \$functionName (Type: \$type)');
        
        dynamic body;
        if (type == 'simple') {
          // Payload simplificado para función unificada
          body = {
            'image_base64': base64Image,
            'media_type': 'image/jpeg',
            'return': 'structured_json',
            'custom_prompt': promptText, // Intentamos pasar el prompt personalizado
            'prompt': promptText,        // Alternativa de nombre de parámetro
            if (contextoConvenio != null) 'contexto_convenio': contextoConvenio,
          };
        } else {
          // Payload completo para función proxy (claude-proxy)
          // Esta función espera el body exacto de Anthropic
          body = {
            "model": "claude-3-haiku-20240307",
            "max_tokens": 4000,
            "messages": [
              {
                "role": "user",
                "content": [
                  {
                    "type": "text",
                    "text": promptText
                  },
                  {
                    "type": "image",
                    "source": {
                      "type": "base64",
                      "media_type": "image/jpeg",
                      "data": base64Image
                    }
                  }
                ]
              }
            ]
          };
        }
        
        final response = await Supabase.instance.client.functions.invoke(
          functionName,
          body: body,
          headers: apiKey != null ? {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          } : null,
        );
        
        final data = response.data;
        
        if (data == null) {
           throw Exception('Respuesta vacía de Supabase Function (\$functionName)');
        }

        // Procesamiento de respuesta
        if (type == 'full') {
           // Si es proxy, la respuesta suele ser el JSON de Anthropic
           // Necesitamos extraer el contenido
           if (data is Map && data.containsKey('content')) {
              final contentList = data['content'] as List;
              if (contentList.isNotEmpty) {
                 String text = contentList[0]['text'];
                 // Limpiar markdown si es necesario
                 if (text.contains('```json')) {
                    text = text.replaceAll('```json', '').replaceAll('```', '');
                 } else if (text.contains('```')) {
                    text = text.replaceAll('```', '');
                 }
                 return text.trim();
              }
           }
           // Si no tiene la estructura esperada, intentar devolver como está
        }
        
        if (data is Map) {
          return jsonEncode(data);
        } else if (data is String) {
          try {
             // Validar JSON
             jsonDecode(data);
             return data; 
          } catch (_) {
             return data;
          }
        } else {
          return data.toString();
        }

      } catch (e) {
        debugPrint('Error en Supabase Function (\$functionName): \$e');
        if (candidate == candidates.last) {
           debugPrint('Todos los intentos de Supabase Functions fallaron.');
           rethrow;
        }
        continue;
      }
    }
    
    throw Exception('No se pudo invocar ninguna función de OCR en Supabase');
  }
}
