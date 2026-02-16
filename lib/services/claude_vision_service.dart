import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ClaudeVisionService {
  static const String _kApiKeyPref = 'claude_api_key';

  /// Guarda la API Key de Claude
  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKeyPref, key);
  }

  /// Obtiene la API Key guardada o del archivo .env
  static Future<String?> getApiKey() async {
    // 1. Prioridad: Key guardada manualmente por el usuario
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_kApiKeyPref);
    if (savedKey != null && savedKey.isNotEmpty) {
      return savedKey;
    }
    
    // 2. Fallback: Key del archivo .env
    return dotenv.env['ANTHROPIC_API_KEY'];
  }

  /// Analiza una imagen usando Claude 3 Haiku y devuelve un JSON string
  static Future<String> analyzeReceipt(Uint8List bytes, {String? contextoConvenio}) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Claude API Key no configurada');
    }

    final base64Image = base64Encode(bytes);

    final url = Uri.parse('https://api.anthropic.com/v1/messages');
    const mediaType = "image/jpeg"; 
    
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
      final content = data['content'][0]['text'];
      return content;
    } else {
      throw Exception('Error Claude: ${response.statusCode} - ${response.body}');
    }
  }
}
