import 'dart:convert';
import 'package:http/http.dart' as http;

// Copiamos la lógica de la clave para la prueba
class ApiKeys {
  static const String _part1 = 'sk-ant-api03-Ls4oPi3Bt12fzGmvznXpJcaxgl1SrNVCS5lfM4_X7vpvkvBOeb6j1QjMNryrSzVVE2uYF5VN4adcjnxcqj1BEA';
  static const String _part2 = '-oJSiRwAA';

  static String get anthropicApiKey => '$_part1$_part2';
}

void main() async {
  print('Iniciando prueba de conexión con Claude API...');
  final apiKey = ApiKeys.anthropicApiKey;
  print('API Key (primeros 10 chars): ${apiKey.substring(0, 10)}...');

  final url = Uri.parse('https://api.anthropic.com/v1/messages');
  
  final body = jsonEncode({
    "model": "claude-3-haiku-20240307",
    "max_tokens": 100,
    "messages": [
      {
        "role": "user",
        "content": "Hola, responde solo con la palabra 'Funciona'."
      }
    ]
  });

  try {
    print('Enviando request a $url...');
    final response = await http.post(
      url,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: body,
    );

    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      print('✅ PRUEBA EXITOSA: La API Key es válida y funciona.');
    } else {
      print('❌ ERROR: La API respondió con error.');
    }
  } catch (e) {
    print('❌ EXCEPCIÓN: $e');
  }
}
