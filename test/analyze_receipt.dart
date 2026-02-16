import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../lib/config/api_keys.dart';

void main() async {
  final String imagePath = 'prueba.jpg'; // El usuario debe subir este archivo
  
  print("=== ANÁLISIS DE RECIBO REAL (INTERNAL TEST) ===");
  print("Buscando archivo: $imagePath");

  final file = File(imagePath);
  if (!file.existsSync()) {
    print("❌ ERROR: No se encontró el archivo '$imagePath'.");
    print("Por favor, sube el recibo con ese nombre a la carpeta raíz del proyecto.");
    return;
  }

  print("✅ Archivo encontrado. Leyendo...");
  final bytes = await file.readAsBytes();
  final String base64Image = base64Encode(bytes);
  
  // Detectar tipo MIME (asumimos jpg o png por simplicidad)
  String mediaType = "image/jpeg";
  if (imagePath.toLowerCase().endsWith(".png")) {
    mediaType = "image/png";
  } else if (imagePath.toLowerCase().endsWith(".pdf")) {
    mediaType = "application/pdf"; // Claude soporta PDF text, pero para visión usamos imagen
    print("⚠️ ADVERTENCIA: Este script está optimizado para imágenes (JPG/PNG). PDF puede requerir conversión.");
  }

  final apiKey = ApiKeys.anthropicApiKey;
  
  // Prompt completo (copiado de claude_vision_service.dart para fidelidad)
  const String promptText = '''Eres un experto auditor de liquidación de sueldos en Argentina. Tu tarea es analizar la imagen del recibo de sueldo y extraer TODA la información en un formato JSON estricto.

Debes responder ÚNICAMENTE con el JSON válido, sin texto adicional antes ni después.

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

Si algún campo no está presente o no es legible, usa null o una cadena vacía. Para montos numéricos usa 0.0.''';

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

  print("Enviando a Claude (Vía Directa)... Espere...");

  try {
    // Usamos conexión directa porque estamos en un script de servidor/local
    // Esto valida que la IA entiende el recibo, independientemente del proxy web
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: body,
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['content'][0]['text'];
      print("\n✅ ¡ANÁLISIS COMPLETADO CON ÉXITO!\n");
      print("--- RESULTADO JSON ---");
      print(content);
      print("----------------------");
    } else {
      print("❌ Error en la API: ${response.statusCode}");
      print(response.body);
    }
  } catch (e) {
    print("❌ Excepción: $e");
  }
}
