import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'claude_vision_service.dart';
import '../models/recibo_model.dart';

class OcrService {
  final ImagePicker _picker = ImagePicker();

  // Resultado del procesamiento de OCR
  late OcrResult result;

  /// Permite al usuario elegir entre cámara o galería.
  Future<XFile?> obtenerImagen(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Seleccionar imagen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.amber),
              title: const Text('Cámara'),
              subtitle: const Text('Tomar foto del recibo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.amber),
              title: const Text('Galería'),
              subtitle: const Text('Elegir imagen existente'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return await _picker.pickImage(source: source, imageQuality: 85);
  }

  /// Procesa la imagen usando el servicio de IA (Claude o Gemini).
  /// Acepta un booleano [conAuditoria] para determinar si se debe ejecutar el análisis completo.
  Future<OcrResult> procesarImagen(XFile file, {bool conAuditoria = false, String? contextoConvenio, bool usarGemini = false}) async {
    try {
      final imagen = await file.readAsBytes();
      ReciboModel reciboModel;
      String textoCrudo;

      if (usarGemini) {
        // Si usamos Gemini, pasamos por el motor unificado de AiEngineService directamente
        // o a través de ClaudeVisionService que ahora está unificado.
        // Para respetar la estructura actual, usaremos ClaudeVisionService que ya parsea el modelo.
        if (conAuditoria) {
          reciboModel = await ClaudeVisionService.analyzeAndAuditReceipt(imagen, contexto: contextoConvenio);
        } else {
          reciboModel = await ClaudeVisionService.extractRawModel(imagen, contexto: contextoConvenio);
        }
        textoCrudo = reciboModel.textoCrudo;
      } else {
        // Lógica original (que ahora también usa AiEngineService pero podemos forzar el provider si fuera necesario)
        if (conAuditoria) {
          reciboModel = await ClaudeVisionService.analyzeAndAuditReceipt(imagen, contexto: contextoConvenio);
        } else {
          reciboModel = await ClaudeVisionService.extractRawModel(imagen, contexto: contextoConvenio);
        }
        textoCrudo = reciboModel.textoCrudo;
      }

      return OcrResult(
        exito: true,
        texto: 'JSON procesado y convertido a modelo.',
        textoCrudo: textoCrudo,
        reciboModel: reciboModel,
      );

    } catch (e) {
      return OcrResult(exito: false, texto: e.toString(), textoCrudo: 'Error durante el procesamiento.');
    }
  }
}

class OcrResult {
  final bool exito;
  final String texto;
  final String textoCrudo;
  final ReciboModel? reciboModel;

  OcrResult({
    required this.exito,
    required this.texto,
    required this.textoCrudo,
    this.reciboModel,
  });
}
