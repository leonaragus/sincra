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

  Future<OcrResult> procesarImagen(InputImage inputImage) async {
    try {
      if (kIsWeb) {
        // USAR TESSERACT PARA WEB - OCR REAL
        final imageBytes = await _inputImageToUint8List(inputImage);
        return await _procesarConTesseract(imageBytes);
      } else {
        // USAR ML KIT PARA MÓVIL
        final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);
        return OcrResult(
          texto: recognizedText.text,
          exito: true,
          confianza: _calcularConfianzaPromedio(recognizedText),
          textoCrudo: recognizedText.text
        );
      }
    } catch (e) {
      print("Error en procesamiento OCR: $e");
      return OcrResult(
        texto: "Se detectaron problemas en el reconocimiento, pero mostramos todo lo que pudimos leer:",
        exito: false,
        confianza: 0.0,
        textoCrudo: "Error: $e",
        esParcial: true
      );
    }
  }

  Future<OcrResult> _procesarConTesseract(Uint8List imageBytes) async {
    try {
      // Guardar imagen temporalmente para Tesseract (necesita path de archivo)
      final tempFile = await _guardarImagenTemporal(imageBytes);
      
      // Configurar Tesseract optimizado para recibos argentinos antiguos
      final resultado = await FlutterTesseractOcr.extractText(
        tempFile.path,
        language: "spa", // Español
        args: {
          'psm': '8',    // Modo de segmentación para palabra única (mejor para recibos)
          'oem': '1',    // Motor OCR LSTM (más preciso)
          'tessedit_char_whitelist': '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.,',
        }
      );
      
      if (resultado.isNotEmpty) {
        return OcrResult(
          texto: resultado,
          exito: true,
          confianza: 0.8, // Valor estimado para Tesseract
          textoCrudo: resultado
        );
      } else {
        // INTENTO ALTERNATIVO con configuración más permisiva
        final resultadoAlternativo = await _procesarConTesseractPermisivo(imageBytes);
        if (resultadoAlternativo.isNotEmpty) {
          return OcrResult(
            texto: "⚠️ Reconocimiento parcial:\n\n$resultadoAlternativo\n\nAlgunos datos pueden estar incompletos.",
            exito: false,
            confianza: 0.4,
            textoCrudo: resultadoAlternativo,
            esParcial: true
          );
        }
        
        throw Exception("No se pudo detectar texto en la imagen");
      }
    } catch (e) {
      print("Error en Tesseract: $e");
      // ÚLTIMO INTENTO: Procesamiento básico para extraer algo
      final textoMinimo = await _extraerTextoMinimo(imageBytes);
      
      return OcrResult(
        texto: textoMinimo.isNotEmpty 
            ? "⚠️ Reconocimiento limitado. Datos leídos:\n\n$textoMinimo\n\nEl recibo puede ser muy antiguo o tener baja calidad."
            : "No se pudo leer el recibo. Intente con mejor iluminación o un recibo más nítido.",
        exito: false,
        confianza: 0.1,
        textoCrudo: textoMinimo,
        esParcial: textoMinimo.isNotEmpty
      );
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

  Future<String> _procesarConTesseractPermisivo(Uint8List imageBytes) async {
    try {
      // Configuración ultra permisiva para recibos difíciles
      final tempFile = await _guardarImagenTemporal(imageBytes);
      final resultado = await FlutterTesseractOcr.extractText(
        tempFile.path,
        language: "spa",
        args: {
          'psm': '13',    // Modo de segmentación RAW LINE - máximo esfuerzo
          'oem': '0',     // Motor OCR legacy (más tolerante)
          'tessedit_char_whitelist': '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.,\$',
        }
      );
      return resultado ?? "";
    } catch (e) {
      print("Error en Tesseract permisivo: $e");
      return "";
    }
  }

  Future<String> _extraerTextoMinimo(Uint8List imageBytes) async {
    try {
      // Último intento: solo números y caracteres básicos
      final tempFile = await _guardarImagenTemporal(imageBytes);
      final resultado = await FlutterTesseractOcr.extractText(
        tempFile.path,
        language: "spa",
        args: {
          'psm': '6',     // Modo de bloque uniforme
          'oem': '0',     // Motor legacy
          'tessedit_char_whitelist': '0123456789.,\$' // Solo números y símbolos monetarios
        }
      );
      return resultado ?? "";
    } catch (e) {
      print("Error en extracción mínima: $e");
      return "";
    }
  }

  Future<File> _guardarImagenTemporal(Uint8List imageBytes) async {
    final tempDir = await Directory.systemTemp.createTemp('ocr_temp');
    final tempFile = File('${tempDir.path}/recibo_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(imageBytes);
    return tempFile;
  }

  double _calcularConfianzaPromedio(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return 0.0;
    
    double confianzaTotal = 0.0;
    int contador = 0;
    
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          confianzaTotal += element.confidence ?? 0.0;
          contador++;
        }
      }
    }
    
    return contador > 0 ? confianzaTotal / contador : 0.0;
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

class OcrResult {
  final String texto;
  final bool exito;
  final double confianza;
  final String textoCrudo;
  final bool esParcial;

  OcrResult({
    required this.texto,
    required this.exito,
    required this.confianza,
    required this.textoCrudo,
    this.esParcial = false,
  });

  @override
  String toString() {
    return 'OcrResult(exito: $exito, confianza: $confianza, esParcial: $esParcial, texto: ${texto.length} caracteres)';
  }
}