import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'ocr_service.dart';

class EmpresaExtractResult {
  final String? razonSocial;
  final String? cuit;
  final String? domicilio;
  final bool hasError;
  final String? error;

  EmpresaExtractResult({
    this.razonSocial,
    this.cuit,
    this.domicilio,
    this.hasError = false,
    this.error,
  });
}

class EmpresaReceiptScanService {
  final OcrService _ocrService = OcrService();

  Future<EmpresaExtractResult> runOcrFromXFile(XFile file) async {
    try {
      // Usamos el contexto general, ya que queremos datos de empresa
      final result = await _ocrService.procesarImagen(file, contextoConvenio: 'General');
      
      if (!result.exito || result.reciboModel == null) {
        return EmpresaExtractResult(
          hasError: true,
          error: result.texto.length > 200 
              ? '${result.texto.substring(0, 200)}...' 
              : result.texto,
        );
      }

      final model = result.reciboModel!;
      return EmpresaExtractResult(
        razonSocial: model.cabecera.empresaNombre,
        cuit: model.cabecera.empresaCuit,
        domicilio: model.cabecera.empresaDomicilio,
      );
    } catch (e) {
      debugPrint('Error en EmpresaReceiptScanService: $e');
      return EmpresaExtractResult(
        hasError: true,
        error: e.toString(),
      );
    }
  }
}
