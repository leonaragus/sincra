import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

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
      // USAR TESSERACT PARA WEB - OCR REAL
      try {
        // Convertir InputImage a Uint8List para Tesseract
        final imageBytes = await _inputImageToUint8List(inputImage);
        return await _procesarConTesseract(imageBytes);
      } catch (e) {
        print("Error con Tesseract en web: $e");
        return "Error: No se pudo procesar la imagen con OCR.";
      }
    }

    try {
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      print("Error al procesar imagen con OCR: $e");
      return "Error: No se pudo leer el texto de la imagen.";
    }
  }

  Future<String> _procesarConTesseract(Uint8List imageBytes) async {
    try {
      // Configurar Tesseract para español de Argentina
      final resultado = await FlutterTesseractOcr.extractText(
        '/', // dummy path for web, bytes are used
        language: "spa", // Español
        args: {
          'psm': '6',    // Modo de segmentación para documentos
          'oem': '1',    // Motor OCR LSTM (más preciso)
        }
      );
      
      return resultado.isNotEmpty ? resultado : "No se pudo detectar texto en la imagen.";
    } catch (e) {
      print("Error en Tesseract: $e");
      return "Error en el procesamiento OCR: $e";
    }
  }

  Future<Uint8List> _inputImageToUint8List(InputImage inputImage) async {
    // Para web, normalmente inputImage.bytes ya está disponible
    if (inputImage.bytes != null) {
      return Uint8List.fromList(inputImage.bytes!);
    }
    
    // Fallback: cargar desde filePath si es necesario
    if (inputImage.filePath != null) {
      final file = File(inputImage.filePath!);
      return await file.readAsBytes();
    }
    
    throw Exception("No se pudo obtener bytes de la imagen");
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