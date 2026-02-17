import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:syncra_arg/config/api_keys.dart';

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

  /// Analiza una imagen usando Claude 3 Haiku y devuelve un JSON string
  /// Implementa redundancia de proxies para asegurar conexión
  static Future<String> analyzeReceipt(Uint8List bytes, {String? contextoConvenio}) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Claude API Key no configurada');
    }

    // Optimización de imagen: Redimensionar si es muy grande para evitar timeouts y errores 413
    Uint8List imageBytes = bytes;
    try {
      // Solo procesar si la imagen es mayor a 1MB
      if (bytes.lengthInBytes > 1024 * 1024) {
        final img.Image? image = img.decodeImage(bytes);
        if (image != null) {
          // Redimensionar a un ancho máximo de 1024px manteniendo relación de aspecto
          if (image.width > 1024) {
            final img.Image resized = img.copyResize(image, width: 1024);
            // Comprimir a JPEG con calidad 85
            imageBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
            debugPrint('Imagen redimensionada y comprimida: ${bytes.lengthInBytes} -> ${imageBytes.lengthInBytes} bytes');
          } else {
             // Si el ancho es aceptable pero el archivo es pesado, solo recomprimir
             imageBytes = Uint8List.fromList(img.encodeJpg(image, quality: 85));
             debugPrint('Imagen recomprimida: ${bytes.lengthInBytes} -> ${imageBytes.lengthInBytes} bytes');
          }
        }
      }
    } catch (e) {
      debugPrint('Error al procesar imagen: $e. Se usará la imagen original.');
      // En caso de error, seguimos con la imagen original
    }

    final base64Image = base64Encode(imageBytes);
    const mediaType = "image/jpeg"; 
    
    // Lista de URLs a probar en orden (Estrategia Failover)
    final List<String> endpoints = [];
    
    // URL base de Anthropic
    const String anthropicUrl = 'https://api.anthropic.com/v1/messages';
    
    if (kIsWeb) {
      // 1. Supabase Edge Function (Opción recomendada y segura)
      endpoints.add('https://sstxhajsclwfktyvawmr.supabase.co/functions/v1/claude-proxy');

      // 2. PROXY LOCAL (Respaldo para desarrollo)
      endpoints.add('http://localhost:3000/v1/messages');

      // 2. Vercel Serverless Function (Transparente si se usa Vercel)
      endpoints.add('/api/claude');

      // 3. Proxy de respaldo (thingproxy) - Suele ser el más confiable
      endpoints.add('https://thingproxy.freeboard.io/fetch/$anthropicUrl');

      // 4. Proxy secundario (corsproxy.io) - Usamos URL codificada
      endpoints.add('https://corsproxy.io/?https%3A%2F%2Fapi.anthropic.com%2Fv1%2Fmessages');
      
      // 5. Proxy de respaldo (codetabs) - URL codificada
      endpoints.add('https://api.codetabs.com/v1/proxy?quest=https%3A%2F%2Fapi.anthropic.com%2Fv1%2Fmessages');
      
      // 6. Intento directo (último recurso)
      endpoints.add(anthropicUrl);
    } else {
      // En móvil/desktop no hay CORS, ir directo
      endpoints.add('https://api.anthropic.com/v1/messages');
    }
    
    // Usamos el primer endpoint por defecto mientras se implementa la lógica de reintento completa
    // final url = Uri.parse(endpoints.first);

    String promptText = '''Eres un experto auditor de liquidación de sueldos en Argentina (Ley 20.744 y Convenios Colectivos). Tu tarea es analizar la imagen del recibo de sueldo y extraer TODA la información en un formato JSON estricto, realizando además una auditoría exhaustiva.

Debes responder ÚNICAMENTE con el JSON válido.

INSTRUCCIONES DE EXTRACCIÓN Y CÁLCULO:
1. Extrae todos los datos de cabecera con máxima precisión. Si la "antigüedad" no está explícita pero sí la "fecha de ingreso", calcúlala a la fecha del periodo liquidado.
2. En "liquidacion_detallada", lista CADA concepto. Identifica si es remunerativo, no remunerativo o retención (descuento).
3. Verifica matemáticamente: (Total Haberes Remunerativos + No Remunerativos) - Retenciones = Neto. Si no coincide, indícalo en "auditoria_ia".
4. Si un número es ilegible, intenta deducirlo por el contexto (ej: el 11% de Jubilación suele ser exacto). Si no, usa 0.0.

INSTRUCCIONES DE AUDITORÍA (CRÍTICO):
- Analiza si los descuentos de ley (Jubilación 11%, Ley 19032 3%, Obra Social 3%) son correctos sobre el bruto remunerativo.
- Detecta si hay conceptos no remunerativos que deberían ser remunerativos según la normativa general.
- Busca "Presentismo", "Antigüedad" y otros adicionales comunes y verifica si sus porcentajes parecen razonables.
- Genera un "analisis_legal" detallado y útil para el usuario, no genérico.
''';

    if (contextoConvenio != null && contextoConvenio.isNotEmpty) {
      promptText += '''
5. COMPARACIÓN CON CONVENIO ESPECÍFICO:
   Aquí tienes los datos oficiales del convenio colectivo aplicable:
   $contextoConvenio
   
   Usa esta información para:
   - Verificar si el sueldo básico coincide con la escala salarial.
   - Auditar si los porcentajes de antigüedad, presentismo y adicionales son correctos según este CCT.
   - En "auditoria_ia", sé muy específico sobre las discrepancias encontradas con estos valores.
''';
    }

    promptText += '''
Usa EXACTAMENTE esta estructura JSON:
{ 
   "cabecera": { 
     "empresa_nombre": "Nombre o Razón Social", 
     "empresa_cuit": "00-00000000-0", 
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
   "auditoria_ia": { 
     "analisis_legal": "Texto detallado (mínimo 3 oraciones) sobre el cumplimiento normativo y la corrección de los cálculos.", 
     "alertas_criticas": [ 
       "Lista de alertas si hay retenciones fuera de rango, faltan aportes, etc." 
     ], 
     "explicacion_conceptos_complejos": "Explicación breve de códigos específicos hallados.",
     "sugerencias_mejora": [
       "Recomendaciones prácticas para el empleado."
     ],
     "puntuacion_confianza_ocr": 0.98 
   } 
}

Si algún campo no está presente o no es legible, usa null o una cadena vacía, pero mantén la estructura. Para los montos numéricos usa 0.0 si no se encuentra.
''';

    String? lastError;
    
    // Bucle de intentos (Failover)
    for (final endpoint in endpoints) {
      debugPrint('Intentando conectar con Claude via: $endpoint');
      final url = Uri.parse(endpoint);

      try {
        final body = jsonEncode({
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
                    "media_type": mediaType,
                    "data": base64Image
                  }
                }
              ]
            }
          ]
        });

        final response = await http.post(
          url,
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: body,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          String content = data['content'][0]['text'];
          
          // Limpieza de Markdown si el modelo lo incluye
          if (content.contains('```json')) {
            content = content.replaceAll('```json', '').replaceAll('```', '');
          } else if (content.contains('```')) {
             content = content.replaceAll('```', '');
          }
          
          return content.trim();
        } else {
          // Guardar error para diagnóstico
          String errorMsg = 'Error ${response.statusCode}';
          try {
            final errBody = jsonDecode(response.body);
            if (errBody['error'] != null) {
              errorMsg += ' - ${errBody['error']['message']}';
            }
          } catch (_) {
             errorMsg += ' - ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...';
          }
          
          if (response.statusCode == 401) {
             errorMsg += " (Verifique su API Key)";
             // Si falla auth, no tiene sentido reintentar otros proxies
             throw Exception(errorMsg);
          }

          // Si es un error 405 Method Not Allowed, probablemente el proxy convirtió POST a GET
          if (response.statusCode == 405) {
             errorMsg += " (Proxy incompatible con POST)";
          }
          
          lastError = errorMsg;
          debugPrint('Fallo endpoint $endpoint: $errorMsg');
          // Continuar al siguiente endpoint
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('Excepción endpoint $endpoint: $e');
        // Continuar al siguiente endpoint
      }
    }
    
    // Si llegamos aquí, fallaron todos
    throw Exception('No se pudo conectar con Claude Vision. Último error: $lastError');
  }
}
