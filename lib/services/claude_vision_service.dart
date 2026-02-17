import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class ClaudeVisionService {
  static const String _prefsKey = 'claude_vision_api_key';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, key);
  }

  static Future<Map<String, dynamic>> analyzeReceipt(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    final supabaseUrl = SupabaseConfig.url;
    final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;

    // Intentar con múltiples nombres de Edge Function por compatibilidad
    final candidates = <String>[
      'ocr-claude',
      'claude-vision-ocr',
      'analyze-receipt',
    ];

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'apikey': SupabaseConfig.anonKey,
      'Authorization': 'Bearer ${accessToken ?? SupabaseConfig.anonKey}',
    };

    final body = jsonEncode({
      'image_base64': base64Image,
      'media_type': 'image/jpeg',
      'return': 'structured_json',
    });

    for (final fn in candidates) {
      final uri = Uri.parse('$supabaseUrl/functions/v1/$fn');
      try {
        final resp = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 60));

        if (resp.statusCode == 200) {
          final bytes = resp.bodyBytes;
          final text = utf8.decode(bytes);
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          if (decoded is String) {
            final parsed = jsonDecode(decoded);
            return (parsed as Map).cast<String, dynamic>();
          }
          throw Exception('Respuesta inválida del OCR');
        } else if (resp.statusCode == 404) {
          // Probar siguiente candidato
          continue;
        } else {
          final msg = utf8.decode(resp.bodyBytes);
          throw Exception('HTTP ${resp.statusCode}: $msg');
        }
      } catch (e) {
        // Si falla este candidato, probar el siguiente; si es el último, re-lanzar
        if (fn == candidates.last) {
          rethrow;
        }
      }
    }

    throw Exception('No se encontró función OCR en Supabase');
  }
}
