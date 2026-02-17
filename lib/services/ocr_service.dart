import 'dart:convert';
// import 'dart:typed_data'; // Unused
// import 'dart:io'; // Removed for web compatibility
import 'package:flutter/foundation.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:image_picker/image_picker.dart';
// import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart'; // REMOVED - NO TESSERACT
import 'claude_vision_service.dart';
import 'subscription_service.dart';
import '../models/recibo_model.dart';

class OcrService {
  final ImagePicker _imagePicker = ImagePicker();
  
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

  Future<OcrResult> procesarImagen(XFile imageFile) async {
    try {
      ReciboModel? model;
      String textoCrudo = "";

      final bytes = await imageFile.readAsBytes();
      final Map<String, dynamic> data = await ClaudeVisionService.analyzeReceipt(bytes);
      textoCrudo = jsonEncode(data);
      
      if (data.isNotEmpty) {
        try {
          model = ReciboModel.fromJson(data);
        } catch (e) {
          print("Error parseando JSON de Claude: $e");
        }

        // Registrar uso de OCR (freemium/quota)
        SubscriptionService.registerOcrScan();

        return OcrResult(
          texto: "OCR estructurado (Claude Vision)",
          exito: true,
          confianza: 0.95,
          textoCrudo: textoCrudo,
          reciboModel: model,
        );
      }
      
      return OcrResult(
        texto: "No se obtuvo información estructurada del OCR.",
        exito: false,
        confianza: 0.0,
        textoCrudo: textoCrudo,
        esParcial: true,
      );
    } catch (e) {
      print("Error en procesamiento OCR: $e");
      return OcrResult(
        texto: "Error en el procesamiento OCR: $e",
        exito: false,
        confianza: 0.0,
        textoCrudo: "Error: $e",
        esParcial: true
      );
    }
  }

  // _procesarConTesseract REMOVED
  
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
