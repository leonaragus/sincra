import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const apiKey = 'AIzaSyAeCV84XF-KUGfUm-fX_DX0HE2vlYtZY68';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
  
  const prompt = r'''
  Actúa como un analista experto en recibos de sueldo de Argentina.
  Tu tarea es extraer de forma precisa y estructurada toda la información de la imagen.
  
  Estructura JSON requerida:
  {
    "cabecera": {
      "empresa_nombre": "Empresa Falsa SA",
      "empresa_cuit": "30-12345678-9",
      "empresa_domicilio": "Calle Falsa 123",
      "empleado_nombre": "Juan Perez",
      "empleado_cuil": "20-12345678-5",
      "fecha_ingreso": "01/01/2020",
      "categoria": "Administrativo",
      "periodo": "Mayo 2024",
      "metadata_docente": null
    },
    "liquidacion": {
      "haberes": [],
      "retenciones": []
    },
    "totales": {
      "bruto": 150.0,
      "retenciones": 50.0,
      "neto": 100.0
    },
    "inferencias": {
      "convenio": "Empleados de Comercio",
      "confianza": "Alta",
      "resumen_amigable": "Todo bien."
    }
  }

  REGLAS CRÍTICAS: Responde ÚNICAMENTE con el objeto JSON puro, sin texto adicional ni bloques de código markdown.
''';

  try {
    print('Llamando a Gemini 2.5...');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt + '\n\nSimula que leíste la imagen y devuelve este JSON exactamente como se pide.'}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'topP': 0.95,
          'maxOutputTokens': 2048,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rawText = data['candidates'][0]['content']['parts'][0]['text'];
      print('--- RESPUESTA CRUDA DE GEMINI ---');
      print(rawText);
      print('---------------------------------');
      
      // Simulamos la limpieza y parseo
      print('Intentando parsear...');
      try {
        String jsonStr = rawText.trim();
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        
        final mapData = jsonDecode(jsonStr);
        print('Parseo exitoso!');
      } catch (e) {
        print('Error de parseo jsonDecode: $e');
      }
    } else {
      print('Error de API: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('Error general: $e');
  }
}
