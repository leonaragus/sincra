import 'dart:convert';
// import 'dart:typed_data'; // Unused
// import 'dart:io'; // Removed for web compatibility
import 'package:flutter/foundation.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:image_picker/image_picker.dart';
// import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart'; // REMOVED - NO TESSERACT
import 'claude_vision_service.dart';
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

  // Changed signature to use XFile instead of InputImage
  Future<OcrResult> procesarImagen(XFile imageFile, {String? contextoConvenio}) async {
    try {
      // 1. Intentar con Claude Vision si hay API Key configurada
      // SIEMPRE intentar usar Claude primero, especialmente en Web
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
              // Limpieza de bloques de código Markdown si existen
              String jsonStr = text;
              if (jsonStr.contains('```json')) {
                jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
              } else if (jsonStr.contains('```')) {
                jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
              }
              
              final jsonMap = jsonDecode(jsonStr);
              model = ReciboModel.fromJson(jsonMap);
              
              // Si llegamos aquí, el parseo fue exitoso
              return OcrResult(
                texto: text,
                exito: true,
                confianza: 0.95,
                textoCrudo: text,
                reciboModel: model,
              );
            } catch (e) {
              print("Error parseando JSON de Claude: $e");
              // Si falla el parseo, devolvemos error explícito en lugar de éxito falso
              return OcrResult(
                texto: "La IA respondió pero no se pudo interpretar el formato (JSON inválido).",
                exito: false,
                confianza: 0.0,
                textoCrudo: text, // Guardamos el original para debug
                esParcial: true,
                reciboModel: null,
              );
            }
          }
        } catch (e) {
          print("Claude Vision falló: $e");
          // Si estamos en web y falla Claude, reportamos el error directamente
          // NO usamos Tesseract como fallback
          if (kIsWeb) {
             return OcrResult(
              texto: "Error al procesar con Claude Vision: $e. Verifique su conexión y API Key.",
              exito: false,
              confianza: 0.0,
              textoCrudo: "Error: $e",
              esParcial: true
            );
          }
        }
      } else {
         if (kIsWeb) {
             return OcrResult(
              texto: "No se encontró API Key de Claude configurada. El sistema requiere una API Key válida para funcionar.",
              exito: false,
              confianza: 0.0,
              textoCrudo: "Falta API Key",
              esParcial: true
            );
          }
      }

      if (kIsWeb) {
        // En Web, si llegamos aquí es porque no había API Key o falló algo antes y no se retornó
        // Ya no usamos Tesseract.
        return OcrResult(
          texto: "Error crítico: No se pudo procesar la imagen con Claude Vision.",
          exito: false,
          confianza: 0.0,
          textoCrudo: "",
          esParcial: true
        );
      } else {
        // USAR ML KIT PARA MÓVIL (si se rehabilitara)
        return OcrResult(
          texto: "OCR Móvil deshabilitado en versión web.",
          exito: false,
          confianza: 0.0,
          textoCrudo: "",
          esParcial: true
        );
      }
    } catch (e) {
      print("Error en procesamiento OCR: $e");
      return OcrResult(
        texto: "Error general en el procesamiento: $e",
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
