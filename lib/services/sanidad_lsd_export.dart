import 'lsd/strategies/sanidad_lsd_strategy.dart';
import 'sanidad_omni_engine.dart';
import 'dart:typed_data';
import '../utils/file_saver.dart';

Future<String> sanidadOmniToLsdTxt({
  required LiquidacionSanidadResult liquidacion,
  required String cuitEmpresa,
  required String razonSocial,
  required String domicilio,
}) async {
  final strategy = SanidadLsdExportStrategy();
  return strategy.generarLsdTxt(
    liquidaciones: [liquidacion],
    empresaData: {
      'cuit': cuitEmpresa,
      'razonSocial': razonSocial,
      'domicilio': domicilio,
    },
  );
}

Future<String> generarPackARCA_Sanidad({
  required List<LiquidacionSanidadResult> liquidaciones,
  required String cuitEmpresa,
  required String razonSocial,
  required String domicilio,
  required Future<Uint8List> Function(LiquidacionSanidadResult) generadorReciboPDF,
}) async {
  final strategy = SanidadLsdExportStrategy();
  return strategy.generarPackARCA(
    liquidaciones: liquidaciones,
    empresaData: {
      'cuit': cuitEmpresa,
      'razonSocial': razonSocial,
      'domicilio': domicilio,
    },
    generadorReciboPDF: generadorReciboPDF,
  );
}
