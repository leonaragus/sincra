import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'claude_vision_service.dart';
import '../models/recibo_model.dart';

class OcrService {
  final ImagePicker _picker = ImagePicker();

  // Resultado del procesamiento de OCR
  late OcrResult result;

  /// Permite al usuario elegir una imagen de la cámara o galería.
  Future<XFile?> obtenerImagen() async {
    return await _picker.pickImage(source: ImageSource.gallery);
  }

  /// Procesa la imagen usando el servicio de Claude Vision.
  /// Acepta un booleano [conAuditoria] para determinar si se debe ejecutar el análisis completo.
  Future<OcrResult> procesarImagen(XFile file, {bool conAuditoria = false, String? contextoConvenio}) async {
    try {
      final imagen = await file.readAsBytes();
      ReciboModel reciboModel;
      String textoCrudo;

      if (conAuditoria) {
        // Llama al método que incluye el paso de auditoría y enriquecimiento.
        reciboModel = await ClaudeVisionService.analyzeAndAuditReceipt(imagen);
        textoCrudo = reciboModel.textoCrudo;
      } else {
        // Llama al método de extracción de datos crudos, más rápido y simple.
        reciboModel = await ClaudeVisionService.extractRawModel(imagen);
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
