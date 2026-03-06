
import 'dart:typed_data';
import 'dart:convert';

import 'lsd/lsd_export_strategy.dart';
import 'lsd/strategies/sanidad_lsd_strategy.dart';
import 'sanidad_omni_engine.dart';
import '../utils/file_saver.dart';

/// LsdService - Orquestador de Estrategias de Exportación de LSD
///
/// Punto de entrada central para generar archivos de Libro de Sueldos Digital.
/// Selecciona la "estrategia" de exportación según el convenio y delega la tarea.
class LsdService {
  final Map<String, LsdExportStrategy> _strategies = {
    'sanidad': SanidadLsdExportStrategy(),
    // Futuras estrategias se registrarán aquí.
  };

  /// Selecciona la estrategia de exportación adecuada para el ID de convenio dado.
  LsdExportStrategy _getStrategy(String convenioId) {
    if (convenioId.contains('122/75') || convenioId.contains('108/75')) {
      return _strategies['sanidad']!;
    }
    throw Exception('Estrategia de LSD no encontrada para el convenio: $convenioId');
  }

  /// Genera y descarga un archivo de texto LSD para un conjunto de liquidaciones.
  ///
  /// [liquidaciones]: Lista de objetos de resultado de liquidación.
  /// [convenioId]: Identificador del convenio.
  /// [empresaData]: Datos de la empresa.
  /// Devuelve la ruta donde se guardó el archivo.
  Future<String> generarLsdTxt({
    required List<dynamic> liquidaciones,
    required String convenioId,
    required Map<String, String> empresaData,
  }) async {
    final strategy = _getStrategy(convenioId);
    final List<dynamic> liquidacionesCasteadas = _castLiquidaciones(liquidaciones, strategy);

    final contenidoTxt = await strategy.generarLsdTxt(
      liquidaciones: liquidacionesCasteadas,
      empresaData: empresaData,
    );

    final periodo = (liquidaciones.first as dynamic).periodo?.replaceAll(RegExp(r'[^\w]'), '_') ?? 'periodo';
    final fileName = 'LSD_${empresaData['cuit']}_${periodo}.txt';
    final path = await saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(latin1.encode(contenidoTxt)),
      mimeType: 'text/plain',
    );
    return path ?? fileName;
  }

  /// Genera y descarga un paquete ARCA (.zip) completo.
  Future<String> generarPackARCA({
    required List<dynamic> liquidaciones,
    required String convenioId,
    required Map<String, String> empresaData,
    required Future<Uint8List> Function(dynamic liquidacion) generadorReciboPDF,
  }) async {
    final strategy = _getStrategy(convenioId);
    final List<dynamic> liquidacionesCasteadas = _castLiquidaciones(liquidaciones, strategy);

    return strategy.generarPackARCA(
      liquidaciones: liquidacionesCasteadas,
      empresaData: empresaData,
      generadorReciboPDF: generadorReciboPDF,
    );
  }

  /// Realiza un casteo seguro de la lista de liquidaciones al tipo esperado por la estrategia.
  List<dynamic> _castLiquidaciones(List<dynamic> liquidaciones, LsdExportStrategy strategy) {
    if (strategy is SanidadLsdExportStrategy) {
      return liquidaciones.cast<LiquidacionSanidadResult>().toList();
    }
    // Añadir más bloques 'if' para futuras estrategias.
    return liquidaciones;
  }
}
