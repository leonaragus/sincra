import 'dart:convert';
import 'dart:typed_data';
// import 'dart:io'; // Removed for web compatibility
import 'package:flutter/foundation.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'claude_vision_service.dart';
import '../models/recibo_model.dart';

class OcrService {
  final ImagePicker _imagePicker = ImagePicker();
  // Inicializamos el recognizer solo si no es web para evitar errores
  // final TextRecognizer? _textRecognizer = 
  //    kIsWeb ? null : TextRecognizer(script: TextRecognitionScript.latin);
  
  // Dummy wrapper to replace InputImage for now
  // on mobile we would need the real one, but for web deploy we skip it
  
  // Future<ImageSource?> _elegirFuenteImagen() async {
  //   return ImageSource.gallery; // Simplificado para ejemplo
  // }

  Future<XFile?> obtenerImagen() async {
    // Permite al usuario elegir entre cámara y galería
    // final source = await _elegirFuenteImagen();
    // if (source == null) return null;
    // For web, usually gallery is safer to start
    return await _imagePicker.pickImage(source: ImageSource.gallery);
  }

  // Changed signature to use XFile instead of InputImage
  Future<OcrResult> procesarImagen(XFile imageFile, {String? contextoConvenio}) async {
    try {
      // 1. Intentar con Claude Vision si hay API Key configurada
      final apiKey = await ClaudeVisionService.getApiKey();
      print("Claude API Key present: ${apiKey != null && apiKey.isNotEmpty}");
      
      if (apiKey != null && apiKey.isNotEmpty) {
        ReciboModel? model;
        String text = "";
        
        try {
          final bytes = await imageFile.readAsBytes();
          text = await ClaudeVisionService.analyzeReceipt(bytes, contextoConvenio: contextoConvenio);
          
          if (text.isNotEmpty) {
            // Intentar parsear el JSON estructurado
            try {
              final jsonMap = jsonDecode(text);
              model = ReciboModel.fromJson(jsonMap);
            } catch (e) {
              print("Error parseando JSON de Claude: $e");
            }

            return OcrResult(
              texto: text,
              exito: true,
              confianza: 0.95, // Alta confianza para Claude
              textoCrudo: text,
              reciboModel: model,
            );
          }
        } catch (e) {
          print("Claude Vision falló: $e");
          // Si estamos en web y falla Claude, NO intentamos Tesseract porque falla
          if (kIsWeb) {
             return OcrResult(
              texto: "Error al procesar con Claude Vision: $e",
              exito: false,
              confianza: 0.0,
              textoCrudo: "Error: $e",
              esParcial: true
            );
          }
          // En móvil podríamos intentar fallback, pero por ahora reportamos el error de Claude
        }
      } else {
         if (kIsWeb) {
             return OcrResult(
              texto: "No se encontró API Key de Claude configurada.",
              exito: false,
              confianza: 0.0,
              textoCrudo: "Falta API Key",
              esParcial: true
            );
          }
      }

      if (kIsWeb) {
        // Tesseract NO funciona bien en web sin configuración extra en index.html
        // Mejor deshabilitarlo para evitar el crash NoSuchMethodError
        return OcrResult(
          texto: "OCR Web fallback (Tesseract) deshabilitado. Verifique API Key de Claude.",
          exito: false,
          confianza: 0.0,
          textoCrudo: "",
          esParcial: true
        );
      } else {
        // USAR TESSERACT PARA WEB - OCR REAL
        final imageBytes = await imageFile.readAsBytes();
        return await _procesarConTesseract(imageBytes, imageFile.path);
      } else {
        // USAR ML KIT PARA MÓVIL
        // Commented out for web deploy compatibility
        return OcrResult(
          texto: "OCR Móvil deshabilitado en versión web.",
          exito: false,
          confianza: 0.0,
          textoCrudo: "",
          esParcial: true
        );
        /*
        final inputImage = InputImage.fromFilePath(imageFile.path);
        final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);
        return OcrResult(
          texto: recognizedText.text,
          exito: true,
          confianza: _calcularConfianzaPromedio(recognizedText),
          textoCrudo: recognizedText.text
        );
        */
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

  Future<OcrResult> _procesarConTesseract(Uint8List imageBytes, String path) async {
    try {
      // Guardar imagen temporalmente para Tesseract (necesita path de archivo)
      // On web, path is a blob url, Tesseract.js might handle it
      
      // Configurar Tesseract optimizado para recibos argentinos antiguos
      final resultado = await FlutterTesseractOcr.extractText(
        path, // On web this is blob:http://...
        language: "spa", // Español
        args: {
          'psm': '6',    // Assume a single uniform block of text.
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
        return OcrResult(
            texto: "No se pudo extraer texto.",
            exito: false,
            confianza: 0.0,
            textoCrudo: "",
            esParcial: true
        );
      }
    } catch (e) {
       return OcrResult(
            texto: "Error Tesseract: $e",
            exito: false,
            confianza: 0.0,
            textoCrudo: "Error: $e",
            esParcial: true
        );
    }
  }
  
  void dispose() {
    // _textRecognizer?.close();
  }
}

class OcrResult {
  final String texto;
  final bool exito;
  final double confianza;
  final String textoCrudo;
  final bool esParcial;
  final ReciboModel? reciboModel; // Nuevo campo para el modelo estructurado

  OcrResult({
    required this.texto,
    required this.exito,
    required this.confianza,
    required this.textoCrudo,
    this.esParcial = false,
    this.reciboModel,
  });
}
