import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Iniciando diagnóstico de proxies...');
  
  final targetUrl = 'https://api.anthropic.com/v1/messages';
  final proxies = [
    'https://corsproxy.io/?$targetUrl',
    'https://api.codetabs.com/v1/proxy?quest=$targetUrl',
  ];

  final headers = {
    'x-api-key': 'dummy_key',
    'anthropic-version': '2023-06-01',
    'content-type': 'application/json',
    // Simulamos origen web
    'Origin': 'http://localhost:8080',
  };

  final body = jsonEncode({
    'model': 'claude-3-haiku-20240307',
    'max_tokens': 10,
    'messages': [{'role': 'user', 'content': 'Hello'}]
  });

  for (final proxyUrl in proxies) {
    print('\n---------------------------------------------------');
    print('Probando Proxy: $proxyUrl');
    try {
      final response = await http.post(
        Uri.parse(proxyUrl),
        headers: headers,
        body: body,
      );
      
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 405) {
        print('!!! DETECTADO ERROR 405 METHOD NOT ALLOWED !!!');
      }
    } catch (e) {
      print('Error de conexión: $e');
    }
  }
}
