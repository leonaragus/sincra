import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
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

  /// Analiza una imagen usando Claude 3 Haiku y devuelve un JSON string
  /// Implementa llamada a Supabase Edge Function con fallback a proxies
  static Future<String> analyzeReceipt(Uint8List bytes, {String? contextoConvenio}) async {
    // Si la API Key de cliente no está configurada, no fallamos inmediatamente
    // porque la Supabase Function podría tener su propia key.
    // Solo validamos si vamos a usar el método cliente (proxies).
    
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

    // Fallback: Si Supabase Function falla, intentamos método cliente
    // Esto requiere API Key de cliente
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
       // Si no hay key y falló la función, lanzamos el error de función o genérico
       throw Exception('No se pudo procesar imagen. Supabase Function falló y no hay API Key local.');
    }

    final base64Image = base64Encode(imageBytes);
    const mediaType = "image/jpeg"; 
    
    // Lista de URLs a probar en orden (Estrategia Failover)
    final List<String> endpoints = [];
    
    // URL base de Anthropic
    const String anthropicUrl = 'https://api.anthropic.com/v1/messages';
    
    // ========================================================================
    // CAMBIO: USAR SUPABASE EDGE FUNCTION EN LUGAR DE PROXIES
    // ========================================================================
    try {
      debugPrint('Invocando Supabase Edge Function: analyze-receipt');
      
      final response = await Supabase.instance.client.functions.invoke(
        'analyze-receipt',
        body: {
          'image': base64Image,
          'contextoConvenio': contextoConvenio,
        },
      );
      
      final data = response.data;
      
      if (data == null) {
        throw Exception('Respuesta vacía de Supabase Function');
      }
      
      // Si la función devuelve un objeto JSON (Map), lo convertimos a string
      // para mantener compatibilidad con el resto del código que espera JSON String.
      if (data is Map) {
        // Si el JSON tiene un campo 'content' o 'text' específico, lo extraemos.
        // Pero normalmente la función devuelve el objeto JSON del recibo.
        return jsonEncode(data);
      } else if (data is String) {
        // Si devuelve un string, asumimos que es el JSON
        return data;
      } else {
        return data.toString();
      }
    } catch (e) {
      debugPrint('Error en Supabase Function: $e');
      // Si falla la función, intentamos el método antiguo (proxies) como fallback
      // aunque es probable que también falle si no hay API Key configurada.
      debugPrint('Intentando fallback con proxies...');
    }
    
    if (kIsWeb) {
      // 1. Proxy principal (thingproxy) - Más robusto con POST
      endpoints.add('https://thingproxy.freeboard.io/fetch/$anthropicUrl');
      
      // 2. Proxy secundario (corsproxy.io) - Usamos URL codificada para evitar problemas
      // Nota: A veces requiere codificación, a veces no. Probamos ambas si es necesario.
      endpoints.add('https://corsproxy.io/?$anthropicUrl');
      
      // 3. Proxy de respaldo (codetabs)
      endpoints.add('https://api.codetabs.com/v1/proxy?quest=$anthropicUrl');
      
       // 4. Intento directo (último recurso)
      endpoints.add(anthropicUrl);
    } else {
      // En móvil/desktop no hay CORS, ir directo
      endpoints.add('https://api.anthropic.com/v1/messages');
    }
    
    // Usamos el primer endpoint por defecto mientras se implementa la lógica de reintento completa
    // final url = Uri.parse(endpoints.first);

    String promptText = '''Eres un experto auditor de liquidación de sueldos en Argentina. Tu tarea es analizar la imagen del recibo de sueldo y extraer TODA la información en un formato JSON estricto.

Debes responder ÚNICAMENTE con el JSON válido, sin texto adicional antes ni después (ni markdown ```json ... ```).

IMPORTANTE: 
1. Revisa que los totales coincidan con la suma de los items.
2. Si un número es ilegible, usa 0.0 o string vacío según corresponda.
3. El campo "es_remunerativo" en haberes debe ser booleano (true/false).
4. El campo "codigo" puede ser vacío si no existe.
''';

    if (contextoConvenio != null && contextoConvenio.isNotEmpty) {
      promptText += '''
5. COMPARACIÓN CON CONVENIO:
   Aquí tienes los datos oficiales del convenio colectivo aplicable:
   $contextoConvenio
   
   Usa esta información para:
   - Verificar si el sueldo básico coincide con la escala salarial.
   - Auditar si los porcentajes de antigüedad, presentismo y adicionales son correctos.
   - En el campo "auditoria_ia", incluye análisis específico sobre discrepancias con este convenio.
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
     "analisis_legal": "Breve resumen del cumplimiento de normativas vigentes.", 
     "alertas_criticas": [ 
       "Lista de alertas si hay retenciones fuera de rango, faltan aportes, etc." 
     ], 
     "explicacion_conceptos_complejos": "Explicación breve de códigos específicos hallados.", 
     "puntuacion_confianza_ocr": 0.98 
   } 
 }

Si algún campo no está presente o no es legible, usa null o una cadena vacía, pero mantén la estructura. Para los montos numéricos usa 0.0 si no se encuentra.
El campo 'auditoria_ia' es CRÍTICO: usa tu conocimiento de leyes laborales argentinas para detectar inconsistencias reales en los montos (ej: Jubilación debe ser 11%, Obra Social 3%, Ley 19032 3%).''';

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
