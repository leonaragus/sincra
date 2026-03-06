
import 'dart:typed_data';


/// Contrato (interfaz abstracta) para una Estrategia de Exportación de LSD.
///
/// Es genérico (<T>) para permitir que cada estrategia defina su propio tipo de
/// resultado de liquidación (ej: LiquidacionSanidadResult), manteniendo la
/// seguridad de tipos en toda la arquitectura.
///
/// Cada convenio (Sanidad, Comercio, etc.) deberá tener su propia implementación
/// de esta clase. Esto nos permite centralizar la lógica de selección en LsdService
/// y mantener el código de cada convenio completamente aislado y seguro.
abstract class LsdExportStrategy<T> {

  /// Genera el contenido del archivo TXT del Libro de Sueldos Digital para una
  /// o más liquidaciones, siguiendo las reglas específicas del convenio.
  ///
  /// [liquidaciones]: Lista de resultados de liquidaciones a procesar.
  /// [empresaData]: Mapa con los datos de la empresa ('cuit', 'razonSocial', 'domicilio').
  ///
  /// Retorna un String con el contenido completo del archivo LSD.txt.
  Future<String> generarLsdTxt({
    required List<T> liquidaciones,
    required Map<String, String> empresaData,
  });

  /// Genera el paquete .ZIP completo para ARCA, que incluye el LSD.txt,
  /// los recibos de sueldo en PDF y otros archivos de soporte.
  ///
  /// [liquidaciones]: La lista de liquidaciones a incluir en el paquete.
  /// [empresaData]: Los datos de la empresa.
  /// [generadorReciboPDF]: Una función que, dada una liquidación de tipo <T>,
  ///                      retorna los bytes de su recibo en formato PDF.
  ///
  /// Retorna la ruta del archivo .zip guardado o su nombre.
  Future<String> generarPackARCA({
    required List<T> liquidaciones,
    required Map<String, String> empresaData,
    required Future<Uint8List> Function(T liquidacion) generadorReciboPDF,
  });
}
