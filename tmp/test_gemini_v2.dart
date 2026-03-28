import 'dart:convert';
import 'dart:io';

void main() async {
  final apiKey = 'AIzaSyAJSp9bwvRFfU_Obw1l5cFtRUWBjNpCA6A';
  final model = 'gemini-2.5-flash'; 
  final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

  print('Probando API Key de Gemini con el modelo $model...');
  
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(url));
    request.headers.set('content-type', 'application/json');
    
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': 'Hola, responde exactamente con la frase "CONEXIÓN EXITOSA CON GEMINI 2.5" si recibes este mensaje.'}
          ]
        }
      ]
    });
    
    request.write(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      print('¡ÉXITO!');
      final data = jsonDecode(responseBody);
      print('Respuesta de Gemini: ${data['candidates'][0]['content']['parts'][0]['text']}');
    } else {
      print('ERROR (${response.statusCode}):');
      print(responseBody);
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
