import 'package:image_picker/image_picker.dart';
import 'claude_vision_service.dart';
import '../models/recibo_model.dart';
import 'ai_engine_service.dart';

class OcrService {
  final ImagePicker _picker = ImagePicker();

  // Resultado del procesamiento de OCR
  late OcrResult result;

  /// Permite al usuario elegir una imagen de la cámara o galería.
  Future<XFile?> obtenerImagen() async {
    return await _picker.pickImage(source: ImageSource.gallery);
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
          reciboModel = await ClaudeVisionService.analyzeAndAuditReceipt(imagen);
        } else {
          reciboModel = await ClaudeVisionService.extractRawModel(imagen);
        }
        textoCrudo = reciboModel.textoCrudo;
      } else {
        // Lógica original (que ahora también usa AiEngineService pero podemos forzar el provider si fuera necesario)
        if (conAuditoria) {
          reciboModel = await ClaudeVisionService.analyzeAndAuditReceipt(imagen);
          textoCrudo = reciboModel.textoCrudo;
        } else {
          reciboModel = await ClaudeVisionService.extractRawModel(imagen);
          textoCrudo = reciboModel.textoCrudo;
        }
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
