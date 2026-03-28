import 'dart:convert';
import 'dart:io';

void main() async {
  final apiKey = 'AIzaSyAJSp9bwvRFfU_Obw1l5cFtRUWBjNpCA6A';
  final url = 'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';

  print('Listando modelos disponibles para la clave...');
  
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      final models = data['models'] as List;
      for (var model in models) {
        print('- ${model['name']} (${model['title']})');
      }
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
