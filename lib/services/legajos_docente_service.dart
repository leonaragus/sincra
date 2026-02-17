import 'package:elevar_liquidacion/models/ocr_confirm_result.dart';
import 'package:elevar_liquidacion/services/instituciones_service.dart';
import 'package:intl/intl.dart';

class LegajosDocenteService {
  static Future<void> saveLegajoFromOcr(String cuitInstitucion, OcrConfirmResult ocrResult) async {
    final Map<String, dynamic> legajoData = {
      'nombre': ocrResult.nombre ?? '',
      'cuil': ocrResult.cuil ?? '',
      'fechaIngreso': ocrResult.fechaIngreso != null ? DateFormat('yyyy-MM-dd').format(ocrResult.fechaIngreso!) : null,
      'cargo': ocrResult.cargo?.name,
      'nivel': ocrResult.nivel?.name,
      'zona': ocrResult.zona?.name,
      'cargasFamiliares': ocrResult.cargasFamiliares,
      'horasCatedra': ocrResult.horasCatedra,
      'cantidadCargos': ocrResult.cantidadCargos,
      'codigoRnos': (ocrResult.codigoRnos == null || ocrResult.codigoRnos!.isEmpty) ? null : ocrResult.codigoRnos,
      'valorIndice': ocrResult.overrides.valorIndiceOverride,
      'sueldoBasicoOverride': ocrResult.overrides.sueldoBasicoOverride,
      'puntosCargoOverride': ocrResult.overrides.puntosCargoOverride,
      'puntosHoraCatedraOverride': ocrResult.overrides.puntosHoraCatedraOverride,
    };

    await InstitucionesService.saveLegajoDocente(cuitInstitucion, legajoData);
  }
}
