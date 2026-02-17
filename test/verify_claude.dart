import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/config/api_keys.dart';

void main() async {
  print("=== PRUEBA DE CONEXIÓN CON CLAUDE (INTERNAL TEST) ===");
  
  final apiKey = ApiKeys.anthropicApiKey;
  print("API Key cargada: ${apiKey.substring(0, 15)}... (longitud: ${apiKey.length})");

  // Imagen base64 mínima (1x1 pixel blanco JPEG)
  // Esto evita tener que cargar un archivo real para probar la conexión
  const String base64Image = "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwf7+ooooA//2Q==";
  const String mediaType = "image/jpeg";

  // Prompt simplificado para prueba rápida
  const String promptText = "Describe esta imagen en una sola palabra. Responde SOLO esa palabra.";

  final body = jsonEncode({
    "model": "claude-3-haiku-20240307",
    "max_tokens": 100,
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

  // Lista de endpoints a probar (Directo y Proxy)
  final List<Map<String, dynamic>> tests = [
    {
      "name": "Directo (api.anthropic.com)",
      "url": "https://api.anthropic.com/v1/messages"
    },
    {
      "name": "Proxy Web (corsproxy.io) - Simulated Browser",
      "url": "https://corsproxy.io/?https://api.anthropic.com/v1/messages",
      "headers": {
        'Origin': 'http://localhost:3000'
      }
    },
    {
      "name": "ThingProxy (Backup)",
      "url": "https://thingproxy.freeboard.io/fetch/https://api.anthropic.com/v1/messages"
    },
    {
      "name": "CodeTabs (Encoded)",
      "url": "https://api.codetabs.com/v1/proxy?quest=https%3A%2F%2Fapi.anthropic.com%2Fv1%2Fmessages"
    },
    {
      "name": "CorsProxy.io (Encoded)",
      "url": "https://corsproxy.io/?https%3A%2F%2Fapi.anthropic.com%2Fv1%2Fmessages"
    }
  ];

  bool allTestsPassed = true;

  for (final test in tests) {
    print("\n--- Probando conexión: ${test['name']} ---");
    print("URL: ${test['url']}");
    
    final Map<String, String> headers = {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
    };

    if (test['headers'] != null) {
      // Add custom headers like Origin
      (test['headers'] as Map<String, String>).forEach((key, value) {
        headers[key] = value;
      });
    }
    
    try {
      final response = await http.post(
        Uri.parse(test['url']!),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 25));

      print("Status Code: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['content'][0]['text'];
        print("✅ ÉXITO. Respuesta de Claude: '$content'");
      } else {
        print("❌ ERROR HTTP: ${response.body}");
        allTestsPassed = false;
      }
    } catch (e) {
      print("❌ EXCEPCIÓN: $e");
      allTestsPassed = false;
    }
  }

  print("\n=========================================");
  if (allTestsPassed) {
    print("✅✅ TODAS LAS PRUEBAS DE CONEXIÓN PASARON ✅✅");
    print("El sistema está listo para procesar recibos.");
  } else {
    print("⚠️ ALGUNAS PRUEBAS FALLARON ⚠️");
    print("Revise los logs anteriores para diagnosticar.");
  }
}
