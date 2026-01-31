import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OcrService {
  final ImagePicker _imagePicker = ImagePicker();
  // Inicializamos el recognizer solo si no es web para evitar errores
  final TextRecognizer? _textRecognizer = 
      kIsWeb ? null : TextRecognizer(script: TextRecognitionScript.latin);

  Future<XFile?> obtenerImagen() async {
    // Permite al usuario elegir entre cámara y galería
    final source = await _elegirFuenteImagen();
    if (source == null) return null;

    return await _imagePicker.pickImage(source: source);
  }

  Future<String> procesarImagen(InputImage inputImage) async {
    if (kIsWeb) {
      // MOCK PARA WEB: Como ML Kit no funciona en web, devolvemos un texto de prueba
      await Future.delayed(const Duration(seconds: 1));
      return "RECIBO DE HABERES\nPERIODO: 01/2026\n\nConceptos:\nSueldo Básico   1.200.000,00\nAntigüedad      120.000,00\n\nDeducciones:\nJubilación (11%) 132.000,00\nLey 19032 (3%)   36.000,00\nObra Social (3%) 36.000,00\n\nNETO A COBRAR:  1.116.000,00";
    }

    try {
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      print("Error al procesar imagen con OCR: $e");
      return "Error: No se pudo leer el texto de la imagen.";
    }
  }

  // Helper para que el usuario elija la fuente. Se puede poner en un Dialog.
  Future<ImageSource?> _elegirFuenteImagen() async {
    // Aquí se podría mostrar un diálogo para que el usuario elija.
    // Por simplicidad, devolvemos Galería por defecto.
    return ImageSource.gallery;
  }

  void dispose() {
    _textRecognizer?.close();
  }
}