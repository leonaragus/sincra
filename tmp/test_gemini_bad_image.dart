import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const apiKey = 'AIzaSyAeCV84XF-KUGfUm-fX_DX0HE2vlYtZY68';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
  
  // 1x1 white pixel base64
  const base64Image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=';

  const prompt = r'''
  Actúa como un analista experto en recibos de sueldo de Argentina.
  Tu tarea es extraer de forma precisa y estructurada toda la información de la imagen.
  
  Estructura JSON requerida:
  {
    "cabecera": {
      "empresa_nombre": "Nombre de la empresa/razón social"
    }
  }
  REGLAS CRÍTICAS: Responde ÚNICAMENTE con el objeto JSON puro, sin texto adicional.
''';

  try {
    print('Llamando a Gemini 2.5 con imagen falsa...');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/png',
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'topP': 0.95,
          'maxOutputTokens': 8192,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Respuesta exitosa:');
      print(jsonEncode(data));
      try {
        final rawText = data['candidates'][0]['content']['parts'][0]['text'];
        print('--- TEXTO DEVUELTO ---');
        print(rawText);
      } catch (e) {
        print('No se pudo extraer el texto: $e');
      }
    } else {
      print('Error de API: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('Error general: $e');
  }
}
