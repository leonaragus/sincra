
import 'dart:convert';
import 'dart:io';

void main() async {
  final apiKey = 'AIzaSyAJSp9bwvRFfU_Obw1l5cFtRUWBjNpCA6A';
  final imagePath = r'C:\Users\PC\.gemini\antigravity\brain\a897adb7-1b28-4f62-83ab-6930e85b213d\syncra_audit_report_mockup_1774713615209.png';
  final model = 'gemini-2.5-flash';
  
  print('--- TEST DE AUTO-ANÁLISIS (GEMINI 2.5) ---');
  print('Analizando archivo local: $imagePath');
  
  try {
    final file = File(imagePath);
    if (!await file.exists()) {
      print('ERROR: El archivo no existe.');
      return;
    }
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    print('Enviando a Gemini 2.5...');
    final prompt = 'Analiza esta imagen de una interfaz de usuario y extrae los datos principales en formato JSON (Empresa, CUIT, Health Score, Alertas).';

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
    
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse(url));
    request.headers.set('content-type', 'application/json');
    
    final body = jsonEncode({
      'contents': [{
        'parts': [
          {'text': prompt},
          {'inline_data': {'mime_type': 'image/png', 'data': base64Image}}
        ]
      }]
    });
    
    request.write(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      print('\n¡ÉXITO! Gemini reconoció su propia creación:');
      final data = jsonDecode(responseBody);
      print(data['candidates'][0]['content']['parts'][0]['text']);
    } else {
      print('ERROR (${response.statusCode}): $responseBody');
    }
    client.close();
  } catch (e) {
    print('Error: $e');
  }
}
