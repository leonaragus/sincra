import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { gemini, claude }

class AiEngineService {
  static const String _geminiModel = 'gemini-2.5-flash'; // Especificado por el usuario
  static const String _claudeModel = 'claude-3-haiku-20240307';

  /// Ejecuta la petición a la IA con lógica de Failover (Gemini -> Claude)
  static Future<String> processImage({
    required Uint8List imageBytes,
    required String prompt,
    AiProvider primaryProvider = AiProvider.gemini,
  }) async {
    try {
      if (primaryProvider == AiProvider.gemini) {
        return await _invokeGemini(imageBytes, prompt);
      } else {
        return await _invokeClaude(imageBytes, prompt);
      }
    } catch (e) {
      debugPrint('AiEngineService: Error con el proveedor primario ($primaryProvider). Intentando failover...');
      
      // Lógica de Failover
      try {
        if (primaryProvider == AiProvider.gemini) {
          return await _invokeClaude(imageBytes, prompt);
        } else {
          return await _invokeGemini(imageBytes, prompt);
        }
      } catch (e2) {
        debugPrint('AiEngineService: Fallaron ambos proveedores. Error final: $e2');
        rethrow;
      }
    }
  }

  static Future<String> _invokeGemini(Uint8List imageBytes, String prompt) async {
    final apiKey = await _getApiKey('gemini_api_key');
    if (apiKey == null || apiKey.isEmpty) throw Exception('API Key de Gemini no configurada.');

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$apiKey');
    
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
                  'mime_type': 'image/jpeg',
                  'data': base64Encode(imageBytes),
                }
              }
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
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception('Error en Gemini (${response.statusCode}): ${response.body}');
    }
  }

  static Future<String> _invokeClaude(Uint8List imageBytes, String prompt) async {
    final apiKey = await _getApiKey('claude_api_key');
    if (apiKey == null || apiKey.isEmpty) throw Exception('API Key de Claude no configurada.');

    final url = Uri.parse('https://api.anthropic.com/v1/messages');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: jsonEncode({
        'model': _claudeModel,
        'max_tokens': 2048,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': base64Encode(imageBytes),
                }
              },
              {'type': 'text', 'text': prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'];
    } else {
      throw Exception('Error en Claude (${response.statusCode}): ${response.body}');
    }
  }

  static Future<String?> _getApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(key);
    
    if (savedKey != null && savedKey.isNotEmpty) return savedKey;

    // Fallback con la clave proporcionada por el usuario (Uso interno/Prueba)
    if (key == 'gemini_api_key') {
      return 'AIzaSyAJSp9bwvRFfU_Obw1l5cFtRUWBjNpCA6A';
    }
    return null;
  }
}
