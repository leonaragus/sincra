
import 'dart:convert';
import 'dart:io';

void main() async {
  final apiKey = 'AIzaSyAJSp9bwvRFfU_Obw1l5cFtRUWBjNpCA6A';
  final imageUrl = 'https://www.ignacioonline.com.ar/wp-content/uploads/2023/05/Recibo-de-Sueldo-Comercio-Mayo-2023.png';
  final model = 'gemini-2.5-flash';
  
  print('--- INICIANDO TEST REAL CON GEMINI 2.5 ---');
  print('1. Descargando imagen de prueba pública...');
  
  final client = HttpClient();
  try {
    final imgRequest = await client.getUrl(Uri.parse(imageUrl));
    final imgResponse = await imgRequest.close();
    final bytes = await imgResponse.fold<List<int>>([], (p, e) => p..addAll(e));
    final base64Image = base64Encode(bytes);
    print('   Imagen descargada (${bytes.length} bytes)');

    print('\n2. Enviando a Gemini 2.5 con el nuevo prompt...');
    final prompt = '''
  Actúa como un analista experto en recibos de sueldo de Argentina.
  Tu tarea es extraer de forma precisa y estructurada toda la información de la imagen.
  
  Estructura JSON requerida:
  {
    "cabecera": {
      "empresa_nombre": "Nombre de la empresa/razón social",
      "empresa_cuit": "CUIT del empleador",
      "empresa_domicilio": "Dirección fiscal si figura",
      "empleado_nombre": "Apellido y Nombre del trabajador",
      "empleado_cuil": "CUIL del trabajador",
      "fecha_ingreso": "Fecha de ingreso (DD/MM/AAAA)",
      "categoria": "Categoría laboral",
      "periodo": "Mes y año liquidado"
    },
    "liquidacion": {
      "haberes": [
        {"codigo": "...", "descripcion": "...", "cantidad": "...", "monto": 100.0, "es_remunerativo": true}
      ],
      "retenciones": [
        {"codigo": "...", "descripcion": "...", "cantidad": "...", "monto": 50.0}
      ]
    },
    "totales": {
      "bruto": 150.0,
      "retenciones": 50.0,
      "neto": 100.0
    },
    "inferencias": {
      "convenio": "CCT identificado",
      "confianza": "Alta/Media/Baja"
    }
  }

  Responde ÚNICAMENTE con el objeto JSON puro.
  ''';

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
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
      print('\n3. RESULTADO DE IA (JSON REAL):');
      final data = jsonDecode(responseBody);
      final rawText = data['candidates'][0]['content']['parts'][0]['text'];
      print(rawText);
    } else {
      print('ERROR en IA (${response.statusCode}): $responseBody');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
